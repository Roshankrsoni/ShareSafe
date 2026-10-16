import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Vision
import CryptoKit
import PDFKit
import CoreImage

public enum DocumentProcessor {
    public static let maximumBytes = 25 * 1024 * 1024
    public static let maximumPixels = 60_000_000

    public static func load(url: URL, includeNames: Bool, prepareCopy: Bool = false, password: String? = nil, progress: @escaping @Sendable (String) -> Void = { _ in }) throws -> ReviewDocument {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= maximumBytes else {
            throw ShareSafeError.invalid("Choose a regular file smaller than 25 MB.")
        }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumBytes else { throw ShareSafeError.invalid("This file exceeds the 25 MB limit.") }
        try Task.checkCancellation()
        let ext = url.pathExtension.lowercased()
        if ["txt", "md"].contains(ext) {
            guard data.count <= 1_000_000, let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
                throw ShareSafeError.invalid("Use a UTF-8 text file smaller than 1 MB, without binary content.")
            }
            progress("Finding sensitive text…")
            let findings = SensitiveDetector(includeNames: includeNames).detect(text)
            return ReviewDocument(name: url.lastPathComponent, sourceURL: url, kind: .text, pages: [DocumentPage(index: 0, text: text)], findings: findings)
        }
        var pages: [DocumentPage] = []
        var findings: [Finding] = []
        if ext == "pdf" {
            guard let provider = CGDataProvider(data: data as CFData), let pdf = CGPDFDocument(provider) else {
                throw ShareSafeError.invalid("This PDF cannot be decoded. It may be damaged or use an unsupported PDF feature. Try exporting a new PDF from its original app.")
            }
            if !pdf.isUnlocked {
                guard let password, pdf.unlockWithPassword(password) else { throw ShareSafeError.passwordRequired }
            }
            guard (1...40).contains(pdf.numberOfPages) else { throw ShareSafeError.invalid("Choose a PDF with 1–40 pages.") }
            let textPDF = PDFDocument(data: data)
            if let password, textPDF?.isLocked == true { _ = textPDF?.unlock(withPassword: password) }
            var total = 0
            for index in 0..<pdf.numberOfPages {
                try Task.checkCancellation()
                progress("Reading page \(index + 1) of \(pdf.numberOfPages)…")
                let result: (DocumentPage, [Finding]) = try autoreleasepool {
                    guard let page = pdf.page(at: index + 1) else { throw ShareSafeError.invalid("A PDF page could not be opened.") }
                    if !prepareCopy { try rejectInteractiveAnnotations(page) }
                    let box = page.getBoxRect(.cropBox)
                    guard box.width.isFinite, box.height.isFinite, box.width > 0, box.height > 0, box.width < 15_000, box.height < 15_000 else { throw ShareSafeError.invalid("This PDF has unsupported page dimensions.") }
                    let rotated = abs(page.rotationAngle) % 180 == 90
                    let width = rotated ? box.height : box.width
                    let height = rotated ? box.width : box.height
                    let scale = min(2, sqrt(12_000_000 / (width * height)))
                    let pw = max(1, Int(width * scale)), ph = max(1, Int(height * scale))
                    total += pw * ph
                    guard total <= maximumPixels else { throw ShareSafeError.invalid("This document is too large to review in one session. Split it into smaller PDFs.") }
                    guard let context = makeContext(width: pw, height: ph) else { throw ShareSafeError.invalid("Not enough memory to render the page.") }
                    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
                    context.scaleBy(x: CGFloat(pw) / width, y: CGFloat(ph) / height)
                    context.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: width, height: height), rotate: 0, preserveAspectRatio: true))
                    context.drawPDFPage(page)
                    if prepareCopy, let nativePage = textPDF?.page(at: index) {
                        // The base page is drawn once. Bake visible annotation appearances
                        // into the same coordinate system before OCR; no live forms survive.
                        // The context already applies page rotation; avoid rotating annotation layout twice.
                        let rotation = nativePage.rotation
                        nativePage.rotation = 0
                        defer { nativePage.rotation = rotation }
                        let media = nativePage.bounds(for: .mediaBox)
                        context.saveGState()
                        context.translateBy(x: media.minX, y: media.minY)
                        for annotation in nativePage.annotations where annotation.shouldDisplay {
                            annotation.draw(with: .mediaBox, in: context)
                        }
                        context.restoreGState()
                    }
                    guard let image = context.makeImage() else { throw ShareSafeError.invalid("The page could not be rendered.") }
                    var result = try recognize(image, index: index, pointSize: CGSize(width: width, height: height), includeNames: includeNames)
                    if let nativePage = textPDF?.page(at: index) {
                        supplementNativeText(nativePage, cgPage: page, result: &result, includeNames: includeNames)
                        if prepareCopy { supplementAnnotationText(nativePage, cgPage: page, result: &result, includeNames: includeNames) }
                    }
                    return result
                }
                pages.append(result.0); findings.append(contentsOf: result.1)
            }
        } else if ["png", "jpg", "jpeg", "heic", "tiff", "tif"].contains(ext) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) == 1 else {
                throw ShareSafeError.invalid("Choose a single-frame PNG, JPEG, HEIC or TIFF image.")
            }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            guard width > 0, height > 0, width <= 20_000, height <= 20_000, width * height <= 12_000_000 else {
                throw ShareSafeError.invalid("Choose an image up to 12 megapixels. Resize a copy before importing.")
            }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: max(width, height)]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw ShareSafeError.invalid("The image could not be decoded.") }
            progress("Reading text on the image…")
            let result = try recognize(image, index: 0, pointSize: CGSize(width: image.width, height: image.height), includeNames: includeNames)
            pages = [result.0]; findings = result.1
        } else {
            throw ShareSafeError.invalid("Supported files: PDF, PNG, JPEG, HEIC, single-frame TIFF, TXT and Markdown. Word documents are not supported yet.")
        }
        try Task.checkCancellation()
        var document = ReviewDocument(name: url.lastPathComponent, sourceURL: url, kind: ext == "pdf" ? .pdf : .image, pages: pages, findings: findings)
        document.wasPrepared = prepareCopy
        return document
    }

    static func recognize(_ image: CGImage, index: Int, pointSize: CGSize, includeNames: Bool) throws -> (DocumentPage, [Finding]) {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = true
        let supported = try request.supportedRecognitionLanguages()
        let preferred = ["en-US", "hi-IN", "mr-IN", "ta-IN", "te-IN", "bn-IN", "gu-IN", "kn-IN", "ml-IN", "pa-IN", "fr-FR", "de-DE", "es-ES", "pt-BR", "it-IT", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "ru-RU", "uk-UA", "ar-SA"]
        request.recognitionLanguages = preferred.filter { supported.contains($0) }
        request.minimumTextHeight = 0.005
        try VNImageRequestHandler(cgImage: image).perform([request])
        try Task.checkCancellation()
        var text = "", regions: [TextRegion] = [], findings: [Finding] = []
        let detector = SensitiveDetector(includeNames: includeNames)
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let offset = (text as NSString).length
            let line = candidate.string
            regions.append(TextRegion(text: line, range: NSRange(location: offset, length: (line as NSString).length), rect: observation.boundingBox))
            for var finding in SensitiveDetector(includeNames: false).detect(line, pageIndex: index) {
                if let range = Range(finding.range, in: line), let box = try? candidate.boundingBox(for: range) {
                    finding.rectangles = [box.boundingBox]
                } else {
                    // Cover the entire OCR line when precise glyph geometry isn't available.
                    finding.rectangles = [observation.boundingBox]
                }
                finding.range.location += offset
                findings.append(finding)
            }
            text += line + "\n"
        }
        if includeNames {
            for var finding in detector.detect(text, pageIndex: index) where finding.kind == .person {
                finding.rectangles = regions.filter { NSIntersectionRange($0.range, finding.range).length > 0 }.map(\.rect)
                if !finding.rectangles.isEmpty { findings.append(finding) }
            }
        }
        let page = DocumentPage(index: index, imageData: try png(image), pixelWidth: image.width, pixelHeight: image.height, pointWidth: pointSize.width, pointHeight: pointSize.height, text: text, regions: regions)
        return (page, findings)
    }

    private static func supplementNativeText(_ native: PDFPage, cgPage: CGPDFPage, result: inout (DocumentPage, [Finding]), includeNames: Bool) {
        guard let text = native.string, !text.isEmpty else { return }
        let width = result.0.pointWidth, height = result.0.pointHeight
        let transform = cgPage.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: width, height: height), rotate: 0, preserveAspectRatio: true)
        func rectangles(_ range: NSRange) -> [CGRect] {
            guard let selection = native.selection(for: range) else { return [] }
            return selection.selectionsByLine().compactMap { line in
                let bounds = line.bounds(for: native).applying(transform)
                    .intersection(CGRect(x: 0, y: 0, width: width, height: height))
                guard !bounds.isNull, !bounds.isEmpty else { return nil }
                return CGRect(x: bounds.minX / width, y: bounds.minY / height, width: bounds.width / width, height: bounds.height / height)
            }
        }
        let offset = (result.0.text as NSString).length
        for var finding in SensitiveDetector(includeNames: includeNames).detect(text, pageIndex: result.0.index) {
            let rects = rectangles(finding.range)
            guard !rects.isEmpty else { continue }
            // Prefer the PDF's exact glyph geometry over OCR when both identify the same area.
            result.1.removeAll { old in
                old.kind == finding.kind && old.rectangles.contains { a in rects.contains { b in
                    let overlap = a.intersection(b)
                    return !overlap.isNull && overlap.width * overlap.height > min(a.width * a.height, b.width * b.height) * 0.45
                } }
            }
            finding.rectangles = rects
            finding.range.location += offset
            result.1.append(finding)
        }
        let ns = text as NSString
        var cursor = 0
        while cursor < ns.length {
            let range = ns.lineRange(for: NSRange(location: cursor, length: 0))
            for rect in rectangles(range) {
                result.0.regions.append(TextRegion(text: ns.substring(with: range), range: NSRange(location: offset + range.location, length: range.length), rect: rect))
            }
            cursor = NSMaxRange(range)
        }
        result.0.text += text + "\n"
        result.1.sort { $0.range.location < $1.range.location }
    }

    private static func supplementAnnotationText(_ native: PDFPage, cgPage: CGPDFPage, result: inout (DocumentPage, [Finding]), includeNames: Bool) {
        let width = result.0.pointWidth, height = result.0.pointHeight
        let transform = cgPage.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: width, height: height), rotate: 0, preserveAspectRatio: true)
        for annotation in native.annotations where annotation.shouldDisplay && ["FreeText", "Widget"].contains(annotation.type ?? "") {
            guard let text = annotation.type == "Widget" ? annotation.widgetStringValue : annotation.contents, !text.isEmpty else { continue }
            let bounds = annotation.bounds.applying(transform).intersection(CGRect(x: 0, y: 0, width: width, height: height))
            guard !bounds.isNull, !bounds.isEmpty else { continue }
            let rect = CGRect(x: bounds.minX / width, y: bounds.minY / height, width: bounds.width / width, height: bounds.height / height)
            let offset = (result.0.text as NSString).length
            for var finding in SensitiveDetector(includeNames: includeNames).detect(text, pageIndex: result.0.index) {
                result.1.removeAll { $0.kind == finding.kind && $0.value == finding.value && $0.rectangles.contains { !$0.intersection(rect).isNull } }
                finding.range.location += offset
                finding.rectangles = [rect] // Field-wide coverage also handles wrapped/rotated appearance text.
                result.1.append(finding)
            }
            result.0.regions.append(TextRegion(text: text, range: NSRange(location: offset, length: (text as NSString).length), rect: rect))
            result.0.text += text + "\n"
        }
    }

    private static func rejectInteractiveAnnotations(_ page: CGPDFPage) throws {
        guard let dictionary = page.dictionary else { throw ShareSafeError.invalid("A PDF page is missing its content dictionary.") }
        var annotations: CGPDFArrayRef?
        if CGPDFDictionaryGetArray(dictionary, "Annots", &annotations), let annotations {
            for index in 0..<CGPDFArrayGetCount(annotations) {
                var annotation: CGPDFDictionaryRef?
                var subtype: UnsafePointer<CChar>?
                guard CGPDFArrayGetDictionary(annotations, index, &annotation), let annotation,
                      CGPDFDictionaryGetName(annotation, "Subtype", &subtype), let subtype,
                      String(cString: subtype) == "Link" else {
                    throw ShareSafeError.preparationRequired
                }
            }
        }
    }

    public static func addExactTerm(_ term: String, to document: inout ReviewDocument) -> Int {
        var count = 0
        for index in document.pages.indices {
            let page = document.pages[index]
            for range in SensitiveDetector.exactMatches(term, in: page.text) {
                guard !document.findings.contains(where: { $0.pageIndex == index && $0.range == range }) else { continue }
                let rects = page.regions.filter { NSIntersectionRange($0.range, range).length > 0 }.map(\.rect)
                // Custom OCR matches cover full lines conservatively.
                document.findings.append(Finding(kind: .custom, value: (page.text as NSString).substring(with: range), pageIndex: index, range: range, rectangles: rects))
                document.pages[index].reviewed = false
                count += 1
            }
        }
        document.findings.sort { ($0.pageIndex, $0.range.location) < ($1.pageIndex, $1.range.location) }
        return count
    }

    public static func image(from data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw ShareSafeError.invalid("A page image could not be decoded.") }
        return image
    }
    static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    }
    static func png(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw ShareSafeError.invalid("Could not create the image export.") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ShareSafeError.invalid("Could not finish the image export.") }
        return data as Data
    }
}

public enum SafeExporter {
    public static func export(_ document: ReviewDocument, progress: @escaping @Sendable (String) -> Void = { _ in }) throws -> ExportResult {
        guard document.maskAppearance.isValid else { throw ShareSafeError.invalid("Choose a valid mask color and blur strength.") }
        guard document.canExport else { throw ShareSafeError.invalid("Decide every finding and review every page before exporting.") }
        for finding in document.findings where finding.decision == .redact {
            guard document.pages.indices.contains(finding.pageIndex) else { throw ShareSafeError.invalid("A redaction references a missing page.") }
            if document.kind == .text {
                let length = (document.pages[finding.pageIndex].text as NSString).length
                guard finding.range.location >= 0, finding.range.length > 0, finding.range.location <= length, finding.range.length <= length - finding.range.location else {
                    throw ShareSafeError.invalid("A text redaction is outside the document. Import the file again.")
                }
            } else {
                guard !finding.rectangles.isEmpty, finding.rectangles.allSatisfy(validRect) else { throw ShareSafeError.invalid("A redaction is missing valid geometry. Add a manual mask and review again.") }
            }
        }
        guard document.masks.allSatisfy({ document.pages.indices.contains($0.pageIndex) && validRect($0.rect) }) else { throw ShareSafeError.invalid("A manual mask is outside the page.") }
        try Task.checkCancellation()
        var data: Data
        var checks: [String]
        if document.kind == .text {
            let output = TextRedactor.redact(document.pages[0].text, findings: document.findings, aliases: document.policy == .ai)
            data = Data(output.utf8)
            checks = ["Selected text ranges replaced", "Fresh UTF-8 file; no source metadata copied"]
        } else {
            let result = NSMutableData()
            var pdf: CGContext?
            if document.kind == .pdf {
                guard let consumer = CGDataConsumer(data: result as CFMutableData), let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { throw ShareSafeError.invalid("Could not create the PDF export.") }
                pdf = context
            }
            var imageOutput = Data()
            for page in document.pages {
                try Task.checkCancellation()
                progress("Protecting page \(page.index + 1) of \(document.pages.count)…")
                try autoreleasepool {
                    guard let sourceData = page.imageData else { throw ShareSafeError.invalid("A page image is missing.") }
                    let source = try DocumentProcessor.image(from: sourceData)
                    guard let context = DocumentProcessor.makeContext(width: source.width, height: source.height) else { throw ShareSafeError.invalid("Not enough memory to export this page.") }
                    let bounds = CGRect(x: 0, y: 0, width: source.width, height: source.height)
                    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(bounds)
                    context.draw(source, in: bounds)
                    context.setAllowsAntialiasing(false)

                    let automatic = document.findings.filter { $0.pageIndex == page.index && $0.decision == .redact }.flatMap(\.rectangles)
                    let manual = document.masks.filter { $0.pageIndex == page.index }.map(\.rect)
                    let rects = (automatic + manual).map { pixelRect($0, width: source.width, height: source.height) }
                    for rect in rects {
                        let tile = try MaskRenderer.tile(source: source, rect: rect, appearance: document.maskAppearance)
                        context.draw(tile, in: rect)
                        guard let check = context.makeImage(), MaskRenderer.verify(check, tile: tile, rect: rect) else {
                            throw ShareSafeError.invalid("Mask verification failed. No file was saved.")
                        }
                    }
                    guard let protected = context.makeImage() else { throw ShareSafeError.invalid("Could not create the protected page.") }

                    if let pdf {
                        var media = CGRect(x: 0, y: 0, width: page.pointWidth, height: page.pointHeight)
                        let boxData = NSData(bytes: &media, length: MemoryLayout<CGRect>.size)
                        pdf.beginPDFPage([kCGPDFContextMediaBox as String: boxData] as CFDictionary)
                        pdf.draw(protected, in: media)
                        pdf.endPDFPage()
                    } else { imageOutput = try DocumentProcessor.png(protected) }
                }
            }
            if let pdf {
                pdf.closePDF()
                data = result as Data
                guard let provider = CGDataProvider(data: data as CFData), let rebuilt = CGPDFDocument(provider), rebuilt.numberOfPages == document.pages.count else { throw ShareSafeError.invalid("Export page-count verification failed.") }
                checks = [document.maskAppearance.effect == .blur ? "Blur applied; visual concealment only" : "Every selected mask passed pixel checks", "Page count verified", "Fresh image-only PDF; source text, links and attachments not copied"]
            } else {
                data = imageOutput
                checks = [document.maskAppearance.effect == .blur ? "Blur applied; visual concealment only" : "Every selected mask passed pixel checks", "Fresh PNG; original metadata not copied"]
            }
        }
        try Task.checkCancellation()
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return ExportResult(data: data, fileExtension: document.kind == .text ? "txt" : (document.kind == .pdf ? "pdf" : "png"), sha256: hash, checks: checks)
    }

    public static func pixelRect(_ normalized: CGRect, width: Int, height: Int) -> CGRect {
        let rect = CGRect(x: normalized.minX * Double(width), y: normalized.minY * Double(height), width: normalized.width * Double(width), height: normalized.height * Double(height))
        return rect.insetBy(dx: -3, dy: -3).integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
    }

    private static func validRect(_ rect: CGRect) -> Bool {
        [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite) && rect.width > 0 && rect.height > 0 && rect.minX >= 0 && rect.minY >= 0 && rect.maxX <= 1.001 && rect.maxY <= 1.001
    }

    static func verifyBlackPixels(_ image: CGImage, rects: [CGRect]) -> Bool {
        guard let context = DocumentProcessor.makeContext(width: image.width, height: image.height), let bytes = context.data else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = bytes.assumingMemoryBound(to: UInt8.self)
        for rect in rects {
            guard !rect.isNull, !rect.isEmpty else { return false }
            for y in Int(rect.minY)..<Int(rect.maxY) {
                for x in Int(rect.minX)..<Int(rect.maxX) {
                    // Bitmap rows are top-down; mask coordinates are bottom-up.
                    let offset = (image.height - 1 - y) * context.bytesPerRow + x * 4
                    if pixels[offset] != 0 || pixels[offset + 1] != 0 || pixels[offset + 2] != 0 { return false }
                }
            }
        }
        return true
    }
}

public enum ExportFileStore {
    public static func conflicts(_ destination: URL, with sources: [URL]) -> Bool {
        let target = destination.resolvingSymlinksInPath().standardizedFileURL
        let targetID = try? target.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject
        for source in sources {
            let original = source.resolvingSymlinksInPath().standardizedFileURL
            // Conservative on case-sensitive volumes too: an alternate spelling isn't worth the risk.
            if target.path.lowercased() == original.path.lowercased() { return true }
            if let targetID, let sourceID = try? original.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject, targetID.isEqual(sourceID) { return true }
        }
        return false
    }

    public static func save(_ data: Data, to destination: URL, protecting sources: [URL]) throws {
        let access = destination.startAccessingSecurityScopedResource()
        defer { if access { destination.stopAccessingSecurityScopedResource() } }
        guard !conflicts(destination, with: sources) else { throw ShareSafeError.invalid("Choose a different filename. An original document cannot be overwritten.") }
        try Task.checkCancellation()
        try data.write(to: destination, options: .atomic)
    }
}
