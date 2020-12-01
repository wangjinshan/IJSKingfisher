
import UIKit

public typealias JSImageView = UIImageView
public typealias JSView = UIView

/// 包装器
public struct JSFisherWrapper<Base> {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

/// 兼容协议器
public protocol JSFisherCompatible:AnyObject {}
public protocol JSFisherCompatibleValue {}

extension JSFisherCompatible {
    public var js: JSFisherWrapper<Self> { // Self 的值等于 type(of: self)。也就是说，这个值是动态获取的
        get{ JSFisherWrapper(self) }
        set {}
    }
}

extension JSFisherCompatibleValue {
    public var js: JSFisherWrapper<Self> {
        get { JSFisherWrapper(self) }
        set {}
    }
}

extension JSImageView: JSFisherCompatible {}



