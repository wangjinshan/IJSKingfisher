
import Foundation

extension Never {}

public enum KingfisherError: Error {

    public enum RequestErrorReason {
        case emptyRequest
        case invalidURL(request: URLRequest)
        case taskCancelled(task: SessionDataTask, token: SessionDataTask.CancelToken)
    }

    public enum ResponseErrorReason {
        case invalidURLResponse(response: URLResponse)
        case invalidHTTPStatusCode(response: HTTPURLResponse)
        case URLSessionError(error: Error)
        case dataModifyingFailed(task: SessionDataTask)
        case noURLResponse(task: SessionDataTask)
    }

    public enum CacheErrorReason {
        case fileEnumeratorCreationFailed(url: URL)
        case invalidFileEnumeratorContent(url: URL)
        case invalidURLResource(error: Error, key: String, url: URL)
        case cannotLoadDataFromDisk(url: URL, error: Error)
        case cannotCreateDirectory(path: String, error: Error)
        case imageNotExisting(key: String)
        case cannotConvertToData(object: Any, error: Error)
        case cannotSerializeImage(image: KFCrossPlatformImage?, original: Data?, serializer: CacheSerializer)
        case cannotCreateCacheFile(fileURL: URL, key: String, data: Data, error: Error)
        case cannotSetCacheFileAttribute(filePath: String, attributes: [FileAttributeKey : Any], error: Error)
    }

    public enum ProcessorErrorReason {
        case processingFailed(processor: ImageProcessor, item: ImageProcessItem)
    }

    public enum ImageSettingErrorReason {
        case emptySource
        case notCurrentSourceTask(result: RetrieveImageResult?, error: Error?, source: Source)
        case dataProviderError(provider: ImageDataProvider, error: Error)
        case alternativeSourcesExhausted([PropagationError])
    }

    case requestError(reason: RequestErrorReason)
    case responseError(reason: ResponseErrorReason)
    case cacheError(reason: CacheErrorReason)
    case processorError(reason: ProcessorErrorReason)
    case imageSettingError(reason: ImageSettingErrorReason)

    public var isTaskCancelled: Bool {
        if case .requestError(reason: .taskCancelled) = self {
            return true
        }
        return false
    }

    public func isInvalidResponseStatusCode(_ code: Int) -> Bool {
        if case .responseError(reason: .invalidHTTPStatusCode(let response)) = self {
            return response.statusCode == code
        }
        return false
    }

    public var isInvalidResponseStatusCode: Bool {
        if case .responseError(reason: .invalidHTTPStatusCode) = self {
            return true
        }
        return false
    }

    public var isNotCurrentTask: Bool {
        if case .imageSettingError(reason: .notCurrentSourceTask(_, _, _)) = self {
            return true
        }
        return false
    }
}

// MARK: - KingfisherError
extension KingfisherError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .requestError(let reason): return reason.errorDescription
        case .responseError(let reason): return reason.errorDescription
        case .cacheError(let reason): return reason.errorDescription
        case .processorError(let reason): return reason.errorDescription
        case .imageSettingError(let reason): return reason.errorDescription
        }
    }
}

// MARK: - Conforming
extension KingfisherError: CustomNSError {

    public static let domain = "com.onevcat.Kingfisher.Error"

    public var errorCode: Int {
        switch self {
        case .requestError(let reason): return reason.errorCode
        case .responseError(let reason): return reason.errorCode
        case .cacheError(let reason): return reason.errorCode
        case .processorError(let reason): return reason.errorCode
        case .imageSettingError(let reason): return reason.errorCode
        }
    }
}

extension KingfisherError.RequestErrorReason {
    var errorDescription: String? {
        switch self {
        case .emptyRequest:
            return "The request is empty or `nil`."
        case .invalidURL(let request):
            return "The request contains an invalid or empty URL. Request: \(request)."
        case .taskCancelled(let task, let token):
            return "The session task was cancelled. Task: \(task), cancel token: \(token)."
        }
    }
    
    var errorCode: Int {
        switch self {
        case .emptyRequest: return 1001
        case .invalidURL: return 1002
        case .taskCancelled: return 1003
        }
    }
}

extension KingfisherError.ResponseErrorReason {
    var errorDescription: String? {
        switch self {
        case .invalidURLResponse(let response):
            return "The URL response is invalid: \(response)"
        case .invalidHTTPStatusCode(let response):
            return "The HTTP status code in response is invalid. Code: \(response.statusCode), response: \(response)."
        case .URLSessionError(let error):
            return "A URL session error happened. The underlying error: \(error)"
        case .dataModifyingFailed(let task):
            return "The data modifying delegate returned `nil` for the downloaded data. Task: \(task)."
        case .noURLResponse(let task):
            return "No URL response received. Task: \(task),"
        }
    }
    
    var errorCode: Int {
        switch self {
        case .invalidURLResponse: return 2001
        case .invalidHTTPStatusCode: return 2002
        case .URLSessionError: return 2003
        case .dataModifyingFailed: return 2004
        case .noURLResponse: return 2005
        }
    }
}

extension KingfisherError.CacheErrorReason {
    var errorDescription: String? {
        switch self {
        case .fileEnumeratorCreationFailed(let url):
            return "Cannot create file enumerator for URL: \(url)."
        case .invalidFileEnumeratorContent(let url):
            return "Cannot get contents from the file enumerator at URL: \(url)."
        case .invalidURLResource(let error, let key, let url):
            return "Cannot get URL resource values or data for the given URL: \(url). " +
                   "Cache key: \(key). Underlying error: \(error)"
        case .cannotLoadDataFromDisk(let url, let error):
            return "Cannot load data from disk at URL: \(url). Underlying error: \(error)"
        case .cannotCreateDirectory(let path, let error):
            return "Cannot create directory at given path: Path: \(path). Underlying error: \(error)"
        case .imageNotExisting(let key):
            return "The image is not in cache, but you requires it should only be " +
                   "from cache by enabling the `.onlyFromCache` option. Key: \(key)."
        case .cannotConvertToData(let object, let error):
            return "Cannot convert the input object to a `Data` object when storing it to disk cache. " +
                   "Object: \(object). Underlying error: \(error)"
        case .cannotSerializeImage(let image, let originalData, let serializer):
            return "Cannot serialize an image due to the cache serializer returning `nil`. " +
                   "Image: \(String(describing:image)), original data: \(String(describing: originalData)), " +
                   "serializer: \(serializer)."
        case .cannotCreateCacheFile(let fileURL, let key, let data, let error):
            return "Cannot create cache file at url: \(fileURL), key: \(key), data length: \(data.count). " +
                   "Underlying foundation error: \(error)."
        case .cannotSetCacheFileAttribute(let filePath, let attributes, let error):
            return "Cannot set file attribute for the cache file at path: \(filePath), attributes: \(attributes)." +
                   "Underlying foundation error: \(error)."
        }
    }
    
    var errorCode: Int {
        switch self {
        case .fileEnumeratorCreationFailed: return 3001
        case .invalidFileEnumeratorContent: return 3002
        case .invalidURLResource: return 3003
        case .cannotLoadDataFromDisk: return 3004
        case .cannotCreateDirectory: return 3005
        case .imageNotExisting: return 3006
        case .cannotConvertToData: return 3007
        case .cannotSerializeImage: return 3008
        case .cannotCreateCacheFile: return 3009
        case .cannotSetCacheFileAttribute: return 3010
        }
    }
}

extension KingfisherError.ProcessorErrorReason {
    var errorDescription: String? {
        switch self {
        case .processingFailed(let processor, let item):
            return "Processing image failed. Processor: \(processor). Processing item: \(item)."
        }
    }
    
    var errorCode: Int {
        switch self {
        case .processingFailed: return 4001
        }
    }
}

extension KingfisherError.ImageSettingErrorReason {
    var errorDescription: String? {
        switch self {
        case .emptySource:
            return "The input resource is empty."
        case .notCurrentSourceTask(let result, let error, let resource):
            if let result = result {
                return "Retrieving resource succeeded, but this source is " +
                       "not the one currently expected. Result: \(result). Resource: \(resource)."
            } else if let error = error {
                return "Retrieving resource failed, and this resource is " +
                       "not the one currently expected. Error: \(error). Resource: \(resource)."
            } else {
                return nil
            }
        case .dataProviderError(let provider, let error):
            return "Image data provider fails to provide data. Provider: \(provider), error: \(error)"
        case .alternativeSourcesExhausted(let errors):
            return "Image setting from alternaive sources failed: \(errors)"
        }
    }
    
    var errorCode: Int {
        switch self {
        case .emptySource: return 5001
        case .notCurrentSourceTask: return 5002
        case .dataProviderError: return 5003
        case .alternativeSourcesExhausted: return 5004
        }
    }
}
