
import Foundation

/// An `ImageModifier` can be used to change properties on an image in between
/// cache serialization and use of the image. The modified returned image will be
/// only used for current rendering purpose, the serialization data will not contain
/// the changes applied by the `ImageModifier`.
public protocol ImageModifier {
    /// Modify an input `Image`.
    ///
    /// - parameter image:   Image which will be modified by `self`
    ///
    /// - returns: The modified image.
    ///
    /// - Note: The return value will be unmodified if modifying is not possible on
    ///         the current platform.
    /// - Note: Most modifiers support UIImage or NSImage, but not CGImage.
    func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage
}

/// A wrapper for creating an `ImageModifier` easier.
/// This type conforms to `ImageModifier` and wraps an image modify block.
/// If the `block` throws an error, the original image will be used.
public struct AnyImageModifier: ImageModifier {

    /// A block which modifies images, or returns the original image
    /// if modification cannot be performed with an error.
    let block: (KFCrossPlatformImage) throws -> KFCrossPlatformImage

    /// Creates an `AnyImageModifier` with a given `modify` block.
    public init(modify: @escaping (KFCrossPlatformImage) throws -> KFCrossPlatformImage) {
        block = modify
    }

    /// Modify an input `Image`. See `ImageModifier` protocol for more.
    public func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        return (try? block(image)) ?? image
    }
}

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

/// Modifier for setting the rendering mode of images.
public struct RenderingModeImageModifier: ImageModifier {

    /// The rendering mode to apply to the image.
    public let renderingMode: UIImage.RenderingMode

    /// Creates a `RenderingModeImageModifier`.
    ///
    /// - Parameter renderingMode: The rendering mode to apply to the image. Default is `.automatic`.
    public init(renderingMode: UIImage.RenderingMode = .automatic) {
        self.renderingMode = renderingMode
    }

    /// Modify an input `Image`. See `ImageModifier` protocol for more.
    public func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        return image.withRenderingMode(renderingMode)
    }
}

/// Modifier for setting the `flipsForRightToLeftLayoutDirection` property of images.
public struct FlipsForRightToLeftLayoutDirectionImageModifier: ImageModifier {

    /// Creates a `FlipsForRightToLeftLayoutDirectionImageModifier`.
    public init() {}

    /// Modify an input `Image`. See `ImageModifier` protocol for more.
    public func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        return image.imageFlippedForRightToLeftLayoutDirection()
    }
}

/// Modifier for setting the `alignmentRectInsets` property of images.
public struct AlignmentRectInsetsImageModifier: ImageModifier {

    /// The alignment insets to apply to the image
    public let alignmentInsets: UIEdgeInsets

    /// Creates an `AlignmentRectInsetsImageModifier`.
    public init(alignmentInsets: UIEdgeInsets) {
        self.alignmentInsets = alignmentInsets
    }

    /// Modify an input `Image`. See `ImageModifier` protocol for more.
    public func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        return image.withAlignmentRectInsets(alignmentInsets)
    }
}
#endif
