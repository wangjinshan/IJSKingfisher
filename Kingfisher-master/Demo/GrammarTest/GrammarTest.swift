import UIKit
import Kingfisher

class IJSGrammarTest {
    func play() {
        let view = UIImageView()
        view.js.click()
        view.kf.setImage(with: URL(string: ""))
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

// MARK: - Result
class IJSResult  {
    func setImage(completionHandler: ((Result<Int, KingfisherError>) -> Void)?) {
        let test: IJSGrammarTest
        if completionHandler != nil {
            test = IJSGrammarTest()
        } else {
            test = IJSGrammarTest()
        }
        test.play()
    }

    private func test() {
        setImage { (result) in
            if case .success(let count) = result {
                print("\(count) unread messages.")
            }
        }
    }
}
