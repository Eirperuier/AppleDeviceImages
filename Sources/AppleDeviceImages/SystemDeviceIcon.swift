#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// macOS's own device icons (CoreTypes.bundle), found by model identifier: offline, 1024 px, one default
/// color per model, and no wallpaper generations. They also cover products the CDNs lack, such as
/// Apple Pencil, Beats and Studio Display (by `Device1,<product ID>` or `AppleDisplayNN,N`).
public enum SystemDeviceIcon {
    /// The icon macOS declares for `model`, or nil when it has none.
    public static func image(forModel model: String) -> NSImage? {
        guard let type = UTType(tag: model, tagClass: UTTagClass(rawValue: "com.apple.device-model-code"),
                                conformingTo: nil),
              !type.isDynamic else { return nil }
        return NSWorkspace.shared.icon(for: type)
    }
}
#endif
