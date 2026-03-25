import SwiftUI

struct AttachmentChipView: View {
    let attachment: Attachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if let thumb = attachment.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .cornerRadius(4)
            } else {
                Image(systemName: "doc")
                    .frame(width: 32, height: 32)
            }

            Text(attachment.fileName)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
