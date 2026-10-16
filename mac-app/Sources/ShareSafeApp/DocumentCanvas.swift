import SwiftUI
import AppKit
import ShareSafeCore

struct DocumentCanvas: View {
    @EnvironmentObject var model: Workspace
    var body: some View {
        VStack(spacing: 0) {
            if model.drawingMask || model.movingMask {
                HStack {
                    Image(systemName: model.movingMask ? "hand.draw" : "cursorarrow.rays")
                    Text(model.movingMask ? "Drag a manual mask to reposition it." : "Drag over a detail to cover it.")
                    Spacer()
                    Button("Done") { model.finishCanvasTool() }
                }.font(.caption).padding(12).background(Style.accent.opacity(0.09))
            }
            GeometryReader { geometry in
                ScrollView([.vertical, .horizontal]) {
                    if let page = model.page, let doc = model.document {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 7) {
                                Image(systemName: model.protectedPreview ? "shield" : "doc")
                                Text(model.protectedPreview ? "PROTECTED PREVIEW" : "ORIGINAL DOCUMENT").tracking(1.4)
                                Spacer()
                                if doc.isSample { Text("FICTIONAL SAMPLE").tracking(0.8) }
                            }.font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                            Group {
                                if doc.kind == .text { textPage(page, doc: doc, scale: pageWidth(page, geometry: geometry.size) / 612) }
                                else {
                                    ImagePage(page: page, findings: model.pageFindings, masks: doc.masks.filter { $0.pageIndex == model.pageIndex }, appearance: doc.maskAppearance, protectedPreview: model.protectedPreview, drawing: model.drawingMask, moving: model.movingMask, drawingShape: model.manualMaskShape, selected: model.selectedFinding, onMask: { model.addMask($0) }, onMoveMask: { id, rect in model.moveMask(id, to: rect) })
                                        .id("\(doc.id)-\(page.index)")
                                }
                            }
                            .background(.white)
                            .overlay(Rectangle().stroke(.black.opacity(0.06), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 8)
                            HStack { Image(systemName: "info.circle"); Text(page.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No readable text found. Use Draw mask to cover private details." : (model.protectedPreview ? (doc.maskAppearance.effect == .blur ? "Blur is visual concealment. Use Solid for sensitive details." : "Only confirmed redactions are applied on export.") : "Original preview contains unredacted information.")) }.font(.system(size: 10)).foregroundStyle(.secondary)
                        }.frame(width: pageWidth(page, geometry: geometry.size)).padding(32)
                            .frame(minWidth: geometry.size.width, alignment: .center)
                            .onAppear { model.displayedZoom = pageWidth(page, geometry: geometry.size) / baseWidth(page) * 100 }
                            .onChange(of: pageWidth(page, geometry: geometry.size)) { _, width in model.displayedZoom = width / baseWidth(page) * 100 }

                    }
                }
            }.background(Style.canvas)
        }
    }
    private func baseWidth(_ page: DocumentPage) -> CGFloat { model.document?.kind == .text ? 612 : max(1, page.pointWidth) }
    private func pageWidth(_ page: DocumentPage, geometry: CGSize) -> CGFloat {
        switch model.zoomMode {
        case "width": return max(180, geometry.width - 64)
        case "page":
            let ratio = model.document?.kind == .text ? 612.0 / 792 : CGFloat(page.pixelWidth) / CGFloat(max(1, page.pixelHeight))
            return max(120, min(geometry.width - 64, (geometry.height - 100) * ratio))
        default: return baseWidth(page) * model.zoomPercent / 100
        }
    }

    private func textPage(_ page: DocumentPage, doc: ReviewDocument, scale: CGFloat) -> some View {
        let text: AttributedString = {
            if model.protectedPreview {
                return AttributedString(TextRedactor.redact(page.text, findings: doc.findings, aliases: doc.policy == .ai))
            }
            let value = NSMutableAttributedString(string: page.text)
            for finding in model.pageFindings {
                guard NSMaxRange(finding.range) <= value.length else { continue }
                value.addAttribute(.backgroundColor, value: NSColor.systemOrange.withAlphaComponent(0.18), range: finding.range)
            }
            return AttributedString(value)
        }()
        return VStack(alignment: .leading, spacing: 0) {
            Text(text).font(.system(size: 12 * scale, weight: .regular, design: .monospaced)).foregroundStyle(Color(white: 0.18)).lineSpacing(6 * scale).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 30)
        }.padding(39 * scale).frame(minHeight: 680 * scale, alignment: .topLeading)
    }
}

struct ImagePage: View {
    let page: DocumentPage
    let findings: [Finding]
    let masks: [ManualMask]
    let appearance: MaskAppearance
    let protectedPreview: Bool
    let drawing: Bool
    let moving: Bool
    let drawingShape: ManualMaskShape
    let selected: UUID?
    let onMask: (CGRect) -> Void
    let onMoveMask: (UUID, CGRect) -> Void
    @State private var image: NSImage?
    @State private var sourceImage: CGImage?
    @State private var start: CGPoint?
    @State private var current: CGPoint?
    @State private var movingMaskID: UUID?
    @State private var movingMaskStart: CGRect?
    @State private var moveTranslation = CGSize.zero
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if let image {
                    Image(nsImage: image).resizable().interpolation(.high)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                findingLayer(size: proxy.size)
                manualLayer(size: proxy.size)
                dragPreview
                if drawing { drawingLayer(size: proxy.size) }
                if moving { moveLayer(size: proxy.size) }
            }.clipped()
        }
        .aspectRatio(CGFloat(page.pixelWidth) / CGFloat(max(1, page.pixelHeight)), contentMode: .fit)
        .onAppear { if let data = page.imageData, let source = try? DocumentProcessor.image(from: data) { sourceImage = source; image = NSImage(cgImage: source, size: .zero) } }
    }
    private func findingLayer(size: CGSize) -> some View {
        ForEach(findings) { finding in
            ForEach(Array(finding.rectangles.enumerated()), id: \.offset) { entry in
                let frame = displayRect(entry.element, size: size)
                let color: Color = protectedPreview && finding.decision == .redact ? .black : finding.decision == .keep ? .clear : .orange.opacity(0.18)
                Group {
                    if protectedPreview && finding.decision == .redact {
                        MaskTile(source: sourceImage, rect: entry.element, appearance: appearance, shape: finding.maskShape)
                    } else { Rectangle().fill(color) }
                }
                    .clipShape(drawingShapeView(finding.maskShape))
                    .overlay(drawingShapeView(finding.maskShape).stroke(selected == finding.id ? Style.accent : Color.clear, lineWidth: 2))
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .accessibilityLabel("\(finding.kind.title), \(finding.decision.rawValue)")
            }
        }
    }
    @ViewBuilder private func manualLayer(size: CGSize) -> some View {
        if protectedPreview {
            ForEach(masks) { mask in
                let normalizedRect = mask.id == movingMaskID ? translatedMaskRect(mask.rect, by: moveTranslation, size: size) : mask.rect
                let frame = displayRect(normalizedRect, size: size)
                MaskTile(source: sourceImage, rect: mask.rect, appearance: appearance, shape: mask.shape).frame(width: frame.width, height: frame.height)
                    .clipShape(drawingShapeView(mask.shape))
                    .overlay(drawingShapeView(mask.shape).stroke(mask.id == movingMaskID ? Style.accent : .black.opacity(0.08), lineWidth: mask.id == movingMaskID ? 2 : 0.5))
                    .offset(x: frame.minX, y: frame.minY).accessibilityLabel("Manual \(mask.shape.rawValue.lowercased()) redaction")
            }
        }
    }
    @ViewBuilder private var dragPreview: some View {
        if let start, let current {
            let rect = dragRect(start, current)
            drawingShapeView(drawingShape).fill(Style.accent.opacity(0.25))
                .overlay(drawingShapeView(drawingShape).stroke(Style.accent, style: StrokeStyle(lineWidth: 1, dash: [4])))
                .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
        }
    }
    private func drawingLayer(size: CGSize) -> some View {
        Color.clear.contentShape(Rectangle()).gesture(
            DragGesture(minimumDistance: 2).onChanged { value in
                start = clamped(value.startLocation, size: size)
                current = clamped(value.location, size: size)
            }.onEnded { value in
                let rect = dragRect(clamped(value.startLocation, size: size), clamped(value.location, size: size))
                onMask(CGRect(x: rect.minX / size.width, y: 1 - rect.maxY / size.height, width: rect.width / size.width, height: rect.height / size.height))
                start = nil; current = nil
            }
        )
    }
    private func moveLayer(size: CGSize) -> some View {
        Color.clear.contentShape(Rectangle()).gesture(
            DragGesture(minimumDistance: 2).onChanged { value in
                if movingMaskID == nil {
                    guard let mask = mask(at: value.startLocation, size: size) else { return }
                    movingMaskID = mask.id
                    movingMaskStart = mask.rect
                }
                moveTranslation = value.translation
            }.onEnded { value in
                if let id = movingMaskID, let start = movingMaskStart {
                    onMoveMask(id, translatedMaskRect(start, by: value.translation, size: size))
                }
                movingMaskID = nil; movingMaskStart = nil; moveTranslation = .zero
            }
        ).help("Drag a manual mask to move it")
    }
    private func mask(at point: CGPoint, size: CGSize) -> ManualMask? {
        let normalized = CGPoint(x: point.x / max(size.width, 1), y: 1 - point.y / max(size.height, 1))
        return masks.reversed().first { mask in
            let r = mask.rect
            guard r.width > 0, r.height > 0 else { return false }
            if mask.shape == .round {
                let dx = (normalized.x - r.midX) / (r.width / 2)
                let dy = (normalized.y - r.midY) / (r.height / 2)
                return dx * dx + dy * dy <= 1
            }
            return r.contains(normalized)
        }
    }
    private func translatedMaskRect(_ rect: CGRect, by translation: CGSize, size: CGSize) -> CGRect {
        let width = max(size.width, 1), height = max(size.height, 1)
        let x = min(max(rect.minX + translation.width / width, 0), 1 - rect.width)
        let y = min(max(rect.minY - translation.height / height, 0), 1 - rect.height)
        return CGRect(x: x, y: y, width: rect.width, height: rect.height)
    }
    private func displayRect(_ normalized: CGRect, size: CGSize) -> CGRect {
        let padded = SafeExporter.pixelRect(normalized, width: page.pixelWidth, height: page.pixelHeight)
        return CGRect(x: padded.minX / Double(page.pixelWidth) * size.width, y: (1 - padded.maxY / Double(page.pixelHeight)) * size.height, width: padded.width / Double(page.pixelWidth) * size.width, height: padded.height / Double(page.pixelHeight) * size.height)
    }
    private func clamped(_ point: CGPoint, size: CGSize) -> CGPoint { CGPoint(x: min(max(point.x, 0), size.width), y: min(max(point.y, 0), size.height)) }
    private func dragRect(_ a: CGPoint, _ b: CGPoint) -> CGRect { CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y)) }
    private func drawingShapeView(_ shape: ManualMaskShape) -> AnyShape {
        shape == .round ? AnyShape(Ellipse()) : AnyShape(Rectangle())
    }
}

struct ExportSheet: View {
    @EnvironmentObject var model: Workspace
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "square.and.arrow.up").font(.system(size: 30, weight: .light)).foregroundStyle(Style.accent)
            Text("A reviewed copy, ready to share.").font(.title2.weight(.semibold))
            if let doc = model.document {
                Text("\(doc.redactionCount) redactions · \(doc.pages.count) reviewed page\(doc.pages.count == 1 ? "" : "s")").foregroundStyle(.secondary)
                Divider()
                Label("Your original stays untouched", systemImage: "doc.on.doc")
                Label("Processed and checked on your Mac", systemImage: "lock.shield")
                if doc.kind == .pdf {
                    Text("The exported PDF contains page images. Original text layers, links, attachments and metadata are not copied. Searchable text, forms, signatures and vector detail are lost.").font(.callout).foregroundStyle(.secondary).lineSpacing(4)
                } else if doc.kind == .image {
                    Text("A new PNG is created with opaque masks and without copying the source metadata.").font(.callout).foregroundStyle(.secondary)
                } else {
                    Text(doc.policy == .ai ? "Selected details become consistent aliases in a new UTF-8 text file. No alias map is saved." : "Selected details become [REDACTED] in a new UTF-8 text file.").font(.callout).foregroundStyle(.secondary)
                }
                if doc.kind != .text && doc.maskAppearance.effect == .blur {
                    Label("Blur is visual concealment, not secure redaction. Details may remain recognizable. Choose Solid for sensitive information.", systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(Style.amber)
                }
                Text("Checks confirm selected changes, not that every sensitive detail was found. Review the exported copy before sharing.").font(.caption).foregroundStyle(.secondary).padding(12).background(Style.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
            }
            HStack { Button("Back to review") { dismiss() }.keyboardShortcut(.cancelAction); Spacer(); Button("Choose save location…") { model.saveExport() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }
        }.padding(30).frame(width: 490).tint(Style.accent)
    }
}

struct ReceiptSheet: View {
    let receipt: ExportReceipt
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 36)).foregroundStyle(Style.success)
            Text("Your reviewed copy is saved.").font(.title2.weight(.semibold))
            Text(receipt.url.lastPathComponent).font(.callout.weight(.medium)).textSelection(.enabled)
            ForEach(receipt.checks, id: \.self) { Label($0, systemImage: "checkmark").font(.callout).foregroundStyle(Style.success) }
            Text("These checks verify the export process. They do not certify that all sensitive information was identified.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("SHA-256 · \(ByteCountFormatter.string(fromByteCount: Int64(receipt.size), countStyle: .file))").font(.caption).foregroundStyle(.secondary)
            Text(receipt.hash).font(.system(size: 9, design: .monospaced)).textSelection(.enabled)
            HStack { Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([receipt.url]) }; Spacer(); Button("Done") { dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }
        }.padding(30).frame(width: 500).tint(Style.success)
    }
}

struct PrivacySheet: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Label("Private, with clear limits.", systemImage: "lock.shield").font(.title2.weight(.semibold)).foregroundStyle(Style.accent)
            Text("Your documents are processed locally. ShareSafe has no account, upload service, analytics or saved document history. Preferences are stored; document content is kept only for the current session.").lineSpacing(4)
            Text("Detection combines PDF text with local OCR in languages supported by your macOS version. Indian ID and international phone patterns are suggestions, not identity validation. Optional face-region suggestions run on new PDF and image imports, but can miss faces or flag illustrations; they never identify people. Addresses, handwriting, faces, indirect identifiers and unfamiliar formats can be missed. Review every page and use custom text or manual masks.").lineSpacing(4)
            Text("PDF exports are rebuilt from images. They discard the original object structure and lose searchable text, forms and signatures. Text aliases apply only to plain-text files.").lineSpacing(4)
            Text("Limits: 25 MB per file, 40 PDF pages, 12 megapixels per image and 1 MB UTF-8 text. Large PDFs may exceed the total rendering limit. Multi-frame images are rejected. PDFs with forms or annotations offer an in-app flattened review copy. Password-protected PDFs can be unlocked for the session.").font(.callout).foregroundStyle(.secondary)
            Text("Solid masks replace source pixels. Blur only obscures their appearance and may leave details recognizable. Local processing does not guarantee secure memory erasure. Your operating system may swap memory or collect crash diagnostics. Saved exports follow the destination’s backup and access settings.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Got it") { dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }
        }.padding(30).frame(width: 550).tint(Style.accent)
    }
}
