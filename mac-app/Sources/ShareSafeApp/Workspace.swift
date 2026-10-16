import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ShareSafeCore

@MainActor
final class Workspace: ObservableObject {
    @Published var documents: [ReviewDocument] = []
    @Published var selectedID: UUID?
    @Published var pageIndex = 0
    @Published var selectedFinding: UUID?
    @Published var protectedPreview = true
    @Published var drawingMask = false
    @Published var movingMask = false
    @Published var manualMaskShape: ManualMaskShape = .rectangle
    @Published var busy = false
    @Published var progress = ""
    @Published var importingName: String?
    @Published var scanPreview: DocumentScanPreview?
    @Published var cancelling = false
    @Published var error: String?
    @Published var notice: String?
    @Published var receipt: ExportReceipt?
    @Published var showExport = false
    @Published var showPrivacy = false
    @Published var customTerm = ""
    @Published var ribbonTab = "Home"
    @Published var section = "Review"
    @Published var searchText = ""
    @Published var pendingRemovalID: UUID?
    @Published var showExportReviewConfirmation = false
    @Published var pendingPDFImport: PDFImportRequest?
    private var widthRestore: (String, Double)?
    func togglePageWidth() {
        if zoomMode == "width" { zoomMode = widthRestore?.0 ?? "page"; zoomPercent = widthRestore?.1 ?? 100; widthRestore = nil }
        else { widthRestore = (zoomMode, zoomPercent); zoomMode = "width" }
    }
    @Published var showReviewPane = true
    @Published var showPagePane = false
    @Published var zoomMode = "width"
    @Published var zoomPercent: Double = 100
    @Published var displayedZoom: Double = 100
    func setZoom(_ value: Double) { zoomPercent = min(300, max(25, value)); zoomMode = "custom" }
    func zoomIn() { setZoom((displayedZoom / 10).rounded(.down) * 10 + 10) }
    func zoomOut() { setZoom((displayedZoom / 10).rounded(.up) * 10 - 10) }
    private var task: Task<Void, Never>?
    private var operationID = UUID()
    var undoManager: UndoManager?
    var canUndo: Bool { !busy && undoManager?.canUndo == true }
    var canRedo: Bool { !busy && undoManager?.canRedo == true }
    func undo() { undoManager?.undo(); objectWillChange.send() }
    func redo() { undoManager?.redo(); objectWillChange.send() }

    private func restore(_ snapshot: ReviewDocument) {
        guard let index = documents.firstIndex(where: { $0.id == snapshot.id }) else { return }
        let current = documents[index]
        undoManager?.registerUndo(withTarget: self) { target in MainActor.assumeIsolated { target.restore(current) } }
        documents[index] = snapshot
        selectedID = snapshot.id
        pageIndex = min(pageIndex, snapshot.pages.count - 1)
        selectedFinding = nil
        notice = nil
    }

    var document: ReviewDocument? { documents.first { $0.id == selectedID } }
    var page: DocumentPage? { document.flatMap { $0.pages.indices.contains(pageIndex) ? $0.pages[pageIndex] : nil } }
    var pageFindings: [Finding] { document?.findings.filter { $0.pageIndex == pageIndex } ?? [] }

    func select(_ id: UUID) {
        selectedID = id; pageIndex = 0; selectedFinding = nil
        drawingMask = false; movingMask = false
        section = "Review"; showReviewPane = true
        notice = nil
    }
    func setMaskTool(_ shape: ManualMaskShape) {
        manualMaskShape = shape; drawingMask = true; movingMask = false; protectedPreview = true
    }
    func setMoveTool() { drawingMask = false; movingMask = true; protectedPreview = true }
    func finishCanvasTool() { drawingMask = false; movingMask = false }
    func update(_ body: (inout ReviewDocument) -> Void) {
        guard !busy, let index = documents.firstIndex(where: { $0.id == selectedID }) else { return }
        let previous = documents[index]
        body(&documents[index])
        undoManager?.registerUndo(withTarget: self) { target in MainActor.assumeIsolated { target.restore(previous) } }
        undoManager?.setActionName("Review Edit")
    }
    func decide(_ id: UUID, _ decision: ReviewDecision) {
        update { doc in
            guard let i = doc.findings.firstIndex(where: { $0.id == id }) else { return }
            doc.findings[i].decision = decision
            doc.pages[doc.findings[i].pageIndex].reviewed = false
        }
    }
    func redactPage() {
        update { doc in
            for i in doc.findings.indices where doc.findings[i].pageIndex == pageIndex { doc.findings[i].decision = .redact }
            doc.pages[pageIndex].reviewed = false
        }
    }
    func requestExport() {
        guard document != nil, !busy else { return }
        if document?.canExport == true { showExport = true }
        else { showExportReviewConfirmation = true }
    }
    func confirmExportReview() {
        guard !busy, document != nil else { return }
        update { doc in
            for index in doc.findings.indices where doc.findings[index].decision == .pending {
                doc.findings[index].decision = .keep
            }
            for index in doc.pages.indices { doc.pages[index].reviewed = true }
        }
        showExportReviewConfirmation = false
        showExport = true
    }
    func addMask(_ rect: CGRect) {
        guard rect.width > 0.003, rect.height > 0.003 else { return }
        update { doc in
            doc.masks.append(ManualMask(pageIndex: pageIndex, rect: rect, shape: manualMaskShape))
            doc.pages[pageIndex].reviewed = false
        }
    }
    func removeMask(_ id: UUID) {
        update { doc in doc.masks.removeAll { $0.id == id }; doc.pages[pageIndex].reviewed = false }
    }
    func moveMask(_ id: UUID, to rect: CGRect) {
        update { doc in
            guard let index = doc.masks.firstIndex(where: { $0.id == id }) else { return }
            doc.masks[index].rect = rect
            doc.pages[doc.masks[index].pageIndex].reviewed = false
        }
    }
    func addTerm() {
        let term = customTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        var added = 0
        update { added = DocumentProcessor.addExactTerm(term, to: &$0) }
        notice = added == 0 ? "No new matches. For images and PDFs, you can draw a mask over anything OCR missed." : "Added \(added) suggestion\(added == 1 ? "" : "s"). Image matches cover the full text line."
        customTerm = ""
    }
    func openPanel() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .png, .jpeg, .heic, .tiff, .plainText, UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsMultipleSelection = false
        panel.message = "Documents are processed on your Mac and stay in this session."
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }
    func load(_ url: URL, isSample: Bool = false, prepareCopy: Bool = false, password: String? = nil) {
        guard !busy else { return }
        guard documents.count < 8 else { error = "Remove a document before adding another. A session holds up to eight documents."; return }
        busy = true; importingName = url.lastPathComponent; scanPreview = nil; cancelling = false
        progress = "Opening document…"; error = nil; notice = nil; receipt = nil
        let includeNames = UserDefaults.standard.object(forKey: "detectNames") as? Bool ?? true
        let includeFaces = UserDefaults.standard.object(forKey: "detectFaces") as? Bool ?? true
        let id = UUID(); operationID = id
        task = Task {
            let worker = Task.detached(priority: .userInitiated) {
                try DocumentProcessor.load(url: url, includeNames: includeNames, includeFaces: includeFaces, prepareCopy: prepareCopy, password: password, preview: { preview in
                    Task { @MainActor [weak self] in
                        guard let self, self.operationID == id, !self.cancelling else { return }
                        self.scanPreview = preview
                    }
                }) { message in
                    Task { @MainActor [weak self] in if self?.operationID == id && self?.cancelling == false { self?.progress = message } }
                }
            }
            do {
                var loaded = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                try Task.checkCancellation()
                loaded.isSample = isSample
                if isSample { loaded.name = "Northstar · client brief.pdf" }
                guard documents.reduce(0, { $0 + $1.pixelCount }) + loaded.pixelCount <= 100_000_000 else {
                    throw ShareSafeError.invalid("This session is full. Remove a document to free memory, then try again.")
                }
                documents.append(loaded); select(loaded.id)
            } catch ShareSafeError.preparationRequired {
                pendingPDFImport = PDFImportRequest(url: url, isSample: isSample, needsPassword: false, password: password, prepareCopy: true)
            } catch ShareSafeError.passwordRequired {
                pendingPDFImport = PDFImportRequest(url: url, isSample: isSample, needsPassword: true, password: nil, prepareCopy: prepareCopy)
            } catch is CancellationError { notice = "Import cancelled." }
            catch { self.error = error.localizedDescription }
            busy = false; progress = ""; operationID = UUID(); importingName = nil; scanPreview = nil; cancelling = false
        }
    }
    func cancel() { cancelling = true; task?.cancel(); progress = "Cancelling after the current page…" }
    func removeSelected() { guard !busy else { return }; pendingRemovalID = selectedID }
    func confirmRemoval() {
        guard !busy, let id = pendingRemovalID else { return }
        undoManager?.removeAllActions()
        documents.removeAll { $0.id == id }
        if selectedID == id { selectedID = documents.first?.id; pageIndex = 0; selectedFinding = nil }
        pendingRemovalID = nil; receipt = nil; notice = nil
    }
    func retryPDF(_ request: PDFImportRequest, password: String? = nil) {
        pendingPDFImport = nil
        load(request.url, isSample: request.isSample, prepareCopy: request.prepareCopy, password: password ?? request.password)
    }
    func loadSample() {
        guard !busy, documents.count < 8 else { return }
        if let sample = documents.first(where: \.isSample) { select(sample.id); return }
        if let url = Bundle.main.url(forResource: "Northstar-Sample", withExtension: "pdf") {
            load(url, isSample: true)
        } else { loadTextSample() }
    }
    func loadTextSample() {
        guard !busy, documents.count < 8 else { return }
        let text = """
        NORTHSTAR STUDIO
        Client project brief
        ──────────────────────────────────────────

        FICTIONAL SAMPLE · FOR EXPLORING SHARESAFE

        Prepared for: Olivia Bennett
        Project: Autumn brand refresh
        Status: Ready for creative review

        01   THE BRIEF

        Create a considered visual identity for the next
        chapter of Northstar. The work should feel clear,
        confident, and unmistakably human.

        02   CLIENT CONTACT

        Contact: Olivia Bennett
        Email: olivia.bennett@example.com
        Phone: +1 415-555-0182

        03   INTERNAL BILLING

        Test card: 4111 1111 1111 1111
        Reference: NS-2026-104

        04   NEXT STEPS

        Share the creative direction with our external
        design partner. Remove personal contact and
        payment details before sending this brief.

        This sample contains invented information.
        """
        var doc = ReviewDocument(name: "Northstar · sample brief.txt", kind: .text, pages: [DocumentPage(index: 0, text: text)], findings: SensitiveDetector().detect(text))
        doc.isSample = true; documents.append(doc); select(doc.id)
    }
    func saveExport() {
        guard let snapshot = document, !busy else { return }
        showExport = false
        let panel = NSSavePanel()
        let ext = snapshot.kind == .text ? "txt" : snapshot.kind == .pdf ? "pdf" : "png"
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .data]
        panel.nameFieldStringValue = "\((snapshot.name as NSString).deletingPathExtension)-shared.\(ext)"
        panel.message = "Save a separate reviewed copy. Your original stays untouched."
        // Present the save panel asynchronously. Calling runModal() from the
        // Export sheet's button action can leave SwiftUI's sheet dismissal and
        // AppKit's modal session competing for the same window, making Export
        // appear to do nothing on some macOS releases.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            panel.begin { [weak self] response in
                guard response == .OK, let url = panel.url else { return }
                Task { @MainActor [weak self] in
                    self?.beginExport(snapshot, to: url)
                }
            }
        }
    }

    private func beginExport(_ snapshot: ReviewDocument, to url: URL) {
        guard !busy else { return }
        let sources = documents.compactMap(\.sourceURL)
        if ExportFileStore.conflicts(url, with: sources) {
            error = "Choose a different filename. ShareSafe never overwrites the source document."; return
        }
        busy = true; progress = "Preparing your reviewed copy…"
        let id = UUID(); operationID = id
        task = Task {
            let worker = Task.detached(priority: .userInitiated) {
                let result = try SafeExporter.export(snapshot) { message in
                    Task { @MainActor [weak self] in if self?.operationID == id && self?.cancelling == false { self?.progress = message } }
                }
                try ExportFileStore.save(result.data, to: url, protecting: sources)
                return result
            }
            do {
                let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                receipt = ExportReceipt(url: url, hash: result.sha256, checks: result.checks, size: result.data.count)
            } catch is CancellationError { notice = "Export cancelled. No file was saved." }
            catch { self.error = error.localizedDescription }
            busy = false; progress = ""; operationID = UUID(); importingName = nil; scanPreview = nil; cancelling = false
        }
    }
}

struct ExportReceipt: Identifiable {
    let id = UUID()
    let url: URL
    let hash: String
    let checks: [String]
    let size: Int
}

struct PDFImportRequest: Identifiable {
    let id = UUID()
    let url: URL
    let isSample: Bool
    let needsPassword: Bool
    let password: String?
    let prepareCopy: Bool
}
