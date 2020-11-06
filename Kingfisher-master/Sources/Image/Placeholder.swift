
#if !os(watchOS)

#if os(macOS)
import AppKit
#else
import UIKit
#endif

public protocol Placeholder {
    func add(to imageView: KFCrossPlatformImageView)
    func remove(from imageView: KFCrossPlatformImageView)
}

extension KFCrossPlatformImage: Placeholder {
    public func add(to imageView: KFCrossPlatformImageView) { imageView.image = self }
    public func remove(from imageView: KFCrossPlatformImageView) { imageView.image = nil }
}

extension Placeholder where Self: KFCrossPlatformView {

    public func add(to imageView: KFCrossPlatformImageView) {
        imageView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        centerXAnchor.constraint(equalTo: imageView.centerXAnchor).isActive = true
        centerYAnchor.constraint(equalTo: imageView.centerYAnchor).isActive = true
        heightAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        widthAnchor.constraint(equalTo: imageView.widthAnchor).isActive = true
    }

    public func remove(from imageView: KFCrossPlatformImageView) {
        removeFromSuperview()
    }
}

#endif
