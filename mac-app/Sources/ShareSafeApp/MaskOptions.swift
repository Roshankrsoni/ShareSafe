import SwiftUI
import AppKit
import ShareSafeCore

struct MaskOptions: View {
    @EnvironmentObject var model: Workspace
    private var appearance: MaskAppearance { model.document?.maskAppearance ?? MaskAppearance() }
    private func change(_ body: (inout MaskAppearance) -> Void) {
        model.update { doc in
            body(&doc.maskAppearance)
            for i in doc.pages.indices { doc.pages[i].reviewed = false }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Mask appearance").font(.system(size: 15, weight: .semibold)); Spacer(); Text("THIS DOCUMENT").font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary) }
            Picker("Treatment", selection: Binding(get: { appearance.effect }, set: { effect in change { $0.effect = effect } })) {
                ForEach(MaskEffect.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            if appearance.effect == .solid {
                HStack(spacing: 12) {
                    ForEach(Array([("Ink", 0.0, 0.0, 0.0), ("Paper", 1.0, 1.0, 1.0), ("Slate", 0.34, 0.38, 0.44), ("Blue", 0.12, 0.36, 0.86)].enumerated()), id: \.offset) { entry in
                        let value = entry.element
                        Button { change { $0.red = value.1; $0.green = value.2; $0.blue = value.3 } } label: {
                            Circle().fill(Color(red: value.1, green: value.2, blue: value.3)).frame(width: 25, height: 25)
                                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                                .overlay(Circle().stroke(Style.accent, lineWidth: 2).padding(-4).opacity(appearance.red == value.1 && appearance.green == value.2 && appearance.blue == value.3 ? 1 : 0))
                        }.buttonStyle(.plain).accessibilityLabel("\(value.0) mask").help(value.0)
                    }
                    Spacer()
                    ColorPicker("Custom", selection: Binding(get: { Color(cgColor: appearance.color) }, set: { value in
                        guard let rgb = NSColor(value).usingColorSpace(.deviceRGB) else { return }
                        change { $0.red = rgb.redComponent; $0.green = rgb.greenComponent; $0.blue = rgb.blueComponent }
                    }), supportsOpacity: false).font(.caption)
                }
                Text("Opaque color replaces covered pixels. Applies to all masks in this document.").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
            } else {
                HStack { Text("Strength"); Spacer(); Text("\(Int(appearance.blurRadius))").monospacedDigit() }.font(.caption)
                Slider(value: Binding(get: { appearance.blurRadius }, set: { radius in change { $0.blurRadius = radius } }), in: 10...60, step: 5)
                Label("Blur can leave information recognizable. Use Solid for sensitive details.", systemImage: "exclamationmark.triangle").font(.system(size: 11)).foregroundStyle(Style.amber).lineSpacing(3)
            }
        }.padding(22).frame(width: 305).tint(Style.accent).disabled(model.busy)
    }
}

struct MaskTile: View {
    let source: CGImage?
    let rect: CGRect
    let appearance: MaskAppearance
    @State private var tile: NSImage?
    private var renderKey: String { "\(rect)-\(appearance)" }
    var body: some View {
        ZStack {
            Color(cgColor: appearance.color)
            if appearance.effect == .blur, let tile { Image(nsImage: tile).resizable().interpolation(.high) }
        }.task(id: renderKey) {
            guard appearance.effect == .blur, let source else { tile = nil; return }
            let maskRect = rect, style = appearance
            let output = await Task.detached(priority: .userInitiated) {
                return try? MaskRenderer.tile(source: source, rect: SafeExporter.pixelRect(maskRect, width: source.width, height: source.height), appearance: style)
            }.value
            guard !Task.isCancelled else { return }
            if let output { tile = NSImage(cgImage: output, size: .zero) }
        }
    }
}
