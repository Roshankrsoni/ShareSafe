import XCTest
import AppKit
import PDFKit
import CoreText
@testable import ShareSafeCore

final class ReviewRecoveryTests: XCTestCase {
    func testResumeContactWithoutTechnicalFalsePositives() {
        let text = """
        ARJUN SHARMA
        +91-9876543210 arjun@example.test linkedin.com/in/arjun-example
        Technical Skills
        Programming: JavaScript/TypeScript, Node.js
        Frontend Technologies: ReactJs/Next.js, Redux, Webview, HTML/CSS, PWA
        Cloud & Infrastructure: AWS, Vercel
        Experience
        Implemented Webviews and UI components with Jest.
        Dr.
        """
        let findings = SensitiveDetector().detect(text)
        XCTAssertTrue(findings.contains { $0.kind == .person && $0.value.uppercased() == "ARJUN SHARMA" })
        for value in ["Dr.", "UI", "Jest", "Webviews", "Vercel", "PWA", "Technical Skills"] {
            XCTAssertFalse(findings.contains { $0.value == value }, "False positive: \(value)")
        }
        XCTAssertTrue(findings.contains { $0.kind == .profile })
        XCTAssertTrue(findings.contains { $0.kind == .email })
        XCTAssertTrue(findings.contains { $0.kind == .phone && $0.value == "+91-9876543210" })
        XCTAssertFalse(SensitiveDetector().detect("Vercel\nJest\nUI\nDr.").contains { $0.kind == .person })
    }
    func testReviewSupportsMixedAndAllKeepDecisions() throws {
        var doc = ReviewDocument(name: "test", kind: .text, pages: [DocumentPage(index: 0, text: "a@example.com b@example.com")], findings: SensitiveDetector(includeNames: false).detect("a@example.com b@example.com"))
        doc.findings[0].decision = .redact
        doc.completeReview(page: 0, keepingUnselected: false)
        XCTAssertFalse(doc.canExport)
        doc.completeReview(page: 0, keepingUnselected: true)
        XCTAssertTrue(doc.canExport)
        XCTAssertEqual(doc.findings[1].decision, .keep)
        XCTAssertEqual(String(data: try SafeExporter.export(doc).data, encoding: .utf8), "[REDACTED] b@example.com")
        doc.findings[0].decision = .keep
        doc.completeReview(page: 0, keepingUnselected: true)
        XCTAssertTrue(doc.canExport)
        XCTAssertEqual(doc.redactionCount, 0)
    }
    func testPreparedCopyIncludesVisibleFreeTextAndPreservesOriginal() throws {
        let pdf = fixture()
        let note = PDFAnnotation(bounds: CGRect(x: 50, y: 420, width: 470, height: 70), forType: .freeText, withProperties: nil)
        note.font = NSFont.systemFont(ofSize: 22)
        note.fontColor = .black
        note.color = .white
        note.contents = "private@example.test"
        pdf.page(at: 0)!.addAnnotation(note)
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let original = pdf.dataRepresentation()!
        try original.write(to: url)
        XCTAssertThrowsError(try DocumentProcessor.load(url: url, includeNames: false))
        let prepared = try DocumentProcessor.load(url: url, includeNames: false, prepareCopy: true)
        XCTAssertTrue(prepared.wasPrepared)
        XCTAssertTrue(prepared.pages[0].text.contains("private@example.test"), prepared.pages[0].text)
        XCTAssertTrue(prepared.findings.contains { $0.kind == .email })
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testPreparedFormValueIsRendered() throws {
        let pdf = fixture()
        let widget = PDFAnnotation(bounds: CGRect(x: 50, y: 420, width: 450, height: 50), forType: .widget, withProperties: nil)
        widget.widgetFieldType = .text
        widget.fieldName = "Contact"
        widget.widgetStringValue = "forms@example.test"
        widget.font = NSFont.systemFont(ofSize: 22)
        pdf.page(at: 0)!.addAnnotation(widget)
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try pdf.dataRepresentation()!.write(to: url)
        let prepared = try DocumentProcessor.load(url: url, includeNames: false, prepareCopy: true)
        XCTAssertTrue(prepared.pages[0].text.contains("forms@example.test"), prepared.pages[0].text)
    }
    func testPasswordProtectedPDFRequiresCorrectPassword() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(fixture().write(to: url, withOptions: [.userPasswordOption: "test-password", .ownerPasswordOption: "owner-password"]))
        XCTAssertThrowsError(try DocumentProcessor.load(url: url, includeNames: false, password: "wrong"))
        let doc = try DocumentProcessor.load(url: url, includeNames: false, password: "test-password")
        XCTAssertTrue(doc.pages[0].text.contains("Public"))
    }
    func testPreparedRotatedAndCroppedAnnotation() throws {
        let pdf = fixture()
        let page = pdf.page(at: 0)!
        let annotation = PDFAnnotation(bounds: CGRect(x: 70, y: 420, width: 400, height: 70), forType: .freeText, withProperties: nil)
        annotation.font = NSFont.systemFont(ofSize: 22)
        annotation.contents = "rotated@example.test"
        page.addAnnotation(annotation)
        page.setBounds(CGRect(x: 30, y: 300, width: 520, height: 400), for: .cropBox)
        page.rotation = 90
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try pdf.dataRepresentation()!.write(to: url)
        let prepared = try DocumentProcessor.load(url: url, includeNames: false, prepareCopy: true)
        // Rotate the baked page back for OCR, avoiding dependency on Vision's orientation heuristics.
        let image = try DocumentProcessor.image(from: prepared.pages[0].imageData!)
        let c = DocumentProcessor.makeContext(width: image.height, height: image.width)!
        c.translateBy(x: CGFloat(image.height), y: 0); c.rotate(by: .pi / 2)
        c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let read = try DocumentProcessor.recognize(c.makeImage()!, index: 0, pointSize: CGSize(width: 520, height: 400), includeNames: false)
        XCTAssertTrue(read.0.text.contains("Public"))
        XCTAssertTrue(prepared.findings.contains { $0.value == "rotated@example.test" })
        var reviewed = prepared
        for i in reviewed.findings.indices { reviewed.findings[i].decision = .redact }
        reviewed.pages[0].reviewed = true
        let output = try SafeExporter.export(reviewed)
        try output.data.write(to: url)
        let rescanned = try DocumentProcessor.load(url: url, includeNames: false)
        XCTAssertFalse(rescanned.pages[0].text.contains("rotate"))
        XCTAssertFalse(rescanned.pages[0].text.contains("@exa"))
    }
    private func temporaryURL() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf") }
    private func fixture() -> PDFDocument {
        let data = NSMutableData()
        var media = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &media, nil)!
        context.beginPDFPage(nil)
        context.textPosition = CGPoint(x: 50, y: 650)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: "Public document", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 22, nil)])), context)
        context.endPDFPage(); context.closePDF()
        return PDFDocument(data: data as Data)!
    }
}
