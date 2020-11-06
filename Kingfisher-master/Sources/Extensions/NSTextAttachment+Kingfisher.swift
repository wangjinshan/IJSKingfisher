
#if !os(watchOS)

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension KingfisherWrapper where Base: NSTextAttachment {
    
    @discardableResult
    public func setImage(
        with source: Source?,
        attributedView: KFCrossPlatformView,
        placeholder: KFCrossPlatformImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        var mutatingSelf = self
        guard let source = source else {
            base.image = placeholder
            mutatingSelf.taskIdentifier = nil
            completionHandler?(.failure(KingfisherError.imageSettingError(reason: .emptySource)))
            return nil
        }

        var options = KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions + (options ?? .empty))
        if !options.keepCurrentImageWhileLoading {
            base.image = placeholder
        }

        let issuedIdentifier = Source.Identifier.next()
        mutatingSelf.taskIdentifier = issuedIdentifier

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
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
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
                            self.base.image = value.image
                            #if canImport(UIKit)
                            attributedView.setNeedsDisplay()
                            #else
                            attributedView.setNeedsDisplay(attributedView.bounds)
                            #endif
                        case .failure:
                            if let image = options.onFailureImage {
                                self.base.image = image
                            }
                    }
                    completionHandler?(result)
                }
            }
        )

        mutatingSelf.imageTask = task
        return task
    }

    @discardableResult
    public func setImage(
        with resource: Resource?,
        attributedView: KFCrossPlatformView,
        placeholder: KFCrossPlatformImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        return setImage(
            with: resource.map { .network($0) },
            attributedView: attributedView,
            placeholder: placeholder,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    public func cancelDownloadTask() {
        imageTask?.cancel()
    }
}

private var taskIdentifierKey: Void?
private var imageTaskKey: Void?

// MARK: 属性
extension KingfisherWrapper where Base: NSTextAttachment {

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

    private var imageTask: DownloadTask? {
        get { return getAssociatedObject(base, &imageTaskKey) }
        set { setRetainedAssociatedObject(base, &imageTaskKey, newValue)}
    }
}

#endif
