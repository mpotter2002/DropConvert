import Foundation

public enum FileType {
    case heic, jpeg, png, mov, mp4, pdf

    public init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "heic", "heif": self = .heic
        case "jpg", "jpeg":  self = .jpeg
        case "png":          self = .png
        case "mov":          self = .mov
        case "mp4":          self = .mp4
        case "pdf":          self = .pdf
        default:             return nil
        }
    }

    public var label: String {
        switch self {
        case .heic: return "HEIC Image"
        case .jpeg: return "JPEG Image"
        case .png:  return "PNG Image"
        case .mov:  return "QuickTime Video"
        case .mp4:  return "MP4 Video"
        case .pdf:  return "PDF Document"
        }
    }

    public var icon: String {
        switch self {
        case .heic, .jpeg, .png: return "photo"
        case .mov, .mp4:         return "video"
        case .pdf:               return "doc.richtext"
        }
    }

    public var availableOutputFormats: [OutputFormat] {
        switch self {
        case .heic, .jpeg, .png: return [.jpg, .png]
        case .mov, .mp4:         return [.mp4]
        case .pdf:               return [.jpg, .png]
        }
    }

    public var defaultOutputFormat: OutputFormat {
        switch self {
        case .heic, .jpeg, .mov, .mp4, .pdf: return .jpg
        case .png:                            return .png
        }
    }
}

public enum OutputFormat: String, Hashable {
    case jpg, png, mp4

    public var label: String {
        switch self {
        case .jpg: return "JPG"
        case .png: return "PNG"
        case .mp4: return "MP4"
        }
    }

    public var fileExtension: String { rawValue }
}

public enum ConversionResult {
    case success(URL)
    case failure(Error)
}
