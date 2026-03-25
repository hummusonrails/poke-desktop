import SwiftUI
import ServiceManagement

struct OnboardingView: View {
    @ObservedObject var messageStore: MessageStore
    @ObservedObject var prefs: PreferencesManager
    let onComplete: (Int64, String, Int64) -> Void  // handleId, identifier, chatId

    @State private var step = 0
    @State private var selectedHandle: (rowId: Int64, identifier: String, chatId: Int64)?
    @State private var handles: [(rowId: Int64, identifier: String, chatId: Int64)] = []
    @State private var appeared = false
    @State private var accessDenied = false

    private let accentGreen = Color(red: 0.18, green: 0.72, blue: 0.53)
    private let accentTeal = Color(red: 0.12, green: 0.56, blue: 0.58)

    var body: some View {
        ZStack {
            // subtle gradient background
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95),
                    accentGreen.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // app icon
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                    .scaleEffect(appeared ? 1.0 : 0.8)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appeared)

                Spacer().frame(height: 20)

                // title
                Text("Poke Desktop")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .opacity(appeared ? 1.0 : 0.0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)

                Spacer().frame(height: 6)

                // subtitle
                Text(step == 0 ? "Let's get you set up" : "Almost there")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.3), value: step)

                Spacer().frame(height: 8)

                // step indicator
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? accentGreen : Color.secondary.opacity(0.2))
                            .frame(width: i == step ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
                    }
                }
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)

                Spacer().frame(height: 28)

                // content card
                Group {
                    switch step {
                    case 0:
                        fullDiskAccessStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case 1:
                        handleSelectionStep
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    default:
                        EmptyView()
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                )
                .padding(.horizontal, 32)
                .opacity(appeared ? 1.0 : 0.0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)

                Spacer()
            }
        }
        .frame(width: 480, height: 460)
        .onAppear { appeared = true }
    }

    // MARK: - step 1 full disk access

    private var fullDiskAccessStep: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 18))
                    .foregroundColor(accentTeal)
                Text("Full Disk Access")
                    .font(.system(size: 15, weight: .semibold))
            }

            Text("Poke Desktop reads your iMessage conversations to connect with Poke. This requires Full Disk Access permission.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                            .font(.system(size: 12, weight: .medium))
                        Text("Open System Settings")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(accentGreen)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if messageStore.openDatabase() {
                        accessDenied = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            handles = messageStore.fetchRecentHandles()
                            step = 1
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            accessDenied = true
                        }
                    }
                }) {
                    Text("I've granted access — continue")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            if accessDenied {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                    Text("Access not yet granted. Open System Settings and enable Full Disk Access for Poke Desktop.")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - step 2 handle selection

    private var handleSelectionStep: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "message")
                    .font(.system(size: 18))
                    .foregroundColor(accentTeal)
                Text("Select your Poke conversation")
                    .font(.system(size: 15, weight: .semibold))
            }

            if handles.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No conversations found. Send a message to Poke in Messages.app first, then relaunch.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(handles, id: \.rowId) { handle in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedHandle = handle
                                }
                            }) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(selectedHandle?.rowId == handle.rowId ? accentGreen : .secondary.opacity(0.4))
                                    Text(handle.identifier)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedHandle?.rowId == handle.rowId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(accentGreen)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedHandle?.rowId == handle.rowId
                                            ? accentGreen.opacity(0.08)
                                            : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(selectedHandle?.rowId == handle.rowId
                                            ? accentGreen.opacity(0.3)
                                            : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 160)
            }

            if let selected = selectedHandle {
                Button(action: {
                    prefs.hasCompletedOnboarding = true
                    if prefs.autoLaunchEnabled {
                        try? SMAppService.mainApp.register()
                    }
                    onComplete(selected.rowId, selected.identifier, selected.chatId)
                }) {
                    HStack(spacing: 6) {
                        Text("Get started")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(accentGreen)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
