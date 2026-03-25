import AppKit
import SwiftUI

class PanelController {
    private var panel: PokePanel?
    private var contentViewProvider: (() -> NSView)?
    private var escapeMonitor: Any?

    var isVisible: Bool { panel?.isVisible ?? false }

    init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        self.contentViewProvider = {
            NSHostingView(rootView: content())
        }
    }

    func toggle() {
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil {
            createPanel()
        }
        guard let panel = panel, let screen = NSScreen.main else { return }

        let panelWidth: CGFloat = 380
        let screenFrame = screen.visibleFrame

        panel.setFrame(NSRect(
            x: screenFrame.maxX,
            y: screenFrame.minY,
            width: panelWidth,
            height: screenFrame.height
        ), display: false)
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 1.0, 0.3, 1.0)
            panel.animator().setFrame(NSRect(
                x: screenFrame.maxX - panelWidth,
                y: screenFrame.minY,
                width: panelWidth,
                height: screenFrame.height
            ), display: true)
        }

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.hide()
                return nil
            }
            return event
        }
    }

    func hide() {
        guard let panel = panel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(NSRect(
                x: screenFrame.maxX,
                y: screenFrame.minY,
                width: 380,
                height: screenFrame.height
            ), display: true)
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
        })
    }

    private func createPanel() {
        let panel = PokePanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = contentViewProvider?()
        panel.isReleasedWhenClosed = false
        contentViewProvider = nil // only need it once

        self.panel = panel
    }
}

class PokePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
