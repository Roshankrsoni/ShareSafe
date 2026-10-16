import SwiftUI
import AppKit
import ImageIO
import ShareSafeCore

struct OfficeRibbon: View {
    @EnvironmentObject var model: Workspace
    @State private var showStyle = false
    private let officeBlue = Color(red: 0.10, green: 0.23, blue: 0.43)
    private var hasDocument: Bool { model.document != nil && !model.busy }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 20))
                Text("ShareSafe").font(.system(size: 14, weight: .semibold))
                Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 17)
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!model.canUndo).help("Undo (⌘Z)").accessibilityLabel("Undo review edit")
                Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }.disabled(!model.canRedo).help("Redo (⇧⌘Z)").accessibilityLabel("Redo review edit")
                Spacer()
                Text(model.document?.name ?? "Private document review").font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer()
                Label("On-device", systemImage: "lock").font(.system(size: 10)).opacity(0.8)
                SettingsLink { Image(systemName: "gearshape") }.help("Settings")
            }.buttonStyle(.plain).foregroundStyle(.white).padding(.leading, 84).padding(.trailing, 22).frame(height: 48).background(officeBlue)
            HStack(spacing: 6) {
                Menu("File") {
                    Button("Open Document…") { model.openPanel() }.disabled(model.busy)
                    Button("Explore Fictional Sample") { model.loadSample() }.disabled(model.busy)
                    Button("Remove Current Document") { model.removeSelected() }.disabled(!hasDocument)
                    Divider()
                    Button("Privacy & Limits") { model.showPrivacy = true }
                }.menuStyle(.borderlessButton).frame(width: 48).padding(.trailing, 8)
                ForEach(["Home", "Redact", "View"], id: \.self) { tab in
                    Button { model.ribbonTab = tab } label: {
                        Text(tab).font(.system(size: 12, weight: model.ribbonTab == tab ? .semibold : .regular))
                            .padding(.horizontal, 15).frame(height: 34)
                            .foregroundStyle(model.ribbonTab == tab ? Style.accent : .primary)
                            .overlay(alignment: .bottom) { if model.ribbonTab == tab { Capsule().fill(Style.accent).frame(height: 3).padding(.horizontal, 12) } }
                    }.buttonStyle(.plain)
                }
                Spacer()
                if let doc = model.document {
                    Label(doc.canExport ? "Ready to export" : "Review required", systemImage: doc.canExport ? "checkmark.circle" : "circle.dashed").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Button { model.requestExport() } label: { Label("Export copy", systemImage: "square.and.arrow.up").font(.system(size: 11, weight: .semibold)).padding(.horizontal, 5) }
                    .buttonStyle(.borderedProminent).disabled(!hasDocument).padding(.leading, 12)
            }.padding(.horizontal, 20).background(Color(nsColor: .controlBackgroundColor))
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if model.ribbonTab == "Home" {
                        group("Document") {
                            ribbonButton("Open", "folder") { model.openPanel() }.disabled(model.busy)
                            ribbonButton("Sample", "doc.badge.plus") { model.loadSample() }.disabled(model.busy)
                        }
                        group("Preview") {
                            ribbonButton("Original", "doc.text", selected: !model.protectedPreview) { model.protectedPreview = false }.disabled(!hasDocument)
                            ribbonButton("Protected", "shield.lefthalf.filled", selected: model.protectedPreview) { model.protectedPreview = true }.disabled(!hasDocument)
                        }
                        group("Protect") { protectTools }
                        group("Review") {
                            ribbonButton("Redact all", "rectangle.inset.filled") { model.redactPage() }.disabled(!hasDocument || model.pageFindings.isEmpty)
                            ribbonButton("Review pane", "sidebar.right", selected: model.showReviewPane) { model.showReviewPane.toggle() }.disabled(!hasDocument)
                        }
                        group("Sharing intent") { policyPicker.frame(width: 160).padding(.top, 13) }
                    } else if model.ribbonTab == "Redact" {
                        group("Mask tools") { protectTools }
                        group("Find sensitive text") {
                            HStack {
                                TextField("Name, address, reference…", text: $model.customTerm).textFieldStyle(.roundedBorder).frame(width: 220).onSubmit { model.addTerm(); model.showReviewPane = true }
                                Button("Find") { model.addTerm(); model.showReviewPane = true }.disabled(model.customTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }.padding(.top, 15).disabled(!hasDocument)
                        }
                        group("Review") {
                            ribbonButton("Redact all", "rectangle.inset.filled") { model.redactPage() }.disabled(!hasDocument || model.pageFindings.isEmpty)
                        }
                        group("Sharing intent") { policyPicker.frame(width: 160).padding(.top, 13) }
                    } else {
                        group("Zoom") {
                            ribbonButton("Zoom out", "minus.magnifyingglass") { model.zoomOut() }.disabled(!hasDocument || model.displayedZoom <= 25)
                            ribbonButton("Zoom in", "plus.magnifyingglass") { model.zoomIn() }.disabled(!hasDocument || model.displayedZoom >= 300)
                            ribbonButton("100%", "viewfinder") { model.setZoom(100) }.disabled(!hasDocument)
                        }
                        group("Page display") {
                            ribbonButton("One page", "doc", selected: model.zoomMode == "page") { model.zoomMode = "page" }.disabled(!hasDocument)
                            ribbonButton(model.zoomMode == "width" ? "Restore view" : "Page width", model.zoomMode == "width" ? "arrow.uturn.backward" : "arrow.left.and.right", selected: model.zoomMode == "width") { model.togglePageWidth() }.disabled(!hasDocument)
                        }
                        group("Panes") {
                            ribbonButton("Navigation", "sidebar.left", selected: model.showPagePane) { model.showPagePane.toggle() }.disabled(!hasDocument)
                            ribbonButton("Review", "sidebar.right", selected: model.showReviewPane) { model.showReviewPane.toggle() }.disabled(!hasDocument)
                        }
                        group("Privacy") { ribbonButton("Privacy & limits", "lock.shield") { model.showPrivacy = true } }
                    }
                    Spacer(minLength: 0)
                }.padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 5)
            }.frame(height: 91).background(Color(nsColor: .controlBackgroundColor))
            Divider()
        }
    }
    private var policyPicker: some View {
        Picker("Sharing intent", selection: Binding(get: { model.document?.policy ?? .external }, set: { value in model.update { doc in doc.policy = value; for i in doc.pages.indices { doc.pages[i].reviewed = false } } })) {
            ForEach(SharingPolicy.allCases) { Text($0.rawValue).tag($0) }
        }.labelsHidden().disabled(!hasDocument)
    }
    @ViewBuilder private var protectTools: some View {
        ribbonButton("Draw mask", "rectangle.dashed", selected: model.drawingMask) { model.drawingMask.toggle(); model.protectedPreview = true }
            .disabled(!hasDocument || model.document?.kind == .text)
        ribbonButton("Mask style", "paintpalette") { showStyle.toggle() }
            .disabled(!hasDocument || model.document?.kind == .text)
            .popover(isPresented: $showStyle) { MaskOptions().environmentObject(model) }
    }
    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(alignment: .top, spacing: 4) { content() }.frame(height: 57, alignment: .top)
                Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
            }.padding(.horizontal, 13)
            Divider().frame(height: 67)
        }
    }
    private func ribbonButton(_ title: String, _ symbol: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 21, weight: .regular)).foregroundStyle(Style.accent).frame(height: 24)
                Text(title).font(.system(size: 10)).lineLimit(1)
            }.frame(minWidth: 52).padding(.horizontal, 6).padding(.vertical, 5)
                .background(selected ? Style.accent.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
}

struct OfficeStatusBar: View {
    @EnvironmentObject var model: Workspace
    var body: some View {
        HStack(spacing: 13) {
            if model.busy {
                ProgressView().controlSize(.small)
                Text(model.progress).font(.caption)
                Button("Cancel") { model.cancel() }.font(.caption)
            } else if let doc = model.document {
                HStack(spacing: 9) {
                    Button { model.pageIndex -= 1; model.selectedFinding = nil } label: { Image(systemName: "chevron.left") }.disabled(model.pageIndex == 0).accessibilityLabel("Previous page")
                    Text("Page \(model.pageIndex + 1) of \(doc.pages.count)").font(.system(size: 10).monospacedDigit())
                    Button { model.pageIndex += 1; model.selectedFinding = nil } label: { Image(systemName: "chevron.right") }.disabled(model.pageIndex + 1 >= doc.pages.count).accessibilityLabel("Next page")
                }
                Divider().frame(height: 13)
                Text("\(doc.pages.filter(\.reviewed).count) reviewed").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 10)
            Text(model.notice ?? "Local processing · Originals stay untouched").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 10)
            if model.document != nil {
                Button { model.zoomMode = "page" } label: { Image(systemName: "doc") }.help("Fit page").accessibilityLabel("Fit page")
                Button { model.togglePageWidth() } label: { Image(systemName: model.zoomMode == "width" ? "arrow.uturn.backward" : "arrow.left.and.right") }.help(model.zoomMode == "width" ? "Restore previous view" : "Fit width").accessibilityLabel(model.zoomMode == "width" ? "Restore previous view" : "Fit width")
                Divider().frame(height: 13)
                Button { model.zoomOut() } label: { Image(systemName: "minus") }.disabled(model.displayedZoom <= 25).help("Zoom out").accessibilityLabel("Zoom out")
                Slider(value: Binding(get: { min(300, max(25, model.displayedZoom)) }, set: { model.setZoom($0) }), in: 25...300, step: 5).frame(width: 110).accessibilityLabel("Document zoom")
                Button { model.zoomIn() } label: { Image(systemName: "plus") }.disabled(model.displayedZoom >= 300).help("Zoom in").accessibilityLabel("Zoom in")
                Menu {
                    ForEach([25, 50, 75, 100, 125, 150, 200, 300], id: \.self) { value in Button("\(value)%") { model.setZoom(Double(value)) } }
                } label: { Text("\(Int(model.displayedZoom.rounded()))%").font(.system(size: 10).monospacedDigit()) }.menuStyle(.borderlessButton).frame(width: 58).accessibilityLabel("Zoom percentage")
            }
        }.buttonStyle(.plain).padding(.horizontal, 16).frame(height: 32).background(Color(nsColor: .controlBackgroundColor))
    }
}

struct PageNavigation: View {
    @EnvironmentObject var model: Workspace
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Pages").font(.system(size: 12, weight: .semibold)); Spacer(); Button { model.showPagePane = false } label: { Image(systemName: "xmark").font(.system(size: 10)) }.buttonStyle(.plain).help("Close navigation") }.padding(16)
            Divider()
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(model.document?.pages ?? []) { page in
                        Button { model.pageIndex = page.index; model.selectedFinding = nil } label: {
                            VStack(spacing: 8) {
                                PageThumbnail(page: page).id("\(model.selectedID?.uuidString ?? "")-\(page.index)").frame(width: 100, height: 130)
                                    .overlay(Rectangle().stroke(model.pageIndex == page.index ? Style.accent : Style.line, lineWidth: model.pageIndex == page.index ? 2 : 1))
                                HStack(spacing: 4) { Text("\(page.index + 1)"); if page.reviewed { Image(systemName: "checkmark.circle.fill").foregroundStyle(Style.accent) } }.font(.system(size: 10))
                            }
                        }.buttonStyle(.plain).accessibilityLabel("Go to page \(page.index + 1)")
                    }
                }.padding(.vertical, 18)
            }
            Text("Original thumbnails").font(.system(size: 9)).foregroundStyle(.secondary).padding(10)
        }.background(Color(nsColor: .controlBackgroundColor)).disabled(model.busy)
    }
}

private struct PageThumbnail: View {
    let page: DocumentPage
    @State private var image: NSImage?
    var body: some View {
        ZStack {
            Color.white
            if let image { Image(nsImage: image).resizable().scaledToFit() }
            else { Image(systemName: "doc.text").font(.system(size: 30)).foregroundStyle(.gray) }
        }.task(id: page.index) {
            guard let data = page.imageData else { return }
            let thumbnail = await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return Optional<CGImage>.none }
                return CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 240] as CFDictionary)
            }.value
            guard !Task.isCancelled, let thumbnail else { return }
            image = NSImage(cgImage: thumbnail, size: .zero)
        }
    }
}
