
import Foundation

public enum CallbackQueue {
    case mainAsync
    case mainCurrentOrAsync
    case untouch
    case dispatch(DispatchQueue)

    public func execute(_ block: @escaping () -> Void) {
        switch self {
        case .mainAsync:
            DispatchQueue.main.async { block() }
        case .mainCurrentOrAsync:
            DispatchQueue.main.safeAsync { block() }
        case .untouch:
            block()
        case .dispatch(let queue):
            queue.async { block() }
        }
    }

    var queue: DispatchQueue {
        switch self {
        case .mainAsync: return .main
        case .mainCurrentOrAsync: return .main
        case .untouch: return OperationQueue.current?.underlyingQueue ?? .main
        case .dispatch(let queue): return queue
        }
    }
}

extension DispatchQueue {
    func safeAsync(_ block: @escaping ()->()) {
        if self === DispatchQueue.main && Thread.isMainThread {
            block()
        } else {
            async { block() }
        }
    }
}
