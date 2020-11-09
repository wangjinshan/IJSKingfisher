
import Foundation

@objc(KFSessionDelegate) 
class SessionDelegate: NSObject {

    typealias SessionChallengeFunc = (
        URLSession,
        URLAuthenticationChallenge,
        (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )

    typealias SessionTaskChallengeFunc = (
        URLSession,
        URLSessionTask,
        URLAuthenticationChallenge,
        (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )

    private var tasks: [URL: SessionDataTask] = [:]
    private let lock = NSLock()

    let onValidStatusCode = Delegate<Int, Bool>()
    let onDownloadingFinished = Delegate<(URL, Result<URLResponse, KingfisherError>), Void>()
    let onDidDownloadData = Delegate<SessionDataTask, Data?>()

    let onReceiveSessionChallenge = Delegate<SessionChallengeFunc, Void>()
    let onReceiveSessionTaskChallenge = Delegate<SessionTaskChallengeFunc, Void>()

    func add( _ dataTask: URLSessionDataTask, url: URL, callback: SessionDataTask.TaskCallback) -> DownloadTask {
        lock.lock()
        defer { lock.unlock() }

        // 创建一个task
        let task = SessionDataTask(task: dataTask)
        task.onCallbackCancelled.delegate(on: self) { [weak task] (self, value) in
            guard let task = task else { return }
            let (token, callback) = value
            let error = KingfisherError.requestError(reason: .taskCancelled(task: task, token: token))
            task.onTaskDone.call((.failure(error), [callback]))
            if !task.containsCallbacks { // 没有callbacks等待则清理 task
                let dataTask = task.task
                self.cancelTask(dataTask)
                self.remove(task)
            }
        }
        let token = task.addCallback(callback)
        tasks[url] = task
        return DownloadTask(sessionTask: task, cancelToken: token)
    }

    private func cancelTask(_ dataTask: URLSessionDataTask) {
        lock.lock()
        defer { lock.unlock() }
        dataTask.cancel()
    }

    func append(_ task: SessionDataTask, url: URL, callback: SessionDataTask.TaskCallback) -> DownloadTask {
        let token = task.addCallback(callback)
        return DownloadTask(sessionTask: task, cancelToken: token)
    }

    private func remove(_ task: SessionDataTask) {
        lock.lock()
        defer { lock.unlock() }
        guard let url = task.originalURL else { return }
        tasks[url] = nil
    }

    private func task(for task: URLSessionTask) -> SessionDataTask? {
        lock.lock()
        defer { lock.unlock() }
        guard let url = task.originalRequest?.url else { return nil }
        guard let sessionTask = tasks[url] else { return nil }
        guard sessionTask.task.taskIdentifier == task.taskIdentifier else { return nil }
        return sessionTask
    }

    func task(for url: URL) -> SessionDataTask? {
        lock.lock()
        defer { lock.unlock() }
        return tasks[url]
    }

    func cancelAll() {
        lock.lock()
        let taskValues = tasks.values
        lock.unlock()
        for task in taskValues {
            task.forceCancel()
        }
    }

    func cancel(url: URL) {
        lock.lock()
        let task = tasks[url]
        lock.unlock()
        task?.forceCancel()
    }
}
// MARK: - URLSessionDataDelegate 下载数据的代理
extension SessionDelegate: URLSessionDataDelegate {
    //收到了相应头
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            let error = KingfisherError.responseError(reason: .invalidURLResponse(response: response))
            onCompleted(task: dataTask, result: .failure(error))
            completionHandler(.cancel)
            return
        }
        let httpStatusCode = httpResponse.statusCode
        guard onValidStatusCode.call(httpStatusCode) == true else {
            let error = KingfisherError.responseError(reason: .invalidHTTPStatusCode(response: httpResponse))
            onCompleted(task: dataTask, result: .failure(error))
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }
    // 开始接收到数据
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let task = self.task(for: dataTask) else { return }
        task.didReceiveData(data)
        task.callbacks.forEach { callback in
            callback.options.onDataReceived?.forEach { sideEffect in
                sideEffect.onDataReceived(session, task: task, data: data)
            }
        }
    }
    // 当task完成的时候调用
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let sessionTask = self.task(for: task) else { return }
        if let url = sessionTask.originalURL {
            let result: Result<URLResponse, KingfisherError>
            if let error = error {
                result = .failure(KingfisherError.responseError(reason: .URLSessionError(error: error)))
            } else if let response = task.response {
                result = .success(response)
            } else {
                result = .failure(KingfisherError.responseError(reason: .noURLResponse(task: sessionTask)))
            }
            onDownloadingFinished.call((url, result))
        }
        let result: Result<(Data, URLResponse?), KingfisherError>
        if let error = error {
            result = .failure(KingfisherError.responseError(reason: .URLSessionError(error: error)))
        } else {
            if let data = onDidDownloadData.call(sessionTask), let finalData = data {
                result = .success((finalData, task.response))
            } else {
                result = .failure(KingfisherError.responseError(reason: .dataModifyingFailed(task: sessionTask)))
            }
        }
        onCompleted(task: task, result: result)
    }
    //如果服务器要求验证客户端身份或向客户端提供其证书用于验证时，则会调用
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        onReceiveSessionChallenge.call((session, challenge, completionHandler))
    }
    //响应来自远程服务器的认证请求，从代理请求凭证
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        onReceiveSessionTaskChallenge.call((session, task, challenge, completionHandler))
    }
    //告诉委托远程服务器请求HTTP重定向
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let sessionDataTask = self.task(for: task),
              let redirectHandler = Array(sessionDataTask.callbacks).last?.options.redirectHandler else {
            completionHandler(request)
            return
        }
        redirectHandler.handleHTTPRedirection(for: sessionDataTask,response: response, newRequest: request, completionHandler: completionHandler)
    }

    private func onCompleted(task: URLSessionTask, result: Result<(Data, URLResponse?), KingfisherError>) {
        guard let sessionTask = self.task(for: task) else { return }
        remove(sessionTask)
        sessionTask.onTaskDone.call((result, sessionTask.callbacks))
    }
}
