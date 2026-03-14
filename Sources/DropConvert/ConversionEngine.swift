import Foundation
import ImageIO
import AppKit
import AVFoundation
import PDFKit

enum ConversionError: LocalizedError {
    case unsupportedConversion
    case imageReadFailed
    case imageWriteFailed
    case videoExportFailed
    case pdfReadFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedConversion: return "This conversion is not supported."
        case .imageReadFailed:       return "Could not read the image file."
        case .imageWriteFailed:      return "Could not write the output file."
        case .videoExportFailed:     return "Video export failed."
        case .pdfReadFailed:         return "Could not read the PDF file."
        }
    }
}

struct ConversionEngine {
    static func convert(file: URL, to format: OutputFormat) async throws -> URL {
        let ext = file.pathExtension.lowercased()
        switch format {
        case .jpg, .png:
            return ext == "pdf"
                ? try convertPDFToImage(file: file, format: format)
                : try convertImage(file: file, to: format)
        case .mp4:
            return try await convertVideoToMP4(file: file)
        }
    }

    // MARK: - Image

    private static func convertImage(file: URL, to format: OutputFormat) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw ConversionError.imageReadFailed }

        let out = outputURL(for: file, extension: format.fileExtension)
        let uti: CFString = format == .png ? "public.png" : "public.jpeg"

        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, uti, 1, nil)
        else { throw ConversionError.imageWriteFailed }

        let opts: [CFString: Any] = format == .jpg
            ? [kCGImageDestinationLossyCompressionQuality: 0.92]
            : [:]
        CGImageDestinationAddImage(dest, cgImage, opts as CFDictionary)

        guard CGImageDestinationFinalize(dest) else { throw ConversionError.imageWriteFailed }
        return out
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

        let out = outputURL(for: file, extension: format.fileExtension)
        let uti: CFString = format == .png ? "public.png" : "public.jpeg"

        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, uti, 1, nil)
        else { throw ConversionError.imageWriteFailed }

        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { throw ConversionError.imageWriteFailed }
        return out
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

    // MARK: - Helpers

    private static func outputURL(for input: URL, extension ext: String) -> URL {
        input.deletingPathExtension().appendingPathExtension(ext)
    }
}
