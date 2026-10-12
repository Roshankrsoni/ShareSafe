import Foundation
import AVFoundation
import CoreGraphics
import ImageIO

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let width = 1280, height = 860, fps: Int32 = 30, duration = 20
func image(_ path: String) -> CGImage { let source=CGImageSourceCreateWithURL(root.appendingPathComponent(path) as CFURL,nil)!;return CGImageSourceCreateImageAtIndex(source,0,nil)! }
let backdrop=image("artifacts/video-frames/wallpaper.png")
for theme in ["light","dark"] {
 let url=root.appendingPathComponent("public/video/sharesafe-demo-\(theme).mp4")
 if FileManager.default.fileExists(atPath:url.path){try FileManager.default.removeItem(at:url)}
 let writer=try AVAssetWriter(outputURL:url,fileType:.mp4)
 let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:width,AVVideoHeightKey:height,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:2_000_000,AVVideoMaxKeyFrameIntervalKey:60,AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel]])
 input.expectsMediaDataInRealTime=false
 let adapter=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true])
 writer.add(input);writer.shouldOptimizeForNetworkUse=true;writer.startWriting();writer.startSession(atSourceTime:.zero)
 let screens=(0..<4).map{image("artifacts/video-frames/\(theme)-\($0).png")}
 func draw(_ index:Int,_ phase:Double,_ alpha:Double,_ context:CGContext){
  let pic=screens[index]
  let fit=min(1120/Double(pic.width),740/Double(pic.height))
  let scale=fit*(1+0.045*(0.5-0.5*cos(min(1,phase)*Double.pi)))
  let w=Double(pic.width)*scale,h=Double(pic.height)*scale
  let rect=CGRect(x:(1280-w)/2,y:(860-h)/2,width:w,height:h)
  context.saveGState();context.setAlpha(alpha);context.setShadow(offset:CGSize(width:0,height:-12),blur:36,color:CGColor(gray:0,alpha:0.35));context.addPath(CGPath(roundedRect:rect,cornerWidth:12,cornerHeight:12,transform:nil));context.clip();context.interpolationQuality = .high;context.draw(pic,in:rect);context.restoreGState()
 }
 for frame in 0..<(duration*Int(fps)) {
  while !input.isReadyForMoreMediaData {Thread.sleep(forTimeInterval:0.002)}
  autoreleasepool {
   var optional:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,adapter.pixelBufferPool!,&optional);let pixel=optional!
   CVPixelBufferLockBaseAddress(pixel,[])
   let context=CGContext(data:CVPixelBufferGetBaseAddress(pixel),width:width,height:height,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pixel),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue)!
   context.draw(backdrop,in:CGRect(x:0,y:0,width:width,height:height))
   let t=Double(frame)/Double(fps),scene=Int(t/5)%4,phase=t.truncatingRemainder(dividingBy:5)
   draw(scene,phase/4.4,1,context)
   if phase>4.4 {let blend=(phase-4.4)/0.6;draw((scene+1)%4,0,blend*blend*(3-2*blend),context)}
   CVPixelBufferUnlockBaseAddress(pixel,[])
   if !adapter.append(pixel,withPresentationTime:CMTime(value:Int64(frame),timescale:fps)){fatalError("Frame failed: \(String(describing:writer.error))")}
  }
 }
 input.markAsFinished();let sem=DispatchSemaphore(value:0);writer.finishWriting{sem.signal()};sem.wait()
 guard writer.status == .completed else {fatalError("Video failed \(String(describing:writer.error))")}
 print("Created \(url.lastPathComponent): \(duration)s, \(fps)fps, \(width)×\(height)")
}
