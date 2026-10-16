import XCTest
import AppKit
import PDFKit
import ShareSafeCore
@testable import ShareSafeApp

final class WorkspaceTests: XCTestCase {
    @MainActor func testReviewExportConfirmationAndUndo() {
        let workspace = Workspace()
        let undo = UndoManager(); undo.groupsByEvent = false
        workspace.undoManager = undo
        workspace.loadTextSample()
        XCTAssertFalse(workspace.document!.canExport)
        workspace.requestExport()
        XCTAssertTrue(workspace.showExportReviewConfirmation)
        XCTAssertFalse(workspace.showExport)
        undo.beginUndoGrouping()
        workspace.confirmExportReview()
        undo.endUndoGrouping()
        XCTAssertTrue(workspace.document!.canExport)
        XCTAssertTrue(workspace.showExport)
        workspace.undo()
        XCTAssertFalse(workspace.document!.canExport)
        workspace.redo()
        XCTAssertTrue(workspace.document!.canExport)
    }

    @MainActor func testZoomToggleAndRemoval() {
        let workspace = Workspace()
        workspace.loadTextSample()
        workspace.setZoom(140)
        workspace.togglePageWidth()
        XCTAssertEqual(workspace.zoomMode, "width")
        workspace.togglePageWidth()
        XCTAssertEqual(workspace.zoomMode, "custom")
        XCTAssertEqual(workspace.zoomPercent, 140)
        workspace.removeSelected()
        XCTAssertEqual(workspace.documents.count, 1)
        workspace.confirmRemoval()
        XCTAssertNil(workspace.document)
        XCTAssertTrue(workspace.documents.isEmpty)
    }

    @MainActor func testFailedImportClearsScanAndPreservesExistingDocument() async throws {
        let workspace = Workspace()
        workspace.loadTextSample()
        let previous = workspace.selectedID
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try Data("invalid pdf".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        workspace.load(url)
        XCTAssertTrue(workspace.busy)
        XCTAssertEqual(workspace.importingName, url.lastPathComponent)
        try await waitForIdle(workspace)
        XCTAssertNil(workspace.importingName)
        XCTAssertNil(workspace.scanPreview)
        XCTAssertNotNil(workspace.error)
        XCTAssertEqual(workspace.selectedID, previous)
    }

    @MainActor func testImportAndImmediateCancellationCleanup() async throws {
        let workspace = Workspace()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        try "Contact: demo@example.test".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        workspace.load(url)
        workspace.cancel()
        try await waitForIdle(workspace)
        XCTAssertTrue(workspace.documents.isEmpty)
        XCTAssertNil(workspace.scanPreview)
        XCTAssertNil(workspace.importingName)
        XCTAssertFalse(workspace.cancelling)
        XCTAssertEqual(workspace.notice, "Import cancelled.")
        workspace.load(url)
        try await waitForIdle(workspace)
        XCTAssertEqual(workspace.documents.count, 1)
        XCTAssertNil(workspace.scanPreview)
        XCTAssertNil(workspace.importingName)
        XCTAssertEqual(workspace.document?.findings.first?.value, "demo@example.test")
    }

    @MainActor func testPasswordRecoveryClearsScanThenRetries() async throws {
        let workspace = Workspace()
        let pdf = makePDF()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        XCTAssertTrue(pdf.write(to: url, withOptions: [.userPasswordOption: "qa-password", .ownerPasswordOption: "qa-owner"]))
        defer { try? FileManager.default.removeItem(at: url) }
        workspace.load(url)
        try await waitForIdle(workspace)
        XCTAssertNil(workspace.importingName)
        XCTAssertNil(workspace.scanPreview)
        let request = try XCTUnwrap(workspace.pendingPDFImport)
        XCTAssertTrue(request.needsPassword)
        XCTAssertTrue(workspace.documents.isEmpty)
        workspace.retryPDF(request, password: "qa-password")
        try await waitForIdle(workspace)
        XCTAssertNil(workspace.pendingPDFImport)
        XCTAssertEqual(workspace.documents.count, 1)
        XCTAssertNil(workspace.error)
    }

    @MainActor func testAnnotationRecoveryRetainsPreviousDocumentUntilRetry() async throws {
        let workspace = Workspace()
        workspace.loadTextSample()
        let previous = workspace.selectedID
        let pdf = makePDF()
        let annotation = PDFAnnotation(bounds: CGRect(x: 20, y: 20, width: 100, height: 30), forType: .freeText, withProperties: nil)
        annotation.contents = "Fictional note"
        pdf.page(at: 0)!.addAnnotation(annotation)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        XCTAssertTrue(pdf.write(to: url))
        defer { try? FileManager.default.removeItem(at: url) }
        workspace.load(url)
        try await waitForIdle(workspace)
        XCTAssertEqual(workspace.selectedID, previous)
        XCTAssertNil(workspace.importingName)
        XCTAssertNil(workspace.scanPreview)
        let request = try XCTUnwrap(workspace.pendingPDFImport)
        XCTAssertTrue(request.prepareCopy)
        workspace.retryPDF(request)
        try await waitForIdle(workspace)
        XCTAssertEqual(workspace.documents.count, 2)
        XCTAssertTrue(workspace.document?.wasPrepared == true)
        XCTAssertNil(workspace.pendingPDFImport)
    }

    private func makePDF() -> PDFDocument {
        let data = NSMutableData()
        var bounds = CGRect(x: 0, y: 0, width: 240, height: 320)
        let context = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &bounds, nil)!
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(bounds)
        context.endPDFPage(); context.closePDF()
        return PDFDocument(data: data as Data)!
    }

    @MainActor private func waitForIdle(_ workspace: Workspace) async throws {
        let deadline = Date().addingTimeInterval(10)
        while workspace.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(workspace.busy, "Operation did not finish in 10 seconds")
    }
}
