import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
for theme in ["light","dark"] {
 let asset=AVURLAsset(url:URL(fileURLWithPath:"public/video/sharesafe-demo-\(theme).mp4"))
 let generator=AVAssetImageGenerator(asset:asset);generator.appliesPreferredTrackTransform=true
 let image=try generator.copyCGImage(at:CMTime(seconds:0,preferredTimescale:30),actualTime:nil)
 let target=URL(fileURLWithPath:"artifacts/video-frames/poster-\(theme).png")
 let destination=CGImageDestinationCreateWithURL(target as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(destination,image,nil);CGImageDestinationFinalize(destination)
}
