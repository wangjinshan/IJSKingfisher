
import Foundation

/// 内存存储
/// 内存检索缓存功能
public enum MemoryStorage {
    public class Backend<T: CacheCostCalculable> {
        let storage = NSCache<NSString, StorageObject<T>>()  //使用NSCache进行缓存,线程安全
        var keys = Set<String>()  //存放所有缓存的key，在删除过期缓存是有用

        private var cleanTimer: Timer? = nil
        private let lock = NSLock()

        public var config: Config {  //配置
            didSet {
                storage.totalCostLimit = config.totalCostLimit
                storage.countLimit = config.countLimit
            }
        }

        public init(config: Config) {
            self.config = config
            storage.totalCostLimit = config.totalCostLimit
            storage.countLimit = config.countLimit

            cleanTimer = .scheduledTimer(withTimeInterval: config.cleanInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.removeExpired()
            }
        }
        //删除过期数据
        func removeExpired() {
            lock.lock()
            defer { lock.unlock() }
            for key in keys {
                let nsKey = key as NSString
                guard let object = storage.object(forKey: nsKey) else {
                    keys.remove(key)
                    continue
                }
                if object.estimatedExpiration.isPast {
                    storage.removeObject(forKey: nsKey)
                    keys.remove(key)
                }
            }
        }
        // 存数据
        func store(value: T, forKey key: String, expiration: StorageExpiration? = nil) throws {
            storeNoThrow(value: value, forKey: key, expiration: expiration)
        }
        // MARK: 图片存储在内存中
        func storeNoThrow(value: T, forKey key: String, expiration: StorageExpiration? = nil) {
            lock.lock()
            defer { lock.unlock() }
            let expiration = expiration ?? config.expiration
            guard !expiration.isExpired else { return }  //判断是否过期，若已经过期直接返回
            let object = StorageObject(value, key: key, expiration: expiration)
            storage.setObject(object, forKey: key as NSString, cost: value.cacheCost)
            keys.insert(key)
        }

         // 读取数据
        func value(forKey key: String, extendingExpiration: ExpirationExtending = .cacheTime) -> T? {
            guard let object = storage.object(forKey: key as NSString) else { return nil }
            if object.expired { return nil }
            object.extendExpiration(extendingExpiration)
            return object.value
        }

        func isCached(forKey key: String) -> Bool {
            guard let _ = value(forKey: key, extendingExpiration: .none) else { return false }
            return true
        }
        // 删除
        func remove(forKey key: String) throws {
            lock.lock()
            defer { lock.unlock() }
            storage.removeObject(forKey: key as NSString)
            keys.remove(key)
        }

        func removeAll() throws {
            lock.lock()
            defer { lock.unlock() }
            storage.removeAllObjects()
            keys.removeAll()
        }
    }
}

/// 配置功能
extension MemoryStorage {
    public struct Config {
        public var totalCostLimit: Int  //内存缓存的最大容量，ImageCache.default中提供的默认值是设备物理内存的四分之一
        public var countLimit: Int = .max  //内存缓存的最大长度
        public var expiration: StorageExpiration = .seconds(300)  //内存缓存的的过期时长 5分钟
        public let cleanInterval: TimeInterval   //清除过期缓存的时间间隔 120

        public init(totalCostLimit: Int, cleanInterval: TimeInterval = 120) {
            self.totalCostLimit = totalCostLimit
            self.cleanInterval = cleanInterval
        }
    }
}

/// 缓存的封装类型
extension MemoryStorage {
    class StorageObject<T> {
        let value: T  //缓存的真正的值
        let expiration: StorageExpiration  //存活时间，也就是多久之后过期
        let key: String
        
        private(set) var estimatedExpiration: Date  //过期时间，默认值是当前时间加上expiration
        
        init(_ value: T, key: String, expiration: StorageExpiration) {
            self.value = value
            self.key = key
            self.expiration = expiration
            self.estimatedExpiration = expiration.estimatedExpirationSinceNow
        }
        // 更新过期时间
        func extendExpiration(_ extendingExpiration: ExpirationExtending = .cacheTime) {
            switch extendingExpiration {
            case .none:
                return
            case .cacheTime:
                self.estimatedExpiration = expiration.estimatedExpirationSinceNow
            case .expirationTime(let expirationTime):
                self.estimatedExpiration = expirationTime.estimatedExpirationSinceNow
            }
        }
        // 是否已经过期
        var expired: Bool {
            return estimatedExpiration.isPast
        }
    }
}
