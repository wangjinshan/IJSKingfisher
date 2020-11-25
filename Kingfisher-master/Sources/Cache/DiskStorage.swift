
import Foundation

/// 磁盘存储
public enum DiskStorage {

    public class Backend<T: DataTransformable> {
        public var config: Config
        public let directoryURL: URL  //写入文件所在的文件夹，默认在cache文件夹里
        let metaChangingQueue: DispatchQueue  //修改文件原信息时，所在的队列

        var maybeCached : Set<String>?
        let maybeCachedCheckingQueue = DispatchQueue(label: "com.onevcat.Kingfisher.maybeCachedCheckingQueue")

        public init(config: Config) throws {
            self.config = config
            let url: URL
            if let directory = config.directory {
                url = directory
            } else {
                url = try config.fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            }

            let cacheName = "com.onevcat.Kingfisher.ImageCache.\(config.name)"
            directoryURL = config.cachePathBlock(url, cacheName)
            metaChangingQueue = DispatchQueue(label: cacheName)
            try prepareDirectory()
            maybeCachedCheckingQueue.async {
                do {
                    self.maybeCached = Set()
                    try config.fileManager.contentsOfDirectory(atPath: self.directoryURL.path).forEach { fileName in
                        self.maybeCached?.insert(fileName)
                    }
                } catch {
                    self.maybeCached = nil //初始化失败直接禁用,恢复到检查文件是否存在的状态
                }
            }
        }

        //该方法会在init着调用，保证directoryURLs文件夹，已经被创建过了
        func prepareDirectory() throws {
            let fileManager = config.fileManager
            let path = directoryURL.path
            guard !fileManager.fileExists(atPath: path) else { return }
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw KingfisherError.cacheError(reason: .cannotCreateDirectory(path: path, error: error))
            }
        }
        // MARK: 缓存数据到沙盒
        func store(value: T, forKey key: String, expiration: StorageExpiration? = nil) throws {
            let expiration = expiration ?? config.expiration
            guard !expiration.isExpired else { return } // 如果已经过期不需要缓存
            let data: Data
            do {
                data = try value.toData()
            } catch {
                throw KingfisherError.cacheError(reason: .cannotConvertToData(object: value, error: error))
            }
            let fileURL = cacheFileURL(forKey: key)
            do {
                try data.write(to: fileURL)
            } catch {
                throw KingfisherError.cacheError(reason: .cannotCreateCacheFile(fileURL: fileURL, key: key, data: data, error: error))
            }
            let now = Date()
            let attributes: [FileAttributeKey : Any] = [
                .creationDate: now.fileAttributeDate, //更新创建时间
                .modificationDate: expiration.estimatedExpirationSinceNow.fileAttributeDate  //更新修改日期
            ]
            do {
                try config.fileManager.setAttributes(attributes, ofItemAtPath: fileURL.path)
            } catch {
                try? config.fileManager.removeItem(at: fileURL)
                throw KingfisherError.cacheError(reason: .cannotSetCacheFileAttribute(filePath: fileURL.path, attributes: attributes, error: error)
                )
            }
            maybeCachedCheckingQueue.async {
                self.maybeCached?.insert(fileURL.lastPathComponent)
            }
        }

        func value(forKey key: String, extendingExpiration: ExpirationExtending = .cacheTime) throws -> T? {
            return try value(forKey: key, referenceDate: Date(), actuallyLoad: true, extendingExpiration: extendingExpiration)
        }

        func value(forKey key: String, referenceDate: Date, actuallyLoad: Bool, extendingExpiration: ExpirationExtending) throws -> T? {
            let fileManager = config.fileManager
            let fileURL = cacheFileURL(forKey: key)
            let filePath = fileURL.path

            let fileMaybeCached = maybeCachedCheckingQueue.sync {
                return maybeCached?.contains(fileURL.lastPathComponent) ?? true
            }
            guard fileMaybeCached else { return nil }
            guard fileManager.fileExists(atPath: filePath) else { return nil }
            let meta: FileMeta
            do {
                let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .creationDateKey]
                meta = try FileMeta(fileURL: fileURL, resourceKeys: resourceKeys)
            } catch {
                throw KingfisherError.cacheError(
                    reason: .invalidURLResource(error: error, key: key, url: fileURL))
            }

            if meta.expired(referenceDate: referenceDate) {
                return nil
            }
            if !actuallyLoad { return T.empty }

            do {
                let data = try Data(contentsOf: fileURL)
                let obj = try T.fromData(data)
                metaChangingQueue.async {
                    meta.extendExpiration(with: fileManager, extendingExpiration: extendingExpiration)
                }
                return obj
            } catch {
                throw KingfisherError.cacheError(reason: .cannotLoadDataFromDisk(url: fileURL, error: error))
            }
        }

        func isCached(forKey key: String) -> Bool {
            return isCached(forKey: key, referenceDate: Date())
        }

        func isCached(forKey key: String, referenceDate: Date) -> Bool {
            do {
                let result = try value(forKey: key, referenceDate: referenceDate, actuallyLoad: false, extendingExpiration: .none)
                return result != nil
            } catch {
                return false
            }
        }

        func remove(forKey key: String) throws {
            let fileURL = cacheFileURL(forKey: key)
            try removeFile(at: fileURL)
        }

        func removeFile(at url: URL) throws {
            try config.fileManager.removeItem(at: url)
        }

        func removeAll() throws {
            try removeAll(skipCreatingDirectory: false)
        }

        func removeAll(skipCreatingDirectory: Bool) throws {
            try config.fileManager.removeItem(at: directoryURL)
            if !skipCreatingDirectory {
                try prepareDirectory()
            }
        }
        // MARK: 文件沙盒的地址
        public func cacheFileURL(forKey key: String) -> URL {
            let fileName = cacheFileName(forKey: key)
            return directoryURL.appendingPathComponent(fileName, isDirectory: false)
        }

        func cacheFileName(forKey key: String) -> String {
            if config.usesHashedFileName {
                let hashedKey = key.kf.md5
                if let ext = config.pathExtension {
                    return "\(hashedKey).\(ext)"
                }
                return hashedKey
            } else {
                if let ext = config.pathExtension {
                    return "\(key).\(ext)"
                }
                return key
            }
        }

        func allFileURLs(for propertyKeys: [URLResourceKey]) throws -> [URL] {
            let fileManager = config.fileManager

            guard let directoryEnumerator = fileManager.enumerator(
                at: directoryURL, includingPropertiesForKeys: propertyKeys, options: .skipsHiddenFiles) else
            {
                throw KingfisherError.cacheError(reason: .fileEnumeratorCreationFailed(url: directoryURL))
            }

            guard let urls = directoryEnumerator.allObjects as? [URL] else {
                throw KingfisherError.cacheError(reason: .invalidFileEnumeratorContent(url: directoryURL))
            }
            return urls
        }

        func removeExpiredValues(referenceDate: Date = Date()) throws -> [URL] {
            let propertyKeys: [URLResourceKey] = [
                .isDirectoryKey,
                .contentModificationDateKey
            ]

            let urls = try allFileURLs(for: propertyKeys)
            let keys = Set(propertyKeys)
            let expiredFiles = urls.filter { fileURL in
                do {
                    let meta = try FileMeta(fileURL: fileURL, resourceKeys: keys)
                    if meta.isDirectory {
                        return false
                    }
                    return meta.expired(referenceDate: referenceDate)
                } catch {
                    return true
                }
            }
            try expiredFiles.forEach { url in
                try removeFile(at: url)
            }
            return expiredFiles
        }

        func removeSizeExceededValues() throws -> [URL] {

            if config.sizeLimit == 0 { return [] } // Back compatible. 0 means no limit.

            var size = try totalSize()
            if size < config.sizeLimit { return [] }

            let propertyKeys: [URLResourceKey] = [
                .isDirectoryKey,
                .creationDateKey,
                .fileSizeKey
            ]
            let keys = Set(propertyKeys)

            let urls = try allFileURLs(for: propertyKeys)
            var pendings: [FileMeta] = urls.compactMap { fileURL in
                guard let meta = try? FileMeta(fileURL: fileURL, resourceKeys: keys) else {
                    return nil
                }
                return meta
            }
            // Sort by last access date. Most recent file first.
            pendings.sort(by: FileMeta.lastAccessDate)

            var removed: [URL] = []
            let target = config.sizeLimit / 2
            while size > target, let meta = pendings.popLast() {
                size -= UInt(meta.fileSize)
                try removeFile(at: meta.url)
                removed.append(meta.url)
            }
            return removed
        }

        /// Get the total file size of the folder in bytes.
        func totalSize() throws -> UInt {
            let propertyKeys: [URLResourceKey] = [.fileSizeKey]
            let urls = try allFileURLs(for: propertyKeys)
            let keys = Set(propertyKeys)
            let totalSize: UInt = urls.reduce(0) { size, fileURL in
                do {
                    let meta = try FileMeta(fileURL: fileURL, resourceKeys: keys)
                    return size + UInt(meta.fileSize)
                } catch {
                    return size
                }
            }
            return totalSize
        }
    }
}

extension DiskStorage {
    /// 磁盘缓存配置
    public struct Config {
        public var sizeLimit: UInt
        public var expiration: StorageExpiration = .days(7)
        public var pathExtension: String? = nil
        public var usesHashedFileName = true

        let name: String
        let fileManager: FileManager
        let directory: URL?

        var cachePathBlock: ((_ directory: URL, _ cacheName: String) -> URL)! = { (directory, cacheName) in
            return directory.appendingPathComponent(cacheName, isDirectory: true)
        }

        public init(name: String, sizeLimit: UInt, fileManager: FileManager = .default, directory: URL? = nil) {
            self.name = name
            self.fileManager = fileManager
            self.directory = directory
            self.sizeLimit = sizeLimit
        }
    }
}

extension DiskStorage {
    struct FileMeta {
        let url: URL
        let lastAccessDate: Date?
        let estimatedExpirationDate: Date?
        let isDirectory: Bool
        let fileSize: Int
        
        static func lastAccessDate(lhs: FileMeta, rhs: FileMeta) -> Bool {
            return lhs.lastAccessDate ?? .distantPast > rhs.lastAccessDate ?? .distantPast
        }
        
        init(fileURL: URL, resourceKeys: Set<URLResourceKey>) throws {
            let meta = try fileURL.resourceValues(forKeys: resourceKeys)
            self.init(fileURL: fileURL, lastAccessDate: meta.creationDate, estimatedExpirationDate: meta.contentModificationDate,
                isDirectory: meta.isDirectory ?? false, fileSize: meta.fileSize ?? 0)
        }
        
        init(fileURL: URL, lastAccessDate: Date?, estimatedExpirationDate: Date?, isDirectory: Bool, fileSize: Int) {
            self.url = fileURL
            self.lastAccessDate = lastAccessDate
            self.estimatedExpirationDate = estimatedExpirationDate
            self.isDirectory = isDirectory
            self.fileSize = fileSize
        }

        func expired(referenceDate: Date) -> Bool {
            return estimatedExpirationDate?.isPast(referenceDate: referenceDate) ?? true
        }
        
        func extendExpiration(with fileManager: FileManager, extendingExpiration: ExpirationExtending) {
            guard let lastAccessDate = lastAccessDate,
                  let lastEstimatedExpiration = estimatedExpirationDate else { return }

            let attributes: [FileAttributeKey : Any]

            switch extendingExpiration {
            case .none:
                // not extending expiration time here
                return
            case .cacheTime:
                let originalExpiration: StorageExpiration =
                    .seconds(lastEstimatedExpiration.timeIntervalSince(lastAccessDate))
                attributes = [
                    .creationDate: Date().fileAttributeDate,
                    .modificationDate: originalExpiration.estimatedExpirationSinceNow.fileAttributeDate
                ]
            case .expirationTime(let expirationTime):
                attributes = [
                    .creationDate: Date().fileAttributeDate,
                    .modificationDate: expirationTime.estimatedExpirationSinceNow.fileAttributeDate
                ]
            }
            try? fileManager.setAttributes(attributes, ofItemAtPath: url.path)
        }
    }
}

