//
//  TrimmedArt.swift
//  VisionChef
//
//  Loads artwork cropped to its opaque pixels.
//
//  The game art is exported on fixed 1920×1080 canvases, so every image is a
//  small island in a sea of transparency — and the island's share of the
//  canvas ranges from 28% (mayo) to 51% (cucumber) of the width. Sizing those
//  raw would render each ingredient at a different visual size and all of them
//  far too small, so the padding is measured and removed once per asset.
//
//  Doing it here rather than re-exporting the PNGs keeps the source art
//  untouched and means new assets can be dropped in with any amount of padding.
//

import SpriteKit
import UIKit

enum TrimmedArt {
    private static var images: [String: UIImage] = [:]
    private static var textures: [String: SKTexture] = [:]

    /// The asset with its transparent border removed. Falls back to the
    /// untrimmed image if the bounds can't be measured.
    static func image(named name: String) -> UIImage? {
        if let cached = images[name] { return cached }
        guard let original = UIImage(named: name) else {
            #if DEBUG
            print("[TrimmedArt] missing image asset '\(name)' — add it to Assets.xcassets under exactly that name.")
            #endif
            return nil
        }
        let result = trimmed(original) ?? original
        images[name] = result
        return result
    }

    static func texture(named name: String) -> SKTexture? {
        if let cached = textures[name] { return cached }
        guard let image = image(named: name) else { return nil }
        let texture = SKTexture(image: image)
        textures[name] = texture
        return texture
    }

    /// Crops to the opaque bounding box. Returns nil when the image is fully
    /// transparent or can't be read.
    private static func trimmed(_ image: UIImage, alphaThreshold: UInt8 = 10) -> UIImage? {
        guard let cg = image.cgImage, cg.width > 0, cg.height > 0 else { return nil }
        let fullWidth = Double(cg.width), fullHeight = Double(cg.height)

        // Scan a downsampled copy: a bounding box needs no fine detail, and
        // this keeps a 2-megapixel asset down to a few thousand comparisons.
        let maxSide = 256.0
        let scale = min(1.0, maxSide / max(fullWidth, fullHeight))
        let width = max(1, Int(fullWidth * scale))
        let height = max(1, Int(fullHeight * scale))

        var alpha = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &alpha, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where alpha[row + x] > alphaThreshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }

        // Back to full resolution. Row 0 of the scan buffer is the *top* of the
        // image, which is also `CGImage.cropping(to:)`'s origin — no flip.
        // One scan-pixel of margin keeps the downsampling from shaving an edge.
        let step = 1.0 / scale
        let x = max(0, Double(minX) * step - step)
        let y = max(0, Double(minY) * step - step)
        let rect = CGRect(
            x: x,
            y: y,
            width: min(fullWidth - x, Double(maxX - minX + 1) * step + 2 * step),
            height: min(fullHeight - y, Double(maxY - minY + 1) * step + 2 * step)
        )

        guard let cropped = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
