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
    case thresholdExceeded(meanAbsoluteError: Double, mismatchedPixelRatio: Double)

    var errorDescription: String? {
        switch self {
        case let .invalidArguments(message): message
        case let .unreadableImage(path): "Unable to read image: \(path)"
        case let .dimensionMismatch(reference, actual):
            "Image dimensions differ. Reference: \(reference), actual: \(actual)"
        case let .imageCreationFailed(path): "Unable to write image: \(path)"
        case let .thresholdExceeded(meanAbsoluteError, mismatchedPixelRatio):
            "Visual thresholds exceeded. MAE: \(meanAbsoluteError), mismatched pixel ratio: \(mismatchedPixelRatio)"
        }
    }
}

struct Configuration {
    struct Crop {
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    let referenceURL: URL
    let actualURL: URL
    let outputDirectoryURL: URL
    let scenario: String
    let figmaNodeID: String
    let sourceReferenceSHA256: String
    let maximumMeanAbsoluteError: Double
    let maximumMismatchedPixelRatio: Double
    let crop: Crop?

    static func parse(arguments: [String]) throws -> Configuration {
        var values: [String: String] = [:]
        var index = 1

        while index < arguments.count {
            let key = arguments[index]
            guard key.hasPrefix("--"), index + 1 < arguments.count else {
                throw VisualDiffError.invalidArguments(
                    Configuration.usage
                )
            }
            values[key] = arguments[index + 1]
            index += 2
        }

        guard
            let reference = values["--reference"],
            let actual = values["--actual"],
            let outputDirectory = values["--output-dir"],
            let scenario = values["--scenario"], !scenario.isEmpty,
            let figmaNodeID = values["--figma-node-id"], !figmaNodeID.isEmpty,
            let sourceReferenceSHA256 = values["--source-reference-sha256"],
            sourceReferenceSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
            let maximumMeanAbsoluteErrorValue = values["--maximum-mean-absolute-error"],
            let maximumMeanAbsoluteError = Double(maximumMeanAbsoluteErrorValue),
            let maximumMismatchedPixelRatioValue = values["--maximum-mismatched-pixel-ratio"],
            let maximumMismatchedPixelRatio = Double(maximumMismatchedPixelRatioValue),
            (0...1).contains(maximumMeanAbsoluteError),
            (0...1).contains(maximumMismatchedPixelRatio)
        else {
            throw VisualDiffError.invalidArguments(Configuration.usage)
        }

        let cropKeys = ["--crop-x", "--crop-y", "--crop-width", "--crop-height"]
        let cropValues = cropKeys.compactMap { values[$0] }
        guard cropValues.isEmpty || cropValues.count == cropKeys.count else {
            throw VisualDiffError.invalidArguments("All crop arguments must be provided together.\n\(Configuration.usage)")
        }
        let crop: Crop?
        if cropValues.isEmpty {
            crop = nil
        } else {
            guard
                let x = Int(values["--crop-x"]!), x >= 0,
                let y = Int(values["--crop-y"]!), y >= 0,
                let width = Int(values["--crop-width"]!), width > 0,
                let height = Int(values["--crop-height"]!), height > 0
            else {
                throw VisualDiffError.invalidArguments("Crop values must be non-negative coordinates and positive dimensions.\n\(Configuration.usage)")
            }
            crop = Crop(x: x, y: y, width: width, height: height)
        }

        return Configuration(
            referenceURL: URL(fileURLWithPath: reference),
            actualURL: URL(fileURLWithPath: actual),
            outputDirectoryURL: URL(fileURLWithPath: outputDirectory, isDirectory: true),
            scenario: scenario,
            figmaNodeID: figmaNodeID,
            sourceReferenceSHA256: sourceReferenceSHA256,
            maximumMeanAbsoluteError: maximumMeanAbsoluteError,
            maximumMismatchedPixelRatio: maximumMismatchedPixelRatio,
            crop: crop
        )
    }

    private static let usage = "Usage: visual-diff.swift --reference <png> --actual <png> --output-dir <directory> --scenario <name> --figma-node-id <id> --source-reference-sha256 <lowercase-sha256> --maximum-mean-absolute-error <0...1> --maximum-mismatched-pixel-ratio <0...1> [--crop-x <pixels> --crop-y <pixels> --crop-width <pixels> --crop-height <pixels>]"
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

func croppedImage(
    _ image: CGImage,
    crop: Configuration.Crop
) throws -> CGImage {
    guard crop.x + crop.width <= image.width, crop.y + crop.height <= image.height else {
        throw VisualDiffError.invalidArguments(
            "Crop \(crop.x),\(crop.y),\(crop.width),\(crop.height) exceeds \(image.width)x\(image.height)."
        )
    }
    guard let result = image.cropping(to: CGRect(
        x: crop.x,
        y: crop.y,
        width: crop.width,
        height: crop.height
    )) else {
        throw VisualDiffError.imageCreationFailed("comparison crop")
    }
    return result
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

    let width = configuration.crop?.width ?? referenceImage.width
    let height = configuration.crop?.height ?? referenceImage.height
    let reference: [UInt8]
    let actual: [UInt8]
    if let crop = configuration.crop {
        reference = try rgbaBytes(from: croppedImage(referenceImage, crop: crop))
        actual = try rgbaBytes(from: croppedImage(actualImage, crop: crop))
        try FileManager.default.createDirectory(
            at: configuration.outputDirectoryURL,
            withIntermediateDirectories: true
        )
        try writePNG(
            bytes: reference,
            width: width,
            height: height,
            to: configuration.outputDirectoryURL.appendingPathComponent("comparison-reference.png")
        )
        try writePNG(
            bytes: actual,
            width: width,
            height: height,
            to: configuration.outputDirectoryURL.appendingPathComponent("comparison-actual.png")
        )
    } else {
        reference = try rgbaBytes(from: referenceImage)
        actual = try rgbaBytes(from: actualImage)
    }
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
        width: width,
        height: height,
        to: configuration.outputDirectoryURL.appendingPathComponent("overlay.png")
    )
    try writePNG(
        bytes: difference,
        width: width,
        height: height,
        to: configuration.outputDirectoryURL.appendingPathComponent("diff.png")
    )

    let pixelCount = UInt64(width * height)
    let meanAbsoluteError = Double(totalAbsoluteError) / Double(pixelCount * 3 * 255)
    let mismatchedPixelRatio = Double(mismatchedPixels) / Double(pixelCount)
    let passed = meanAbsoluteError <= configuration.maximumMeanAbsoluteError &&
        mismatchedPixelRatio <= configuration.maximumMismatchedPixelRatio
    var report: [String: Any] = [
        "mode": "threshold",
        "passed": passed,
        "width": width,
        "height": height,
        "mismatchedPixels": mismatchedPixels,
        "mismatchedPixelRatio": mismatchedPixelRatio,
        "maximumMismatchedPixelRatio": configuration.maximumMismatchedPixelRatio,
        "meanAbsoluteError": meanAbsoluteError,
        "maximumMeanAbsoluteError": configuration.maximumMeanAbsoluteError,
        "maximumChannelError": maximumChannelError,
        "scenario": configuration.scenario,
        "figmaNodeId": configuration.figmaNodeID,
        "sourceReferenceSha256": configuration.sourceReferenceSHA256,
        "reference": configuration.referenceURL.lastPathComponent,
        "actual": configuration.actualURL.lastPathComponent
    ]
    if let crop = configuration.crop {
        report["comparisonCrop"] = [
            "x": crop.x,
            "y": crop.y,
            "width": crop.width,
            "height": crop.height
        ]
        report["sourceWidth"] = referenceImage.width
        report["sourceHeight"] = referenceImage.height
    }
    let reportData = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    try reportData.write(
        to: configuration.outputDirectoryURL.appendingPathComponent("report.json"),
        options: .atomic
    )

    guard passed else {
        throw VisualDiffError.thresholdExceeded(
            meanAbsoluteError: meanAbsoluteError,
            mismatchedPixelRatio: mismatchedPixelRatio
        )
    }
}

do {
    try run()
} catch {
    let message = "Visual diff failed: \(error.localizedDescription)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(EXIT_FAILURE)
}
