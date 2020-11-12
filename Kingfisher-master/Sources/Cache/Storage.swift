
import Foundation

/// 时间配置器
struct TimeConstants {
    static let secondsInOneMinute = 60
    static let minutesInOneHour = 60
    static let hoursInOneDay = 24
    static let secondsInOneDay = 86_400
}

/// 时间过期策略
public enum StorageExpiration {
    case never
    case seconds(TimeInterval)
    case days(Int)
    case date(Date)
    case expired  //已经过期,跳过缓存
    //预计到期时间
    func estimatedExpirationSince(_ date: Date) -> Date {
        switch self {
        case .never: return .distantFuture
        case .seconds(let seconds):
            return date.addingTimeInterval(seconds)
        case .days(let days):
            let duration = TimeInterval(TimeConstants.secondsInOneDay) * TimeInterval(days)
            return date.addingTimeInterval(duration)
        case .date(let ref):
            return ref
        case .expired:
            return .distantPast
        }
    }
    
    var estimatedExpirationSinceNow: Date {
        return estimatedExpirationSince(Date())
    }
    
    var isExpired: Bool {
        return timeInterval <= 0
    }

    var timeInterval: TimeInterval {
        switch self {
        case .never: return .infinity
        case .seconds(let seconds): return seconds
        case .days(let days): return TimeInterval(TimeConstants.secondsInOneDay) * TimeInterval(days)
        case .date(let ref): return ref.timeIntervalSinceNow
        case .expired: return -(.infinity)
        }
    }
}

/// 过期时间延长策略
public enum ExpirationExtending {
    case none
    case cacheTime //每次访问后，项目的过期时间将延长原始缓存时间
    case expirationTime(_ expiration: StorageExpiration) //每次访问后，项目的过期时间都会延长
}

/// 缓存个数
public protocol CacheCostCalculable {
    var cacheCost: Int { get }
}

/// 数据转换
public protocol DataTransformable {
    func toData() throws -> Data
    static func fromData(_ data: Data) throws -> Self
    static var empty: Self { get }
}
