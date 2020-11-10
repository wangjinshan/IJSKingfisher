
import Foundation

#if swift(>=4.3)
#else

public enum Result<Success, Failure> {
    case success(Success)
    case failure(Failure)

    public func map<NewSuccess>(
        _ transform: (Success) -> NewSuccess
        ) -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return .success(transform(success))
        case let .failure(failure):
            return .failure(failure)
        }
    }

    public func mapError<NewFailure>(
        _ transform: (Failure) -> NewFailure
        ) -> Result<Success, NewFailure> {
        switch self {
        case let .success(success):
            return .success(success)
        case let .failure(failure):
            return .failure(transform(failure))
        }
    }

    public func flatMap<NewSuccess>(
        _ transform: (Success) -> Result<NewSuccess, Failure>
        ) -> Result<NewSuccess, Failure> {
        switch self {
        case let .success(success):
            return transform(success)
        case let .failure(failure):
            return .failure(failure)
        }
    }

    public func flatMapError<NewFailure>(
        _ transform: (Failure) -> Result<Success, NewFailure>
        ) -> Result<Success, NewFailure> {
        switch self {
        case let .success(success):
            return .success(success)
        case let .failure(failure):
            return transform(failure)
        }
    }
}

extension Result where Failure: Error {
    public func get() throws -> Success {
        switch self {
        case let .success(success):
            return success
        case let .failure(failure):
            throw failure
        }
    }
}

extension Result where Failure == Swift.Error {
    @_transparent
    public init(catching body: () throws -> Success) {
        do {
            self = .success(try body())
        } catch {
            self = .failure(error)
        }
    }
}

extension Result : Equatable where Success : Equatable, Failure: Equatable { }

extension Result : Hashable where Success : Hashable, Failure : Hashable { }

extension Result : CustomDebugStringConvertible {
    public var debugDescription: String {
        var output = "Result."
        switch self {
        case let .success(value):
            output += "success("
            debugPrint(value, terminator: "", to: &output)
        case let .failure(error):
            output += "failure("
            debugPrint(error, terminator: "", to: &output)
        }
        output += ")"

        return output
    }
}
#endif

extension Result where Failure: Error {
    
    func match<Output>(onSuccess: (Success) -> Output, onFailure: (Failure) -> Output) -> Output {
        switch self {
        case let .success(value):
            return onSuccess(value)
        case let .failure(error):
            return onFailure(error)
        }
    }

    func matchSuccess<Output>(with folder: (Success?) -> Output) -> Output {
        return match(
            onSuccess: { value in return folder(value) },
            onFailure: { _ in return folder(nil) }
        )
    }

    func matchFailure<Output>(with folder: (Error?) -> Output) -> Output {
        return match(
            onSuccess: { _ in return folder(nil) },
            onFailure: { error in return folder(error) }
        )
    }

    func match<Output>(with folder: (Success?, Error?) -> Output) -> Output {
        return match(
            onSuccess: { return folder($0, nil) },
            onFailure: { return folder(nil, $0) }
        )
    }
}
