import Foundation

enum FileType {
    case heic, jpeg, png, webp, tiff, bmp, gif, mov, mp4, avi, mkv, webm, pdf, svg

    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "heic", "heif": self = .heic
        case "jpg", "jpeg":  self = .jpeg
        case "png":          self = .png
        case "webp":         self = .webp
        case "tiff", "tif":  self = .tiff
        case "bmp":          self = .bmp
        case "gif":          self = .gif
        case "mov":          self = .mov
        case "mp4":          self = .mp4
        case "avi":          self = .avi
        case "mkv":          self = .mkv
        case "webm":         self = .webm
        case "pdf":          self = .pdf
        case "svg":          self = .svg
        default:             return nil
        }
    }

    var label: String {
        switch self {
        case .heic: return "HEIC Image"
        case .jpeg: return "JPEG Image"
        case .png:  return "PNG Image"
        case .webp: return "WebP Image"
        case .tiff: return "TIFF Image"
        case .bmp:  return "BMP Image"
        case .gif:  return "GIF Image"
        case .mov:  return "QuickTime Video"
        case .mp4:  return "MP4 Video"
        case .avi:  return "AVI Video"
        case .mkv:  return "MKV Video"
        case .webm: return "WebM Video"
        case .pdf:  return "PDF Document"
        case .svg:  return "SVG Image"
        }
    }

    var icon: String {
        switch self {
        case .heic, .jpeg, .png, .webp, .tiff, .bmp, .gif, .svg: return "photo"
        case .mov, .mp4, .avi, .mkv, .webm:                       return "video"
        case .pdf:                                                 return "doc.richtext"
        }
    }

    var availableOutputFormats: [OutputFormat] {
        switch self {
        case .heic, .jpeg, .png, .tiff, .bmp: return [.jpg, .png, .webp, .gif]
        case .webp:                            return [.jpg, .png, .gif]
        case .gif:                             return [.jpg, .png, .webp]
        case .mov, .mp4, .avi, .mkv, .webm:   return [.mp4, .mov]
        case .pdf:                             return [.jpg, .png, .webp]
        case .svg:                             return [.jpg, .png, .webp]
        }
    }

    var defaultOutputFormat: OutputFormat {
        switch self {
        case .heic, .jpeg, .mov, .mp4, .avi, .mkv, .webm, .pdf, .svg: return .jpg
        case .png, .webp, .tiff, .bmp, .gif:                           return .png
        }
    }
}

enum OutputFormat: String, Hashable {
    case jpg, png, webp, gif, mp4, mov

    var label: String {
        switch self {
        case .jpg:  return "JPG"
        case .png:  return "PNG"
        case .webp: return "WebP"
        case .gif:  return "GIF"
        case .mp4:  return "MP4"
        case .mov:  return "MOV"
        }
    }

    var fileExtension: String { rawValue }
}

enum ConversionResult {
    case success(URL)
    case failure(Error)
}
