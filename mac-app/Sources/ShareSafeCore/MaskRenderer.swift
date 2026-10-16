import Foundation
import CoreGraphics
import CoreImage

/// Shared by preview and export so the selected appearance uses the same pixel treatment.
public enum MaskRenderer {
    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    public static func tile(source: CGImage, rect: CGRect, appearance: MaskAppearance, shape: ManualMaskShape = .rectangle) throws -> CGImage {
        guard appearance.isValid, !rect.isEmpty, let context = DocumentProcessor.makeContext(width: Int(rect.width), height: Int(rect.height)) else {
            throw ShareSafeError.invalid("Could not render this mask.")
        }
        let bounds = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)
        if shape == .round {
            let crop = CGRect(x: rect.minX, y: Double(source.height) - rect.maxY, width: rect.width, height: rect.height)
            guard let originalTile = source.cropping(to: crop) else { throw ShareSafeError.invalid("Could not crop this round mask.") }
            context.draw(originalTile, in: bounds)
            context.saveGState()
            context.addEllipse(in: bounds)
            context.clip()
        }
        context.setFillColor(appearance.color)
        context.fill(bounds)
        if appearance.effect == .blur {
            // Crop before filtering to avoid sampling unrelated text outside the selected area.
            let input = CIImage(cgImage: source).cropped(to: rect)
            let filtered = input.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: appearance.blurRadius]).cropped(to: rect)
            guard let blurred = ciContext.createCGImage(filtered, from: rect) else { throw ShareSafeError.invalid("Blur rendering failed.") }
            context.draw(blurred, in: bounds)
        }
        if shape == .round { context.restoreGState() }
        guard let output = context.makeImage() else { throw ShareSafeError.invalid("Mask rendering failed.") }
        return output
    }

    static func verify(_ image: CGImage, tile: CGImage, rect: CGRect) -> Bool {
        // CGImage cropping uses top-left coordinates; drawing coordinates use bottom-left.
        let crop = CGRect(x: rect.minX, y: Double(image.height) - rect.maxY, width: rect.width, height: rect.height)
        guard let actual = image.cropping(to: crop), let a = DocumentProcessor.makeContext(width: tile.width, height: tile.height),
              let b = DocumentProcessor.makeContext(width: tile.width, height: tile.height), let ap = a.data, let bp = b.data else { return false }
        let bounds = CGRect(x: 0, y: 0, width: tile.width, height: tile.height)
        a.draw(actual, in: bounds); b.draw(tile, in: bounds)
        let av = ap.assumingMemoryBound(to: UInt8.self), bv = bp.assumingMemoryBound(to: UInt8.self)
        for i in stride(from: 0, to: tile.width * tile.height * 4, by: 4) {
            for channel in 0..<3 where abs(Int(av[i + channel]) - Int(bv[i + channel])) > 1 { return false }
        }
        return true
    }
}
