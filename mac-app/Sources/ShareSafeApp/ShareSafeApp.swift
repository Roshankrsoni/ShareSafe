import SwiftUI
import AppKit
import Vision

@main
struct ShareSafeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var workspace = Workspace()
    @AppStorage("appearance") private var appearance = "Light"
    var body: some Scene {
        WindowGroup {
            WorkspaceView().environmentObject(workspace)
                .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
                .frame(minWidth: 1040, minHeight: 700)
                .onOpenURL { workspace.load($0) }
        }
        .defaultSize(width: 1360, height: 880)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Document…") { workspace.openPanel() }.keyboardShortcut("o")
                Button("Open Fictional Sample") { workspace.loadSample() }
                Button("Open Plain-Text Sample") { workspace.loadTextSample() }
                Divider()
                Button("Export Reviewed Copy…") { workspace.requestExport() }.keyboardShortcut("e", modifiers: [.command, .shift]).disabled(workspace.document == nil || workspace.busy)
                Button("Remove Document") { workspace.removeSelected() }.keyboardShortcut(.delete, modifiers: .command).disabled(workspace.document == nil || workspace.busy)
            }
            CommandMenu("Zoom") {
                Button("Zoom In") { workspace.zoomIn() }.keyboardShortcut("=", modifiers: .command).disabled(workspace.document == nil || workspace.displayedZoom >= 300)
                Button("Zoom Out") { workspace.zoomOut() }.keyboardShortcut("-", modifiers: .command).disabled(workspace.document == nil || workspace.displayedZoom <= 25)
                Button("Actual Size") { workspace.setZoom(100) }.keyboardShortcut("0", modifiers: .command).disabled(workspace.document == nil)
                Divider()
                Button("Fit Page") { workspace.zoomMode = "page" }.disabled(workspace.document == nil)
                Button("Fit Width") { workspace.togglePageWidth() }.disabled(workspace.document == nil)
            }
            CommandMenu("Review") {
                Button("Redact All on Page") { workspace.redactPage() }.keyboardShortcut("r", modifiers: [.command, .shift]).disabled(workspace.document == nil || workspace.busy)
                Button("Toggle Protected Preview") { workspace.protectedPreview.toggle() }.keyboardShortcut("p", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .help) {
                Button("ShareSafe Privacy & Limits") { workspace.showPrivacy = true }
            }
        }
        Settings { PreferencesView().frame(width: 470) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct PreferencesView: View {
    @AppStorage("detectNames") private var detectNames = true
    @AppStorage("detectFaces") private var detectFaces = true
    @AppStorage("appearance") private var appearance = "Light"
    private var recognitionLanguages: String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let codes = (try? request.supportedRecognitionLanguages()) ?? ["en-US"]
        return Array(Set(codes.compactMap { Locale.current.localizedString(forLanguageCode: String($0.prefix(2))) })).sorted().joined(separator: ", ")
    }
    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }
            Toggle("Suggest person names", isOn: $detectNames)
            Text("Applies to new imports. Name detection is approximate; review suggestions and manually cover details it misses.").font(.caption).foregroundStyle(.secondary)
            Toggle("Suggest face regions", isOn: $detectFaces)
            Text("Uses on-device Vision to suggest face-shaped regions in PDFs and images. It does not identify people. Check every page; missed faces and false matches are possible. Applies to new imports.").font(.caption).foregroundStyle(.secondary)
            Section("Text recognition") {
                Text("PDF text + on-device OCR").font(.callout.weight(.medium))
                Text("Embedded PDF text is read directly, including regional scripts when the PDF has valid text encoding. Image-only scans depend on the languages supported by this Mac.").font(.caption).foregroundStyle(.secondary)
                Text("Scanned text: " + recognitionLanguages).font(.caption).foregroundStyle(.secondary)
                Text("Indian ID patterns are possible matches, not proof of a valid identity. Always review addresses, names, QR codes, photos and handwriting manually.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Private by design") {
                Label("Processing happens on your Mac", systemImage: "lock.shield")
                Text("No uploads, accounts, analytics or document history. Only these preferences are saved. Exported copies remain where you save them.").font(.callout).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).padding(12)
    }
}
