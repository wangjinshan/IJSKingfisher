
import UIKit

protocol Resource {
    var cacheKey: String { get}
    var downLoadUrl: URL { get }
}

extension Resource {
    func coverToSource() -> Source {
        return .newwork(self)
    }
}

extension URL: Resource {
    var cacheKey: String {
        return absoluteString
    }
    var downLoadUrl: URL {
        return self
    }
}

public struct ImageResource: Resource {
    let cacheKey: String
    let downLoadUrl: URL
    init(cacheKey: String, downLoadUrl: URL) {
        self.cacheKey = cacheKey
        self.downLoadUrl = downLoadUrl
    }
}

