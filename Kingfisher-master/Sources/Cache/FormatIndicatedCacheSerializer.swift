
import Foundation
import CoreGraphics

/// `FormatIndicatedCacheSerializer` lets you indicate an image format for serialized caches.
///
/// It could serialize and deserialize PNG, JPEG and GIF images. For
/// image other than these formats, a normalized `pngRepresentation` will be used.
///
/// Example:
/// ````
/// let profileImageSize = CGSize(width: 44, height: 44)
///
/// // A round corner image.
/// let imageProcessor = RoundCornerImageProcessor(
///     cornerRadius: profileImageSize.width / 2, targetSize: profileImageSize)
///
/// let optionsInfo: KingfisherOptionsInfo = [
///     .cacheSerializer(FormatIndicatedCacheSerializer.png), 
///     .processor(imageProcessor)]
///
/// A URL pointing to a JPEG image.
/// let url = URL(string: "https://example.com/image.jpg")!
///
/// // Image will be always cached as PNG format to preserve alpha channel for round rectangle.
/// // So when you load it from cache again later, it will be still round cornered.
/// // Otherwise, the corner part would be filled by white color (since JPEG does not contain an alpha channel).
/// imageView.kf.setImage(with: url, options: optionsInfo)
/// ````
public struct FormatIndicatedCacheSerializer: CacheSerializer {
    
    /// A `FormatIndicatedCacheSerializer` which converts image from and to PNG format. If the image cannot be
    /// represented by PNG format, it will fallback to its real format which is determined by `original` data.
    public static let png = FormatIndicatedCacheSerializer(imageFormat: .PNG, jpegCompressionQuality: nil)
    
    /// A `FormatIndicatedCacheSerializer` which converts image from and to JPEG format. If the image cannot be
    /// represented by JPEG format, it will fallback to its real format which is determined by `original` data.
    /// The compression quality is 1.0 when using this serializer. If you need to set a customized compression quality,
    /// use `jpeg(compressionQuality:)`.
    public static let jpeg = FormatIndicatedCacheSerializer(imageFormat: .JPEG, jpegCompressionQuality: 1.0)

    /// A `FormatIndicatedCacheSerializer` which converts image from and to JPEG format with a settable compression
    /// quality. If the image cannot be represented by JPEG format, it will fallback to its real format which is
    /// determined by `original` data.
    /// - Parameter compressionQuality: The compression quality when converting image to JPEG data.
    public static func jpeg(compressionQuality: CGFloat) -> FormatIndicatedCacheSerializer {
        return FormatIndicatedCacheSerializer(imageFormat: .JPEG, jpegCompressionQuality: compressionQuality)
    }
    
    /// A `FormatIndicatedCacheSerializer` which converts image from and to GIF format. If the image cannot be
    /// represented by GIF format, it will fallback to its real format which is determined by `original` data.
    public static let gif = FormatIndicatedCacheSerializer(imageFormat: .GIF, jpegCompressionQuality: nil)
    
    /// The indicated image format.
    private let imageFormat: ImageFormat

    /// The compression quality used for loss image format (like JPEG).
    private let jpegCompressionQuality: CGFloat?
    
    /// Creates data which represents the given `image` under a format.
    public func data(with image: KFCrossPlatformImage, original: Data?) -> Data? {
        
        func imageData(withFormat imageFormat: ImageFormat) -> Data? {
            return autoreleasepool { () -> Data? in
                switch imageFormat {
                case .PNG: return image.kf.pngRepresentation()
                case .JPEG: return image.kf.jpegRepresentation(compressionQuality: jpegCompressionQuality ?? 1.0)
                case .GIF: return image.kf.gifRepresentation()
                case .unknown: return nil
                }
            }
        }
        
        // generate data with indicated image format
        if let data = imageData(withFormat: imageFormat) {
            return data
        }
        
        let originalFormat = original?.kf.imageFormat ?? .unknown
        
        // generate data with original image's format
        if originalFormat != imageFormat, let data = imageData(withFormat: originalFormat) {
            return data
        }
        
        return original ?? image.kf.normalized.kf.pngRepresentation()
    }
    
    /// Same implementation as `DefaultCacheSerializer`.
    public func image(with data: Data, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        return KingfisherWrapper.image(data: data, options: options.imageCreatingOptions)
    }
}
