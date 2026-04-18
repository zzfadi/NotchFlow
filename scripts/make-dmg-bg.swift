#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let outPath = CommandLine.arguments.dropFirst().first ?? "assets/dmg/background.png"
let W: CGFloat = 540, H: CGFloat = 380
let scale: CGFloat = 2
let pxW = Int(W * scale), pxH = Int(H * scale)

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: pxW, height: pxH,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }
ctx.scaleBy(x: scale, y: scale)

// Dark minimal background
let gradient = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1),
        CGColor(red: 0.12, green: 0.11, blue: 0.16, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(gradient, start: .init(x: 0, y: H), end: .init(x: 0, y: 0), options: [])

// Text
let title = "Install NotchFlow"
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
    .foregroundColor: NSColor.white
]
let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
let tsz = titleStr.size()
let flipped = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = flipped
titleStr.draw(at: .init(x: (W - tsz.width) / 2, y: H - 54))

let subtitle = "Drag into your Applications folder"
let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor(white: 0.6, alpha: 1.0)
]
let subStr = NSAttributedString(string: subtitle, attributes: subAttrs)
let ssz = subStr.size()
subStr.draw(at: .init(x: (W - ssz.width) / 2, y: H - 82))
NSGraphicsContext.restoreGraphicsState()

// Glowing neon arrow
ctx.saveGState()
ctx.setStrokeColor(CGColor(red: 0.8, green: 0.2, blue: 1.0, alpha: 0.9))
ctx.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 1.0, alpha: 0.9))
ctx.setLineWidth(4)
ctx.setLineCap(.round)
ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 12, color: CGColor(red: 0.8, green: 0.2, blue: 1.0, alpha: 0.8))

let y: CGFloat = 180
let x1: CGFloat = 215, x2: CGFloat = 325
ctx.move(to: .init(x: x1, y: y))
ctx.addLine(to: .init(x: x2 - 12, y: y))
ctx.strokePath()

ctx.move(to: .init(x: x2, y: y))
ctx.addLine(to: .init(x: x2 - 18, y: y + 10))
ctx.addLine(to: .init(x: x2 - 18, y: y - 10))
ctx.closePath()
ctx.fillPath()
ctx.restoreGState()

// Export
guard let cg = ctx.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: cg)
rep.size = NSSize(width: W, height: H)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) \(pxW)x\(pxH)")
