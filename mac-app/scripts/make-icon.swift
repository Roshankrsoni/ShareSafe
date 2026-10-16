import AppKit
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(calibratedRed: 0.87, green: 0.015, blue: 0.12, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 205, yRadius: 205).fill()
let shield = NSBezierPath()
shield.move(to: NSPoint(x: 512, y: 822))
shield.curve(to: NSPoint(x: 770, y: 720), controlPoint1: NSPoint(x: 618, y: 788), controlPoint2: NSPoint(x: 695, y: 745))
shield.line(to: NSPoint(x: 754, y: 450))
shield.curve(to: NSPoint(x: 512, y: 218), controlPoint1: NSPoint(x: 746, y: 346), controlPoint2: NSPoint(x: 650, y: 264))
shield.curve(to: NSPoint(x: 270, y: 450), controlPoint1: NSPoint(x: 374, y: 264), controlPoint2: NSPoint(x: 278, y: 346))
shield.line(to: NSPoint(x: 254, y: 720))
shield.curve(to: NSPoint(x: 512, y: 822), controlPoint1: NSPoint(x: 329, y: 745), controlPoint2: NSPoint(x: 406, y: 788))
shield.close()
NSColor(calibratedRed: 0.97, green: 0.98, blue: 1.0, alpha: 1).setFill(); shield.fill()
let check = NSBezierPath()
check.move(to: NSPoint(x: 380, y: 524)); check.line(to: NSPoint(x: 471, y: 436)); check.line(to: NSPoint(x: 650, y: 630))
check.lineWidth = 53; check.lineCapStyle = .round; check.lineJoinStyle = .round
NSColor(calibratedRed: 0.87, green: 0.015, blue: 0.12, alpha: 1).setStroke(); check.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
