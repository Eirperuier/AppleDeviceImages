#if os(macOS)
import AppKit
import UniformTypeIdentifiers

extension AppleDevice {
    /// macOS's own icon for the model (from CoreTypes.bundle): offline and 1024 px, in one color and without
    /// wallpaper generations, or nil when macOS doesn't know the model. It also covers products the CDNs lack,
    /// such as Apple Pencil, Beats and Studio Display.
    public var systemIcon: NSImage? {
        guard let type = UTType(tag: model, tagClass: UTTagClass(rawValue: "com.apple.device-model-code"),
                                conformingTo: nil),
              !type.isDynamic else { return nil }
        return NSWorkspace.shared.icon(for: type)
    }
}
#endif
