
import Foundation

public protocol Resource {
    var cacheKey: String { get }
    var downloadURL: URL { get }
}

// MARK: 转换 Source
extension Resource {
    public func convertToSource() -> Source {
        return downloadURL.isFileURL ?
            .provider(LocalFileImageDataProvider(fileURL: downloadURL, cacheKey: cacheKey)) :
            .network(self)
    }
}

public struct ImageResource: Resource {

    public let cacheKey: String
    public let downloadURL: URL

    public init(downloadURL: URL, cacheKey: String? = nil) {
        self.downloadURL = downloadURL
        self.cacheKey = cacheKey ?? downloadURL.absoluteString
    }
}

// MARK: key: absoluteString 下载地址是自己, 自定义用 ImageResource
extension URL: Resource {
    public var cacheKey: String { return absoluteString }
    public var downloadURL: URL { return self }
}
