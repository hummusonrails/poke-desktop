import SwiftUI
import AppKit

// nsview that tracks mousedown/mouseup for push-to-talk
struct PushToTalkButton: NSViewRepresentable {
    let isListening: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    func makeNSView(context: Context) -> PushToTalkNSView {
        let view = PushToTalkNSView()
        view.onPress = onPress
        view.onRelease = onRelease
        return view
    }

    func updateNSView(_ nsView: PushToTalkNSView, context: Context) {
        nsView.onPress = onPress
        nsView.onRelease = onRelease
    }
}

class PushToTalkNSView: NSView {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        onPress?()
    }

    override func mouseUp(with event: NSEvent) {
        onRelease?()
    }
}

struct PopoverView: View {
    @ObservedObject var messageStore: MessageStore
    let onExpandToPanel: () -> Void
    let onPushToTalk: (Bool) -> Void
    let onPreferences: () -> Void

    @State private var isListening = false

    private let accentTeal = Color(red: 0.18, green: 0.72, blue: 0.53)

    var body: some View {
        VStack(spacing: 14) {
            // last reply
            if let lastReply = messageStore.messages.last(where: { !$0.isFromMe }) {
                Text(lastReply.text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
            } else {
                Text("No messages yet")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
            }

            // mic button
            ZStack {
                Circle()
                    .fill(isListening ? accentTeal.opacity(0.2) : Color.white.opacity(0.06))
                    .frame(width: 58, height: 58)

                Circle()
                    .stroke(isListening ? accentTeal.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1.5)
                    .frame(width: 58, height: 58)

                Image(systemName: "mic.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isListening ? accentTeal : .white.opacity(0.7))
                    .allowsHitTesting(false)

                PushToTalkButton(
                    isListening: isListening,
                    onPress: {
                        isListening = true
                        onPushToTalk(true)
                    },
                    onRelease: {
                        isListening = false
                        onPushToTalk(false)
                    }
                )
                .frame(width: 58, height: 58)
            }
            .scaleEffect(isListening ? 1.08 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isListening)

            Text("Hold to Talk")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
                .textCase(.uppercase)
                .tracking(0.5)

            // footer
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            HStack {
                Button(action: onExpandToPanel) {
                    HStack(spacing: 5) {
                        Text("⌘⇧P")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.25))
                        Text("Open panel")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.25))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 10) {
                    Button(action: onPreferences) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)

                    Button(action: { NSApp.terminate(nil) }) {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(width: 280, height: 220)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
        .preferredColorScheme(.dark)
    }
}
