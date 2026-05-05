#if os(iOS)
import CoreGraphics
import UIKit
import XCTest

struct ImageSnapshotHelper {
    let tolerance: Double
    let fileManager: FileManager

    init(
        tolerance: Double = ImageSnapshotHelper.configuredTolerance(),
        fileManager: FileManager = .default
    ) {
        self.tolerance = tolerance
        self.fileManager = fileManager
    }

    func assertSnapshot(
        _ image: UIImage,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let baselineURL = baselineDirectory(file: file).appendingPathComponent("\(name).png")
        let actualData = try pngData(from: image)

        if isRecording {
            try fileManager.createDirectory(at: baselineURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try actualData.write(to: baselineURL)
            return
        }

        guard fileManager.fileExists(atPath: baselineURL.path) else {
            XCTFail(
                "Missing snapshot baseline: \(baselineURL.path). Re-run with DMP_RECORD_SNAPSHOTS=1 to record baselines.",
                file: file,
                line: line
            )
            return
        }

        let expectedImage = try loadImage(at: baselineURL)
        let actualImage = try cgImage(from: image)
        let result = compare(actual: actualImage, expected: expectedImage)
        guard result.failedPixelRatio <= tolerance else {
            let artifactDirectory = try writeFailureArtifacts(
                name: name,
                actualData: actualData,
                expected: expectedImage,
                diff: result.diff
            )
            XCTFail(
                "Snapshot \(name) failed. Difference \(result.failedPixelRatio) exceeds tolerance \(tolerance). Artifacts: \(artifactDirectory.path)",
                file: file,
                line: line
            )
            return
        }
    }

    private var isRecording: Bool {
        ProcessInfo.processInfo.environment["DMP_RECORD_SNAPSHOTS"] == "1"
            || CommandLine.arguments.contains("DMP_RECORD_SNAPSHOTS=1")
            || Bundle(for: SnapshotBundleMarker.self).object(forInfoDictionaryKey: "DMPRecordSnapshots") as? String == "1"
    }

    private static func configuredTolerance() -> Double {
        if let value = ProcessInfo.processInfo.environment["DMP_SNAPSHOT_TOLERANCE"].flatMap(Double.init) {
            return value
        }
        if let value = Bundle(for: SnapshotBundleMarker.self).object(forInfoDictionaryKey: "DMPSnapshotTolerance") as? String,
           let tolerance = Double(value) {
            return tolerance
        }
        return 0.01
    }

    private func baselineDirectory(file: StaticString) -> URL {
        let helperFile = URL(fileURLWithPath: "\(file)")
        let directory = helperFile.deletingLastPathComponent()
        let testDirectory = directory.lastPathComponent == "SnapshotTesting"
            ? directory.deletingLastPathComponent()
            : directory
        return testDirectory.appendingPathComponent("__Snapshots__", isDirectory: true)
    }

    private func pngData(from image: UIImage) throws -> Data {
        guard let data = image.pngData() else {
            throw ImageSnapshotError.pngEncodingFailed
        }
        return data
    }

    private func loadImage(at url: URL) throws -> CGImage {
        guard let image = UIImage(contentsOfFile: url.path), let cgImage = image.cgImage else {
            throw ImageSnapshotError.imageLoadFailed(url.path)
        }
        return cgImage
    }

    private func cgImage(from image: UIImage) throws -> CGImage {
        guard let cgImage = image.cgImage else {
            throw ImageSnapshotError.imageConversionFailed
        }
        return cgImage
    }

    private func compare(actual: CGImage, expected: CGImage) -> SnapshotComparisonResult {
        let width = min(actual.width, expected.width)
        let height = min(actual.height, expected.height)
        guard width > 0, height > 0,
              let actualBytes = rgbaBytes(from: actual, width: width, height: height),
              let expectedBytes = rgbaBytes(from: expected, width: width, height: height)
        else {
            return SnapshotComparisonResult(failedPixelRatio: 1, diff: makeSolidDiff(width: max(width, 1), height: max(height, 1)))
        }

        var failedPixels = 0
        var diffBytes = [UInt8](repeating: 255, count: width * height * 4)
        for pixel in 0..<(width * height) {
            let offset = pixel * 4
            let channelDelta = max(
                abs(Int(actualBytes[offset]) - Int(expectedBytes[offset])),
                abs(Int(actualBytes[offset + 1]) - Int(expectedBytes[offset + 1])),
                abs(Int(actualBytes[offset + 2]) - Int(expectedBytes[offset + 2])),
                abs(Int(actualBytes[offset + 3]) - Int(expectedBytes[offset + 3]))
            )
            if channelDelta > 2 {
                failedPixels += 1
                diffBytes[offset] = 255
                diffBytes[offset + 1] = 0
                diffBytes[offset + 2] = 0
                diffBytes[offset + 3] = 255
            }
        }

        if actual.width != expected.width || actual.height != expected.height {
            failedPixels += max(actual.width * actual.height, expected.width * expected.height) - width * height
        }

        let totalPixels = max(actual.width * actual.height, expected.width * expected.height)
        return SnapshotComparisonResult(
            failedPixelRatio: Double(failedPixels) / Double(max(totalPixels, 1)),
            diff: cgImage(fromRGBA: diffBytes, width: width, height: height) ?? makeSolidDiff(width: width, height: height)
        )
    }

    private func rgbaBytes(from image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    private func writeFailureArtifacts(
        name: String,
        actualData: Data,
        expected: CGImage,
        diff: CGImage
    ) throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DoReMiRendererSnapshots", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try actualData.write(to: directory.appendingPathComponent("actual.png"))
        try UIImage(cgImage: expected).pngData()?.write(to: directory.appendingPathComponent("expected.png"))
        try UIImage(cgImage: diff).pngData()?.write(to: directory.appendingPathComponent("diff.png"))
        return directory
    }

    private func cgImage(fromRGBA bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        var mutableBytes = bytes
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &mutableBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        return context.makeImage()
    }

    private func makeSolidDiff(width: Int, height: Int) -> CGImage {
        let bytes = [UInt8](repeating: 255, count: width * height * 4)
        return cgImage(fromRGBA: bytes, width: width, height: height)!
    }
}

private struct SnapshotComparisonResult {
    let failedPixelRatio: Double
    let diff: CGImage
}

private enum ImageSnapshotError: Error {
    case pngEncodingFailed
    case imageLoadFailed(String)
    case imageConversionFailed
}

private final class SnapshotBundleMarker {}
#endif
