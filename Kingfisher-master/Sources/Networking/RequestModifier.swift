
import Foundation

public protocol ImageDownloadRequestModifier {
    func modified(for request: URLRequest) -> URLRequest?
}

/// ImageDownloadRequestModifier 包装器, 请求参数验签
public struct AnyModifier: ImageDownloadRequestModifier {
    
    let block: (URLRequest) -> URLRequest?

    public func modified(for request: URLRequest) -> URLRequest? {
        return block(request)
    }

    public init(modify: @escaping (URLRequest) -> URLRequest?) {
        block = modify
    }
}
