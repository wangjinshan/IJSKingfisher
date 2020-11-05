import UIKit
import Kingfisher

class IJSGrammarTest {

    func play() {
        let view = UIView()
        view.js.base
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

