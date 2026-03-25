import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let onRetry: (() -> Void)?

    private let sentColor = Color(red: 0.04, green: 0.52, blue: 1.0)
    private let recvColor = Color.white.opacity(0.08)

    var body: some View {
        HStack {
            if message.isFromMe { Spacer(minLength: 50) }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 5) {
                Text(message.text)
                    .font(.system(size: 13.5, weight: .regular))
                    .lineSpacing(2)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(message.isFromMe ? sentColor : recvColor)
                    .foregroundColor(.white.opacity(message.isFromMe ? 1.0 : 0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // attachments
                ForEach(message.attachments) { attachment in
                    if let thumb = attachment.thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                            Text(attachment.fileName)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                // failed state
                if case .failed(let error) = message.sendStatus {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red.opacity(0.8))
                            .font(.system(size: 11))
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundColor(.red.opacity(0.7))
                        if let onRetry = onRetry {
                            Button("Retry", action: onRetry)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(sentColor)
                        }
                    }
                }

                // timestamp
                Text(message.date, style: .time)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.2))
            }

            if !message.isFromMe { Spacer(minLength: 50) }
        }
    }
}
