import XCTest
import PDFKit
@testable import ShareSafeCore

private final class PreviewLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [DocumentScanPreview] = []
    func append(_ preview: DocumentScanPreview) { lock.lock(); defer { lock.unlock() }; items.append(preview) }
    var values: [DocumentScanPreview] { lock.lock(); defer { lock.unlock() }; return items }
}

final class ScanPreviewTests: XCTestCase {
    func testPDFPreviewGeometryAndPageOrder() throws {
        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data)!
        var bounds = CGRect(x: 0, y: 0, width: 240, height: 320)
        let context = CGContext(consumer: consumer, mediaBox: &bounds, nil)!
        for _ in 0..<3 {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(bounds)
            context.endPDFPage()
        }
        context.closePDF()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try (data as Data).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let log = PreviewLog()
        let document = try DocumentProcessor.load(url: url, includeNames: false, preview: { log.append($0) })
        XCTAssertEqual(log.values.map(\.pageIndex), [0, 1, 2])
        XCTAssertEqual(log.values.map(\.pageCount), [3, 3, 3])
        for (preview, page) in zip(log.values, document.pages) {
            XCTAssertEqual(preview.image?.width, page.pixelWidth)
            XCTAssertEqual(preview.image?.height, page.pixelHeight)
            XCTAssertNil(preview.text)
        }
    }

    func testTextPreviewIsBoundedButDetectionUsesWholeText() throws {
        let text = String(repeating: "Public information. ", count: 400) + "contact@example.test"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let log = PreviewLog()
        let doc = try DocumentProcessor.load(url: url, includeNames: false, preview: { log.append($0) })
        XCTAssertEqual(log.values.first?.text?.count, 4000)
        XCTAssertNil(log.values.first?.image)
        XCTAssertTrue(doc.findings.contains { $0.value == "contact@example.test" })
    }

    func testImagePreviewAndCancellationBeforeRecognition() async throws {
        let context = DocumentProcessor.makeContext(width: 300, height: 200)!
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try DocumentProcessor.png(context.makeImage()!).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let log = PreviewLog()
        let worker = Task.detached {
            try DocumentProcessor.load(url: url, includeNames: false, preview: {
                log.append($0)
                withUnsafeCurrentTask { $0?.cancel() }
            })
        }
        do { _ = try await worker.value; XCTFail("Cancellation must prevent import") }
        catch is CancellationError {}
        XCTAssertEqual(log.values.count, 1)
        XCTAssertEqual(log.values.first?.image?.width, 300)
        XCTAssertEqual(log.values.first?.image?.height, 200)
    }
}
