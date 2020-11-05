
import Foundation

public protocol Resource {
    var cacheKey: String { get }
    var downloadURL: URL { get }
}

extension Resource {

    /// Converts `self` to a valid `Source` based on its `downloadURL` scheme. A `.provider` with
    /// `LocalFileImageDataProvider` associated will be returned if the URL points to a local file. Otherwise,
    /// `.network` is returned.
    public func convertToSource() -> Source {
        return downloadURL.isFileURL ?
            .provider(LocalFileImageDataProvider(fileURL: downloadURL, cacheKey: cacheKey)) :
            .network(self)
    }
}

/// ImageResource is a simple combination of `downloadURL` and `cacheKey`.
/// When passed to image view set methods, Kingfisher will try to download the target
/// image from the `downloadURL`, and then store it with the `cacheKey` as the key in cache.
public struct ImageResource: Resource {

    // MARK: - Initializers

    /// Creates an image resource.
    ///
    /// - Parameters:
    ///   - downloadURL: The target image URL from where the image can be downloaded.
    ///   - cacheKey: The cache key. If `nil`, Kingfisher will use the `absoluteString` of `downloadURL` as the key.
    ///               Default is `nil`.
    public init(downloadURL: URL, cacheKey: String? = nil) {
        self.downloadURL = downloadURL
        self.cacheKey = cacheKey ?? downloadURL.absoluteString
    }

    // MARK: Protocol Conforming
    
    /// The key used in cache.
    public let cacheKey: String

    /// The target image URL.
    public let downloadURL: URL
}

/// URL conforms to `Resource` in Kingfisher.
/// The `absoluteString` of this URL is used as `cacheKey`. And the URL itself will be used as `downloadURL`.
/// If you need customize the url and/or cache key, use `ImageResource` instead.
extension URL: Resource {
    public var cacheKey: String { return absoluteString }
    public var downloadURL: URL { return self }
}
