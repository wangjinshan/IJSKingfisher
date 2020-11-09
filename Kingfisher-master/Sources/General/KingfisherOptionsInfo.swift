#if os(macOS)
import AppKit
#else
import UIKit
#endif

public typealias KingfisherOptionsInfo = [KingfisherOptionsInfoItem]

extension Array where Element == KingfisherOptionsInfoItem {
    static let empty: KingfisherOptionsInfo = []
}

public enum KingfisherOptionsInfoItem {
    case targetCache(ImageCache)
    case originalCache(ImageCache)
    case downloader(ImageDownloader)
    case transition(ImageTransition)
    case downloadPriority(Float)
    case forceRefresh
    case fromMemoryCacheOrRefresh
    case forceTransition
    case cacheMemoryOnly
    case waitForCache
    case onlyFromCache
    case backgroundDecode
    case callbackQueue(CallbackQueue)
    case scaleFactor(CGFloat)
    case preloadAllAnimationData
    case requestModifier(ImageDownloadRequestModifier)
    case redirectHandler(ImageDownloadRedirectHandler)
    case processor(ImageProcessor)
    case cacheSerializer(CacheSerializer)
    case imageModifier(ImageModifier)
    case keepCurrentImageWhileLoading
    case onlyLoadFirstFrame
    case cacheOriginalImage
    case onFailureImage(KFCrossPlatformImage?)
    case alsoPrefetchToMemory
    case loadDiskFileSynchronously
    case memoryCacheExpiration(StorageExpiration)
    case memoryCacheAccessExtendingExpiration(ExpirationExtending)
    case diskCacheExpiration(StorageExpiration)
    case diskCacheAccessExtendingExpiration(ExpirationExtending)
    case processingQueue(CallbackQueue)
    case progressiveJPEG(ImageProgressive)
    case alternativeSources([Source])
    case retryStrategy(RetryStrategy)
}

/// 配置信息
public struct KingfisherParsedOptionsInfo {
    public var targetCache: ImageCache? = nil
    public var originalCache: ImageCache? = nil
    public var downloader: ImageDownloader? = nil
    public var transition: ImageTransition = .none
    public var downloadPriority: Float = URLSessionTask.defaultPriority
    public var forceRefresh = false
    public var fromMemoryCacheOrRefresh = false
    public var forceTransition = false
    public var cacheMemoryOnly = false
    public var waitForCache = false
    public var onlyFromCache = false
    public var backgroundDecode = false
    public var preloadAllAnimationData = false
    public var callbackQueue: CallbackQueue = .mainCurrentOrAsync
    public var scaleFactor: CGFloat = 1.0
    public var requestModifier: ImageDownloadRequestModifier? = nil
    public var redirectHandler: ImageDownloadRedirectHandler? = nil
    public var processor: ImageProcessor = DefaultImageProcessor.default
    public var imageModifier: ImageModifier? = nil
    public var cacheSerializer: CacheSerializer = DefaultCacheSerializer.default
    public var keepCurrentImageWhileLoading = false 
    public var onlyLoadFirstFrame = false
    public var cacheOriginalImage = false
    public var onFailureImage: Optional<KFCrossPlatformImage?> = .none
    public var alsoPrefetchToMemory = false
    public var loadDiskFileSynchronously = false
    public var memoryCacheExpiration: StorageExpiration? = nil
    public var memoryCacheAccessExtendingExpiration: ExpirationExtending = .cacheTime
    public var diskCacheExpiration: StorageExpiration? = nil
    public var diskCacheAccessExtendingExpiration: ExpirationExtending = .cacheTime
    public var processingQueue: CallbackQueue? = nil
    public var progressiveJPEG: ImageProgressive? = nil
    public var alternativeSources: [Source]? = nil
    public var retryStrategy: RetryStrategy? = nil

    var onDataReceived: [DataReceivingSideEffect]? = nil
    
    public init(_ info: KingfisherOptionsInfo?) {
        guard let info = info else { return }
        for option in info {
            switch option {
            case .targetCache(let value): targetCache = value
            case .originalCache(let value): originalCache = value
            case .downloader(let value): downloader = value
            case .transition(let value): transition = value
            case .downloadPriority(let value): downloadPriority = value
            case .forceRefresh: forceRefresh = true
            case .fromMemoryCacheOrRefresh: fromMemoryCacheOrRefresh = true
            case .forceTransition: forceTransition = true
            case .cacheMemoryOnly: cacheMemoryOnly = true
            case .waitForCache: waitForCache = true
            case .onlyFromCache: onlyFromCache = true
            case .backgroundDecode: backgroundDecode = true
            case .preloadAllAnimationData: preloadAllAnimationData = true
            case .callbackQueue(let value): callbackQueue = value
            case .scaleFactor(let value): scaleFactor = value
            case .requestModifier(let value): requestModifier = value
            case .redirectHandler(let value): redirectHandler = value
            case .processor(let value): processor = value
            case .imageModifier(let value): imageModifier = value
            case .cacheSerializer(let value): cacheSerializer = value
            case .keepCurrentImageWhileLoading: keepCurrentImageWhileLoading = true
            case .onlyLoadFirstFrame: onlyLoadFirstFrame = true
            case .cacheOriginalImage: cacheOriginalImage = true
            case .onFailureImage(let value): onFailureImage = .some(value)
            case .alsoPrefetchToMemory: alsoPrefetchToMemory = true
            case .loadDiskFileSynchronously: loadDiskFileSynchronously = true
            case .memoryCacheExpiration(let expiration): memoryCacheExpiration = expiration
            case .memoryCacheAccessExtendingExpiration(let expirationExtending): memoryCacheAccessExtendingExpiration = expirationExtending
            case .diskCacheExpiration(let expiration): diskCacheExpiration = expiration
            case .diskCacheAccessExtendingExpiration(let expirationExtending): diskCacheAccessExtendingExpiration = expirationExtending
            case .processingQueue(let queue): processingQueue = queue
            case .progressiveJPEG(let value): progressiveJPEG = value
            case .alternativeSources(let sources): alternativeSources = sources
            case .retryStrategy(let strategy): retryStrategy = strategy
            }
        }

        if originalCache == nil {
            originalCache = targetCache
        }
    }
}

extension KingfisherParsedOptionsInfo {
    var imageCreatingOptions: ImageCreatingOptions {
        return ImageCreatingOptions(
            scale: scaleFactor,
            duration: 0.0,
            preloadAll: preloadAllAnimationData,
            onlyFirstFrame: onlyLoadFirstFrame)
    }
}

protocol DataReceivingSideEffect: AnyObject {
    var onShouldApply: () -> Bool { get set }
    func onDataReceived(_ session: URLSession, task: SessionDataTask, data: Data)
}

class ImageLoadingProgressSideEffect: DataReceivingSideEffect {

    var onShouldApply: () -> Bool = { return true }
    
    let block: DownloadProgressBlock

    init(_ block: @escaping DownloadProgressBlock) {
        self.block = block
    }

    func onDataReceived(_ session: URLSession, task: SessionDataTask, data: Data) {
        DispatchQueue.main.async {
            guard self.onShouldApply() else { return }
            guard let expectedContentLength = task.task.response?.expectedContentLength, expectedContentLength != -1 else {
                return
            }
            let dataLength = Int64(task.mutableData.count)
            self.block(dataLength, expectedContentLength)
        }
    }
}
