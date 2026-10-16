import SwiftUI
import AppKit
import ShareSafeCore

enum Style {
    static let accent = Color(red: 0.87, green: 0.015, blue: 0.12)
    static let success = Color(nsColor: .systemGreen)
    static let amber = Color(nsColor: .systemOrange)
    static let line = Color.primary.opacity(0.07)
    static let canvas = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.09, alpha: 1)
            : NSColor(calibratedRed: 0.96, green: 0.965, blue: 0.975, alpha: 1)
    })
    static let panel = Color(nsColor: .controlBackgroundColor)
}

/// A system-managed backdrop gives the workspace the same softly blurred
/// window surface used by native macOS sidebars and utility panels.
struct NativeWindowBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = .sidebar
        view.blendingMode = .behindWindow
    }
}

struct WorkspaceView: View {
    @EnvironmentObject var model: Workspace
    @Environment(\.undoManager) private var undoManager
    @State private var targeted = false
    var body: some View {
        VStack(spacing: 0) {
            StudioHeader()
            Divider()
            HStack(spacing: 14) {
                StudioSidebar().frame(width: 206)
                VStack(spacing: 0) {
                    if model.document != nil {
                        StudioToolbar()
                        HStack(spacing: 0) {
                            if model.showPagePane { PageNavigation().frame(width: 130); Divider() }
                            DocumentCanvas()
                        }
                    } else { welcome }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Style.line))
                if model.document != nil && model.showReviewPane {
                    StudioInspector().frame(width: 314).background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Style.line))
                }
            }.padding(.trailing, 14).padding(.vertical, 12)
            OfficeStatusBar()
        }
        .background(NativeWindowBackdrop().ignoresSafeArea()).tint(Style.accent)
        .onAppear { model.undoManager = undoManager; undoManager?.levelsOfUndo = 60 }
        .overlay { if targeted { RoundedRectangle(cornerRadius: 14).stroke(Style.accent, lineWidth: 3).padding(5).allowsHitTesting(false) } }
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            guard !model.busy, let provider = providers.first else { return false }
            provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, _ in
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in model.load(url) }
            }
            return true
        }
        .alert("Unable to open or export", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        .alert("Remove from this session?", isPresented: Binding(get: { model.pendingRemovalID != nil }, set: { if !$0 { model.pendingRemovalID = nil } })) {
            Button("Cancel", role: .cancel) { model.pendingRemovalID = nil }
            Button("Remove", role: .destructive) { model.confirmRemoval() }
        } message: { Text("\(model.documents.first { $0.id == model.pendingRemovalID }?.name ?? "This document") will be removed along with its unsaved review changes. Your original file and saved exports stay untouched.") }
        .alert("Review before export", isPresented: $model.showExportReviewConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Keep unselected & continue") { model.confirmExportReview() }
        } message: {
            Text("\(model.document?.pendingCount ?? 0) undecided suggestion(s) will be kept, and all pages will be marked reviewed. Redactions you selected remain applied. Continue to export?")
        }
        .sheet(item: $model.pendingPDFImport) { request in PDFRecoverySheet(request: request) }
        .sheet(isPresented: $model.showExport) { ExportSheet() }
        .sheet(isPresented: $model.showPrivacy) { PrivacySheet() }
        .sheet(item: $model.receipt) { ReceiptSheet(receipt: $0) }
    }
    private var welcome: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill").font(.system(size: 56)).foregroundStyle(Style.accent)
            Text("A private space\nfor your next handoff.").font(.system(size: 34, weight: .semibold)).tracking(-1).multilineTextAlignment(.center)
            Text("Open a document, choose what stays,\nand make a copy you’re ready to share.").font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(5)
            Button("Open a document") { model.openPanel() }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy)
            Button("Explore a fictional sample") { model.loadSample() }.buttonStyle(.plain).foregroundStyle(Style.accent).disabled(model.busy)
            Text("PDF · Images · Plain text    /    All on your Mac").font(.caption).foregroundStyle(.secondary).padding(.top, 15)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PDFRecoverySheet: View {
    @EnvironmentObject var model: Workspace
    @Environment(\.dismiss) private var dismiss
    let request: PDFImportRequest
    @State private var password = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: request.needsPassword ? "lock.doc" : "doc.on.doc").font(.system(size: 32)).foregroundStyle(Style.accent)
            Text(request.needsPassword ? "Unlock this PDF" : "Create a review copy").font(.title2.weight(.semibold))
            Text(request.url.lastPathComponent).font(.callout).foregroundStyle(.secondary)
            if request.needsPassword {
                Text("Enter the document’s password. It is used locally for this import and is not saved.").font(.callout)
                SecureField("PDF password", text: $password).textFieldStyle(.roundedBorder)
            } else {
                Text("This PDF has forms or annotations. ShareSafe can create a flattened copy in this session, including visible field values and annotation appearances, for you to review.").lineSpacing(4)
                Text("Your original stays untouched. Interactive fields and digital-signature validation are not preserved. Hidden comment threads, attachments and interactive media are not included. Check the rendered pages before exporting a separate file.").font(.caption).foregroundStyle(.secondary).lineSpacing(3)
            }
            HStack {
                Button("Cancel") { model.pendingPDFImport = nil; dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(request.needsPassword ? "Unlock & open" : "Create review copy") { let value = password; password = ""; model.retryPDF(request, password: request.needsPassword ? value : nil) }.buttonStyle(.borderedProminent).disabled(request.needsPassword && password.isEmpty)
            }
        }.padding(30).frame(width: 460).tint(Style.accent).onDisappear { password = "" }
    }
}
