#if os(macOS)
import AppKit
import UniformTypeIdentifiers

extension AppleDevice {
    /// macOS's own icon for the model (from CoreTypes.bundle): offline and 1024 px, in the device's color when
    /// macOS has it, without wallpaper generations, or nil when macOS doesn't know the model. It also covers products the CDNs lack,
    /// such as Apple Pencil, Beats and Studio Display.
    public var systemIcon: NSImage? {
        if let color = iconColor, let icon = Self.icon(tag: "\(model)@ECOLOR=\(color)") {
            return icon
        }
        if let identifier = Self.mistaggedIcons[model], let type = UTType(identifier), type.isDeclared {
            return NSWorkspace.shared.icon(for: type)
        }
        return Self.icon(tag: model)
    }

    /// The color as macOS's icons tag it: a number (`7`, also read from Find My's `0-7-0`) for Apple silicon Macs,
    /// red, green and blue (`235,215,191`) for older ones.
    private var iconColor: String? {
        guard let color, !color.isEmpty else { return nil }
        let parts = color.split(separator: "-")
        return parts.count == 3 && parts.first == "0" ? String(parts[1]) : color
    }

    private static func icon(tag: String) -> NSImage? {
        guard let type = UTType(tag: tag, tagClass: UTTagClass(rawValue: "com.apple.device-model-code"),
                                conformingTo: nil),
              !type.isDynamic else { return nil }
        return NSWorkspace.shared.icon(for: type)
    }

    /// Models macOS 27 files under the wrong type: it tags both 2026 Studio Displays `AppleDisplay18,2`.
    private static let mistaggedIcons = [
        "AppleDisplay18,1": "com.apple.studio-display-xdr-2026",
        "AppleDisplay18,2": "com.apple.studio-display-2026",
    ]
}
#endif
