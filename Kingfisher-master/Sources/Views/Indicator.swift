
#if !os(watchOS)

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
public typealias IndicatorView = NSView
#else
import UIKit
public typealias IndicatorView = UIView
#endif

public enum IndicatorType {
    case none
    case activity
    case image(imageData: Data)
    case custom(indicator: Indicator)
}

public protocol Indicator {

    func startAnimatingView()

    func stopAnimatingView()

    var centerOffset: CGPoint { get }

    var view: IndicatorView { get }

    func sizeStrategy(in imageView: KFCrossPlatformImageView) -> IndicatorSizeStrategy
}

public enum IndicatorSizeStrategy {
    case intrinsicSize
    case full
    case size(CGSize)
}

extension Indicator {

    public var centerOffset: CGPoint { return .zero }

    public func sizeStrategy(in imageView: KFCrossPlatformImageView) -> IndicatorSizeStrategy {
        return .full
    }
}

final class ActivityIndicator: Indicator {

    #if os(macOS)
    private let activityIndicatorView: NSProgressIndicator
    #else
    private let activityIndicatorView: UIActivityIndicatorView
    #endif
    private var animatingCount = 0

    var view: IndicatorView {
        return activityIndicatorView
    }

    func startAnimatingView() {
        if animatingCount == 0 {
            #if os(macOS)
            activityIndicatorView.startAnimation(nil)
            #else
            activityIndicatorView.startAnimating()
            #endif
            activityIndicatorView.isHidden = false
        }
        animatingCount += 1
    }

    func stopAnimatingView() {
        animatingCount = max(animatingCount - 1, 0)
        if animatingCount == 0 {
            #if os(macOS)
                activityIndicatorView.stopAnimation(nil)
            #else
                activityIndicatorView.stopAnimating()
            #endif
            activityIndicatorView.isHidden = true
        }
    }

    func sizeStrategy(in imageView: KFCrossPlatformImageView) -> IndicatorSizeStrategy {
        return .intrinsicSize
    }

    init() {
        #if os(macOS)
            activityIndicatorView = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
            activityIndicatorView.controlSize = .small
            activityIndicatorView.style = .spinning
        #else
            let indicatorStyle: UIActivityIndicatorView.Style

            #if os(tvOS)
            if #available(tvOS 13.0, *) {
                indicatorStyle = UIActivityIndicatorView.Style.large
            } else {
                indicatorStyle = UIActivityIndicatorView.Style.white
            }
            #else
            if #available(iOS 13.0, * ) {
                indicatorStyle = UIActivityIndicatorView.Style.medium
            } else {
                indicatorStyle = UIActivityIndicatorView.Style.gray
            }
            #endif

            #if swift(>=4.2)
            activityIndicatorView = UIActivityIndicatorView(style: indicatorStyle)
            #else
            activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: indicatorStyle)
            #endif
        #endif
    }
}

#if canImport(UIKit)
extension UIActivityIndicatorView.Style {
    #if compiler(>=5.1)
    #else
    static let large = UIActivityIndicatorView.Style.white
    #if !os(tvOS)
    static let medium = UIActivityIndicatorView.Style.gray
    #endif
    #endif
}
#endif

// MARK: - ImageIndicator
// Displays an ImageView. Supports gif
final class ImageIndicator: Indicator {
    private let animatedImageIndicatorView: KFCrossPlatformImageView

    var view: IndicatorView {
        return animatedImageIndicatorView
    }

    init?(
        imageData data: Data,
        processor: ImageProcessor = DefaultImageProcessor.default,
        options: KingfisherParsedOptionsInfo? = nil)
    {
        var options = options ?? KingfisherParsedOptionsInfo(nil)
        // Use normal image view to show animations, so we need to preload all animation data.
        if !options.preloadAllAnimationData {
            options.preloadAllAnimationData = true
        }
        
        guard let image = processor.process(item: .data(data), options: options) else {
            return nil
        }

        animatedImageIndicatorView = KFCrossPlatformImageView()
        animatedImageIndicatorView.image = image
        
        #if os(macOS)
            // Need for gif to animate on macOS
            animatedImageIndicatorView.imageScaling = .scaleNone
            animatedImageIndicatorView.canDrawSubviewsIntoLayer = true
        #else
            animatedImageIndicatorView.contentMode = .center
        #endif
    }

    func startAnimatingView() {
        #if os(macOS)
            animatedImageIndicatorView.animates = true
        #else
            animatedImageIndicatorView.startAnimating()
        #endif
        animatedImageIndicatorView.isHidden = false
    }

    func stopAnimatingView() {
        #if os(macOS)
            animatedImageIndicatorView.animates = false
        #else
            animatedImageIndicatorView.stopAnimating()
        #endif
        animatedImageIndicatorView.isHidden = true
    }
}

#endif
