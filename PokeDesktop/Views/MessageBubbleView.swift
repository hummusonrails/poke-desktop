import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let onRetry: (() -> Void)?

    var body: some View {
        HStack {
            if message.isFromMe { Spacer(minLength: 60) }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(message.isFromMe ? Color.blue : Color(nsColor: .controlBackgroundColor))
                    .foregroundColor(message.isFromMe ? .white : .primary)
                    .cornerRadius(12)

                ForEach(message.attachments) { attachment in
                    if let thumb = attachment.thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 150)
                            .cornerRadius(8)
                    } else {
                        Label(attachment.fileName, systemImage: "doc")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if case .failed(let error) = message.sendStatus {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 11))
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        if let onRetry = onRetry {
                            Button("Retry", action: onRetry)
                                .font(.system(size: 10))
                        }
                    }
                }

                Text(message.date, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if !message.isFromMe { Spacer(minLength: 60) }
        }
    }
}
