import Foundation
import ImageIO
import AppKit
import AVFoundation
import PDFKit
import UniformTypeIdentifiers

enum ConversionError: LocalizedError {
    case unsupportedConversion
    case imageReadFailed
    case imageWriteFailed
    case videoExportFailed
    case pdfReadFailed
    case svgReadFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedConversion: return "This conversion is not supported."
        case .imageReadFailed:       return "Could not read the image file."
        case .imageWriteFailed:      return "Could not write the output file."
        case .videoExportFailed:     return "Video export failed."
        case .pdfReadFailed:         return "Could not read the PDF file."
        case .svgReadFailed:         return "Could not read the SVG file."
        }
    }
}

struct ConversionEngine {
    static func convert(file: URL, to format: OutputFormat) async throws -> URL {
        let ext = file.pathExtension.lowercased()
        switch format {
        case .jpg, .png, .webp, .gif:
            switch ext {
            case "pdf":
                return try convertPDFToImage(file: file, format: format)
            case "svg":
                return try convertSVGToImage(file: file, format: format)
            default:
                return try convertImage(file: file, to: format)
            }
        case .mp4:
            return try await convertVideoToMP4(file: file)
        case .mov:
            return try await convertVideoToMOV(file: file)
        }
    }

    // MARK: - Image

    private static func convertImage(file: URL, to format: OutputFormat) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw ConversionError.imageReadFailed }

        return try writeImage(cgImage, for: file, format: format)
    }

    // MARK: - SVG

    private static func convertSVGToImage(file: URL, format: OutputFormat) throws -> URL {
        guard let svgData = try? Data(contentsOf: file),
              let svgImage = NSImage(data: svgData)
        else { throw ConversionError.svgReadFailed }

        let scale: CGFloat = 2.0
        let size = CGSize(width: svgImage.size.width * scale, height: svgImage.size.height * scale)
        let rendered = NSImage(size: size)
        rendered.lockFocus()
        svgImage.draw(in: NSRect(origin: .zero, size: size))
        rendered.unlockFocus()

        guard let cgImage = rendered.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { throw ConversionError.imageWriteFailed }

        return try writeImage(cgImage, for: file, format: format)
    }

    // MARK: - PDF

    private static func convertPDFToImage(file: URL, format: OutputFormat) throws -> URL {
        guard let pdf = PDFDocument(url: file),
              let page = pdf.page(at: 0)
        else { throw ConversionError.pdfReadFailed }

        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx)
        }
        image.unlockFocus()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { throw ConversionError.imageWriteFailed }

        return try writeImage(cgImage, for: file, format: format)
    }

    // MARK: - Video

    private static func convertVideoToMP4(file: URL) async throws -> URL {
        let asset = AVURLAsset(url: file)
        let out = outputURL(for: file, extension: "mp4")
        try? FileManager.default.removeItem(at: out)

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        else { throw ConversionError.videoExportFailed }

        session.outputURL = out
        session.outputFileType = .mp4
        await session.export()

        guard session.status == .completed else { throw ConversionError.videoExportFailed }
        return out
    }

    private static func convertVideoToMOV(file: URL) async throws -> URL {
        let asset = AVURLAsset(url: file)
        let out = outputURL(for: file, extension: "mov")
        try? FileManager.default.removeItem(at: out)

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        else { throw ConversionError.videoExportFailed }

        session.outputURL = out
        session.outputFileType = .mov
        await session.export()

        guard session.status == .completed else { throw ConversionError.videoExportFailed }
        return out
    }

    // MARK: - Helpers

    private static func outputURL(for input: URL, extension ext: String) -> URL {
        input.deletingPathExtension().appendingPathExtension(ext)
    }

    private static func utType(for format: OutputFormat) -> UTType {
        switch format {
        case .jpg:  return .jpeg
        case .png:  return .png
        case .webp: return .webP
        case .gif:  return .gif
        default:    return .jpeg
        }
    }

    private static func writeImage(_ cgImage: CGImage, for file: URL, format: OutputFormat) throws -> URL {
        let out = outputURL(for: file, extension: format.fileExtension)
        let uti = utType(for: format).identifier as CFString

        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, uti, 1, nil)
        else { throw ConversionError.imageWriteFailed }

        var opts: [CFString: Any] = [:]
        if format == .jpg {
            opts[kCGImageDestinationLossyCompressionQuality] = 0.92
        } else if format == .webp {
            opts[kCGImageDestinationLossyCompressionQuality] = 0.90
        }

        CGImageDestinationAddImage(dest, cgImage, opts as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ConversionError.imageWriteFailed }
        return out
    }
}
