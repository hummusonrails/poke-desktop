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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        Button("Load older messages") {
                            messageStore.loadMore()
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                        ForEach(messageStore.messages) { message in
                            MessageBubbleView(message: message, onRetry: nil)
                                .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messageStore.messages.count) { newCount in
                    if let lastId = messageStore.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

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
        .background(Color(nsColor: .windowBackgroundColor))
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
