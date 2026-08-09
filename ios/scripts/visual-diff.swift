#!/usr/bin/env xcrun swift

import CoreGraphics
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum VisualDiffError: LocalizedError {
    case invalidArguments(String)
    case unreadableImage(String)
    case dimensionMismatch(reference: String, actual: String)
    case imageCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArguments(message): message
        case let .unreadableImage(path): "Unable to read image: \(path)"
        case let .dimensionMismatch(reference, actual):
            "Image dimensions differ. Reference: \(reference), actual: \(actual)"
        case let .imageCreationFailed(path): "Unable to write image: \(path)"
        }
    }
}

struct Configuration {
    let referenceURL: URL
    let actualURL: URL
    let outputDirectoryURL: URL

    static func parse(arguments: [String]) throws -> Configuration {
        var values: [String: String] = [:]
        var index = 1

        while index < arguments.count {
            let key = arguments[index]
            guard key.hasPrefix("--"), index + 1 < arguments.count else {
                throw VisualDiffError.invalidArguments(
                    "Usage: visual-diff.swift --reference <png> --actual <png> --output-dir <directory>"
                )
            }
            values[key] = arguments[index + 1]
            index += 2
        }

        guard
            let reference = values["--reference"],
            let actual = values["--actual"],
            let outputDirectory = values["--output-dir"]
        else {
            throw VisualDiffError.invalidArguments(
                "Usage: visual-diff.swift --reference <png> --actual <png> --output-dir <directory>"
            )
        }

        return Configuration(
            referenceURL: URL(fileURLWithPath: reference),
            actualURL: URL(fileURLWithPath: actual),
            outputDirectoryURL: URL(fileURLWithPath: outputDirectory, isDirectory: true)
        )
    }
}

func loadImage(at url: URL) throws -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw VisualDiffError.unreadableImage(url.path)
    }
    return image
}

func rgbaBytes(from image: CGImage) throws -> [UInt8] {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue |
        CGImageAlphaInfo.premultipliedLast.rawValue

    guard let context = CGContext(
        data: &bytes,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo
    ) else {
        throw VisualDiffError.imageCreationFailed("in-memory RGBA buffer")
    }

    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return bytes
}

func writePNG(bytes: [UInt8], width: Int, height: Int, to url: URL) throws {
    let data = Data(bytes)
    guard let provider = CGDataProvider(data: data as CFData) else {
        throw VisualDiffError.imageCreationFailed(url.path)
    }

    let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
        CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    )
    guard let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ), let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw VisualDiffError.imageCreationFailed(url.path)
    }

    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw VisualDiffError.imageCreationFailed(url.path)
    }
}

func run() throws {
    let configuration = try Configuration.parse(arguments: CommandLine.arguments)
    let referenceImage = try loadImage(at: configuration.referenceURL)
    let actualImage = try loadImage(at: configuration.actualURL)

    guard referenceImage.width == actualImage.width, referenceImage.height == actualImage.height else {
        throw VisualDiffError.dimensionMismatch(
            reference: "\(referenceImage.width)x\(referenceImage.height)",
            actual: "\(actualImage.width)x\(actualImage.height)"
        )
    }

    let reference = try rgbaBytes(from: referenceImage)
    let actual = try rgbaBytes(from: actualImage)
    var overlay = [UInt8](repeating: 255, count: reference.count)
    var difference = [UInt8](repeating: 255, count: reference.count)
    var totalAbsoluteError: UInt64 = 0
    var mismatchedPixels: UInt64 = 0
    var maximumChannelError: UInt8 = 0

    for pixelOffset in stride(from: 0, to: reference.count, by: 4) {
        var pixelMismatch = false
        for channel in 0..<3 {
            let referenceValue = reference[pixelOffset + channel]
            let actualValue = actual[pixelOffset + channel]
            let channelDifference = referenceValue > actualValue
                ? referenceValue - actualValue
                : actualValue - referenceValue

            overlay[pixelOffset + channel] = UInt8(
                (UInt16(referenceValue) + UInt16(actualValue)) / 2
            )
            difference[pixelOffset + channel] = UInt8(
                min(UInt16(channelDifference) * 4, UInt16(UInt8.max))
            )
            totalAbsoluteError += UInt64(channelDifference)
            maximumChannelError = max(maximumChannelError, channelDifference)
            pixelMismatch = pixelMismatch || channelDifference > 0
        }
        if pixelMismatch {
            mismatchedPixels += 1
        }
    }

    try FileManager.default.createDirectory(
        at: configuration.outputDirectoryURL,
        withIntermediateDirectories: true
    )
    try writePNG(
        bytes: overlay,
        width: referenceImage.width,
        height: referenceImage.height,
        to: configuration.outputDirectoryURL.appendingPathComponent("overlay.png")
    )
    try writePNG(
        bytes: difference,
        width: referenceImage.width,
        height: referenceImage.height,
        to: configuration.outputDirectoryURL.appendingPathComponent("diff.png")
    )

    let pixelCount = UInt64(referenceImage.width * referenceImage.height)
    let report: [String: Any] = [
        "mode": "report-only",
        "width": referenceImage.width,
        "height": referenceImage.height,
        "mismatchedPixels": mismatchedPixels,
        "mismatchedPixelRatio": Double(mismatchedPixels) / Double(pixelCount),
        "meanAbsoluteError": Double(totalAbsoluteError) / Double(pixelCount * 3 * 255),
        "maximumChannelError": maximumChannelError,
        "reference": configuration.referenceURL.lastPathComponent,
        "actual": configuration.actualURL.lastPathComponent
    ]
    let reportData = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    try reportData.write(
        to: configuration.outputDirectoryURL.appendingPathComponent("report.json"),
        options: .atomic
    )
}

do {
    try run()
} catch {
    let message = "Visual diff failed: \(error.localizedDescription)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(EXIT_FAILURE)
}
