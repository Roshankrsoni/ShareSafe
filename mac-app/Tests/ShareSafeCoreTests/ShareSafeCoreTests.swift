import XCTest
import CoreGraphics
import CoreText
import PDFKit
import ImageIO
import UniformTypeIdentifiers
@testable import ShareSafeCore

final class ShareSafeCoreTests: XCTestCase {
    let detector = SensitiveDetector(includeNames: false)

    func testEmailAndPhoneDetectionWithUnicodePrefix() {
        let text = "🔒 Contact zoë: hello@example.com or +1 415-555-0182."
        let result = detector.detect(text)
        XCTAssertEqual(result.map(\.kind), [.email, .phone])
        for finding in result { XCTAssertEqual((text as NSString).substring(with: finding.range), finding.value) }
    }
    func testCardValidationAndFalsePositives() {
        XCTAssertTrue(SensitiveDetector.isValidCard("4111 1111 1111 1111"))
        XCTAssertFalse(SensitiveDetector.isValidCard("4111 1111 1111 1112"))
        XCTAssertFalse(SensitiveDetector.isValidCard("0000 0000 0000 0000"))
        XCTAssertFalse(SensitiveDetector.isValidCard("123"))
    }
    func testIdentityDoesNotBecomePhone() {
        let result = detector.detect("SSN 123-45-6789")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.kind, .identity)
    }
    func testUnicodeRedactionAndKeepDecision() {
        let text = "🔒 café\nhello@example.com and keep@example.org"
        var findings = detector.detect(text)
        findings[0].decision = .redact; findings[1].decision = .keep
        XCTAssertEqual(TextRedactor.redact(text, findings: findings, aliases: false), "🔒 café\n[REDACTED] and keep@example.org")
    }
    func testAliasesAreConsistentAndDistinct() {
        let text = "a@example.com A@example.com b@example.com"
        var findings = detector.detect(text)
        for i in findings.indices { findings[i].decision = .redact }
        XCTAssertEqual(TextRedactor.redact(text, findings: findings, aliases: true), "[EMAIL_1] [EMAIL_1] [EMAIL_2]")
    }
    func testOverlappingRedactionsCoverUnion() {
        let findings = [Finding(kind: .custom, value: "ABCDEF", range: NSRange(location: 0, length: 6), decision: .redact), Finding(kind: .custom, value: "DEFGHI", range: NSRange(location: 3, length: 6), decision: .redact)]
        XCTAssertEqual(TextRedactor.redact("ABCDEFGHI rest", findings: findings, aliases: true), "[REDACTED] rest")
    }
    func testExactTextEscapesRegexAndFindsRepeatedUnicode() {
        let text = "A+B (private) 🔑 A+B"
        let ranges = SensitiveDetector.exactMatches("A+B", in: text)
        XCTAssertEqual(ranges.count, 2)
        XCTAssertTrue(SensitiveDetector.exactMatches("  ", in: text).isEmpty)
    }
    func testExportGateRequiresAllDecisionsAndPages() throws {
        var doc = textDocument("a@example.com")
        XCTAssertThrowsError(try SafeExporter.export(doc))
        doc.findings[0].decision = .redact
        XCTAssertFalse(doc.canExport)
        doc.pages[0].reviewed = true
        XCTAssertTrue(doc.canExport)
        let result = try SafeExporter.export(doc)
        XCTAssertEqual(String(data: result.data, encoding: .utf8), "[REDACTED]")
        XCTAssertEqual(result.sha256.count, 64)
    }
    func testZeroFindingsStillNeedsHumanReview() {
        var doc = textDocument("Nothing detected is not proof of privacy.")
        XCTAssertFalse(doc.canExport)
        doc.pages[0].reviewed = true
        XCTAssertTrue(doc.canExport)
    }
    func testCustomRuleInvalidatesReviewAndDoesNotDuplicate() {
        var doc = textDocument("Internal reference BLUEBIRD")
        doc.pages[0].reviewed = true
        XCTAssertEqual(DocumentProcessor.addExactTerm("BLUEBIRD", to: &doc), 1)
        XCTAssertFalse(doc.pages[0].reviewed)
        XCTAssertEqual(DocumentProcessor.addExactTerm("BLUEBIRD", to: &doc), 0)
    }
    func testPNGExportMasksAndDropsMetadata() throws {
        let image = try fixtureImage()
        let input = try DocumentProcessor.png(image)
        var doc = ReviewDocument(name: "image.png", kind: .image, pages: [DocumentPage(index: 0, imageData: input, pixelWidth: 200, pixelHeight: 100, text: "")], findings: [])
        doc.pages[0].reviewed = true
        doc.masks = [ManualMask(pageIndex: 0, rect: CGRect(x: 0.1, y: 0.6, width: 0.3, height: 0.2))]
        let result = try SafeExporter.export(doc)
        let output = try DocumentProcessor.image(from: result.data)
        XCTAssertTrue(SafeExporter.verifyBlackPixels(output, rects: [SafeExporter.pixelRect(doc.masks[0].rect, width: 200, height: 100)]))
        XCTAssertEqual(result.fileExtension, "png")
        let source = CGImageSourceCreateWithData(result.data as CFData, nil)!
        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        XCTAssertNil(metadata?[kCGImagePropertyGPSDictionary])
        XCTAssertNil((metadata?[kCGImagePropertyExifDictionary] as? [String: Any])?["UserComment"])
    }
    func testPDFRoundTripRemovesTextMetadataAndAnnotations() throws {
        let sourceData = try fixturePDF()
        let original = PDFDocument(data: sourceData)!
        original.documentAttributes = [PDFDocumentAttribute.authorAttribute: "Secret author", PDFDocumentAttribute.subjectAttribute: "Secret subject"]
        let annotation = PDFAnnotation(bounds: CGRect(x: 10, y: 10, width: 20, height: 20), forType: .link, withProperties: nil)
        annotation.contents = "Hidden secret note"
        original.page(at: 0)!.addAnnotation(annotation)
        let input = original.dataRepresentation()!
        let url = temporaryURL("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try input.write(to: url)
        var doc = try DocumentProcessor.load(url: url, includeNames: false)
        XCTAssertTrue(doc.findings.contains { $0.kind == .email })
        for i in doc.findings.indices { doc.findings[i].decision = .redact }
        for i in doc.pages.indices { doc.pages[i].reviewed = true }
        let exported = try SafeExporter.export(doc)
        let pdf = PDFDocument(data: exported.data)!
        XCTAssertEqual(pdf.pageCount, 1)
        XCTAssertTrue((pdf.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(pdf.page(at: 0)!.annotations.isEmpty)
        XCTAssertNotEqual(pdf.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String, "Secret author")
        XCTAssertEqual(try Data(contentsOf: url), input, "Original must not change")
        let exportedURL = temporaryURL("pdf")
        defer { try? FileManager.default.removeItem(at: exportedURL) }
        try exported.data.write(to: exportedURL)
        let rescanned = try DocumentProcessor.load(url: exportedURL, includeNames: false)
        XCTAssertFalse(rescanned.pages[0].text.contains("secret@example.com"), "OCR must not recover the covered address")
        XCTAssertTrue(rescanned.pages[0].text.contains("Public"), "Unredacted content must remain legible: \(rescanned.pages[0].text)")
    }
    func testRotatedPDFKeepsGeometryAndMaskAlignment() throws {
        let pdf = PDFDocument(data: try fixturePDF())!
        pdf.page(at: 0)!.rotation = 90
        let url = temporaryURL("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try pdf.dataRepresentation()!.write(to: url)
        var doc = try DocumentProcessor.load(url: url, includeNames: false)
        XCTAssertEqual(doc.pages[0].pointWidth, 792)
        XCTAssertEqual(doc.pages[0].pointHeight, 612)
        // A full-page manual mask tests rotated coordinate coverage independently of OCR orientation.
        doc.masks = [ManualMask(pageIndex: 0, rect: CGRect(x: 0, y: 0, width: 1, height: 1))]
        for i in doc.findings.indices { doc.findings[i].decision = .redact }
        doc.pages[0].reviewed = true
        let output = try SafeExporter.export(doc)
        let result = PDFDocument(data: output.data)!
        XCTAssertEqual(result.page(at: 0)!.bounds(for: .mediaBox).width, 792)
    }
    func testInvalidPDFRejected() throws {
        let url = temporaryURL("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a pdf".utf8).write(to: url)
        XCTAssertThrowsError(try DocumentProcessor.load(url: url, includeNames: false))
    }
    func testPDFWithFormOrCommentRequiresFlattening() throws {
        let pdf = PDFDocument(data: try fixturePDF())!
        let annotation = PDFAnnotation(bounds: CGRect(x: 50, y: 50, width: 100, height: 100), forType: .freeText, withProperties: nil)
        annotation.contents = "Visible private note"
        pdf.page(at: 0)!.addAnnotation(annotation)
        let url = temporaryURL("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try pdf.dataRepresentation()!.write(to: url)
        XCTAssertThrowsError(try DocumentProcessor.load(url: url, includeNames: false)) { error in
            guard case ShareSafeError.preparationRequired = error else { return XCTFail("Expected a review-copy prompt") }
        }
    }
    func testCroppedPDFPreservesCropSizeAndText() throws {
        let pdf = PDFDocument(data: try fixturePDF())!
        pdf.page(at: 0)!.setBounds(CGRect(x: 30, y: 400, width: 500, height: 300), for: .cropBox)
        let url = temporaryURL("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try pdf.dataRepresentation()!.write(to: url)
        var doc = try DocumentProcessor.load(url: url, includeNames: false)
        XCTAssertEqual(doc.pages[0].pointWidth, 500)
        XCTAssertEqual(doc.pages[0].pointHeight, 300)
        XCTAssertTrue(doc.pages[0].text.contains("Public"))
        for i in doc.findings.indices { doc.findings[i].decision = .redact }
        doc.pages[0].reviewed = true
        let result = try SafeExporter.export(doc)
        let output = PDFDocument(data: result.data)!
        XCTAssertEqual(output.page(at: 0)!.bounds(for: .mediaBox).size, CGSize(width: 500, height: 300))
    }
    func testOversizedTextRejected() throws {
        let url = temporaryURL("txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 65, count: 1_000_001).write(to: url)
        XCTAssertThrowsError(try DocumentProcessor.load(url: url, includeNames: false))
    }
    func testEncryptedPDFRejected() throws {
        let pdf = PDFDocument(data: try fixturePDF())!
        let url = temporaryURL("pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(pdf.write(to: url, withOptions: [.userPasswordOption: "secret", .ownerPasswordOption: "owner"]))
        XCTAssertThrowsError(try DocumentProcessor.load(url: url, includeNames: false))
    }
    func testUnsupportedFileRejected() throws {
        let url = temporaryURL("docx")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("text".utf8).write(to: url)
        XCTAssertThrowsError(try DocumentProcessor.load(url: url, includeNames: false))
    }
    func testPixelRectsPadAndClamp() {
        let rect = SafeExporter.pixelRect(CGRect(x: 0, y: 0, width: 0.1, height: 0.1), width: 100, height: 100)
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 13, height: 13))
    }
    func testCancellationPreventsExport() async throws {
        var doc = textDocument("private@example.com")
        doc.findings[0].decision = .redact; doc.pages[0].reviewed = true
        let task = Task {
            try await Task.sleep(nanoseconds: 100_000_000)
            return try SafeExporter.export(doc)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancellation must throw") } catch is CancellationError {} catch { XCTFail("Unexpected error \(error)") }
    }
    func testInvalidTextRangeFailsClosed() {
        var doc = textDocument("original")
        doc.findings = [Finding(kind: .custom, value: "bad", range: NSRange(location: 999, length: 3), decision: .redact)]
        doc.pages[0].reviewed = true
        XCTAssertThrowsError(try SafeExporter.export(doc))
    }
    func testMissingImageGeometryFailsClosed() throws {
        let image = try fixtureImage()
        var doc = ReviewDocument(name: "test.png", kind: .image, pages: [DocumentPage(index: 0, imageData: try DocumentProcessor.png(image), pixelWidth: 200, pixelHeight: 100, text: "secret")], findings: [Finding(kind: .custom, value: "secret", range: NSRange(location: 0, length: 6), decision: .redact)])
        doc.pages[0].reviewed = true
        XCTAssertThrowsError(try SafeExporter.export(doc))
    }
    func testOriginalAndSymlinkDestinationsAreProtected() throws {
        let source = temporaryURL("txt"), link = temporaryURL("txt"), hardLink = temporaryURL("txt")
        defer { for url in [source, link, hardLink] { try? FileManager.default.removeItem(at: url) } }
        let original = Data("private original".utf8)
        try original.write(to: source)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        try FileManager.default.linkItem(at: source, to: hardLink)
        for destination in [source, link, hardLink] {
            XCTAssertTrue(ExportFileStore.conflicts(destination, with: [source]))
            XCTAssertThrowsError(try ExportFileStore.save(Data("replacement".utf8), to: destination, protecting: [source]))
        }
        XCTAssertEqual(try Data(contentsOf: source), original)
    }
    func testSeparateExportSavesExactBytes() throws {
        let url = temporaryURL("txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let output = Data("[REDACTED]".utf8)
        try ExportFileStore.save(output, to: url, protecting: [])
        XCTAssertEqual(try Data(contentsOf: url), output)
    }

    private func textDocument(_ text: String) -> ReviewDocument { ReviewDocument(name: "test.txt", kind: .text, pages: [DocumentPage(index: 0, text: text)], findings: detector.detect(text)) }
    private func temporaryURL(_ ext: String) -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext) }
    private func fixtureImage() throws -> CGImage {
        let context = DocumentProcessor.makeContext(width: 200, height: 100)!
        context.setFillColor(CGColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        return context.makeImage()!
    }
    private func fixturePDF() throws -> Data {
        let data = NSMutableData()
        var media = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &media, nil)!
        context.beginPDFPage(nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "secret@example.com", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
        context.textPosition = CGPoint(x: 60, y: 640); CTLineDraw(line, context)
        let publicLine = CTLineCreateWithAttributedString(NSAttributedString(string: "Public project brief", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
        context.textPosition = CGPoint(x: 60, y: 500); CTLineDraw(publicLine, context)
        context.endPDFPage(); context.closePDF()
        return data as Data
    }
}
