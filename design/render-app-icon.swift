// Rasterises design/app-icon.svg to the 1024×1024 opaque PNG the asset catalogue ships (spec §10).
// Run from the repo root: swift design/render-app-icon.swift
import AppKit
import UniformTypeIdentifiers

let source = URL(fileURLWithPath: "design/app-icon.svg")
let target = URL(fileURLWithPath: "PuntoDeOro/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let side = 1024

guard let svg = NSImage(contentsOf: source) else { fatalError("Could not read \(source.path)") }
var rect = NSRect(x: 0, y: 0, width: side, height: side)
guard let image = svg.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
    fatalError("Could not rasterise \(source.path)")
}

// No alpha channel: the watch rejects icons with transparency, and the ground is full bleed anyway.
guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
          data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
          space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      )
else { fatalError("Could not create an opaque sRGB bitmap") }
context.draw(image, in: rect)

guard let flat = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("Could not prepare \(target.path)") }
CGImageDestinationAddImage(destination, flat, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(target.path)") }
