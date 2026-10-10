import Foundation
#if canImport(UIKit)
import UIKit
/// `UIImage`, or `NSImage` on macOS.
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// `UIImage`, or `NSImage` on macOS.
public typealias PlatformImage = NSImage
#endif

extension AppleDevice {
    /// The device's image.
    ///
    /// On macOS, when no CDN has the device, this falls back to the system's own icon for the model.
    public func image(size: AppleDeviceImageSize = .large, scale: Int = defaultScale) async throws -> PlatformImage {
        do {
            let data = try await imageData(size: size, scale: scale)
            #if canImport(UIKit)
            if let image = UIImage(data: data, scale: CGFloat(scale)) { return image }
            #elseif canImport(AppKit)
            if let image = NSImage(data: data) {
                if let pixels = image.representations.first {
                    image.size = NSSize(width: CGFloat(pixels.pixelsWide) / CGFloat(scale),
                                        height: CGFloat(pixels.pixelsHigh) / CGFloat(scale))
                }
                return image
            }
            #endif
            throw AppleDeviceImageError.notFound(self)
        } catch AppleDeviceImageError.notFound {
            #if os(macOS)
            if let icon = systemIcon { return icon }
            #endif
            throw AppleDeviceImageError.notFound(self)
        }
    }

    /// The device's image as PNG data.
    public func imageData(size: AppleDeviceImageSize = .large, scale: Int = defaultScale) async throws -> Data {
        try await ImageLoader.shared.image(for: self, size: size, scale: scale).data
    }

    /// The URL of the device's image, found by trying ``imageURLCandidates(size:scale:)`` in order.
    public func imageURL(size: AppleDeviceImageSize = .large, scale: Int = defaultScale) async throws -> URL {
        try await ImageLoader.shared.image(for: self, size: size, scale: scale).url
    }

    /// Every URL the image may be at, best first, without fetching any:
    /// Apple's account CDN at the device's OS generation, then older and newer generations,
    /// then Find My's CDN in the device's color and in the default one.
    public func imageURLCandidates(size: AppleDeviceImageSize = .large, scale: Int = defaultScale) -> [URL] {
        let product = Product(model: model)
        let color = parsedColor
        let file = "online-\(size.fileName)\(scale > 1 ? "__\(min(scale, 3))x" : "").png"
        var urls: [URL] = []
        if !product.accountNeedsColor || color.account != nil {
            let folder = product.accountFolder(color: color.account)
            for generation in generationOrder {
                urls.append(URL(string: "https://appleid.cdn-apple.com/static/deviceImages-\(generation)/\(folder)/\(file)")!)
            }
        }
        for folder in product.findMyFolders(color: color.findMy) {
            urls.append(URL(string: "https://statici.icloud.com/fmipmobile/deviceImages-9.0/\(folder)/\(file)")!)
        }
        return urls
    }

    /// The scale of this platform's screens: 2 on macOS, 3 elsewhere.
    public static var defaultScale: Int {
        #if os(macOS)
        2
        #else
        3
        #endif
    }

    /// The device's generation first, then older ones, then newer ones up to the newest this package or the
    /// system it runs on knows; without an OS version, the newest first.
    var generationOrder: [OSGeneration] {
        let newest = [OSGeneration.newestKnown, Self.runningGeneration, generation].compactMap { $0 }.max()!.year
        let start = max(generation?.year ?? newest, OSGeneration.oldest.year)
        let older = stride(from: start, through: OSGeneration.oldest.year, by: -1)
        let newer = start < newest ? Array((start + 1)...newest) : []
        return (Array(older) + newer).map(OSGeneration.init(year:))
    }

    private static let runningGeneration = AppleDevice.current.generation
}

public enum AppleDeviceImageError: Error, Sendable {
    /// Neither CDN has an image of the device.
    case notFound(AppleDevice)
}
