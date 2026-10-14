import Foundation
import AVFoundation
import CoreMedia

// ─────────────────────────────────────────────────────────────────────────────
// Adds the synthesised soundtrack to the rendered silent master and writes the
// final MP4. AVMutableComposition keeps the original video track untouched and
// AVAssetExportSession encodes only the PCM audio to AAC.
// ─────────────────────────────────────────────────────────────────────────────

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let audioURL = root.appendingPathComponent("artifacts/audio/sharesafe-demo.wav")

for theme in ["light", "dark"] {
  let silentURL = root.appendingPathComponent("artifacts/video/frames-\(theme).mov")
  let finalURL = root.appendingPathComponent("public/video/sharesafe-demo-\(theme).mp4")
  guard FileManager.default.fileExists(atPath: silentURL.path) else {
    fatalError("Missing silent master \(silentURL.path) — run render-product-video.swift first")
  }
  if FileManager.default.fileExists(atPath: finalURL.path) { try FileManager.default.removeItem(at: finalURL) }

  let video = AVURLAsset(url: silentURL)
  let sound = AVURLAsset(url: audioURL)

  guard let videoTrack = video.tracks(withMediaType: .video).first,
        let audioTrack = sound.tracks(withMediaType: .audio).first else {
    fatalError("Could not read tracks from \(silentURL.lastPathComponent)")
  }

  let duration = CMTimeMinimum(video.duration, sound.duration)
  let composition = AVMutableComposition()
  guard let outVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
        let outAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
    fatalError("Could not build composition")
  }

  try outVideo.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
  outVideo.preferredTransform = videoTrack.preferredTransform
  try outAudio.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)

  // Passthrough keeps the video bit-exact, but MP4 cannot carry PCM, so fall
  // back to a re-encoding preset (video re-encoded, audio to AAC) if needed.
  func attempt(_ preset: String) -> AVAssetExportSession? {
    guard let session = AVAssetExportSession(asset: composition, presetName: preset) else { return nil }
    session.outputURL = finalURL
    session.outputFileType = .mp4
    session.shouldOptimizeForNetworkUse = true
    let semaphore = DispatchSemaphore(value: 0)
    session.exportAsynchronously { semaphore.signal() }
    semaphore.wait()
    return session.status == .completed ? session : nil
  }

  if attempt(AVAssetExportPresetPassthrough) == nil {
    if FileManager.default.fileExists(atPath: finalURL.path) { try FileManager.default.removeItem(at: finalURL) }
    print("  passthrough unavailable for PCM; re-encoding with \(AVAssetExportPresetHighestQuality)")
    guard attempt(AVAssetExportPresetHighestQuality) != nil else {
      fatalError("Export failed with every preset: \(String(describing: finalURL.path))")
    }
  }

  let bytes = (try! FileManager.default.attributesOfItem(atPath: finalURL.path)[.size] as! NSNumber).intValue
  print("Muxed \(finalURL.lastPathComponent): video + AAC audio, \(String(format: "%.2f", Double(bytes) / 1048576)) MB")
}