import AppKit
import SwiftUI
import Combine
import HotKey
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let prefs = PreferencesManager()
    private lazy var messageStore = MessageStore(prefs: prefs)
    private var panelController: PanelController!
    private let composerState = ComposerState()
    private var hotKey: HotKey!
    private var hasBadge = false
    private var messageSender: MessageSender?
    private var voiceEngine: VoiceEngine!
    private var cancellables = Set<AnyCancellable>()
    private var onboardingWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        voiceEngine = VoiceEngine()

        // cancel speech when read-aloud is toggled off
        prefs.$readAloudEnabled
            .dropFirst()
            .filter { !$0 }
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.voiceEngine.cancelSpeech()
                }
            }
            .store(in: &cancellables)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let popoverView = PopoverView(
            messageStore: messageStore,
            onExpandToPanel: { [weak self] in
                self?.popover.performClose(nil)
                self?.panelController.toggle()
                self?.updateBadge(unread: false)
            },
            onPushToTalk: { [weak self] isRecording in
                guard let self = self else { return }
                Task { @MainActor in
                    if isRecording {
                        self.voiceEngine.startListening()
                    } else {
                        let text = self.voiceEngine.stopListening()
                        guard !text.isEmpty, let sender = self.messageSender else { return }
                        self.messageStore.enterFastPollMode()
                        try? await sender.sendText(text)
                    }
                }
            },
            onPreferences: { [weak self] in
                self?.popover.performClose(nil)
                self?.showPreferences()
            }
        )

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 210)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: popoverView)

        panelController = PanelController {
            PanelView(
                messageStore: self.messageStore,
                composerState: self.composerState,
                onSend: { [weak self] text, attachments in
                    guard let self = self, let sender = self.messageSender else { return }
                    self.messageStore.enterFastPollMode()
                    Task {
                        do {
                            try await sender.sendMessage(text: text, attachments: attachments)
                        } catch {
                            let msg = Message(
                                rowId: 0,
                                text: text,
                                isFromMe: true,
                                date: Date(),
                                attachments: attachments,
                                sendStatus: .failed(error: error.localizedDescription)
                            )
                            await MainActor.run {
                                self.messageStore.messages.append(msg)
                            }
                        }
                    }
                },
                onScreenshot: { [weak self] in
                    Task {
                        if let attachment = await ScreenshotCapture.captureInteractive() {
                            await MainActor.run {
                                self?.composerState.addAttachment(attachment)
                            }
                        }
                    }
                },
                onPickFile: { [weak self] in
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = true
                    panel.canChooseDirectories = false
                    panel.begin { response in
                        guard response == .OK else { return }
                        for url in panel.urls {
                            self?.composerState.addAttachment(Attachment(filePath: url.path))
                        }
                    }
                }
            )
        }

        // global hotkey
        hotKey = HotKey(key: .p, modifiers: [.command, .shift])
        hotKey.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            if self.popover.isShown {
                self.popover.performClose(nil)
            }
            self.panelController.toggle()
            self.updateBadge(unread: false)
        }

        // sparkle auto-updates
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        // start messaging or show onboarding
        if !prefs.hasCompletedOnboarding {
            showOnboarding()
        } else if let handleId = prefs.pokeHandleId, let chatId = prefs.pokeChatId {
            startMessaging(handleId: handleId, chatId: chatId)
        }
    }

    // MARK: - onboarding

    private func showOnboarding() {
        let onboardingView = OnboardingView(
            messageStore: messageStore,
            prefs: prefs,
            onComplete: { [weak self] handleId, identifier, chatId in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
                self?.prefs.pokeHandleIdentifier = identifier
                self?.messageSender = MessageSender(handleIdentifier: identifier)
                self?.startMessaging(handleId: handleId, chatId: chatId)
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Poke Desktop Setup"
        window.contentView = NSHostingView(rootView: onboardingView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    // MARK: - preferences

    @objc private func showPreferences() {
        if let existing = preferencesWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let prefsView = PreferencesView(prefs: prefs)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Poke Desktop Preferences"
        window.contentView = NSHostingView(rootView: prefsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow = window
    }

    // MARK: - messaging

    private func startMessaging(handleId: Int64, chatId: Int64) {
        guard messageStore.openDatabase() else { return }
        messageStore.setHandle(handleId, chatId: chatId)
        prefs.pokeChatId = chatId

        let handles = messageStore.fetchRecentHandles()
        if let handle = handles.first(where: { $0.rowId == handleId }) {
            messageSender = MessageSender(handleIdentifier: handle.identifier)
            prefs.pokeHandleIdentifier = handle.identifier
        } else if let identifier = prefs.pokeHandleIdentifier {
            messageSender = MessageSender(handleIdentifier: identifier)
        }

        // only fires for new messages from polling, not initial load or loadmore
        messageStore.onNewMessages = { [weak self] newMessages in
            guard let self = self else { return }
            for msg in newMessages where !msg.isFromMe {
                if !self.panelController.isVisible && !self.popover.isShown {
                    self.updateBadge(unread: true)
                }
                if self.prefs.readAloudEnabled || self.popover.isShown {
                    Task { @MainActor in
                        self.voiceEngine.speak(msg.text)
                    }
                }
            }
        }

        messageStore.loadInitialMessages()
        messageStore.startPolling()
    }

    // MARK: - status item

    @objc private func togglePopover() {
        guard let event = NSApp.currentEvent, let button = statusItem.button else { return }

        if event.type == .rightMouseUp {
            // right-click show menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit Poke Desktop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil // reset so left-click works next time
            return
        }

        // left-click toggle popover
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            updateBadge(unread: false)
        }
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func updateBadge(unread: Bool) {
        hasBadge = unread
        guard let button = statusItem.button else { return }
        if unread {
            let badge = NSView(frame: NSRect(x: 14, y: 12, width: 8, height: 8))
            badge.wantsLayer = true
            badge.layer?.backgroundColor = NSColor.systemRed.cgColor
            badge.layer?.cornerRadius = 4
            badge.identifier = NSUserInterfaceItemIdentifier("badge")
            button.addSubview(badge)
        } else {
            button.subviews.first { $0.identifier?.rawValue == "badge" }?.removeFromSuperview()
        }
    }
}
