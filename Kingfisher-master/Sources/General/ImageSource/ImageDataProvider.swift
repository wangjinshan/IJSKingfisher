
import Foundation

/// 自定义设置图片
public protocol ImageDataProvider {
    var cacheKey: String { get }
    var contentURL: URL? { get }

    func data(handler: @escaping (Result<Data, Error>) -> Void) // url 转data
}

public extension ImageDataProvider {
    var contentURL: URL? { return nil }
}

/// 本地图
public struct LocalFileImageDataProvider: ImageDataProvider {

    public let fileURL: URL

    public init(fileURL: URL, cacheKey: String? = nil) {
        self.fileURL = fileURL
        self.cacheKey = cacheKey ?? fileURL.absoluteString
    }

    public var cacheKey: String

    public func data(handler: (Result<Data, Error>) -> Void) {
        handler(Result(catching: { try Data(contentsOf: fileURL) }))
    }

    public var contentURL: URL? { // 本地文件路径
        return fileURL
    }
}

/// base64
public struct Base64ImageDataProvider: ImageDataProvider {

    public let base64String: String

    public init(base64String: String, cacheKey: String) {
        self.base64String = base64String
        self.cacheKey = cacheKey
    }

    public var cacheKey: String

    public func data(handler: (Result<Data, Error>) -> Void) {
        let data = Data(base64Encoded: base64String)!
        handler(.success(data))
    }
}


/// raw源数据
public struct RawImageDataProvider: ImageDataProvider {

    public let data: Data

    public init(data: Data, cacheKey: String) {
        self.data = data
        self.cacheKey = cacheKey
    }

    public var cacheKey: String

    public func data(handler: @escaping (Result<Data, Error>) -> Void) {
        handler(.success(data))
    }
}
