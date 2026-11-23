import AppKit
let image = NSImage(size: NSSize(width: 1400, height: 900))
image.lockFocus()
NSColor.white.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: image.size)).fill()
("KOMET" as NSString).draw(at: NSPoint(x: 140, y: 590),
    withAttributes: [.font: NSFont.systemFont(ofSize: 110), .foregroundColor: NSColor.black])
image.unlockFocus()
let data = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
