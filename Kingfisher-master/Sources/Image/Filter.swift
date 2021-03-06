
#if !os(watchOS)

import CoreImage

// Reuse the same CI Context for all CI drawing.
private let ciContext = CIContext(options: nil)

/// Represents the type of transformer method, which will be used in to provide a `Filter`.
public typealias Transformer = (CIImage) -> CIImage?

/// Represents a processor based on a `CIImage` `Filter`.
/// It requires a filter to create an `ImageProcessor`.
public protocol CIImageProcessor: ImageProcessor {
    var filter: Filter { get }
}

extension CIImageProcessor {
    
    /// Processes the input `ImageProcessItem` with this processor.
    ///
    /// - Parameters:
    ///   - item: Input item which will be processed by `self`.
    ///   - options: Options when processing the item.
    /// - Returns: The processed image.
    ///
    /// - Note: See documentation of `ImageProcessor` protocol for more.
    public func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case .image(let image):
            return image.kf.apply(filter)
        case .data:
            return (DefaultImageProcessor.default |> self).process(item: item, options: options)
        }
    }
}

/// A wrapper struct for a `Transformer` of CIImage filters. A `Filter`
/// value could be used to create a `CIImage` processor.
public struct Filter {
    
    let transform: Transformer

    public init(transform: @escaping Transformer) {
        self.transform = transform
    }
    
    /// Tint filter which will apply a tint color to images.
    public static var tint: (KFCrossPlatformColor) -> Filter = {
        color in
        Filter {
            input in
            
            let colorFilter = CIFilter(name: "CIConstantColorGenerator")!
            colorFilter.setValue(CIColor(color: color), forKey: kCIInputColorKey)
            
            let filter = CIFilter(name: "CISourceOverCompositing")!
            
            let colorImage = colorFilter.outputImage
            filter.setValue(colorImage, forKey: kCIInputImageKey)
            filter.setValue(input, forKey: kCIInputBackgroundImageKey)
            
            return filter.outputImage?.cropped(to: input.extent)
        }
    }
    
    /// Represents color control elements. It is a tuple of
    /// `(brightness, contrast, saturation, inputEV)`
    public typealias ColorElement = (CGFloat, CGFloat, CGFloat, CGFloat)
    
    /// Color control filter which will apply color control change to images.
    public static var colorControl: (ColorElement) -> Filter = { arg -> Filter in
        let (brightness, contrast, saturation, inputEV) = arg
        return Filter { input in
            let paramsColor = [kCIInputBrightnessKey: brightness,
                               kCIInputContrastKey: contrast,
                               kCIInputSaturationKey: saturation]
            let blackAndWhite = input.applyingFilter("CIColorControls", parameters: paramsColor)
            let paramsExposure = [kCIInputEVKey: inputEV]
            return blackAndWhite.applyingFilter("CIExposureAdjust", parameters: paramsExposure)
        }
    }
}

extension KingfisherWrapper where Base: KFCrossPlatformImage {

    /// Applies a `Filter` containing `CIImage` transformer to `self`.
    ///
    /// - Parameter filter: The filter used to transform `self`.
    /// - Returns: A transformed image by input `Filter`.
    ///
    /// - Note:
    ///    Only CG-based images are supported. If any error happens
    ///    during transforming, `self` will be returned.
    public func apply(_ filter: Filter) -> KFCrossPlatformImage {
        
        guard let cgImage = cgImage else {
            assertionFailure("[Kingfisher] Tint image only works for CG-based image.")
            return base
        }
        
        let inputImage = CIImage(cgImage: cgImage)
        guard let outputImage = filter.transform(inputImage) else {
            return base
        }

        guard let result = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            assertionFailure("[Kingfisher] Can not make an tint image within context.")
            return base
        }
        
        #if os(macOS)
            return fixedForRetinaPixel(cgImage: result, to: size)
        #else
            return KFCrossPlatformImage(cgImage: result, scale: base.scale, orientation: base.imageOrientation)
        #endif
    }

}

#endif
