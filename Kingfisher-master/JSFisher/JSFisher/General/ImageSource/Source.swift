
import UIKit

enum Source {
    case newwork(Resource)

    enum Identifier {
        typealias Value = UInt
        static var current: Value = 0
        static func next() -> Value {
            current += 1
            return current
        }
    }

    var cacheKey: String {
        switch self {
            case .newwork(let resource): return resource.cacheKey
        }
    }

    var url: URL? {
        switch self {
            case .newwork(let resource): return resource.downLoadUrl
        }
    }
}
