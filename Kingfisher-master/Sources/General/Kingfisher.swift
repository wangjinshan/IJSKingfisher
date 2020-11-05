
import Foundation
import ImageIO

#if os(macOS)
import AppKit
public typealias KFCrossPlatformImage = NSImage
public typealias KFCrossPlatformView = NSView
public typealias KFCrossPlatformColor = NSColor
public typealias KFCrossPlatformImageView = NSImageView
public typealias KFCrossPlatformButton = NSButton
#else
import UIKit
public typealias KFCrossPlatformImage = UIImage
public typealias KFCrossPlatformColor = UIColor
#if !os(watchOS)
public typealias KFCrossPlatformImageView = UIImageView
public typealias KFCrossPlatformView = UIView
public typealias KFCrossPlatformButton = UIButton
#else
import WatchKit
#endif
#endif

/// 泛型容器-包装后面需要的具体类型
public struct KingfisherWrapper<Base> {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

/// 计算属性 kf 的管理值
public protocol KingfisherCompatible: AnyObject { }
public protocol KingfisherCompatibleValue {}

extension KingfisherCompatible {
    public var kf: KingfisherWrapper<Self> {
        get { return KingfisherWrapper(self) }
        set { }
    }
}

extension KingfisherCompatibleValue {
    public var kf: KingfisherWrapper<Self> {
        get { return KingfisherWrapper(self) }
        set { }
    }
}

/// 给系统默认的 控件(UIImageView) 扩展, 让控件拥有 kf属性
extension KFCrossPlatformImage: KingfisherCompatible { }
#if !os(watchOS)
extension KFCrossPlatformImageView: KingfisherCompatible { }
extension KFCrossPlatformButton: KingfisherCompatible { }
extension NSTextAttachment: KingfisherCompatible { }
#else
extension WKInterfaceImage: KingfisherCompatible { }
#endif
