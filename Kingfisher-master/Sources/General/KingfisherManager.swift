
import Foundation

public typealias DownloadProgressBlock = ((_ receivedSize: Int64, _ totalSize: Int64) -> Void)

public struct RetrieveImageResult {
    public let image: KFCrossPlatformImage
    public let cacheType: CacheType
    public let source: Source
    public let originalSource: Source
}

public struct PropagationError {
    public let source: Source
    public let error: KingfisherError
}

public typealias DownloadTaskUpdatedBlock = ((_ newTask: DownloadTask?) -> Void)

public class KingfisherManager {

    public static let shared = KingfisherManager()
    public var cache: ImageCache
    public var downloader: ImageDownloader
    public var defaultOptions = KingfisherOptionsInfo.empty

    private var currentDefaultOptions: KingfisherOptionsInfo {
        return [.downloader(downloader), .targetCache(cache)] + defaultOptions
    }

    private let processingQueue: CallbackQueue
    
    private convenience init() {
        self.init(downloader: .default, cache: .default)
    }

    public init(downloader: ImageDownloader, cache: ImageCache) {
        self.downloader = downloader
        self.cache = cache

        let processQueueName = "com.onevcat.Kingfisher.KingfisherManager.processQueue.\(UUID().uuidString)"
        processingQueue = .dispatch(DispatchQueue(label: processQueueName))
    }

    @discardableResult
    public func retrieveImage(with resource: Resource,
                              options: KingfisherOptionsInfo? = nil,
                              progressBlock: DownloadProgressBlock? = nil,
                              downloadTaskUpdated: DownloadTaskUpdatedBlock? = nil,
                              completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?) -> DownloadTask? {
        return retrieveImage(with: resource.convertToSource(), options: options, progressBlock: progressBlock, downloadTaskUpdated: downloadTaskUpdated, completionHandler: completionHandler)
    }

    public func retrieveImage(with source: Source,
                              options: KingfisherOptionsInfo? = nil,
                              progressBlock: DownloadProgressBlock? = nil,
                              downloadTaskUpdated: DownloadTaskUpdatedBlock? = nil,
                              completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?) -> DownloadTask? {
        let options = currentDefaultOptions + (options ?? .empty)
        var info = KingfisherParsedOptionsInfo(options)
        if let block = progressBlock {
            info.onDataReceived = (info.onDataReceived ?? []) + [ImageLoadingProgressSideEffect(block)]
        }
        return retrieveImage(
            with: source,
            options: info,
            downloadTaskUpdated: downloadTaskUpdated,
            completionHandler: completionHandler)
    }

    func retrieveImage(with source: Source,
                       options: KingfisherParsedOptionsInfo,
                       downloadTaskUpdated: DownloadTaskUpdatedBlock? = nil,
                       completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?) -> DownloadTask? {
        let retrievingContext = RetrievingContext(options: options, originalSource: source)
        var retryContext: RetryContext?

        func startNewRetrieveTask(with source: Source, downloadTaskUpdated: DownloadTaskUpdatedBlock?) {
            let newTask = self.retrieveImage(with: source, context: retrievingContext) { result in
                handler(currentSource: source, result: result)
            }
            downloadTaskUpdated?(newTask)
        }

        func failCurrentSource(_ source: Source, with error: KingfisherError) {
            guard !error.isTaskCancelled else { // 取消则跳过来源
                completionHandler?(.failure(error))
                return
            }
            if let nextSource = retrievingContext.popAlternativeSource() {
                startNewRetrieveTask(with: nextSource, downloadTaskUpdated: downloadTaskUpdated)
            } else {
                if retrievingContext.propagationErrors.isEmpty { //没有其他来源就报错
                    completionHandler?(.failure(error))
                } else {
                    retrievingContext.appendError(error, to: source)
                    let finalError = KingfisherError.imageSettingError(
                        reason: .alternativeSourcesExhausted(retrievingContext.propagationErrors)
                    )
                    completionHandler?(.failure(finalError))
                }
            }
        }

        func handler(currentSource: Source, result: (Result<RetrieveImageResult, KingfisherError>)) -> Void {
            switch result {
            case .success:
                completionHandler?(result)
            case .failure(let error):
                if let retryStrategy = options.retryStrategy {
                    let context = retryContext?.increaseRetryCount() ?? RetryContext(source: source, error: error)
                    retryContext = context

                    retryStrategy.retry(context: context) { decision in
                        switch decision {
                        case .retry(let userInfo):
                            retryContext?.userInfo = userInfo
                            startNewRetrieveTask(with: source, downloadTaskUpdated: downloadTaskUpdated)
                        case .stop:
                            failCurrentSource(currentSource, with: error)
                        }
                    }
                } else {

                    // Skip alternative sources if the user cancelled it.
                    guard !error.isTaskCancelled else {
                        completionHandler?(.failure(error))
                        return
                    }
                    if let nextSource = retrievingContext.popAlternativeSource() {
                        retrievingContext.appendError(error, to: currentSource)
                        startNewRetrieveTask(with: nextSource, downloadTaskUpdated: downloadTaskUpdated)
                    } else {
                        // No other alternative source. Finish with error.
                        if retrievingContext.propagationErrors.isEmpty {
                            completionHandler?(.failure(error))
                        } else {
                            retrievingContext.appendError(error, to: currentSource)
                            let finalError = KingfisherError.imageSettingError(
                                reason: .alternativeSourcesExhausted(retrievingContext.propagationErrors)
                            )
                            completionHandler?(.failure(finalError))
                        }
                    }
                }
            }
        }

        return retrieveImage(with: source, context: retrievingContext) { result in
            handler(currentSource: source, result: result)
        }
    }
    
    private func retrieveImage(with source: Source,
                               context: RetrievingContext,
                               completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?) -> DownloadTask? {
        let options = context.options
        if options.forceRefresh { //强制刷新
            return loadAndCacheImage(source: source, context: context, completionHandler: completionHandler)?.value
        } else {
            let loadedFromCache = retrieveImageFromCache(source: source, context: context, completionHandler: completionHandler)
            if loadedFromCache { return nil }
            if options.onlyFromCache {
                let error = KingfisherError.cacheError(reason: .imageNotExisting(key: source.cacheKey))
                completionHandler?(.failure(error))
                return nil
            }
            return loadAndCacheImage(source: source, context: context, completionHandler: completionHandler)?.value
        }
    }

    func provideImage(provider: ImageDataProvider,
                      options: KingfisherParsedOptionsInfo,
                      completionHandler: ((Result<ImageLoadingResult, KingfisherError>) -> Void)?) {
        guard let  completionHandler = completionHandler else { return }
        provider.data { result in
            switch result {
            case .success(let data):
                (options.processingQueue ?? self.processingQueue).execute {
                    let processor = options.processor
                    let processingItem = ImageProcessItem.data(data)
                    guard let image = processor.process(item: processingItem, options: options) else {
                        options.callbackQueue.execute {
                            let error = KingfisherError.processorError(
                                reason: .processingFailed(processor: processor, item: processingItem))
                            completionHandler(.failure(error))
                        }
                        return
                    }

                    let finalImage = options.imageModifier?.modify(image) ?? image
                    options.callbackQueue.execute {
                        let result = ImageLoadingResult(image: finalImage, url: nil, originalData: data)
                        completionHandler(.success(result))
                    }
                }
            case .failure(let error):
                options.callbackQueue.execute {
                    let error = KingfisherError.imageSettingError(
                        reason: .dataProviderError(provider: provider, error: error))
                    completionHandler(.failure(error))
                }

            }
        }
    }

    private func cacheImage(source: Source,
                            options: KingfisherParsedOptionsInfo,
                            context: RetrievingContext,
                            result: Result<ImageLoadingResult, KingfisherError>,
                            completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?) {
        switch result {
        case .success(let value):
            let needToCacheOriginalImage = options.cacheOriginalImage && options.processor != DefaultImageProcessor.default
            let coordinator = CacheCallbackCoordinator(shouldWaitForCache: options.waitForCache, shouldCacheOriginal: needToCacheOriginalImage)
            // 添加图片到 cache.
            let targetCache = options.targetCache ?? self.cache
            targetCache.store(value.image, original: value.originalData, forKey: source.cacheKey, options: options, toDisk: !options.cacheMemoryOnly) { _ in
                coordinator.apply(.cachingImage) {
                    let result = RetrieveImageResult(
                        image: value.image,
                        cacheType: .none,
                        source: source,
                        originalSource: context.originalSource
                    )
                    completionHandler?(.success(result))
                }
            }

            // 把原图添加到缓存
            if needToCacheOriginalImage {
                let originalCache = options.originalCache ?? targetCache
                originalCache.storeToDisk(value.originalData, forKey: source.cacheKey, processorIdentifier: DefaultImageProcessor.default.identifier, expiration: options.diskCacheExpiration){ _ in
                    coordinator.apply(.cachingOriginalImage) {
                        let result = RetrieveImageResult(
                            image: value.image,
                            cacheType: .none,
                            source: source,
                            originalSource: context.originalSource
                        )
                        completionHandler?(.success(result))
                    }
                }
            }

            coordinator.apply(.cacheInitiated) {
                let result = RetrieveImageResult(image: value.image, cacheType: .none, source: source, originalSource: context.originalSource)
                completionHandler?(.success(result))
            }

        case .failure(let error):
            completionHandler?(.failure(error))
        }
    }

    @discardableResult
    func loadAndCacheImage(source: Source,
                           context: RetrievingContext,
                           completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?) -> DownloadTask.WrappedTask? {
        let options = context.options
        func _cacheImage(_ result: Result<ImageLoadingResult, KingfisherError>) {
            cacheImage(source: source, options: options, context: context, result: result, completionHandler: completionHandler)
        }
        switch source {
            case .network(let resource):
            let downloader = options.downloader ?? self.downloader
            let task = downloader.downloadImage(with: resource.downloadURL, options: options, completionHandler: _cacheImage)
            if let task = task {
                return .download(task)
            } else {
                return nil
            }

        case .provider(let provider):
            provideImage(provider: provider, options: options, completionHandler: _cacheImage)
            return .dataProviding
        }
    }

    func retrieveImageFromCache(source: Source,
                                context: RetrievingContext,
                                completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)?) -> Bool {
        let options = context.options
        // 1. 判断图片是否已经存在目标缓存中
        let targetCache = options.targetCache ?? cache
        let key = source.cacheKey
        let targetImageCached = targetCache.imageCachedType(forKey: key, processorIdentifier: options.processor.identifier)
        
        let validCache = targetImageCached.cached && (options.fromMemoryCacheOrRefresh == false || targetImageCached == .memory)
        if validCache {
            targetCache.retrieveImage(forKey: key, options: options) { result in
                guard let completionHandler = completionHandler else { return }
                options.callbackQueue.execute {
                    result.match(
                        onSuccess: { cacheResult in
                            let value: Result<RetrieveImageResult, KingfisherError>
                            if let image = cacheResult.image {
                                value = result.map {
                                    RetrieveImageResult(
                                        image: image,
                                        cacheType: $0.cacheType,
                                        source: source,
                                        originalSource: context.originalSource
                                    )
                                }
                            } else {
                                value = .failure(KingfisherError.cacheError(reason: .imageNotExisting(key: key)))
                            }
                            completionHandler(value)
                        },
                        onFailure: { _ in
                            completionHandler(.failure(KingfisherError.cacheError(reason: .imageNotExisting(key: key))))
                        }
                    )
                }
            }
            return true
        }

        // 2. 判断原始的图片是否已经缓存，如果存在缓存图片，那么直接返回, 不需要重复缓存
        let originalCache = options.originalCache ?? targetCache
        if originalCache === targetCache && options.processor == DefaultImageProcessor.default {
            return false
        }

        // 检查是否存在未处理的图片
        let originalImageCacheType = originalCache.imageCachedType(forKey: key, processorIdentifier: DefaultImageProcessor.default.identifier)
        let canAcceptDiskCache = !options.fromMemoryCacheOrRefresh
        
        let canUseOriginalImageCache =
            (canAcceptDiskCache && originalImageCacheType.cached) ||
            (!canAcceptDiskCache && originalImageCacheType == .memory)
        
        if canUseOriginalImageCache {
            // 找到缓存的图片，处理为原始的数据
            var optionsWithoutProcessor = options
            optionsWithoutProcessor.processor = DefaultImageProcessor.default
            originalCache.retrieveImage(forKey: key, options: optionsWithoutProcessor) { result in
                result.match(
                    onSuccess: { cacheResult in
                        guard let image = cacheResult.image else {
                            assertionFailure("The image (under key: \(key) should be existing in the original cache.")
                            return
                        }

                        let processor = options.processor
                        (options.processingQueue ?? self.processingQueue).execute {
                            let item = ImageProcessItem.image(image)
                            guard let processedImage = processor.process(item: item, options: options) else {
                                let error = KingfisherError.processorError(
                                    reason: .processingFailed(processor: processor, item: item))
                                options.callbackQueue.execute { completionHandler?(.failure(error)) }
                                return
                            }

                            var cacheOptions = options
                            cacheOptions.callbackQueue = .untouch

                            let coordinator = CacheCallbackCoordinator(
                                shouldWaitForCache: options.waitForCache, shouldCacheOriginal: false)

                            targetCache.store(processedImage, forKey: key, options: cacheOptions, toDisk: !options.cacheMemoryOnly) {
                                _ in
                                coordinator.apply(.cachingImage) {
                                    let value = RetrieveImageResult(
                                        image: processedImage,
                                        cacheType: .none,
                                        source: source,
                                        originalSource: context.originalSource
                                    )
                                    options.callbackQueue.execute { completionHandler?(.success(value)) }
                                }
                            }

                            coordinator.apply(.cacheInitiated) {
                                let value = RetrieveImageResult(image: processedImage, cacheType: .none, source: source, originalSource: context.originalSource)
                                options.callbackQueue.execute { completionHandler?(.success(value)) }
                            }
                        }
                    },
                    onFailure: { _ in
                        options.callbackQueue.execute {
                            completionHandler?(
                                .failure(KingfisherError.cacheError(reason: .imageNotExisting(key: key)))
                            )
                        }
                    }
                )
            }
            return true
        }
        return false
    }
}

class RetrievingContext {

    var options: KingfisherParsedOptionsInfo

    let originalSource: Source
    var propagationErrors: [PropagationError] = []

    init(options: KingfisherParsedOptionsInfo, originalSource: Source) {
        self.originalSource = originalSource
        self.options = options
    }

    func popAlternativeSource() -> Source? {
        guard var alternativeSources = options.alternativeSources, !alternativeSources.isEmpty else {
            return nil
        }
        let nextSource = alternativeSources.removeFirst()
        options.alternativeSources = alternativeSources
        return nextSource
    }

    @discardableResult
    func appendError(_ error: KingfisherError, to source: Source) -> [PropagationError] {
        let item = PropagationError(source: source, error: error)
        propagationErrors.append(item)
        return propagationErrors
    }
}

/// 缓存回调协作器
class CacheCallbackCoordinator {
    enum State {
        case idle
        case imageCached
        case originalImageCached
        case done
    }

    enum Action {
        case cacheInitiated
        case cachingImage
        case cachingOriginalImage
    }

    private let shouldWaitForCache: Bool
    private let shouldCacheOriginal: Bool
    private let stateQueue: DispatchQueue
    private var threadSafeState: State = .idle

    private (set) var state: State {
        set { stateQueue.sync { threadSafeState = newValue } }
        get { stateQueue.sync { threadSafeState } }
    }

    init(shouldWaitForCache: Bool, shouldCacheOriginal: Bool) {
        self.shouldWaitForCache = shouldWaitForCache
        self.shouldCacheOriginal = shouldCacheOriginal
        let stateQueueName = "com.onevcat.Kingfisher.CacheCallbackCoordinator.stateQueue.\(UUID().uuidString)"
        self.stateQueue = DispatchQueue(label: stateQueueName)
    }

    func apply(_ action: Action, trigger: () -> Void) {
        switch (state, action) {
        case (.done, _):
            break
        case (.idle, .cacheInitiated): // .idle
            if !shouldWaitForCache {
                state = .done
                trigger()
            }
        case (.idle, .cachingImage):
            if shouldCacheOriginal {
                state = .imageCached
            } else {
                state = .done
                trigger()
            }
        case (.idle, .cachingOriginalImage):
            state = .originalImageCached
        case (.imageCached, .cachingOriginalImage): // .imageCached
            state = .done
            trigger()
        case (.originalImageCached, .cachingImage): // .originalImageCached
            state = .done
            trigger()

        default:
            assertionFailure("This case should not happen in CacheCallbackCoordinator: \(state) - \(action)")
        }
    }
}
