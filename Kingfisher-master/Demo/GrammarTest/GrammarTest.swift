import UIKit
import Kingfisher

class IJSGrammarTest {

    func play() {
        let view = UIImageView()
        view.js.click()
    }
}

public struct IJSKingfisherWrapper<Base> {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

public protocol IJSKingfisherCompatible: AnyObject { }

extension IJSKingfisherCompatible {
    public var js: IJSKingfisherWrapper<Self> {
        get { return IJSKingfisherWrapper(self) }
        set { }
    }
}

extension UIImageView: IJSKingfisherCompatible { }
extension UIView: IJSKingfisherCompatible { }

extension IJSKingfisherWrapper where Base: UIImageView {
    public func click() {
        print("金山")
    }
}
