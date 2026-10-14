import Foundation
import AVFoundation
import CoreGraphics
import CoreText
import ImageIO

// ─────────────────────────────────────────────────────────────────────────────
// ShareSafe product demo — 24s · 1280×860 · 30fps · silent master.
// 2s title · 4 × 5s scenes (Detect, Decide, Protect, Export) · 2s end card.
// Captures are shown at a fixed size — no camera zoom — so every pixel of the
// real UI stays legible. A pointer animates across each scene and a tooltip
// names the control it is addressing. Audio is muxed in afterwards.
// ─────────────────────────────────────────────────────────────────────────────

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let width = 1280, height = 860, fps: Int32 = 30
let duration = 24.0
let titleEnd = 2.0, sceneLen = 5.0, scenesStart = 2.0, scenesEnd = 22.0

func smooth(_ x: Double) -> Double { let c = min(1, max(0, x)); return c * c * (3 - 2 * c) }
func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }

struct Move { let t: Double; let u: Double; let v: Double }
struct Hint { let from: Double; let to: Double; let text: String }
struct Scene { let moves: [Move]; let clicks: [Double]; let hints: [Hint] }

let scenes: [Scene] = [
  // 01 Detect — tour the three suggestions; no decision is taken yet.
  Scene(moves: [
    Move(t: 0.00, u: 0.40, v: 0.58),
    Move(t: 0.70, u: 0.83, v: 0.27),
    Move(t: 1.45, u: 0.82, v: 0.41),
    Move(t: 2.15, u: 0.82, v: 0.54),
    Move(t: 2.85, u: 0.82, v: 0.66),
    Move(t: 3.60, u: 0.83, v: 0.30),
    Move(t: 5.00, u: 0.83, v: 0.27),
  ], clicks: [], hints: [
    Hint(from: 0.70, to: 1.45, text: "3 suggestions found on this page"),
    Hint(from: 1.45, to: 2.15, text: "Email address — flagged for review"),
    Hint(from: 2.15, to: 2.85, text: "Phone number — flagged for review"),
    Hint(from: 2.85, to: 3.60, text: "Payment card — flagged for review"),
    Hint(from: 3.60, to: 5.00, text: "Detection runs locally on your Mac"),
  ]),
  // 02 Decide — redact the email, keep the phone number.
  Scene(moves: [
    Move(t: 0.00, u: 0.83, v: 0.30),
    Move(t: 0.70, u: 0.82, v: 0.45),
    Move(t: 1.80, u: 0.91, v: 0.58),
    Move(t: 2.80, u: 0.82, v: 0.70),
    Move(t: 3.60, u: 0.82, v: 0.45),
    Move(t: 5.00, u: 0.82, v: 0.45),
  ], clicks: [0.95, 2.05], hints: [
    Hint(from: 0.70, to: 1.80, text: "Redact — cover this detail"),
    Hint(from: 1.80, to: 2.80, text: "Keep — leave it visible"),
    Hint(from: 2.80, to: 3.60, text: "Payment card — still undecided"),
    Hint(from: 3.60, to: 5.00, text: "Undo and redo stay one click away"),
  ]),
  // 03 Protect — one click covers the whole page.
  Scene(moves: [
    Move(t: 0.00, u: 0.82, v: 0.50),
    Move(t: 1.00, u: 0.87, v: 0.85),
    Move(t: 2.20, u: 0.87, v: 0.85),
    Move(t: 3.40, u: 0.87, v: 0.85),
    Move(t: 5.00, u: 0.87, v: 0.85),
  ], clicks: [1.25], hints: [
    Hint(from: 1.00, to: 2.20, text: "Redact all on page — mask every suggestion"),
    Hint(from: 2.20, to: 3.40, text: "Solid masks replace the pixels"),
    Hint(from: 3.40, to: 5.00, text: "Blur alone is not redaction"),
  ]),
  // 04 Export — read the receipt, then dismiss it.
  Scene(moves: [
    Move(t: 0.00, u: 0.10, v: 0.13),
    Move(t: 0.95, u: 0.10, v: 0.40),
    Move(t: 1.80, u: 0.33, v: 0.76),
    Move(t: 2.65, u: 0.89, v: 0.91),
    Move(t: 5.00, u: 0.89, v: 0.91),
  ], clicks: [2.90], hints: [
    Hint(from: 0.95, to: 1.80, text: "Mask checks and page count verified"),
    Hint(from: 1.80, to: 2.65, text: "SHA-256 fingerprint of the saved file"),
    Hint(from: 2.65, to: 5.00, text: "Done — close the receipt"),
  ]),
]

func pointer(_ scene: Int, _ local: Double) -> (u: Double, v: Double) {
  let path = scenes[scene].moves
  var i = 0
  while i < path.count - 2 && local > path[i + 1].t { i += 1 }
  let a = path[i], b = path[min(i + 1, path.count - 1)]
  let span = max(0.0001, b.t - a.t)
  let k = smooth((local - a.t) / span)
  return (a.u + (b.u - a.u) * k, a.v + (b.v - a.v) * k)
}

func clickAmount(_ scene: Int, _ local: Double) -> Double {
  var best = 0.0
  for time in scenes[scene].clicks {
    let d = local - time
    if d >= 0 && d < 0.55 { best = max(best, (1 - d / 0.55) * (d < 0.06 ? d / 0.06 : 1)) }
  }
  return best
}

/// Tooltip copy for the moment, faded in and out at the edges of its window.
func hintAlpha(_ scene: Int, _ local: Double) -> (String, Double) {
  for hint in scenes[scene].hints where local >= hint.from && local < hint.to {
    let span = min(0.22, (hint.to - hint.from) / 3)
    let fadeIn = span > 0 ? smooth((local - hint.from) / span) : 1
    let fadeOut = span > 0 ? smooth((hint.to - local) / span) : 1
    return (hint.text, min(fadeIn, fadeOut))
  }
  return ("", 0)
}

func image(_ path: String) -> CGImage {
  let source = CGImageSourceCreateWithURL(root.appendingPathComponent(path) as CFURL, nil)!
  return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}

let backdrop = image("artifacts/video-frames/wallpaper.png")
let overlays: [String: CGImage] = [
  "title": image("artifacts/video-frames/overlay-title.png"),
  "0": image("artifacts/video-frames/overlay-0.png"),
  "1": image("artifacts/video-frames/overlay-1.png"),
  "2": image("artifacts/video-frames/overlay-2.png"),
  "3": image("artifacts/video-frames/overlay-3.png"),
  "end": image("artifacts/video-frames/overlay-end.png"),
]

/// macOS-style pointer: white body, dark rim, soft shadow.
func drawCursor(_ x: Double, _ y: Double, _ press: Double, _ context: CGContext) {
  if press > 0.01 {
    let radius = 6 + 30 * (1 - press)
    context.saveGState()
    context.setStrokeColor(CGColor(red: 0.34, green: 0.70, blue: 0.55, alpha: 0.85 * press))
    context.setLineWidth(2.2)
    context.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    context.strokePath()
    context.restoreGState()
  }
  let shape: [(Double, Double)] = [(0, 0), (0, 24), (5.6, 18.6), (9.6, 27.2), (13.6, 24.6), (9.6, 16.6), (15.2, 16.6)]
  let path = CGMutablePath()
  path.move(to: CGPoint(x: x + shape[0].0, y: y + shape[0].1))
  for p in shape.dropFirst() { path.addLine(to: CGPoint(x: x + p.0, y: y + p.1)) }
  path.closeSubpath()

  context.saveGState()
  context.setShadow(offset: CGSize(width: 1.5, height: -2), blur: 4, color: CGColor(gray: 0, alpha: 0.35))
  context.setFillColor(CGColor(gray: 1, alpha: 1))
  context.addPath(path); context.fillPath()
  context.restoreGState()

  context.saveGState()
  context.addPath(path)
  context.setStrokeColor(CGColor(gray: 0.05, alpha: 0.92))
  context.setLineWidth(1.3); context.setLineJoin(.round)
  context.strokePath()
  context.restoreGState()
}

/// Caption pill that names the control the pointer is addressing.
func drawTooltip(_ text: String, _ px: Double, _ py: Double, _ alpha: Double, _ context: CGContext) {
  guard alpha > 0.02, !text.isEmpty else { return }
  let font = CTFontCreateWithName("SFProText-Semibold" as CFString, 16, nil)
  let attributes: [CFString: Any] = [
    kCTFontAttributeName: font,
    kCTForegroundColorAttributeName: CGColor(gray: 1, alpha: 1),
    kCTKernAttributeName: 0.1,
  ]
  guard let attributed = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary) else { return }
  let line = CTLineCreateWithAttributedString(attributed)
  let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
  let textWidth = Double(CTLineGetTypographicBounds(line, nil, nil, nil))

  let padX = 14.0, padY = 9.0
  let boxW = min(textWidth + padX * 2, 400)
  let boxH = Double(ascent - descent) + padY * 2
  // Sit below the pointer, nudged to whichever side has room, always on frame and
  // clear of the caption bar that occupies the bottom of every scene.
  let belowY = clamp(py + 34, 18, 732 - boxH)
  var bx = px + 28
  if bx + boxW > Double(width) - 20 { bx = px - 28 - boxW }
  bx = clamp(bx, 20, Double(width) - 20 - boxW)
  let box = CGRect(x: bx, y: belowY, width: boxW, height: boxH)

  context.saveGState()
  context.setAlpha(alpha)
  context.setShadow(offset: CGSize(width: 0, height: 6), blur: 14, color: CGColor(gray: 0, alpha: 0.38))
  context.setFillColor(CGColor(red: 0.055, green: 0.09, blue: 0.075, alpha: 0.96))
  context.addPath(CGPath(roundedRect: box, cornerWidth: 10, cornerHeight: 10, transform: nil))
  context.fillPath()
  context.setShadow(offset: .zero, blur: 0, color: nil)
  context.setStrokeColor(CGColor(red: 0.34, green: 0.70, blue: 0.55, alpha: 0.55))
  context.setLineWidth(1)
  context.addPath(CGPath(roundedRect: box, cornerWidth: 10, cornerHeight: 10, transform: nil))
  context.strokePath()
  context.restoreGState()

  context.saveGState()
  // The caller has already flipped the context; glyphs need one more flip so
  // the baseline sits correctly in that top-left-origin space.
  context.textMatrix = .identity
  context.translateBy(x: CGFloat(bx + padX), y: CGFloat(belowY + padY + Double(ascent)))
  context.scaleBy(x: 1, y: -1)
  CTLineDraw(line, context)
  context.restoreGState()
}

for theme in ["light", "dark"] {
  let out = root.appendingPathComponent("artifacts/video/frames-\(theme).mov")
  try? FileManager.default.removeItem(at: out)
  try? FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)

  let writer = try AVAssetWriter(outputURL: out, fileType: .mov)
  let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width, AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
      AVVideoAverageBitRateKey: 3_200_000,
      AVVideoMaxKeyFrameIntervalKey: 60,
      AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    ],
  ])
  input.expectsMediaDataInRealTime = false
  let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
  ])
  writer.add(input); writer.shouldOptimizeForNetworkUse = true
  writer.startWriting(); writer.startSession(atSourceTime: .zero)

  let screens = (0..<4).map { image("artifacts/video-frames/clean/\(theme)-\($0).png") }

  /// Fixed geometry — the capture is never scaled up or zoomed during a scene.
  func rect(_ index: Int) -> CGRect {
    let pic = screens[index]
    let fit = min(1120.0 / Double(pic.width), 720.0 / Double(pic.height))
    let w = Double(pic.width) * fit, h = Double(pic.height) * fit
    return CGRect(x: (1280 - w) / 2, y: (860 - h) / 2 + 14, width: w, height: h)
  }
  func drawShot(_ index: Int, _ alpha: Double, _ context: CGContext) {
    if alpha <= 0.001 { return }
    let r = rect(index)
    context.saveGState()
    context.setAlpha(alpha)
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 36, color: CGColor(gray: 0, alpha: 0.35))
    context.addPath(CGPath(roundedRect: r, cornerWidth: 14, cornerHeight: 14, transform: nil))
    context.clip()
    context.interpolationQuality = .high
    context.draw(screens[index], in: r)
    context.restoreGState()
  }
  func drawOverlay(_ name: String, _ alpha: Double, _ context: CGContext) {
    guard alpha > 0.001, let ov = overlays[name] else { return }
    context.saveGState()
    context.setAlpha(alpha); context.interpolationQuality = .high
    context.draw(ov, in: CGRect(x: 0, y: 0, width: width, height: height))
    context.restoreGState()
  }
  func drawPointer(_ index: Int, _ local: Double, _ alpha: Double, _ context: CGContext) {
    if alpha <= 0.01 { return }
    let r = rect(index)
    let (u, v) = pointer(index, local)
    let x = r.minX + u * r.width
    let y = r.minY + v * r.height
    // Bitmap contexts are bottom-left origin; flip so paths and text sit upright.
    context.saveGState()
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    drawCursor(x, y, clickAmount(index, local), context)
    let (text, hintFade) = hintAlpha(index, local)
    if hintFade > 0.02 { drawTooltip(text, x, y, hintFade * alpha, context) }
    context.restoreGState()
  }
  func drawProgress(_ t: Double, _ context: CGContext) {
    let bar = CGRect(x: 0, y: Double(height) - 6, width: Double(width), height: 6)
    context.saveGState()
    context.setFillColor(CGColor(gray: 1, alpha: 0.22)); context.fill(bar)
    context.setFillColor(CGColor(red: 0.29, green: 0.70, blue: 0.54, alpha: 1))
    context.fill(CGRect(x: 0, y: Double(height) - 6, width: Double(width) * min(1, t / duration), height: 6))
    context.restoreGState()
  }

  for frame in 0..<Int(duration * Double(fps)) {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    autoreleasepool {
      var optional: CVPixelBuffer?
      CVPixelBufferPoolCreatePixelBuffer(nil, adapter.pixelBufferPool!, &optional)
      let pixel = optional!
      CVPixelBufferLockBaseAddress(pixel, [])
      let context = CGContext(
        data: CVPixelBufferGetBaseAddress(pixel), width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!

      context.draw(backdrop, in: CGRect(x: 0, y: 0, width: width, height: height))
      let t = Double(frame) / Double(fps)

      if t < scenesStart {
        var a = min(1, t / 0.45)
        var blend = 0.0
        if t > titleEnd - 0.6 { blend = smooth((t - (titleEnd - 0.6)) / 0.6); a = 1 - blend }
        drawOverlay("title", a, context)
        if blend > 0 {
          drawShot(0, blend, context)
          drawOverlay("0", blend, context)
          drawPointer(0, 0, blend, context)
        }
      } else if t < scenesEnd {
        let local = t - scenesStart
        let scene = min(3, Int(local / sceneLen))
        let phase = (local - Double(scene) * sceneLen) / sceneLen
        let sceneLocal = local - Double(scene) * sceneLen
        if phase <= 0.88 {
          drawShot(scene, 1, context)
          drawOverlay("\(scene)", 1, context)
          drawPointer(scene, sceneLocal, 1, context)
        } else {
          let b = smooth((phase - 0.88) / 0.12)
          let next = scene + 1
          drawShot(scene, 1 - b, context)
          drawOverlay("\(scene)", 1 - b, context)
          if next < 4 {
            drawShot(next, b, context)
            drawOverlay("\(next)", b, context)
            drawPointer(next, 0, b, context)
          } else {
            drawOverlay("end", b, context)
          }
        }
      } else {
        drawOverlay("end", 1, context)
      }

      drawProgress(t, context)
      CVPixelBufferUnlockBaseAddress(pixel, [])
      if !adapter.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: fps)) {
        fatalError("Frame failed: \(String(describing: writer.error))")
      }
    }
  }
  input.markAsFinished()
  let sem = DispatchSemaphore(value: 0)
  writer.finishWriting { sem.signal() }
  sem.wait()
  guard writer.status == .completed else { fatalError("Video failed \(String(describing: writer.error))") }
  print("Rendered \(out.lastPathComponent): \(Int(duration))s, \(fps)fps, \(width)×\(height) — static captures, no zoom")
}