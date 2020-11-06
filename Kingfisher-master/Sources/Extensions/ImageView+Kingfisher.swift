
#if !os(watchOS)

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension KingfisherWrapper where Base: KFCrossPlatformImageView {

    @discardableResult
    public func setImage(with source: Source?,
                         placeholder: Placeholder? = nil,
                         options: KingfisherOptionsInfo? = nil,
                         progressBlock: DownloadProgressBlock? = nil,
                         completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask? {
        var mutatingSelf = self
        guard let source = source else {
            mutatingSelf.placeholder = placeholder
            mutatingSelf.taskIdentifier = nil
            completionHandler?(.failure(KingfisherError.imageSettingError(reason: .emptySource)))
            return nil
        }
        var options = KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions + (options ?? .empty))
        let isEmptyImage = base.image == nil && self.placeholder == nil
        if !options.keepCurrentImageWhileLoading || isEmptyImage {
            mutatingSelf.placeholder = placeholder  // 没设置站位图就设置一个
        }

        let maybeIndicator = indicator
        maybeIndicator?.startAnimatingView()

        let issuedIdentifier = Source.Identifier.next()
        mutatingSelf.taskIdentifier = issuedIdentifier

        if base.shouldPreloadAllAnimation() {
            options.preloadAllAnimationData = true
        }

        if let block = progressBlock {
            options.onDataReceived = (options.onDataReceived ?? []) + [ImageLoadingProgressSideEffect(block)]
        }

        if let provider = ImageProgressiveProvider(options, refresh: { image in
            self.base.image = image
        }) {
            options.onDataReceived = (options.onDataReceived ?? []) + [provider]
        }
        
        options.onDataReceived?.forEach {
            $0.onShouldApply = { issuedIdentifier == self.taskIdentifier }
        }

        let task = KingfisherManager.shared.retrieveImage(
            with: source,
            options: options,
            downloadTaskUpdated: { mutatingSelf.imageTask = $0 },
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
                    maybeIndicator?.stopAnimatingView()
                    guard issuedIdentifier == self.taskIdentifier else {
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
                    mutatingSelf.taskIdentifier = nil
                    
                    switch result {
                    case .success(let value):
                        guard self.needsTransition(options: options, cacheType: value.cacheType) else {
                            mutatingSelf.placeholder = nil
                            self.base.image = value.image
                            completionHandler?(result)
                            return
                        }
                        
                        self.makeTransition(image: value.image, transition: options.transition) {
                            completionHandler?(result)
                        }
                        
                    case .failure:
                        if let image = options.onFailureImage {
                            self.base.image = image
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
    public func setImage(with resource: Resource?,
                         placeholder: Placeholder? = nil,
                         options: KingfisherOptionsInfo? = nil,
                         progressBlock: DownloadProgressBlock? = nil,
                         completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask? {
        return setImage(
            with: resource?.convertToSource(),
            placeholder: placeholder,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    @discardableResult
    public func setImage(with provider: ImageDataProvider?,
                         placeholder: Placeholder? = nil,
                         options: KingfisherOptionsInfo? = nil,
                         progressBlock: DownloadProgressBlock? = nil,
                         completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask? {
        return setImage(
            with: provider.map { .provider($0) },
            placeholder: placeholder,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    public func cancelDownloadTask() {
        imageTask?.cancel()
    }

    private func needsTransition(options: KingfisherParsedOptionsInfo, cacheType: CacheType) -> Bool {
        switch options.transition {
        case .none:
            return false
        #if !os(macOS)
        default:
            if options.forceTransition { return true }
            if cacheType == .none { return true }
            return false
        #endif
        }
    }

    private func makeTransition(image: KFCrossPlatformImage, transition: ImageTransition, done: @escaping () -> Void) {
        #if !os(macOS)
        // Force hiding the indicator without transition first.
        UIView.transition(
            with: self.base,
            duration: 0.0,
            options: [],
            animations: { self.indicator?.stopAnimatingView() },
            completion: { _ in
                var mutatingSelf = self
                mutatingSelf.placeholder = nil
                UIView.transition(
                    with: self.base,
                    duration: transition.duration,
                    options: [transition.animationOptions, .allowUserInteraction],
                    animations: { transition.animations?(self.base, image) },
                    completion: { finished in
                        transition.completion?(finished)
                        done()
                    }
                )
            }
        )
        #else
        done()
        #endif
    }
}

// MARK: - 关联对象
private var taskIdentifierKey: Void?
private var indicatorKey: Void?
private var indicatorTypeKey: Void?
private var placeholderKey: Void?
private var imageTaskKey: Void?

extension KingfisherWrapper where Base: KFCrossPlatformImageView {

    public private(set) var taskIdentifier: Source.Identifier.Value? {
        get {
            let box: Box<Source.Identifier.Value>? = getAssociatedObject(base, &taskIdentifierKey)
            return box?.value
        }
        set {
            let box = newValue.map { Box($0) }
            setRetainedAssociatedObject(base, &taskIdentifierKey, box)
        }
    }

    /// Holds which indicator type is going to be used.
    /// Default is `.none`, means no indicator will be shown while downloading.
    public var indicatorType: IndicatorType {
        get {
            return getAssociatedObject(base, &indicatorTypeKey) ?? .none
        }
        
        set {
            switch newValue {
            case .none: indicator = nil
            case .activity: indicator = ActivityIndicator()
            case .image(let data): indicator = ImageIndicator(imageData: data)
            case .custom(let anIndicator): indicator = anIndicator
            }

            setRetainedAssociatedObject(base, &indicatorTypeKey, newValue)
        }
    }

    public private(set) var indicator: Indicator? {
        get {
            let box: Box<Indicator>? = getAssociatedObject(base, &indicatorKey)
            return box?.value
        }
        
        set {
            if let previousIndicator = indicator { //移除
                previousIndicator.view.removeFromSuperview()
            }
            if let newIndicator = newValue { //新加并且默认布局
                let view = newIndicator.view
                base.addSubview(view)
                view.translatesAutoresizingMaskIntoConstraints = false
                view.centerXAnchor.constraint(
                    equalTo: base.centerXAnchor, constant: newIndicator.centerOffset.x).isActive = true
                view.centerYAnchor.constraint(
                    equalTo: base.centerYAnchor, constant: newIndicator.centerOffset.y).isActive = true

                switch newIndicator.sizeStrategy(in: base) {
                case .intrinsicSize:
                    break
                case .full:
                    view.heightAnchor.constraint(equalTo: base.heightAnchor, constant: 0).isActive = true
                    view.widthAnchor.constraint(equalTo: base.widthAnchor, constant: 0).isActive = true
                case .size(let size):
                    view.heightAnchor.constraint(equalToConstant: size.height).isActive = true
                    view.widthAnchor.constraint(equalToConstant: size.width).isActive = true
                }
                
                newIndicator.view.isHidden = true
            }

            // Save in associated object
            // Wrap newValue with Box to workaround an issue that Swift does not recognize
            // and casting protocol for associate object correctly. https://github.com/onevcat/Kingfisher/issues/872
            setRetainedAssociatedObject(base, &indicatorKey, newValue.map(Box.init))
        }
    }
    
    private var imageTask: DownloadTask? {
        get { return getAssociatedObject(base, &imageTaskKey) }
        set { setRetainedAssociatedObject(base, &imageTaskKey, newValue)}
    }

    /// Represents the `Placeholder` used for this image view. A `Placeholder` will be shown in the view while
    /// it is downloading an image.
    public private(set) var placeholder: Placeholder? {
        get { return getAssociatedObject(base, &placeholderKey) }
        set {
            if let previousPlaceholder = placeholder {
                previousPlaceholder.remove(from: base)
            }
            
            if let newPlaceholder = newValue {
                newPlaceholder.add(to: base)
            } else {
                base.image = nil
            }
            setRetainedAssociatedObject(base, &placeholderKey, newValue)
        }
    }
}


extension KFCrossPlatformImageView {
    @objc func shouldPreloadAllAnimation() -> Bool { return true }
}

extension KingfisherWrapper where Base: KFCrossPlatformImageView {
    /// Gets the image URL bound to this image view.
    @available(*, deprecated, message: "Use `taskIdentifier` instead to identify a setting task.")
    public private(set) var webURL: URL? {
        get { return nil }
        set { }
    }
}

#endif
