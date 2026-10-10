#if canImport(SwiftUI)
import SwiftUI

/// A view that loads and shows a device's image, like `AsyncImage`.
///
/// ```swift
/// AppleDeviceImage("Mac16,1")
///     .frame(width: 120)
///
/// AppleDeviceImage(AppleDevice("iPhone18,1", color: "3b3b3c-47ade5", osVersion: "26.1")) { image in
///     image.resizable().scaledToFit().shadow(radius: 4)
/// } placeholder: {
///     Color.secondary.opacity(0.1)
/// }
/// ```
///
/// By default the image is resizable and fits its frame, a progress view shows while it loads, and nothing
/// shows if no image is found. A custom placeholder also stands in when no image is found.
public struct AppleDeviceImage<Content: View, Placeholder: View>: View {
    private let device: AppleDevice
    private let size: AppleDeviceImageSize
    private let content: ((Image) -> Content)?
    private let placeholder: Placeholder
    private let showsPlaceholderOnFailure: Bool

    @Environment(\.displayScale) private var displayScale
    @State private var phase = Phase.loading

    private enum Phase {
        case loading
        case loaded(Load, Image)
        case failed(Load)
    }

    private struct Load: Hashable {
        let device: AppleDevice
        let size: AppleDeviceImageSize
        let scale: Int
    }

    public init(
        _ device: AppleDevice,
        size: AppleDeviceImageSize = .large,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.device = device
        self.size = size
        self.content = content
        self.placeholder = placeholder()
        self.showsPlaceholderOnFailure = true
    }

    public var body: some View {
        let load = Load(device: device, size: size, scale: max(1, min(3, Int(displayScale.rounded()))))
        Group {
            switch phase {
            case .loaded(let loaded, let image) where loaded == load:
                if let content {
                    content(image)
                } else {
                    image.resizable().scaledToFit()
                }
            case .failed(let failed) where failed == load && !showsPlaceholderOnFailure:
                Color.clear
            default:
                placeholder
            }
        }
        .task(id: load) {
            do {
                let image = try await load.device.image(size: load.size, scale: load.scale)
                phase = .loaded(load, Image(platformImage: image))
            } catch is CancellationError {
            } catch {
                phase = .failed(load)
            }
        }
    }
}

extension AppleDeviceImage where Content == Never, Placeholder == ProgressView<EmptyView, EmptyView> {
    /// The device's image, resizable and fitting its frame, with a progress view while it loads.
    public init(_ device: AppleDevice, size: AppleDeviceImageSize = .large) {
        self.device = device
        self.size = size
        self.content = nil
        self.placeholder = ProgressView()
        self.showsPlaceholderOnFailure = false
    }
}

extension AppleDeviceImage where Content == Never {
    /// The device's image, resizable and fitting its frame, with `placeholder` while it loads or if none is found.
    public init(_ device: AppleDevice, size: AppleDeviceImageSize = .large, @ViewBuilder placeholder: () -> Placeholder) {
        self.device = device
        self.size = size
        self.content = nil
        self.placeholder = placeholder()
        self.showsPlaceholderOnFailure = true
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}
#endif
