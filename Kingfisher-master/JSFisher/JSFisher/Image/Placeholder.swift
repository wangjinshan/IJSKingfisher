
import UIKit

protocol Placeholder {
    func add(imageView: JSImageView)
    func remove(imageView: JSImageView)
}

extension Placeholder where Self: JSView {
    func add(imageView: JSImageView) {
        addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        centerXAnchor.constraint(equalTo: imageView.centerXAnchor).isActive = true
        centerYAnchor.constraint(equalTo: imageView.centerYAnchor).isActive = true
        heightAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        widthAnchor.constraint(equalTo: imageView.widthAnchor).isActive = true
    }

    func remove(image: JSImageView) {
        removeFromSuperview()
    }
}
