// Draws Recall's app icon: a glossy colour blob on a dark tile.
// Usage: swift scripts/make-icon.swift <outdir>
// Writes, all 1024×1024:
//   icon.png        complete icon with a squircle tile and margins (website, README, older macOS)
//   background.png  full-bleed dark tile only   } layers for AppIcon.icon (macOS 26+ masks
//   blob.png        blob on transparency        }  and frames them itself)
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

let size: CGFloat = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let space = CGColorSpace(name: CGColorSpace.displayP3)!
let ci = CIContext(options: [.workingColorSpace: space])
let full = CGRect(x: 0, y: 0, width: size, height: size)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
}

func newContext() -> CGContext {
    let c = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    return c
}

func blurred(_ image: CGImage, _ radius: Double) -> CGImage {
    let f = CIFilter.gaussianBlur()
    f.inputImage = CIImage(cgImage: image).clampedToExtent()
    f.radius = Float(radius)
    return ci.createCGImage(f.outputImage!, from: full)!
}

func layer(_ draw: (CGContext) -> Void) -> CGImage { let c = newContext(); draw(c); return c.makeImage()! }

/// macOS-style continuous-corner tile.
func squircle(_ rect: CGRect) -> CGPath {
    let p = CGMutablePath(), n = 5.0, steps = 720
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi, c = cos(t), s = sin(t)
        let x = pow(abs(c), 2 / n) * (c < 0 ? -1 : 1), y = pow(abs(s), 2 / n) * (s < 0 ? -1 : 1)
        let pt = CGPoint(x: rect.midX + x * rect.width / 2, y: rect.midY + y * rect.height / 2)
        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    return p
}

/// All geometry is in "tile units" (0…1 across the tile), so the same drawing works for the
/// framed icon (tile = 824 px with margins) and the full-bleed layers (tile = whole canvas).
struct Art {
    let tile: CGRect
    func pt(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: tile.minX + u * tile.width, y: tile.minY + v * tile.height) }
    func len(_ u: CGFloat) -> CGFloat { u * tile.width }

    var shape: CGPath {
        let p = CGMutablePath(), c = pt(0.5, 0.485), radius = len(0.318), steps = 720
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let r = radius * (1 + 0.075 * sin(3 * t + 0.5) + 0.045 * sin(2 * t + 2.1) + 0.03 * cos(5 * t + 0.9))
            let q = CGPoint(x: c.x + r * cos(t), y: c.y + r * sin(t))
            i == 0 ? p.move(to: q) : p.addLine(to: q)
        }
        p.closeSubpath()
        return p
    }

    /// Soft overlapping lights, heavily blurred: the blob's colour.
    var field: CGImage {
        blurred(layer { c in
            c.setFillColor(rgb(0x6B4BFF)); c.fill(full)
            let lights: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
                (0.316, 0.655, 0.316, 0xFF5BD1), // pink, top-left
                (0.716, 0.716, 0.279, 0xFFA24D), // orange, top-right
                (0.728, 0.279, 0.316, 0x2FD9FF), // cyan, bottom-right
                (0.291, 0.243, 0.267, 0x7C4DFF), // violet, bottom-left
                (0.510, 0.510, 0.182, 0xFF7AA8), // warm core
            ]
            for (u, v, r, col) in lights {
                let p = pt(u, v), rr = len(r)
                c.setFillColor(rgb(col)); c.fillEllipse(in: CGRect(x: p.x - rr, y: p.y - rr, width: 2 * rr, height: 2 * rr))
            }
        }, Double(len(0.115)))
    }

    func drawBackground(_ c: CGContext) {
        let bg = CGGradient(colorsSpace: space, colors: [rgb(0x1C1638), rgb(0x0A0914)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(bg, start: CGPoint(x: tile.midX, y: tile.maxY), end: CGPoint(x: tile.midX, y: tile.minY),
                             options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    func drawBlob(_ c: CGContext, field: CGImage) {
        let shape = self.shape
        // Glow around the blob.
        let glow = blurred(layer { g in g.addPath(shape); g.clip(); g.draw(field, in: full) }, Double(len(0.085)))
        c.setAlpha(0.85); c.draw(glow, in: full.offsetBy(dx: 0, dy: -len(0.022))); c.setAlpha(1)

        c.saveGState()
        c.addPath(shape); c.clip()
        c.draw(field, in: full)
        // Depth: darker toward the lower edge.
        let shade = CGGradient(colorsSpace: space, colors: [rgb(0x000000, 0), rgb(0x12082E, 0.55)] as CFArray, locations: [0.55, 1])!
        c.drawRadialGradient(shade, startCenter: pt(0.449, 0.607), startRadius: 0, endCenter: pt(0.5, 0.485),
                             endRadius: len(0.4), options: [.drawsAfterEndLocation])
        // Rim light along the top edge.
        let rim = blurred(layer { r in r.addPath(shape); r.setLineWidth(len(0.012)); r.setStrokeColor(rgb(0xFFFFFF, 0.55)); r.strokePath() }, Double(len(0.011)))
        let fade = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 1), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
        c.beginTransparencyLayer(auxiliaryInfo: nil)
        c.draw(rim, in: full)
        c.setBlendMode(.destinationIn)
        c.drawLinearGradient(fade, start: pt(0.5, 0.825), end: pt(0.5, 0.449), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        c.endTransparencyLayer()
        // Specular highlights, upper left.
        let spec = blurred(layer { s in
            s.setFillColor(rgb(0xFFFFFF, 0.9))
            let p = pt(0.358, 0.674); s.translateBy(x: p.x, y: p.y); s.rotate(by: 0.55)
            s.fillEllipse(in: CGRect(x: -len(0.115), y: -len(0.051), width: len(0.23), height: len(0.102)))
        }, Double(len(0.032)))
        c.draw(spec, in: full)
        let dot = blurred(layer { d in
            let p = pt(0.265, 0.708), r = len(0.0206)
            d.setFillColor(rgb(0xFFFFFF, 0.95)); d.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
        }, Double(len(0.005)))
        c.draw(dot, in: full)
        c.restoreGState()
    }
}

func save(_ image: CGImage, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outDir + "/" + name))
}

// Framed icon.
let framed = Art(tile: CGRect(x: 100, y: 100, width: 824, height: 824))
save(layer { c in
    let tile = squircle(framed.tile)
    c.addPath(tile); c.clip()
    framed.drawBackground(c)
    framed.drawBlob(c, field: framed.field)
    c.resetClip()
    c.addPath(tile); c.setLineWidth(3); c.setStrokeColor(rgb(0xFFFFFF, 0.08)); c.strokePath()
}, "icon.png")

// Full-bleed layers for Icon Composer.
let bleed = Art(tile: full)
save(layer { bleed.drawBackground($0) }, "background.png")
save(layer { bleed.drawBlob($0, field: bleed.field) }, "blob.png")
print("wrote icon.png, background.png, blob.png to \(outDir)")
