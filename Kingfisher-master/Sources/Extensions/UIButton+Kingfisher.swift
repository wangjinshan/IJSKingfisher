
#if !os(watchOS)

#if canImport(UIKit)
import UIKit

extension KingfisherWrapper where Base: UIButton {

    @discardableResult
    public func setImage(
        with source: Source?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        guard let source = source else {
            base.setImage(placeholder, for: state)
            setTaskIdentifier(nil, for: state)
            completionHandler?(.failure(KingfisherError.imageSettingError(reason: .emptySource)))
            return nil
        }
        
        var options = KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions + (options ?? .empty))
        if !options.keepCurrentImageWhileLoading {
            base.setImage(placeholder, for: state)
        }
        
        var mutatingSelf = self
        let issuedIdentifier = Source.Identifier.next()
        setTaskIdentifier(issuedIdentifier, for: state)
        
        if let block = progressBlock {
            options.onDataReceived = (options.onDataReceived ?? []) + [ImageLoadingProgressSideEffect(block)]
        }
        
        if let provider = ImageProgressiveProvider(options, refresh: { image in
            self.base.setImage(image, for: state)
        }) {
            options.onDataReceived = (options.onDataReceived ?? []) + [provider]
        }
        
        options.onDataReceived?.forEach {
            $0.onShouldApply = { issuedIdentifier == self.taskIdentifier(for: state) }
        }
        
        let task = KingfisherManager.shared.retrieveImage(
            with: source,
            options: options,
            downloadTaskUpdated: { mutatingSelf.imageTask = $0 },
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
                    guard issuedIdentifier == self.taskIdentifier(for: state) else {
                        let reason: KingfisherError.ImageSettingErrorReason
                        do {
                            let value = try result.get()
                            reason = .notCurrentSourceTask(result: value, error: nil, source: source)
                        } catch {
                            reason = .notCurrentSourceTask(result: nil, error: error, source: source)
                        }
                        let error = KingfisherError.imageSettingError(reason: reason)
                        completionHandler?(.failure(error))
                        return
                    }
                    
                    mutatingSelf.imageTask = nil
                    mutatingSelf.setTaskIdentifier(nil, for: state)
                    
                    switch result {
                    case .success(let value):
                        self.base.setImage(value.image, for: state) // 设置图片
                        completionHandler?(result)
                        
                    case .failure:
                        if let image = options.onFailureImage {
                            self.base.setImage(image, for: state)
                        }
                        completionHandler?(result)
                    }
                }
            }
        )
        
        mutatingSelf.imageTask = task
        return task
    }

    @discardableResult
    public func setImage(
        with resource: Resource?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        return setImage(
            with: resource?.convertToSource(),
            for: state,
            placeholder: placeholder,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    public func cancelImageDownloadTask() {
        imageTask?.cancel()
    }

    @discardableResult
    public func setBackgroundImage(
        with source: Source?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        guard let source = source else {
            base.setBackgroundImage(placeholder, for: state)
            setBackgroundTaskIdentifier(nil, for: state)
            completionHandler?(.failure(KingfisherError.imageSettingError(reason: .emptySource)))
            return nil
        }

        var options = KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions + (options ?? .empty))
        if !options.keepCurrentImageWhileLoading {
            base.setBackgroundImage(placeholder, for: state)
        }
        
        var mutatingSelf = self
        let issuedIdentifier = Source.Identifier.next()
        setBackgroundTaskIdentifier(issuedIdentifier, for: state)
        
        if let block = progressBlock {
            options.onDataReceived = (options.onDataReceived ?? []) + [ImageLoadingProgressSideEffect(block)]
        }
        
        if let provider = ImageProgressiveProvider(options, refresh: { image in
            self.base.setBackgroundImage(image, for: state)
        }) {
            options.onDataReceived = (options.onDataReceived ?? []) + [provider]
        }
        
        options.onDataReceived?.forEach {
            $0.onShouldApply = { issuedIdentifier == self.backgroundTaskIdentifier(for: state) }
        }
        
        let task = KingfisherManager.shared.retrieveImage(
            with: source,
            options: options,
            downloadTaskUpdated: { mutatingSelf.backgroundImageTask = $0 },
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
                    guard issuedIdentifier == self.backgroundTaskIdentifier(for: state) else {
                        let reason: KingfisherError.ImageSettingErrorReason
                        do {
                            let value = try result.get()
                            reason = .notCurrentSourceTask(result: value, error: nil, source: source)
                        } catch {
                            reason = .notCurrentSourceTask(result: nil, error: error, source: source)
                        }
                        let error = KingfisherError.imageSettingError(reason: reason)
                        completionHandler?(.failure(error))
                        return
                    }
                    
                    mutatingSelf.backgroundImageTask = nil
                    mutatingSelf.setBackgroundTaskIdentifier(nil, for: state)
                    
                    switch result {
                    case .success(let value):
                        self.base.setBackgroundImage(value.image, for: state)
                        completionHandler?(result)
                        
                    case .failure:
                        if let image = options.onFailureImage {
                            self.base.setBackgroundImage(image, for: state)
                        }
                        completionHandler?(result)
                    }
                }
            }
        )

        mutatingSelf.backgroundImageTask = task
        return task
    }

    @discardableResult
    public func setBackgroundImage(
        with resource: Resource?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        return setBackgroundImage(
            with: resource?.convertToSource(),
            for: state,
            placeholder: placeholder,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    public func cancelBackgroundImageDownloadTask() {
        backgroundImageTask?.cancel()
    }
}

// MARK: - 管理对象
private var taskIdentifierKey: Void?
private var imageTaskKey: Void?

// MARK: 属性
extension KingfisherWrapper where Base: UIButton {

    private typealias TaskIdentifier = Box<[UInt: Source.Identifier.Value]>
    
    public func taskIdentifier(for state: UIControl.State) -> Source.Identifier.Value? {
        return taskIdentifierInfo.value[state.rawValue]
    }

    private func setTaskIdentifier(_ identifier: Source.Identifier.Value?, for state: UIControl.State) {
        taskIdentifierInfo.value[state.rawValue] = identifier
    }
    
    private var taskIdentifierInfo: TaskIdentifier {
        return  getAssociatedObject(base, &taskIdentifierKey) ?? {
            setRetainedAssociatedObject(base, &taskIdentifierKey, $0)
            return $0
        } (TaskIdentifier([:]))
    }
    
    private var imageTask: DownloadTask? {
        get { return getAssociatedObject(base, &imageTaskKey) }
        set { setRetainedAssociatedObject(base, &imageTaskKey, newValue)}
    }
}


private var backgroundTaskIdentifierKey: Void?
private var backgroundImageTaskKey: Void?

// MARK: 背景属性
extension KingfisherWrapper where Base: UIButton {
    
    public func backgroundTaskIdentifier(for state: UIControl.State) -> Source.Identifier.Value? {
        return backgroundTaskIdentifierInfo.value[state.rawValue]
    }
    
    private func setBackgroundTaskIdentifier(_ identifier: Source.Identifier.Value?, for state: UIControl.State) {
        backgroundTaskIdentifierInfo.value[state.rawValue] = identifier
    }
    
    private var backgroundTaskIdentifierInfo: TaskIdentifier {
        return  getAssociatedObject(base, &backgroundTaskIdentifierKey) ?? {
            setRetainedAssociatedObject(base, &backgroundTaskIdentifierKey, $0)
            return $0
        } (TaskIdentifier([:]))
    }
    
    private var backgroundImageTask: DownloadTask? {
        get { return getAssociatedObject(base, &backgroundImageTaskKey) }
        mutating set { setRetainedAssociatedObject(base, &backgroundImageTaskKey, newValue) }
    }
}

#endif

#endif
