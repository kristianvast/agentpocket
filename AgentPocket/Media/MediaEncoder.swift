import Foundation
import UIKit

// MARK: - MediaEncoder

enum MediaEncoder {

    // MARK: - Audio Encoding

    static func encodeAudioToDataURI(_ data: Data, mimeType: String = "audio/wav") -> String {
        let base64 = data.base64EncodedString()
        return "data:\(mimeType);base64,\(base64)"
    }

    static func encodeAudioContent(_ content: AudioContent) -> String? {
        guard let data = content.data else { return content.url }
        return encodeAudioToDataURI(data, mimeType: content.mimeType)
    }

    // MARK: - Image Encoding

    static func encodeImageToDataURI(
        _ data: Data,
        mimeType: String = "image/jpeg"
    ) -> String {
        let base64 = data.base64EncodedString()
        return "data:\(mimeType);base64,\(base64)"
    }

    static func encodeUIImage(
        _ image: UIImage,
        quality: CGFloat = 0.8,
        maxDimension: CGFloat = 2048
    ) -> String? {
        let resized = resizeIfNeeded(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
        return encodeImageToDataURI(data, mimeType: "image/jpeg")
    }

    static func encodeImageContent(_ content: ImageContent) -> String? {
        guard let data = content.data else { return content.url }
        return encodeImageToDataURI(data, mimeType: content.mimeType)
    }

    // MARK: - OpenAI-Compatible API Format

    static func makeAudioInputContent(_ content: AudioContent) -> [String: Any]? {
        guard let dataURI = encodeAudioContent(content) else { return nil }
        return [
            "type": "input_audio",
            "input_audio": [
                "data": dataURI,
                "format": formatFromMimeType(content.mimeType),
            ],
        ]
    }

    static func makeImageInputContent(_ content: ImageContent) -> [String: Any]? {
        guard let dataURI = encodeImageContent(content) else { return nil }
        return [
            "type": "image_url",
            "image_url": [
                "url": dataURI,
            ],
        ]
    }

    static func makeMultimodalContent(from messageContent: [MessageContent]) -> [[String: Any]] {
        var parts: [[String: Any]] = []

        for content in messageContent {
            switch content.data {
            case .text(let textContent):
                parts.append([
                    "type": "text",
                    "text": textContent.text,
                ])

            case .audio(let audioContent):
                if let audioPart = makeAudioInputContent(audioContent) {
                    parts.append(audioPart)
                }

            case .image(let imageContent):
                if let imagePart = makeImageInputContent(imageContent) {
                    parts.append(imagePart)
                }

            case .file, .tool, .reasoning, .error:
                break
            }
        }

        return parts
    }

    // MARK: - Decode

    static func decodeDataURI(_ uri: String) -> (data: Data, mimeType: String)? {
        guard uri.hasPrefix("data:") else { return nil }

        let withoutPrefix = String(uri.dropFirst(5))
        guard let semicolonIndex = withoutPrefix.firstIndex(of: ";") else { return nil }

        let mimeType = String(withoutPrefix[withoutPrefix.startIndex..<semicolonIndex])
        let afterSemicolon = withoutPrefix[withoutPrefix.index(after: semicolonIndex)...]

        guard afterSemicolon.hasPrefix("base64,") else { return nil }
        let base64String = String(afterSemicolon.dropFirst(7))

        guard let data = Data(base64Encoded: base64String) else { return nil }
        return (data, mimeType)
    }

    // MARK: - Private

    private static func formatFromMimeType(_ mimeType: String) -> String {
        switch mimeType {
        case "audio/wav", "audio/x-wav", "audio/wave":
            return "wav"
        case "audio/mp3", "audio/mpeg":
            return "mp3"
        case "audio/ogg":
            return "ogg"
        case "audio/flac":
            return "flac"
        case "audio/webm":
            return "webm"
        default:
            return "wav"
        }
    }

    private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestEdge = max(size.width, size.height)

        guard longestEdge > maxDimension else { return image }

        let scale = maxDimension / longestEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
