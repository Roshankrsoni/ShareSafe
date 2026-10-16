import SwiftUI
import ShareSafeCore

/// The animation describes activity, never a percentage or a detection result.
struct DocumentScanView: View {
    @EnvironmentObject private var model: Workspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    private let laser = Color(red: 1, green: 0.38, blue: 0.20)

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "viewfinder").foregroundStyle(laser)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scanning on your Mac").font(.headline)
                    Text(model.importingName ?? "Document").font(.caption).foregroundStyle(.white.opacity(0.65)).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Label("LOCAL", systemImage: "lock.shield").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
            }
            GeometryReader { geometry in
                let ratio = model.scanPreview?.image.map { CGFloat($0.width) / CGFloat($0.height) } ?? 612.0 / 792
                let width = max(1, min(geometry.size.width - 32, (geometry.size.height - 24) * ratio))
                let height = width / ratio
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(laser.opacity(0.06)).blur(radius: 30)
                    page
                        .frame(width: width, height: height, alignment: .topLeading)
                        .clipped()
                        .overlay {
                            if reduceMotion || model.cancelling {
                                Rectangle().stroke(laser.opacity(0.7), lineWidth: 2)
                            } else {
                                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                                    let phase = context.date.timeIntervalSince(started).truncatingRemainder(dividingBy: 2.8) / 2.8
                                    scanBeam(y: phase * (height + 100) - 50, width: width)
                                }.clipped().accessibilityHidden(true)
                            }
                        }
                        .overlay { ScanCorners().stroke(laser, style: StrokeStyle(lineWidth: 2, lineCap: .round)).padding(-7) }
                        .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(spacing: 12) {
                if !reduceMotion { ProgressView().controlSize(.small).preferredColorScheme(.dark) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.progress).font(.callout.weight(.medium))
                    Text(model.scanPreview.map { "Page \($0.pageIndex + 1) of \($0.pageCount) · Review suggestions when scanning completes" } ?? "Preparing a document preview…")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Button { model.cancel() } label: {
                    Text(model.cancelling ? "Cancelling…" : "Cancel scan")
                        .font(.callout.weight(.medium)).foregroundStyle(.white)
                        .padding(.horizontal, 15).padding(.vertical, 9)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.2)))
                }.buttonStyle(.plain).disabled(model.cancelling)
                    .accessibilityLabel("Cancel document scan")
            }
        }
        .padding(28)
        .foregroundStyle(.white)
        .background(Color(red: 0.065, green: 0.065, blue: 0.08))
    }

    @ViewBuilder private var page: some View {
        if let image = model.scanPreview?.image {
            Image(decorative: image, scale: 1).resizable().interpolation(.medium).overlay(.black.opacity(0.12))
                .accessibilityLabel("Original document preview during scanning")
        } else if let text = model.scanPreview?.text {
            Text(text).font(.system(size: 11, design: .monospaced)).lineSpacing(5)
                .foregroundStyle(.black.opacity(0.75)).padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(.white)
                .accessibilityLabel("Text document preview during scanning")
        } else {
            VStack(spacing: 14) {
                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 48, weight: .ultraLight))
                Text("Preparing preview").font(.callout)
            }.foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.04))
        }
    }

    private func scanBeam(y: Double, width: CGFloat) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [.clear, laser.opacity(0.25)], startPoint: .top, endPoint: .bottom).frame(height: 90).offset(y: y - 90)
            Rectangle().fill(laser.opacity(0.7)).frame(height: 8).blur(radius: 7).offset(y: y - 3)
            Rectangle().fill(.white).frame(height: 1.5).shadow(color: laser, radius: 4).offset(y: y)
        }.frame(width: width, alignment: .top).frame(maxHeight: .infinity, alignment: .top).allowsHitTesting(false)
    }
}

private struct ScanCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = 18
        return Path { path in
            for (x, y, dx, dy) in [(rect.minX, rect.minY, 1.0, 1.0), (rect.maxX, rect.minY, -1.0, 1.0), (rect.minX, rect.maxY, 1.0, -1.0), (rect.maxX, rect.maxY, -1.0, -1.0)] {
                path.move(to: CGPoint(x: x + dx * length, y: y))
                path.addLine(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + dy * length))
            }
        }
    }
}
