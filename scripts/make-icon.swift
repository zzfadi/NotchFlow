#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let outPath = CommandLine.arguments.dropFirst().first ?? "assets/icon.png"
let size: CGFloat = 1024

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }

let inset: CGFloat = 100
let tile = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius: CGFloat = tile.width * 0.2237

// 1. Deep Background with subtle texture
let bgGradient = CGGradient(
    colorsSpace: cs,
    colors: [
        CGColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1),
        CGColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 1)
    ] as CFArray,
    locations: [0.0, 1.0]
)!

ctx.saveGState()
let path = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(path)
ctx.clip()
ctx.drawLinearGradient(bgGradient, start: CGPoint(x: tile.midX, y: tile.maxY), end: CGPoint(x: tile.midX, y: tile.minY), options: [])

// 2. The "Flow" - Organic spectral silk
func drawSilk(color: CGColor, start: CGPoint, width: CGFloat, amplitude: CGFloat, frequency: CGFloat, phase: CGFloat) {
    ctx.saveGState()
    ctx.setBlendMode(.screen)
    ctx.setStrokeColor(color.copy(alpha: 0.15)!)
    ctx.setLineWidth(2)
    
    for i in 0..<15 {
        let flowPath = CGMutablePath()
        let offset = CGFloat(i) * 4.0
        flowPath.move(to: CGPoint(x: start.x - width/2 + offset, y: start.y))
        
        for y in stride(from: start.y, to: tile.minY - 100, by: -10) {
            let relativeY = (start.y - y) / tile.height
            let wave = sin(relativeY * frequency + phase + CGFloat(i) * 0.1) * amplitude * (1.0 - relativeY)
            flowPath.addLine(to: CGPoint(x: start.x + wave - width/2 + offset, y: y))
        }
        ctx.addPath(flowPath)
        ctx.strokePath()
    }
    ctx.restoreGState()
}

// Draw multiple layers of "silk" in different colors
let colors: [(CGColor, CGFloat)] = [
    (CGColor(red: 0.0, green: 1.0, blue: 0.9, alpha: 1.0), 0.0),   // Cyan
    (CGColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1.0), 1.5),   // Purple
    (CGColor(red: 1.0, green: 0.0, blue: 0.5, alpha: 1.0), 3.0),   // Pink
    (CGColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0), 4.5)    // Gold
]

for (color, phase) in colors {
    drawSilk(color: color, start: CGPoint(x: tile.midX, y: tile.maxY - 40), width: 80, amplitude: 140, frequency: 6.0, phase: phase)
}

// 3. Ambient Bottom Glow
let bottomGlow = CGGradient(colorsSpace: cs, colors: [CGColor(red: 0.3, green: 0.1, blue: 0.5, alpha: 0.4), CGColor(red: 0, green: 0, blue: 0, alpha: 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(bottomGlow, startCenter: CGPoint(x: tile.midX, y: tile.minY + 100), startRadius: 0, endCenter: CGPoint(x: tile.midX, y: tile.minY + 100), endRadius: 400, options: [])

// 4. The Glass Notch
let notchW: CGFloat = 380
let notchH: CGFloat = 85
let notchRect = CGRect(x: tile.midX - notchW/2, y: tile.maxY - notchH - 20, width: notchW, height: notchH + 60)
let notchPath = CGPath(roundedRect: notchRect, cornerWidth: 32, cornerHeight: 32, transform: nil)

// Notch Shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.8))
ctx.addPath(notchPath)
ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0))
ctx.fillPath()
ctx.restoreGState()

// Notch Glass Effect (Rim Light)
ctx.saveGState()
ctx.addPath(notchPath)
ctx.clip()
let glassGrad = CGGradient(colorsSpace: cs, colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.15), CGColor(red: 1, green: 1, blue: 1, alpha: 0.02)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(glassGrad, start: CGPoint(x: tile.midX, y: notchRect.minY), end: CGPoint(x: tile.midX, y: notchRect.maxY), options: [])
ctx.restoreGState()

// Notch Bevel
ctx.saveGState()
ctx.setLineWidth(1.5)
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.2))
ctx.addPath(notchPath)
ctx.strokePath()
ctx.restoreGState()

// 5. Particles / Digital Dust
for _ in 0..<60 {
    let px = tile.minX + CGFloat.random(in: 0...tile.width)
    let py = tile.minY + CGFloat.random(in: 0...tile.height)
    let pSize = CGFloat.random(in: 1...3)
    let pAlpha = CGFloat.random(in: 0.1...0.4)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: pAlpha))
    ctx.fillEllipse(in: CGRect(x: px, y: py, width: pSize, height: pSize))
}

ctx.restoreGState()

// Export
guard let cg = ctx.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: cg)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
let url = URL(fileURLWithPath: outPath)
try! png.write(to: url)
print("wrote \(outPath) \(Int(size))x\(Int(size))")
