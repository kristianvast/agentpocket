import XCTest
@testable import AgentPocket

final class MediaEncoderTests: XCTestCase {

    // MARK: - Audio Data URI

    func testEncodeAudioToDataURIDefaultMimeType() {
        let data = Data([0x01, 0x02, 0x03])
        let uri = MediaEncoder.encodeAudioToDataURI(data)

        XCTAssertTrue(uri.hasPrefix("data:audio/wav;base64,"))
        let base64Part = String(uri.dropFirst("data:audio/wav;base64,".count))
        XCTAssertEqual(Data(base64Encoded: base64Part), data)
    }

    func testEncodeAudioToDataURICustomMimeType() {
        let data = Data([0xAA, 0xBB])
        let uri = MediaEncoder.encodeAudioToDataURI(data, mimeType: "audio/mp3")
        XCTAssertTrue(uri.hasPrefix("data:audio/mp3;base64,"))
    }

    func testEncodeAudioToDataURIEmptyData() {
        let uri = MediaEncoder.encodeAudioToDataURI(Data())
        XCTAssertEqual(uri, "data:audio/wav;base64,")
    }

    // MARK: - Audio Content Encoding

    func testEncodeAudioContentWithData() {
        let content = AudioContent(data: Data([0x10, 0x20]), mimeType: "audio/wav")
        let result = MediaEncoder.encodeAudioContent(content)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasPrefix("data:audio/wav;base64,"))
    }

    func testEncodeAudioContentFallsBackToURL() {
        let content = AudioContent(data: nil, url: "https://example.com/audio.wav", mimeType: "audio/wav")
        let result = MediaEncoder.encodeAudioContent(content)
        XCTAssertEqual(result, "https://example.com/audio.wav")
    }

    func testEncodeAudioContentNilDataNilURL() {
        let content = AudioContent(data: nil, url: nil, mimeType: "audio/wav")
        let result = MediaEncoder.encodeAudioContent(content)
        XCTAssertNil(result)
    }

    // MARK: - Image Data URI

    func testEncodeImageToDataURIDefaultMimeType() {
        let data = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let uri = MediaEncoder.encodeImageToDataURI(data)

        XCTAssertTrue(uri.hasPrefix("data:image/jpeg;base64,"))
        let base64Part = String(uri.dropFirst("data:image/jpeg;base64,".count))
        XCTAssertEqual(Data(base64Encoded: base64Part), data)
    }

    func testEncodeImageToDataURIPNG() {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let uri = MediaEncoder.encodeImageToDataURI(data, mimeType: "image/png")
        XCTAssertTrue(uri.hasPrefix("data:image/png;base64,"))
    }

    func testEncodeImageToDataURIEmptyData() {
        let uri = MediaEncoder.encodeImageToDataURI(Data())
        XCTAssertEqual(uri, "data:image/jpeg;base64,")
    }

    // MARK: - Image Content Encoding

    func testEncodeImageContentWithData() {
        let content = ImageContent(data: Data([0xFF, 0xD8]), mimeType: "image/jpeg")
        let result = MediaEncoder.encodeImageContent(content)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasPrefix("data:image/jpeg;base64,"))
    }

    func testEncodeImageContentFallsBackToURL() {
        let content = ImageContent(data: nil, url: "https://example.com/img.png", mimeType: "image/png")
        let result = MediaEncoder.encodeImageContent(content)
        XCTAssertEqual(result, "https://example.com/img.png")
    }

    func testEncodeImageContentNilDataNilURL() {
        let content = ImageContent(data: nil, url: nil, mimeType: "image/jpeg")
        let result = MediaEncoder.encodeImageContent(content)
        XCTAssertNil(result)
    }

    // MARK: - Decode Data URI

    func testDecodeValidDataURI() {
        let original = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F])
        let uri = "data:text/plain;base64,\(original.base64EncodedString())"

        let result = MediaEncoder.decodeDataURI(uri)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.data, original)
        XCTAssertEqual(result?.mimeType, "text/plain")
    }

    func testDecodeAudioDataURI() {
        let audio = Data([0x01, 0x02, 0x03, 0x04])
        let uri = "data:audio/wav;base64,\(audio.base64EncodedString())"

        let result = MediaEncoder.decodeDataURI(uri)
        XCTAssertEqual(result?.data, audio)
        XCTAssertEqual(result?.mimeType, "audio/wav")
    }

    func testDecodeImageDataURI() {
        let image = Data([0xFF, 0xD8, 0xFF])
        let uri = "data:image/jpeg;base64,\(image.base64EncodedString())"

        let result = MediaEncoder.decodeDataURI(uri)
        XCTAssertEqual(result?.data, image)
        XCTAssertEqual(result?.mimeType, "image/jpeg")
    }

    func testDecodeInvalidPrefixReturnsNil() {
        let result = MediaEncoder.decodeDataURI("https://example.com/file")
        XCTAssertNil(result)
    }

    func testDecodeNoSemicolonReturnsNil() {
        let result = MediaEncoder.decodeDataURI("data:text/plainbase64,abc")
        XCTAssertNil(result)
    }

    func testDecodeNotBase64ReturnsNil() {
        let result = MediaEncoder.decodeDataURI("data:text/plain;charset=utf-8,hello")
        XCTAssertNil(result)
    }

    func testDecodeInvalidBase64ReturnsNil() {
        let result = MediaEncoder.decodeDataURI("data:text/plain;base64,!!!invalid!!!")
        XCTAssertNil(result)
    }

    func testDecodeEmptyBase64Data() {
        let result = MediaEncoder.decodeDataURI("data:text/plain;base64,")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.data, Data())
        XCTAssertEqual(result?.mimeType, "text/plain")
    }

    // MARK: - Round-trip Encode/Decode

    func testAudioRoundTrip() {
        let original = Data(repeating: 0xAB, count: 256)
        let uri = MediaEncoder.encodeAudioToDataURI(original, mimeType: "audio/mp3")
        let decoded = MediaEncoder.decodeDataURI(uri)

        XCTAssertEqual(decoded?.data, original)
        XCTAssertEqual(decoded?.mimeType, "audio/mp3")
    }

    func testImageRoundTrip() {
        let original = Data(repeating: 0xCD, count: 512)
        let uri = MediaEncoder.encodeImageToDataURI(original, mimeType: "image/png")
        let decoded = MediaEncoder.decodeDataURI(uri)

        XCTAssertEqual(decoded?.data, original)
        XCTAssertEqual(decoded?.mimeType, "image/png")
    }

    // MARK: - Make Audio Input Content

    func testMakeAudioInputContentStructure() {
        let audio = AudioContent(data: Data([0x01]), mimeType: "audio/wav")
        let result = MediaEncoder.makeAudioInputContent(audio)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?["type"] as? String, "input_audio")

        let inputAudio = result?["input_audio"] as? [String: Any]
        XCTAssertNotNil(inputAudio)
        XCTAssertEqual(inputAudio?["format"] as? String, "wav")
        XCTAssertNotNil(inputAudio?["data"] as? String)
    }

    func testMakeAudioInputContentNilWhenNoData() {
        let audio = AudioContent(data: nil, url: nil, mimeType: "audio/wav")
        let result = MediaEncoder.makeAudioInputContent(audio)
        XCTAssertNil(result)
    }

    // MARK: - Make Image Input Content

    func testMakeImageInputContentStructure() {
        let image = ImageContent(data: Data([0xFF, 0xD8]), mimeType: "image/jpeg")
        let result = MediaEncoder.makeImageInputContent(image)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?["type"] as? String, "image_url")

        let imageURL = result?["image_url"] as? [String: Any]
        XCTAssertNotNil(imageURL)
        let url = imageURL?["url"] as? String
        XCTAssertTrue(url?.hasPrefix("data:image/jpeg;base64,") == true)
    }

    func testMakeImageInputContentNilWhenNoData() {
        let image = ImageContent(data: nil, url: nil, mimeType: "image/jpeg")
        let result = MediaEncoder.makeImageInputContent(image)
        XCTAssertNil(result)
    }

    // MARK: - Make Multimodal Content

    func testMakeMultimodalContentWithText() {
        let contents = [MessageContent(id: "c1", type: .text, data: .plainText("Hello"))]
        let parts = MediaEncoder.makeMultimodalContent(from: contents)

        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts[0]["type"] as? String, "text")
        XCTAssertEqual(parts[0]["text"] as? String, "Hello")
    }

    func testMakeMultimodalContentSkipsNonMediaTypes() {
        let contents = [
            MessageContent(id: "c1", type: .file, data: .file(FileContent(path: "/test"))),
            MessageContent(id: "c2", type: .tool, data: .tool(ToolContent(toolID: "t1", name: "bash", status: .running))),
            MessageContent(id: "c3", type: .reasoning, data: .reasoning(ReasoningContent(text: "thinking"))),
            MessageContent(id: "c4", type: .error, data: .error(ErrorContent(name: "E", message: "err"))),
        ]
        let parts = MediaEncoder.makeMultimodalContent(from: contents)
        XCTAssertTrue(parts.isEmpty)
    }

    func testMakeMultimodalContentMixed() {
        let contents = [
            MessageContent(id: "c1", type: .text, data: .plainText("Describe this")),
            MessageContent(id: "c2", type: .image, data: .image(ImageContent(data: Data([0xFF]), mimeType: "image/png"))),
            MessageContent(id: "c3", type: .audio, data: .audio(AudioContent(data: Data([0x01]), mimeType: "audio/wav"))),
            MessageContent(id: "c4", type: .file, data: .file(FileContent(path: "/skip"))),
        ]
        let parts = MediaEncoder.makeMultimodalContent(from: contents)

        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0]["type"] as? String, "text")
        XCTAssertEqual(parts[1]["type"] as? String, "image_url")
        XCTAssertEqual(parts[2]["type"] as? String, "input_audio")
    }

    func testMakeMultimodalContentEmptyInput() {
        let parts = MediaEncoder.makeMultimodalContent(from: [])
        XCTAssertTrue(parts.isEmpty)
    }

    func testMakeMultimodalContentSkipsMediaWithoutData() {
        let contents = [
            MessageContent(id: "c1", type: .image, data: .image(ImageContent(data: nil, url: nil, mimeType: "image/jpeg"))),
            MessageContent(id: "c2", type: .audio, data: .audio(AudioContent(data: nil, url: nil, mimeType: "audio/wav"))),
        ]
        let parts = MediaEncoder.makeMultimodalContent(from: contents)
        XCTAssertTrue(parts.isEmpty)
    }

    // MARK: - Large Data Encoding

    func testLargeDataRoundTrip() {
        let largeData = Data(repeating: 0x42, count: 100_000)
        let uri = MediaEncoder.encodeAudioToDataURI(largeData)
        let decoded = MediaEncoder.decodeDataURI(uri)

        XCTAssertEqual(decoded?.data.count, 100_000)
        XCTAssertEqual(decoded?.data, largeData)
    }
}
