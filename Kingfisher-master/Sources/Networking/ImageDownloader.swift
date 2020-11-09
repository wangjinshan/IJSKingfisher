
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 下载结果
public struct ImageLoadingResult {
    public let image: KFCrossPlatformImage
    public let url: URL?
    public let originalData: Data
}

public struct DownloadTask {
    public let sessionTask: SessionDataTask
    public let cancelToken: SessionDataTask.CancelToken

    public func cancel() {
        sessionTask.cancel(token: cancelToken)
    }
}

extension DownloadTask {
    enum WrappedTask {
        case download(DownloadTask)
        case dataProviding

        func cancel() {
            switch self {
            case .download(let task): task.cancel()
            case .dataProviding: break
            }
        }

        var value: DownloadTask? {
            switch self {
            case .download(let task): return task
            case .dataProviding: return nil
            }
        }
    }
}

/// 下载器
open class ImageDownloader {

    public static let `default` = ImageDownloader(name: "default")

    open var downloadTimeout: TimeInterval = 15.0
    open var trustedHosts: Set<String>? //信任的请求地址，和自己实现请求代理设置冲突，二选一

    open var requestsUsePipelining = false //是否按顺序下载，第一个下载完成在下载下张图片
    open weak var delegate: ImageDownloaderDelegate?  // \\下信任请求代理，和trustedHosts冲突二选一
    open weak var authenticationChallengeResponder: AuthenticationChallengeResponsable?

    private let name: String
    private let sessionDelegate: SessionDelegate
    private var session: URLSession

    open var sessionConfiguration = URLSessionConfiguration.ephemeral {
        didSet {
            session.invalidateAndCancel()
            session = URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: nil)
        }
    }

    public init(name: String) {
        if name.isEmpty {
            fatalError("[Kingfisher] You should specify a name for the downloader. "
                + "A downloader with empty name is not permitted.")
        }
        self.name = name
        sessionDelegate = SessionDelegate()
        session = URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: nil)
        authenticationChallengeResponder = self
        setupSessionHandler()
    }

    deinit { session.invalidateAndCancel() }

    private func setupSessionHandler() {
        sessionDelegate.onReceiveSessionChallenge.delegate(on: self) { (self, invoke) in
            self.authenticationChallengeResponder?.downloader(self, didReceive: invoke.1, completionHandler: invoke.2)
        }
        sessionDelegate.onReceiveSessionTaskChallenge.delegate(on: self) { (self, invoke) in
            self.authenticationChallengeResponder?.downloader(
                self, task: invoke.1, didReceive: invoke.2, completionHandler: invoke.3)
        }
        sessionDelegate.onValidStatusCode.delegate(on: self) { (self, code) in
            return (self.delegate ?? self).isValidStatusCode(code, for: self)
        }
        sessionDelegate.onDownloadingFinished.delegate(on: self) { (self, value) in
            let (url, result) = value
            do {
                let value = try result.get()
                self.delegate?.imageDownloader(self, didFinishDownloadingImageForURL: url, with: value, error: nil)
            } catch {
                self.delegate?.imageDownloader(self, didFinishDownloadingImageForURL: url, with: nil, error: error)
            }
        }
        sessionDelegate.onDidDownloadData.delegate(on: self) { (self, task) in
            guard let url = task.originalURL else {
                return task.mutableData
            }
            return (self.delegate ?? self).imageDownloader(self, didDownload: task.mutableData, for: url)
        }
    }

    @discardableResult
    open func downloadImage(with url: URL, options: KingfisherParsedOptionsInfo, completionHandler: ((Result<ImageLoadingResult, KingfisherError>) -> Void)? = nil) -> DownloadTask? {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: downloadTimeout)
        request.httpShouldUsePipelining = requestsUsePipelining

        if let requestModifier = options.requestModifier { // 请求头自定义参数验签
            guard let r = requestModifier.modified(for: request) else {
                options.callbackQueue.execute {
                    completionHandler?(.failure(KingfisherError.requestError(reason: .emptyRequest)))
                }
                return nil
            }
            request = r
        }

        guard let url = request.url, !url.absoluteString.isEmpty else { // url 判空
            options.callbackQueue.execute {
                completionHandler?(.failure(KingfisherError.requestError(reason: .invalidURL(request: request))))
            }
            return nil
        }

        // 把 completionHandler 包装成 onCompleted
        let onCompleted = completionHandler.map { (block) -> Delegate<Result<ImageLoadingResult, KingfisherError>, Void> in
            let delegate =  Delegate<Result<ImageLoadingResult, KingfisherError>, Void>()
            delegate.delegate(on: self) { (_, callback) in
                block(callback)
            }
            return delegate
        }
        let callback = SessionDataTask.TaskCallback(onCompleted: onCompleted, options: options)

        // 开始下载, 让 session task的sessionHandler 去管理
        let downloadTask: DownloadTask
        if let existingTask = sessionDelegate.task(for: url) {
            downloadTask = sessionDelegate.append(existingTask, url: url, callback: callback)
        } else {
            let sessionDataTask = session.dataTask(with: request)
            sessionDataTask.priority = options.downloadPriority
            downloadTask = sessionDelegate.add(sessionDataTask, url: url, callback: callback)
        }

        let sessionTask = downloadTask.sessionTask

        if !sessionTask.started { // 未开始
            sessionTask.onTaskDone.delegate(on: self) { (self, done) in
                // Underlying downloading finishes.
                // result: Result<(Data, URLResponse?)>, callbacks: [TaskCallback]
                let (result, callbacks) = done

                // Before processing the downloaded data.
                do {
                    let value = try result.get()
                    self.delegate?.imageDownloader(
                        self,
                        didFinishDownloadingImageForURL: url,
                        with: value.1,
                        error: nil
                    )
                } catch {
                    self.delegate?.imageDownloader(
                        self,
                        didFinishDownloadingImageForURL: url,
                        with: nil,
                        error: error
                    )
                }

                switch result {
                // Download finished. Now process the data to an image.
                case .success(let (data, response)):
                    let processor = ImageDataProcessor(
                        data: data, callbacks: callbacks, processingQueue: options.processingQueue)
                    processor.onImageProcessed.delegate(on: self) { (self, result) in
                        // `onImageProcessed` will be called for `callbacks.count` times, with each
                        // `SessionDataTask.TaskCallback` as the input parameter.
                        // result: Result<Image>, callback: SessionDataTask.TaskCallback
                        let (result, callback) = result

                        if let image = try? result.get() {
                            self.delegate?.imageDownloader(self, didDownload: image, for: url, with: response)
                        }

                        let imageResult = result.map { ImageLoadingResult(image: $0, url: url, originalData: data) }
                        let queue = callback.options.callbackQueue
                        queue.execute { callback.onCompleted?.call(imageResult) }
                    }
                    processor.process()

                case .failure(let error):
                    callbacks.forEach { callback in
                        let queue = callback.options.callbackQueue
                        queue.execute { callback.onCompleted?.call(.failure(error)) }
                    }
                }
            }
            delegate?.imageDownloader(self, willDownloadImageForURL: url, with: request)
            sessionTask.resume()
        }
        return downloadTask
    }

    @discardableResult
    open func downloadImage(with url: URL, options: KingfisherOptionsInfo? = nil, progressBlock: DownloadProgressBlock? = nil, completionHandler: ((Result<ImageLoadingResult, KingfisherError>) -> Void)? = nil) -> DownloadTask? {
        var info = KingfisherParsedOptionsInfo(options)
        if let block = progressBlock {
            info.onDataReceived = (info.onDataReceived ?? []) + [ImageLoadingProgressSideEffect(block)]
        }
        return downloadImage(with: url, options: info, completionHandler: completionHandler)
    }
}

// MARK: 取消 Task
extension ImageDownloader {

    public func cancelAll() {
        sessionDelegate.cancelAll()
    }

    public func cancel(url: URL) {
        sessionDelegate.cancel(url: url)
    }
}
// MARK: 准守协议
extension ImageDownloader: AuthenticationChallengeResponsable {}
extension ImageDownloader: ImageDownloaderDelegate {}
