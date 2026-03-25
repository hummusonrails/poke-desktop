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

    var body: some View {
        VStack(spacing: 12) {
            if let lastReply = messageStore.messages.last(where: { !$0.isFromMe }) {
                Text(lastReply.text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
            } else {
                Text("No messages yet")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            ZStack {
                Circle()
                    .fill(isListening ? Color.green.opacity(0.3) : Color(nsColor: .controlBackgroundColor))
                    .frame(width: 56, height: 56)

                Image(systemName: "mic.fill")
                    .font(.system(size: 22))
                    .foregroundColor(isListening ? .green : .primary)
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
                .frame(width: 56, height: 56)
            }
            .scaleEffect(isListening ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isListening)

            Text("Hold to Talk")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Divider()

            HStack {
                Button(action: onExpandToPanel) {
                    HStack(spacing: 4) {
                        Text("⌘⇧P")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text("Open panel")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onPreferences) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 280, height: 210)
    }
}
