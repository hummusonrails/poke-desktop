import Foundation
import ScreenCaptureKit
import AppKit

class ScreenshotCapture {
    static func captureInteractive() async -> Attachment? {
        if #available(macOS 14.0, *) {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else { return nil }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(display.width) * 2
                config.height = Int(display.height) * 2

                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                let tempPath = NSTemporaryDirectory() + "poke-screenshot-\(UUID().uuidString).png"
                let rep = NSBitmapImageRep(cgImage: image)
                guard let pngData = rep.representation(using: .png, properties: [:]) else { return nil }
                try pngData.write(to: URL(fileURLWithPath: tempPath))

                return Attachment(filePath: tempPath, mimeType: "image/png")
            } catch {
                return await captureViaScreencaptureCLI()
            }
        } else {
            return await captureViaScreencaptureCLI()
        }
    }

    private static func captureViaScreencaptureCLI() async -> Attachment? {
        let tempPath = NSTemporaryDirectory() + "poke-screenshot-\(UUID().uuidString).png"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-s", tempPath]

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  FileManager.default.fileExists(atPath: tempPath) else { return nil }
            return Attachment(filePath: tempPath, mimeType: "image/png")
        } catch {
            return nil
        }
    }
}
