
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Notification.Name {
    public static let KingfisherDidCleanDiskCache =
        Notification.Name("com.onevcat.Kingfisher.KingfisherDidCleanDiskCache")
}

public let KingfisherDiskCacheCleanedHashKey = "com.onevcat.Kingfisher.cleanedHash"

/// 缓存的类型
public enum CacheType {
    case none
    case memory
    case disk
    public var cached: Bool {
        switch self {
        case .memory, .disk: return true
        case .none: return false
        }
    }
}

public struct CacheStoreResult {
    public let memoryCacheResult: Result<(), Never>
    public let diskCacheResult: Result<(), KingfisherError>
}

extension KFCrossPlatformImage: CacheCostCalculable {
    public var cacheCost: Int { return kf.cost }
}

extension Data: DataTransformable {
    public func toData() throws -> Data {
        return self
    }

    public static func fromData(_ data: Data) throws -> Data {
        return data
    }

    public static let empty = Data()
}

public enum ImageCacheResult {
    case disk(KFCrossPlatformImage)
    case memory(KFCrossPlatformImage)
    case none

    public var image: KFCrossPlatformImage? {
        switch self {
        case .disk(let image): return image
        case .memory(let image): return image
        case .none: return nil
        }
    }

    public var cacheType: CacheType {
        switch self {
        case .disk: return .disk
        case .memory: return .memory
        case .none: return .none
        }
    }
}

open class ImageCache {

    public static let `default` = ImageCache(name: "default")
    public let memoryStorage: MemoryStorage.Backend<KFCrossPlatformImage>
    public let diskStorage: DiskStorage.Backend<Data>
    private let ioQueue: DispatchQueue
    public typealias DiskCachePathClosure = (URL, String) -> URL

    public init(memoryStorage: MemoryStorage.Backend<KFCrossPlatformImage>, diskStorage: DiskStorage.Backend<Data>) {
        self.memoryStorage = memoryStorage
        self.diskStorage = diskStorage
        let ioQueueName = "com.onevcat.Kingfisher.ImageCache.ioQueue.\(UUID().uuidString)"
        ioQueue = DispatchQueue(label: ioQueueName)

        let notifications: [(Notification.Name, Selector)]
        #if !os(macOS) && !os(watchOS)
        #if swift(>=4.2)
        notifications = [
            (UIApplication.didReceiveMemoryWarningNotification, #selector(clearMemoryCache)),
            (UIApplication.willTerminateNotification, #selector(cleanExpiredDiskCache)),
            (UIApplication.didEnterBackgroundNotification, #selector(backgroundCleanExpiredDiskCache))
        ]
        #else
        notifications = [
            (NSNotification.Name.UIApplicationDidReceiveMemoryWarning, #selector(clearMemoryCache)),
            (NSNotification.Name.UIApplicationWillTerminate, #selector(cleanExpiredDiskCache)),
            (NSNotification.Name.UIApplicationDidEnterBackground, #selector(backgroundCleanExpiredDiskCache))
        ]
        #endif
        #elseif os(macOS)
        notifications = [
            (NSApplication.willResignActiveNotification, #selector(cleanExpiredDiskCache)),
        ]
        #else
        notifications = []
        #endif
        notifications.forEach {
            NotificationCenter.default.addObserver(self, selector: $0.1, name: $0.0, object: nil)
        }
    }

    public convenience init(name: String) {
        try! self.init(name: name, cacheDirectoryURL: nil, diskCachePathClosure: nil)
    }

    public convenience init(name: String, cacheDirectoryURL: URL?, diskCachePathClosure: DiskCachePathClosure? = nil) throws {
        if name.isEmpty {
            fatalError("[Kingfisher] You should specify a name for the cache. A cache with empty name is not permitted.")
        }

        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let costLimit = totalMemory / 4
        let memoryStorage = MemoryStorage.Backend<KFCrossPlatformImage>(config:
            .init(totalCostLimit: (costLimit > Int.max) ? Int.max : Int(costLimit)))

        var diskConfig = DiskStorage.Config(
            name: name,
            sizeLimit: 0,
            directory: cacheDirectoryURL
        )
        if let closure = diskCachePathClosure {
            diskConfig.cachePathBlock = closure
        }
        let diskStorage = try DiskStorage.Backend<Data>(config: diskConfig)
        diskConfig.cachePathBlock = nil

        self.init(memoryStorage: memoryStorage, diskStorage: diskStorage)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Storing Images
    open func store(_ image: KFCrossPlatformImage,
                    original: Data? = nil,
                    forKey key: String,
                    options: KingfisherParsedOptionsInfo,
                    toDisk: Bool = true,
                    completionHandler: ((CacheStoreResult) -> Void)? = nil) {
        let identifier = options.processor.identifier
        let callbackQueue = options.callbackQueue
        
        let computedKey = key.computedKey(with: identifier)
        // Memory storage should not throw.
        memoryStorage.storeNoThrow(value: image, forKey: computedKey, expiration: options.memoryCacheExpiration)
        
        guard toDisk else {
            if let completionHandler = completionHandler {
                let result = CacheStoreResult(memoryCacheResult: .success(()), diskCacheResult: .success(()))
                callbackQueue.execute { completionHandler(result) }
            }
            return
        }
        
        ioQueue.async {
            let serializer = options.cacheSerializer
            if let data = serializer.data(with: image, original: original) {
                self.syncStoreToDisk(
                    data,
                    forKey: key,
                    processorIdentifier: identifier,
                    callbackQueue: callbackQueue,
                    expiration: options.diskCacheExpiration,
                    completionHandler: completionHandler)
            } else {
                guard let completionHandler = completionHandler else { return }
                
                let diskError = KingfisherError.cacheError(
                    reason: .cannotSerializeImage(image: image, original: original, serializer: serializer))
                let result = CacheStoreResult(
                    memoryCacheResult: .success(()),
                    diskCacheResult: .failure(diskError))
                callbackQueue.execute { completionHandler(result) }
            }
        }
    }

    open func store(_ image: KFCrossPlatformImage,
                      original: Data? = nil,
                      forKey key: String,
                      processorIdentifier identifier: String = "",
                      cacheSerializer serializer: CacheSerializer = DefaultCacheSerializer.default,
                      toDisk: Bool = true,
                      callbackQueue: CallbackQueue = .untouch,
                      completionHandler: ((CacheStoreResult) -> Void)? = nil)
    {
        struct TempProcessor: ImageProcessor {
            let identifier: String
            func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
                return nil
            }
        }
        
        let options = KingfisherParsedOptionsInfo([
            .processor(TempProcessor(identifier: identifier)),
            .cacheSerializer(serializer),
            .callbackQueue(callbackQueue)
        ])
        store(image, original: original, forKey: key, options: options,
              toDisk: toDisk, completionHandler: completionHandler)
    }
    
    open func storeToDisk(
        _ data: Data,
        forKey key: String,
        processorIdentifier identifier: String = "",
        expiration: StorageExpiration? = nil,
        callbackQueue: CallbackQueue = .untouch,
        completionHandler: ((CacheStoreResult) -> Void)? = nil)
    {
        ioQueue.async {
            self.syncStoreToDisk(
                data,
                forKey: key,
                processorIdentifier: identifier,
                callbackQueue: callbackQueue,
                expiration: expiration,
                completionHandler: completionHandler)
        }
    }
    
    private func syncStoreToDisk(
        _ data: Data,
        forKey key: String,
        processorIdentifier identifier: String = "",
        callbackQueue: CallbackQueue = .untouch,
        expiration: StorageExpiration? = nil,
        completionHandler: ((CacheStoreResult) -> Void)? = nil)
    {
        let computedKey = key.computedKey(with: identifier)
        let result: CacheStoreResult
        do {
            try self.diskStorage.store(value: data, forKey: computedKey, expiration: expiration)
            result = CacheStoreResult(memoryCacheResult: .success(()), diskCacheResult: .success(()))
        } catch {
            let diskError: KingfisherError
            if let error = error as? KingfisherError {
                diskError = error
            } else {
                diskError = .cacheError(reason: .cannotConvertToData(object: data, error: error))
            }
            
            result = CacheStoreResult(
                memoryCacheResult: .success(()),
                diskCacheResult: .failure(diskError)
            )
        }
        if let completionHandler = completionHandler {
            callbackQueue.execute { completionHandler(result) }
        }
    }

    open func removeImage(forKey key: String,
                          processorIdentifier identifier: String = "",
                          fromMemory: Bool = true,
                          fromDisk: Bool = true,
                          callbackQueue: CallbackQueue = .untouch,
                          completionHandler: (() -> Void)? = nil)
    {
        let computedKey = key.computedKey(with: identifier)

        if fromMemory {
            try? memoryStorage.remove(forKey: computedKey)
        }
        
        if fromDisk {
            ioQueue.async{
                try? self.diskStorage.remove(forKey: computedKey)
                if let completionHandler = completionHandler {
                    callbackQueue.execute { completionHandler() }
                }
            }
        } else {
            if let completionHandler = completionHandler {
                callbackQueue.execute { completionHandler() }
            }
        }
    }

    func retrieveImage(forKey key: String, options: KingfisherParsedOptionsInfo, callbackQueue: CallbackQueue = .mainCurrentOrAsync, completionHandler: ((Result<ImageCacheResult, KingfisherError>) -> Void)?) {
        // No completion handler. No need to start working and early return.
        guard let completionHandler = completionHandler else { return }

        // Try to check the image from memory cache first.
        if let image = retrieveImageInMemoryCache(forKey: key, options: options) {
            let image = options.imageModifier?.modify(image) ?? image
            callbackQueue.execute { completionHandler(.success(.memory(image))) }
        } else if options.fromMemoryCacheOrRefresh {
            callbackQueue.execute { completionHandler(.success(.none)) }
        } else {

            // Begin to disk search.
            self.retrieveImageInDiskCache(forKey: key, options: options, callbackQueue: callbackQueue) {
                result in
                switch result {
                case .success(let image):

                    guard let image = image else {
                        // No image found in disk storage.
                        callbackQueue.execute { completionHandler(.success(.none)) }
                        return
                    }

                    let finalImage = options.imageModifier?.modify(image) ?? image
                    // Cache the disk image to memory.
                    // We are passing `false` to `toDisk`, the memory cache does not change
                    // callback queue, we can call `completionHandler` without another dispatch.
                    var cacheOptions = options
                    cacheOptions.callbackQueue = .untouch
                    self.store(
                        finalImage,
                        forKey: key,
                        options: cacheOptions,
                        toDisk: false)
                    {
                        _ in
                        callbackQueue.execute { completionHandler(.success(.disk(finalImage))) }
                    }
                case .failure(let error):
                    callbackQueue.execute { completionHandler(.failure(error)) }
                }
            }
        }
    }

    open func retrieveImage(forKey key: String,
                               options: KingfisherOptionsInfo? = nil,
                        callbackQueue: CallbackQueue = .mainCurrentOrAsync,
                     completionHandler: ((Result<ImageCacheResult, KingfisherError>) -> Void)?)
    {
        retrieveImage(
            forKey: key,
            options: KingfisherParsedOptionsInfo(options),
            callbackQueue: callbackQueue,
            completionHandler: completionHandler)
    }

    func retrieveImageInMemoryCache(
        forKey key: String,
        options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage?
    {
        let computedKey = key.computedKey(with: options.processor.identifier)
        return memoryStorage.value(forKey: computedKey, extendingExpiration: options.memoryCacheAccessExtendingExpiration)
    }

    open func retrieveImageInMemoryCache(
        forKey key: String,
        options: KingfisherOptionsInfo? = nil) -> KFCrossPlatformImage?
    {
        return retrieveImageInMemoryCache(forKey: key, options: KingfisherParsedOptionsInfo(options))
    }

    func retrieveImageInDiskCache(
        forKey key: String,
        options: KingfisherParsedOptionsInfo,
        callbackQueue: CallbackQueue = .untouch,
        completionHandler: @escaping (Result<KFCrossPlatformImage?, KingfisherError>) -> Void)
    {
        let computedKey = key.computedKey(with: options.processor.identifier)
        let loadingQueue: CallbackQueue = options.loadDiskFileSynchronously ? .untouch : .dispatch(ioQueue)
        loadingQueue.execute {
            do {
                var image: KFCrossPlatformImage? = nil
                if let data = try self.diskStorage.value(forKey: computedKey, extendingExpiration: options.diskCacheAccessExtendingExpiration) {
                    image = options.cacheSerializer.image(with: data, options: options)
                }
                callbackQueue.execute { completionHandler(.success(image)) }
            } catch {
                if let error = error as? KingfisherError {
                    callbackQueue.execute { completionHandler(.failure(error)) }
                } else {
                    assertionFailure("The internal thrown error should be a `KingfisherError`.")
                }
            }
        }
    }

    open func retrieveImageInDiskCache(
        forKey key: String,
        options: KingfisherOptionsInfo? = nil,
        callbackQueue: CallbackQueue = .untouch,
        completionHandler: @escaping (Result<KFCrossPlatformImage?, KingfisherError>) -> Void)
    {
        retrieveImageInDiskCache(
            forKey: key,
            options: KingfisherParsedOptionsInfo(options),
            callbackQueue: callbackQueue,
            completionHandler: completionHandler)
    }

    public func clearCache(completion handler: (() -> Void)? = nil) {
        clearMemoryCache()
        clearDiskCache(completion: handler)
    }

    @objc public func clearMemoryCache() {
        try? memoryStorage.removeAll()
    }

    open func clearDiskCache(completion handler: (() -> Void)? = nil) {
        ioQueue.async {
            do {
                try self.diskStorage.removeAll()
            } catch _ { }
            if let handler = handler {
                DispatchQueue.main.async { handler() }
            }
        }
    }

    open func cleanExpiredCache(completion handler: (() -> Void)? = nil) {
        cleanExpiredMemoryCache()
        cleanExpiredDiskCache(completion: handler)
    }

    open func cleanExpiredMemoryCache() {
        memoryStorage.removeExpired()
    }

    @objc func cleanExpiredDiskCache() {
        cleanExpiredDiskCache(completion: nil)
    }

    open func cleanExpiredDiskCache(completion handler: (() -> Void)? = nil) {
        ioQueue.async {
            do {
                var removed: [URL] = []
                let removedExpired = try self.diskStorage.removeExpiredValues()
                removed.append(contentsOf: removedExpired)

                let removedSizeExceeded = try self.diskStorage.removeSizeExceededValues()
                removed.append(contentsOf: removedSizeExceeded)

                if !removed.isEmpty {
                    DispatchQueue.main.async {
                        let cleanedHashes = removed.map { $0.lastPathComponent }
                        NotificationCenter.default.post(
                            name: .KingfisherDidCleanDiskCache,
                            object: self,
                            userInfo: [KingfisherDiskCacheCleanedHashKey: cleanedHashes])
                    }
                }

                if let handler = handler {
                    DispatchQueue.main.async { handler() }
                }
            } catch {}
        }
    }

#if !os(macOS) && !os(watchOS)
    @objc public func backgroundCleanExpiredDiskCache() {
        guard let sharedApplication = KingfisherWrapper<UIApplication>.shared else { return }

        func endBackgroundTask(_ task: inout UIBackgroundTaskIdentifier) {
            sharedApplication.endBackgroundTask(task)
            #if swift(>=4.2)
            task = UIBackgroundTaskIdentifier.invalid
            #else
            task = UIBackgroundTaskInvalid
            #endif
        }
        
        var backgroundTask: UIBackgroundTaskIdentifier!
        backgroundTask = sharedApplication.beginBackgroundTask {
            endBackgroundTask(&backgroundTask!)
        }
        
        cleanExpiredDiskCache {
            endBackgroundTask(&backgroundTask!)
        }
    }
#endif

    open func imageCachedType(forKey key: String, processorIdentifier identifier: String = DefaultImageProcessor.default.identifier) -> CacheType {
        let computedKey = key.computedKey(with: identifier)
        if memoryStorage.isCached(forKey: computedKey) { return .memory }
        if diskStorage.isCached(forKey: computedKey) { return .disk }
        return .none
    }

    public func isCached(forKey key: String, processorIdentifier identifier: String = DefaultImageProcessor.default.identifier) -> Bool {
        return imageCachedType(forKey: key, processorIdentifier: identifier).cached
    }

    open func hash(forKey key: String, processorIdentifier identifier: String = DefaultImageProcessor.default.identifier) -> String {
        let computedKey = key.computedKey(with: identifier)
        return diskStorage.cacheFileName(forKey: computedKey)
    }

    open func calculateDiskStorageSize(completion handler: @escaping ((Result<UInt, KingfisherError>) -> Void)) {
        ioQueue.async {
            do {
                let size = try self.diskStorage.totalSize()
                DispatchQueue.main.async { handler(.success(size)) }
            } catch {
                if let error = error as? KingfisherError {
                    DispatchQueue.main.async { handler(.failure(error)) }
                } else {
                    assertionFailure("The internal thrown error should be a `KingfisherError`.")
                }
                
            }
        }
    }

    open func cachePath(forKey key: String, processorIdentifier identifier: String = DefaultImageProcessor.default.identifier) -> String {
        let computedKey = key.computedKey(with: identifier)
        return diskStorage.cacheFileURL(forKey: computedKey).path
    }
}

extension Dictionary {
    func keysSortedByValue(_ isOrderedBefore: (Value, Value) -> Bool) -> [Key] {
        return Array(self).sorted{ isOrderedBefore($0.1, $1.1) }.map{ $0.0 }
    }
}

#if !os(macOS) && !os(watchOS)
// MARK: - For App Extensions
extension UIApplication: KingfisherCompatible { }
extension KingfisherWrapper where Base: UIApplication {
    public static var shared: UIApplication? {
        let selector = NSSelectorFromString("sharedApplication")
        guard Base.responds(to: selector) else { return nil }
        return Base.perform(selector).takeUnretainedValue() as? UIApplication
    }
}
#endif

extension String {
    func computedKey(with identifier: String) -> String {
        if identifier.isEmpty {
            return self
        } else {
            return appending("@\(identifier)")
        }
    }
}
