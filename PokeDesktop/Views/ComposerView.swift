import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    @Binding var stagedAttachments: [Attachment]
    let onSend: () -> Void
    let onScreenshot: () -> Void
    let onPickFile: () -> Void
    let onOptionHold: (Bool) -> Void

    private let accentBlue = Color(red: 0.04, green: 0.52, blue: 1.0)

    var body: some View {
        VStack(spacing: 8) {
            // staged attachments
            if !stagedAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(stagedAttachments) { attachment in
                            AttachmentChipView(attachment: attachment) {
                                stagedAttachments.removeAll { $0.id == attachment.id }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }

            // input row
            HStack(spacing: 10) {
                Button(action: onPickFile) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
                .buttonStyle(.plain)

                Button(action: onScreenshot) {
                    Image(systemName: "camera")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
                .buttonStyle(.plain)

                TextField("Message Poke...", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onSubmit(onSend)

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(text.isEmpty && stagedAttachments.isEmpty ? .white.opacity(0.15) : accentBlue)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty && stagedAttachments.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }
}
