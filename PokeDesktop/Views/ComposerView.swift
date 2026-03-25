import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    @Binding var stagedAttachments: [Attachment]
    let onSend: () -> Void
    let onScreenshot: () -> Void
    let onPickFile: () -> Void
    let onOptionHold: (Bool) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if !stagedAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(stagedAttachments) { attachment in
                            AttachmentChipView(attachment: attachment) {
                                stagedAttachments.removeAll { $0.id == attachment.id }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            HStack(spacing: 8) {
                Button(action: onPickFile) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                Button(action: onScreenshot) {
                    Image(systemName: "camera")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)

                TextField("Message Poke...", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .onSubmit(onSend)

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(text.isEmpty && stagedAttachments.isEmpty ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty && stagedAttachments.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
