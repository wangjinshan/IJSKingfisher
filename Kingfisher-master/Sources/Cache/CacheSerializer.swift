
import Foundation
import CoreGraphics

/// 序列化
public protocol CacheSerializer {
    func data(with image: KFCrossPlatformImage, original: Data?) -> Data?
    func image(with data: Data, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage?
}

extension CacheSerializer {
    public func image(with data: Data, options: KingfisherOptionsInfo?) -> KFCrossPlatformImage? {
        return image(with: data, options: KingfisherParsedOptionsInfo(options))
    }
}

/// 默认序列化
public struct DefaultCacheSerializer: CacheSerializer {

    public static let `default` = DefaultCacheSerializer()
    public var compressionQuality: CGFloat = 1.0  //压缩比
    public var preferCacheOriginalData: Bool = false  //是否将源数据序列化

    public init() { }

    // MARK: 将image -> Data
    public func data(with image: KFCrossPlatformImage, original: Data?) -> Data? {
        if preferCacheOriginalData {
            return original ?? image.kf.data(format: original?.kf.imageFormat ?? .unknown, compressionQuality: compressionQuality)
        } else {
            return image.kf.data(format: original?.kf.imageFormat ?? .unknown, compressionQuality: compressionQuality)
        }
    }

    // MARK: 序列化 Data -> Image
    public func image(with data: Data, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        return KingfisherWrapper.image(data: data, options: options.imageCreatingOptions)
    }
}
