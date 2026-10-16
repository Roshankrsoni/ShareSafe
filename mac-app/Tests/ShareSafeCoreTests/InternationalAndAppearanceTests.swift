import XCTest
import CoreGraphics
import CoreText
import PDFKit
@testable import ShareSafeCore

final class InternationalAndAppearanceTests: XCTestCase {
    func testIndianAndInternationalSuggestions() {
        let text = """
        PAN: ABCPD1234E
        Aadhaar: 2345 6789 0123
        Mobile: +91 98765 43210
        UPI: sample@okaxis
        Phone: +442079460958
        DOB: 12/05/1990
        Account number: 001234567890
        Passport: Z1234567
        Address: 10 Example Road, Pune
        """
        let results = SensitiveDetector(includeNames: false).detect(text)
        for kind: SensitiveKind in [.pan, .aadhaar, .phone, .upi, .dateOfBirth, .bankAccount, .passport, .address] {
            XCTAssertTrue(results.contains { $0.kind == kind }, "Missing \(kind): \(results.map(\.value))")
        }
        XCTAssertTrue(results.contains { $0.value == "+442079460958" })
        XCTAssertTrue(results.contains { $0.value == "+91 98765 43210" })
    }
    func testNameUnderSeparatePDFLabel() {
        let results = SensitiveDetector().detect("PREPARED FOR\nOlivia Bennett\nEMAIL\nolivia@example.com")
        XCTAssertTrue(results.contains { $0.kind == .person && $0.value == "Olivia Bennett" })
    }
    func testUnicodeLabelsAndSeparators() {
        let text = "नाम: आरव शर्मा\nजन्म तिथि: 01/01/1990\nपता: उदाहरण मार्ग पुणे\n2345\u{00a0}6789\u{00a0}0123"
        let results = SensitiveDetector().detect(text)
        XCTAssertTrue(results.contains { $0.kind == .person && $0.value.contains("आरव") })
        XCTAssertTrue(results.contains { $0.kind == .dateOfBirth })
        XCTAssertTrue(results.contains { $0.kind == .address })
        XCTAssertTrue(results.contains { $0.kind == .aadhaar })
    }
    func testAadhaarDoesNotCaptureCardSuffixOrLongNumber() {
        let results = SensitiveDetector(includeNames: false).detect("4111 1111 1111 1111\n1234 5678 9012 3456")
        XCTAssertFalse(results.contains { $0.kind == .aadhaar })
        XCTAssertTrue(results.contains { $0.kind == .paymentCard })
    }
    func testNativePDFIndianDetectionAndRotatedCoverage() throws {
        let data = NSMutableData()
        var media = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &media, nil)!
        context.beginPDFPage(nil)
        for (i, text) in ["PAN: ABCPD1234E", "Aadhaar: 2345 6789 0123", "Mobile: +91 98765 43210"].enumerated() {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 16, nil)]))
            context.textPosition = CGPoint(x: 70, y: 650 - i * 40); CTLineDraw(line, context)
        }
        context.endPDFPage(); context.closePDF()
        let pdf = PDFDocument(data: data as Data)!
        pdf.page(at: 0)!.rotation = 90
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try pdf.dataRepresentation()!.write(to: url)
        var doc = try DocumentProcessor.load(url: url, includeNames: false)
        XCTAssertTrue(doc.findings.contains { $0.kind == .pan })
        XCTAssertTrue(doc.findings.contains { $0.kind == .aadhaar })
        for i in doc.findings.indices { doc.findings[i].decision = .redact }
        doc.pages[0].reviewed = true
        let exported = try SafeExporter.export(doc)
        try exported.data.write(to: url)
        let rescanned = try DocumentProcessor.load(url: url, includeNames: false)
        XCTAssertFalse(rescanned.pages[0].text.contains("ABCPD1234E"))
        XCTAssertFalse(rescanned.pages[0].text.contains("2345 6789 0123"))
    }
    func testColoredMasksAndBlurExport() throws {
        let context = DocumentProcessor.makeContext(width: 160, height: 120)!
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        for x in stride(from: 20, to: 140, by: 8) { context.fill(CGRect(x: x, y: 20, width: 4, height: 80)) }
        let source = context.makeImage()!
        var doc = ReviewDocument(name: "test.png", kind: .image, pages: [DocumentPage(index: 0, imageData: try DocumentProcessor.png(source), pixelWidth: 160, pixelHeight: 120, text: "")], findings: [])
        let normalized = CGRect(x: 0.2, y: 0.25, width: 0.6, height: 0.5)
        doc.masks = [ManualMask(pageIndex: 0, rect: normalized)]
        doc.pages[0].reviewed = true
        doc.maskAppearance.red = 0.2; doc.maskAppearance.green = 0.4; doc.maskAppearance.blue = 0.8
        let solid = try SafeExporter.export(doc)
        let rect = SafeExporter.pixelRect(normalized, width: 160, height: 120)
        let expected = try MaskRenderer.tile(source: source, rect: rect, appearance: doc.maskAppearance)
        XCTAssertTrue(MaskRenderer.verify(try DocumentProcessor.image(from: solid.data), tile: expected, rect: rect))
        doc.maskAppearance.effect = .blur
        let blurred = try SafeExporter.export(doc)
        XCTAssertNotEqual(blurred.data, solid.data)
        XCTAssertTrue(blurred.checks.contains { $0.contains("visual concealment") })
        XCTAssertFalse(blurred.checks.contains { $0.contains("passed pixel") })
        let blurTile = try MaskRenderer.tile(source: source, rect: rect, appearance: doc.maskAppearance)
        XCTAssertTrue(MaskRenderer.verify(try DocumentProcessor.image(from: blurred.data), tile: blurTile, rect: rect))
    }
    func testInvalidMaskAppearanceFailsClosed() throws {
        var doc = ReviewDocument(name: "test", kind: .text, pages: [DocumentPage(index: 0, text: "hello")], findings: [])
        doc.pages[0].reviewed = true
        doc.maskAppearance.red = .nan
        XCTAssertThrowsError(try SafeExporter.export(doc))
    }
}
