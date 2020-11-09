
import Foundation

/// 管理每个要进行下载的URLSessionDataTask；接收下载的数据；取消下载任务时，同时取消对应的回调
public class SessionDataTask {

    public typealias CancelToken = Int

    public let task: URLSessionDataTask
    let originalURL: URL?
    private let lock = NSLock()

    let onTaskDone = Delegate<(Result<(Data, URLResponse?), KingfisherError>, [TaskCallback]), Void>()
    let onCallbackCancelled = Delegate<(CancelToken, TaskCallback), Void>()

    private var callbacksStore = [CancelToken: TaskCallback]()
    private var currentToken = 0
    public private(set) var mutableData: Data  //raw data 当前任务下载的数据
    var started = false

    struct TaskCallback {
        let onCompleted: Delegate<Result<ImageLoadingResult, KingfisherError>, Void>?
        let options: KingfisherParsedOptionsInfo
    }

    var callbacks: [SessionDataTask.TaskCallback] {
        lock.lock()
        defer { lock.unlock() }
        return Array(callbacksStore.values)
    }

    var containsCallbacks: Bool {
        return !callbacks.isEmpty
    }

    init(task: URLSessionDataTask) {
        self.task = task
        self.originalURL = task.originalRequest?.url
        mutableData = Data()
    }

    func addCallback(_ callback: TaskCallback) -> CancelToken {
        lock.lock()
        defer { lock.unlock() }
        callbacksStore[currentToken] = callback
        defer { currentToken += 1 } //后面的defer先执行
        return currentToken
    }

    func removeCallback(_ token: CancelToken) -> TaskCallback? {
        lock.lock()
        defer { lock.unlock() }
        if let callback = callbacksStore[token] {
            callbacksStore[token] = nil
            return callback
        }
        return nil
    }

    func resume() {
        guard !started else { return }
        started = true
        task.resume()
    }

    func cancel(token: CancelToken) {
        guard let callback = removeCallback(token) else { return }
        onCallbackCancelled.call((token, callback))
    }

    func forceCancel() {
        for token in callbacksStore.keys {
            cancel(token: token)
        }
    }

    func didReceiveData(_ data: Data) {
        mutableData.append(data)
    }
}
