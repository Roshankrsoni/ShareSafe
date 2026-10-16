import SwiftUI
import AppKit
import ShareSafeCore

struct StudioHeader: View {
    @EnvironmentObject var model: Workspace
    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 11) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 27)).foregroundStyle(Style.accent)
                Text("ShareSafe").font(.system(size: 22, weight: .bold)).tracking(-0.8)
            }.frame(width: 188, alignment: .leading)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search suggestions or sensitive details…", text: $model.searchText).textFieldStyle(.plain)
                    .onChange(of: model.searchText) { _, text in if !text.isEmpty { model.section = "Review"; model.showReviewPane = true } }
                if !model.searchText.isEmpty { Button { model.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary) }
            }.padding(.horizontal, 16).frame(height: 38)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Style.line))
                .frame(maxWidth: 650)
            Spacer(minLength: 10)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { NSApp.keyWindow?.performZoom(nil) }
                .help("Double-click to zoom the window")
            Label("On-device", systemImage: "lock.shield").font(.system(size: 12))
            Divider().frame(height: 22)
            Button { model.requestExport() } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent).tint(Style.success)
            .disabled(model.document == nil || model.busy)
            .help("Export a reviewed copy")
            SettingsLink { Image(systemName: "gearshape").font(.system(size: 18)) }.buttonStyle(.plain).help("Settings")
        }
        .padding(.leading, 24).padding(.trailing, 24).padding(.top, 22).padding(.bottom, 15)
        .background(.regularMaterial)
    }
}

struct StudioSidebar: View {
    @EnvironmentObject var model: Workspace
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button { model.openPanel() } label: { Label("Open document", systemImage: "folder").font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 12) }.buttonStyle(.plain).foregroundStyle(.white).background(Style.accent, in: RoundedRectangle(cornerRadius: 13)).disabled(model.busy).padding(.bottom, 9)
            nav("Home", "house.fill") { model.section = "Home"; model.showReviewPane = false }
            nav("Review", "eye") { model.section = "Review"; model.showReviewPane = true; model.drawingMask = false }
            nav("Redact", "pencil.tip.crop.circle") { model.section = "Redact"; model.showReviewPane = true }
            nav("Insights", "chart.bar") { model.section = "Insights"; model.showReviewPane = true }
            nav("Export", "square.and.arrow.up") { model.requestExport() }.disabled(model.document == nil || model.busy)
            Divider().padding(.vertical, 14)
            Text("Session files").font(.system(size: 12, weight: .medium)).padding(.horizontal, 8).padding(.bottom, 7)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.documents) { SessionFileRow(document: $0) }
                }
            }
            Spacer(minLength: 6)
            Button { model.showPrivacy = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield").font(.system(size: 19))
                    VStack(alignment: .leading, spacing: 4) { Text("Local processing").font(.system(size: 11, weight: .semibold)); Text("Your files stay on this Mac.").font(.system(size: 10)).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 16)
            }.buttonStyle(.plain)
        }.padding(.leading, 14).padding(.trailing, 0)
    }
    private func nav(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 17)).frame(width: 20)
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                if title == "Review", let doc = model.document { Text("\(doc.pendingCount)").font(.system(size: 10, weight: .semibold)).foregroundStyle(Style.accent).padding(5).background(Style.accent.opacity(0.08), in: Circle()) }
            }.padding(.horizontal, 13).frame(height: 42).background(model.section == title ? Color.primary.opacity(0.055) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}

struct SessionFileRow: View {
    @EnvironmentObject var model: Workspace
    let document: ReviewDocument
    @State private var hovered = false
    var body: some View {
        HStack(spacing: 9) {
            Button { model.select(document.id) } label: {
                HStack(spacing: 9) {
                    Image(systemName: document.kind == .image ? "photo" : "doc.text").font(.system(size: 24, weight: .light)).foregroundStyle(.secondary).frame(width: 29, height: 40).background(Style.panel, in: RoundedRectangle(cornerRadius: 5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(document.name).font(.system(size: 11, weight: document.id == model.selectedID ? .semibold : .regular)).lineLimit(2).multilineTextAlignment(.leading)
                        Text("\(document.findings.count) suggestions").font(.system(size: 10)).foregroundStyle(document.id == model.selectedID ? Style.accent : .secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.buttonStyle(.plain)
            Button { model.pendingRemovalID = document.id } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).frame(width: 21, height: 28) }
                .buttonStyle(.plain).opacity(hovered ? 1 : 0).help("Remove \(document.name)").accessibilityLabel("Remove \(document.name)")
        }.padding(9).background(document.id == model.selectedID ? Style.accent.opacity(0.055) : Color.clear, in: RoundedRectangle(cornerRadius: 11)).onHover { hovered = $0 }.disabled(model.busy)
    }
}

struct StudioToolbar: View {
    @EnvironmentObject var model: Workspace
    @State private var showStyle = false
    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                Button { model.showPagePane.toggle() } label: { Image(systemName: "sidebar.left") }.help("Page navigation")
                HStack(spacing: 9) {
                    Button { model.pageIndex -= 1; model.selectedFinding = nil } label: { Image(systemName: "chevron.left") }.disabled(model.pageIndex == 0)
                    Text("\(model.pageIndex + 1) / \(model.document?.pages.count ?? 1)").font(.system(size: 11).monospacedDigit())
                    Button { model.pageIndex += 1; model.selectedFinding = nil } label: { Image(systemName: "chevron.right") }.disabled(model.pageIndex + 1 >= (model.document?.pages.count ?? 1))
                }.padding(8).background(Style.panel, in: RoundedRectangle(cornerRadius: 10))
                HStack(spacing: 10) {
                    Button { model.zoomOut() } label: { Image(systemName: "minus") }.disabled(model.displayedZoom <= 25).help("Zoom out")
                    Text("\(Int(model.displayedZoom.rounded()))%").font(.system(size: 11, weight: .medium).monospacedDigit()).frame(width: 35)
                    Button { model.zoomIn() } label: { Image(systemName: "plus") }.disabled(model.displayedZoom >= 300).help("Zoom in")
                }.padding(8).background(Style.panel, in: RoundedRectangle(cornerRadius: 10))
                Spacer(minLength: 0)
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!model.canUndo).help("Undo")
                Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }.disabled(!model.canRedo).help("Redo")
                Button { model.drawingMask.toggle(); model.protectedPreview = true } label: { Image(systemName: model.manualMaskShape == .round ? "circle.dashed" : "rectangle.dashed").foregroundStyle(model.drawingMask ? Style.accent : .primary) }.disabled(model.document?.kind == .text).help(model.manualMaskShape == .round ? "Draw a round mask" : "Draw a rectangular mask")
                Button { showStyle = true } label: { Image(systemName: "paintpalette") }.disabled(model.document?.kind == .text).help("Mask style").popover(isPresented: $showStyle) { MaskOptions().environmentObject(model) }
            }
            HStack {
                Picker("Document view", selection: $model.protectedPreview) { Text("Original").tag(false); Text("Protected").tag(true) }.pickerStyle(.segmented).labelsHidden().frame(width: 174)
                Spacer(minLength: 2)
                Button { model.togglePageWidth() } label: { Label(model.zoomMode == "width" ? "Restore view" : "Page width", systemImage: model.zoomMode == "width" ? "arrow.uturn.backward" : "arrow.left.and.right") }.font(.system(size: 10)).foregroundStyle(Style.accent)
                Button { model.zoomMode = "page" } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("Fit page")
            }
        }.buttonStyle(.plain).padding(14).background(.thinMaterial).disabled(model.busy)
    }
}

struct StudioInspector: View {
    @EnvironmentObject var model: Workspace
    @State private var filter = "All"
    private var currentTab: String { ["Redact", "Insights"].contains(model.section) ? model.section : "Review" }
    private func category(_ finding: Finding) -> String {
        switch finding.kind { case .paymentCard, .bankAccount, .upi: return "Financial"; case .custom: return "Custom"; default: return "Personal" }
    }
    private var candidates: [Finding] {
        let list = model.searchText.isEmpty ? model.pageFindings : (model.document?.findings ?? [])
        return list.filter { (filter == "All" || category($0) == filter) && (model.searchText.isEmpty || $0.value.localizedCaseInsensitiveContains(model.searchText) || $0.kind.title.localizedCaseInsensitiveContains(model.searchText)) }
    }
    private var reviewProgressColor: Color {
        guard !model.pageFindings.isEmpty,
              model.pageFindings.allSatisfy({ $0.decision != .pending }) else { return Style.accent }
        return Style.success
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 22) {
                ForEach(["Review", "Redact", "Insights"], id: \.self) { tab in
                    Button { model.section = tab } label: { Text(tab).font(.system(size: 12, weight: currentTab == tab ? .semibold : .regular)).padding(.vertical, 19).overlay(alignment: .bottom) { if currentTab == tab { Capsule().fill(Style.accent).frame(height: 3) } } }.buttonStyle(.plain)
                }
            }.frame(maxWidth: .infinity)
            Divider()
            if currentTab == "Review" { review }
            else if currentTab == "Redact" { redaction }
            else { insights }
        }.disabled(model.busy)
    }
    private var review: some View {
        VStack(spacing: 12) {
            HStack(spacing: 13) {
                ZStack {
                    Circle().stroke(reviewProgressColor.opacity(0.12), lineWidth: 8)
                    Circle().trim(from: 0, to: CGFloat(model.pageFindings.filter { $0.decision != .pending }.count) / CGFloat(max(1, model.pageFindings.count))).stroke(reviewProgressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(model.pageFindings.count)").font(.system(size: 24, weight: .semibold))
                }.frame(width: 61, height: 61)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Suggestions to review").font(.system(size: 13, weight: .semibold))
                    Text("Choose what to redact. Keep anything that belongs.").font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(3)
                }
            }.padding(15).frame(maxWidth: .infinity).background(Style.canvas, in: RoundedRectangle(cornerRadius: 16))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(["All", "Personal", "Financial", "Custom"], id: \.self) { title in
                        Button { filter = title } label: { Text(title).font(.system(size: 9, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 7).foregroundStyle(filter == title ? .white : .primary).background(filter == title ? Style.accent : Style.canvas, in: Capsule()) }.buttonStyle(.plain)
                    }
                }
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    if candidates.isEmpty {
                        Text(model.searchText.isEmpty ? "No suggestions in this view. Check the page manually for anything detection missed." : "No matching suggestions.").font(.caption).foregroundStyle(.secondary).padding(15)
                    }
                    ForEach(candidates) { finding in findingCard(finding) }
                    ForEach(model.document?.masks.filter { $0.pageIndex == model.pageIndex } ?? []) { mask in
                        HStack { Label("Manual mask", systemImage: "rectangle.dashed").font(.caption); Spacer(); Button { model.removeMask(mask.id) } label: { Image(systemName: "xmark.circle") }.buttonStyle(.plain).help("Remove manual mask") }.padding(12).background(Style.canvas, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            Button { model.redactPage() } label: { Label("Redact all on page (\(model.pageFindings.count))", systemImage: "sparkles").font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 12) }.buttonStyle(.plain).foregroundStyle(.white).background(Style.accent, in: RoundedRectangle(cornerRadius: 13)).disabled(model.pageFindings.isEmpty)
            Button { model.section = "Redact" } label: { Label("Review manually", systemImage: "eye").font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 11) }.buttonStyle(.plain).foregroundStyle(Style.accent).background(Style.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
        }.padding(16)
    }
    private func findingCard(_ finding: Finding) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { model.pageIndex = finding.pageIndex; model.selectedFinding = finding.id } label: {
                HStack(spacing: 10) {
                    Image(systemName: finding.kind.symbol).font(.system(size: 18)).foregroundStyle(Style.accent).frame(width: 38, height: 38).background(Style.accent.opacity(0.065), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(finding.kind.title).font(.system(size: 11, weight: .semibold))
                        Text(finding.value).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                        if !model.searchText.isEmpty { Text("Page \(finding.pageIndex + 1)").font(.system(size: 9)).foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }.buttonStyle(.plain)
            HStack(spacing: 8) {
                decision("Redact", symbol: finding.decision == .redact ? "checkmark.square.fill" : "square", selected: finding.decision == .redact, color: Style.accent) { model.decide(finding.id, .redact) }.accessibilityLabel("Redact \(finding.kind.title): \(finding.value)")
                decision("Keep", symbol: "eye", selected: finding.decision == .keep, color: Style.success) { model.decide(finding.id, .keep) }.accessibilityLabel("Keep \(finding.kind.title): \(finding.value)")
            }
        }.padding(12).background(Style.panel, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(model.selectedFinding == finding.id ? Style.accent.opacity(0.5) : Style.line))
    }
    private func decision(_ title: String, symbol: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: symbol).font(.system(size: 10, weight: .medium)).frame(maxWidth: .infinity).padding(.vertical, 6).foregroundStyle(selected ? color : .secondary).background(selected ? color.opacity(0.12) : Style.canvas, in: Capsule()) }.buttonStyle(.plain)
    }
    private var redaction: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Find a specific detail").font(.system(size: 13, weight: .semibold))
                TextField("Name, address, reference…", text: $model.customTerm).textFieldStyle(.roundedBorder).onSubmit { model.addTerm(); model.section = "Review" }
                Button("Find exact matches") { model.addTerm(); model.section = "Review" }.buttonStyle(.borderedProminent).disabled(model.customTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if model.document?.kind != .text {
                    Divider()
                    Button { model.drawingMask.toggle(); model.protectedPreview = true } label: { Label(model.drawingMask ? "Finish drawing" : "Draw a manual mask", systemImage: "rectangle.dashed") }.buttonStyle(.bordered)
                    MaskShapePicker(selection: $model.manualMaskShape)
                    Text("Cover photos, QR codes, handwriting or details that weren’t detected.").font(.caption).foregroundStyle(.secondary)
                    MaskOptions().padding(.horizontal, -16)
                }
                Divider()
                Picker("Sharing intent", selection: Binding(get: { model.document?.policy ?? .external }, set: { value in model.update { doc in doc.policy = value; for i in doc.pages.indices { doc.pages[i].reviewed = false } } })) { ForEach(SharingPolicy.allCases) { Text($0.rawValue).tag($0) } }
            }.padding(18)
        }
    }
    private var insights: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("On-device processing", systemImage: "lock.shield").font(.system(size: 15, weight: .semibold)).foregroundStyle(Style.accent)
                Text("Nothing is uploaded. Your original is preserved; exported copies are saved separately.").font(.callout).foregroundStyle(.secondary)
                Divider()
                if let doc = model.document {
                    metric("Pages", "\(doc.pages.count)")
                    metric("Suggestions", "\(doc.findings.count)")
                    metric("Selected redactions", "\(doc.redactionCount)")
                    metric("Pages reviewed", "\(doc.pages.filter(\.reviewed).count)")
                    if doc.wasPrepared { Label("Flattened review copy", systemImage: "doc.on.doc").font(.callout); Text("Visible annotation appearances were included. Compare with your original before exporting.").font(.caption).foregroundStyle(.secondary) }
                }
                Divider()
                Text("Detection is a starting point, not a privacy guarantee. Names without context, multi-line addresses, handwriting and unsupported scanned scripts may be missed.").font(.caption).foregroundStyle(.secondary).lineSpacing(4)
                Button("Privacy & language limits") { model.showPrivacy = true }.buttonStyle(.link)
            }.padding(22)
        }
    }
    private func metric(_ title: String, _ value: String) -> some View { HStack { Text(title).font(.callout); Spacer(); Text(value).font(.system(size: 16, weight: .semibold).monospacedDigit()) } }
}
