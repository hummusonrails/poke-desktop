import SwiftUI
import UniformTypeIdentifiers

class ComposerState: ObservableObject {
    @Published var stagedAttachments: [Attachment] = []

    func addAttachment(_ attachment: Attachment) {
        stagedAttachments.append(attachment)
    }
}

struct PanelView: View {
    @ObservedObject var messageStore: MessageStore
    @ObservedObject var composerState: ComposerState
    @State private var composerText = ""
    let onSend: (String, [Attachment]) -> Void
    let onScreenshot: () -> Void
    let onPickFile: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // conversation
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        Button(action: { messageStore.loadMore() }) {
                            Text("Load older messages")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.25))
                                .padding(.vertical, 6)
                                .padding(.horizontal, 14)
                                .background(Color.white.opacity(0.04))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)

                        ForEach(messageStore.messages) { message in
                            MessageBubbleView(message: message, onRetry: nil)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                }
                .onChange(of: messageStore.messages.count) { newCount in
                    if let lastId = messageStore.messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            // divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // composer
            ComposerView(
                text: $composerText,
                stagedAttachments: $composerState.stagedAttachments,
                onSend: {
                    let text = composerText
                    let attachments = composerState.stagedAttachments
                    composerText = ""
                    composerState.stagedAttachments = []
                    onSend(text, attachments)
                },
                onScreenshot: onScreenshot,
                onPickFile: onPickFile,
                onOptionHold: { _ in }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
        .preferredColorScheme(.dark)
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    let attachment = Attachment(filePath: url.path)
                    DispatchQueue.main.async {
                        composerState.addAttachment(attachment)
                    }
                }
            }
            return true
        }
    }
}
