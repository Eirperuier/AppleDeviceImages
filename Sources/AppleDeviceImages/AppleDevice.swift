import Foundation

/// An Apple product whose image you want: its model, and optionally its color and the OS version it runs.
///
/// ```swift
/// let phone = AppleDevice("iPhone18,1", color: "3b3b3c-47ade5", osVersion: "26.1")
/// let image = try await phone.image()
/// ```
public struct AppleDevice: Hashable, Sendable {
    /// The model identifier: `iPhone18,1`, `iPad16,3`, `Mac16,1`, `Watch7,1`, `AppleTV14,1`, `AudioAccessory5,1`,
    /// `RealityDevice14,1`, `HomeAccessory17,1`, or for AirPods and Beats `Device1,<Bluetooth product ID>`.
    public var model: String

    /// The color as Apple encodes it, in any of its forms:
    /// - `"3b3b3c-47ade5"`: cover glass and housing hex (iPhone, iPad, iPod, HomePod)
    /// - `"AlmPink"`: material and color (Apple Watch)
    /// - `"1-9-0"` or `"1-9"`: `DeviceColor` and `DeviceEnclosureColor` numbers (Find My)
    ///
    /// Without it the image shows the model's default color.
    public var color: String?

    /// The OS version the device runs, such as `"26.1"` or `"18.6"`; it picks the wallpaper.
    /// Without it the image shows the newest wallpaper.
    public var osVersion: String?

    public init(_ model: String, color: String? = nil, osVersion: String? = nil) {
        self.model = model
        self.color = color
        self.osVersion = osVersion
    }

    /// The device this code runs on, with its OS version. Its color isn't readable through public API.
    public static var current: AppleDevice {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return AppleDevice(
            currentModel(),
            osVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        )
    }

    var generation: OSGeneration? {
        guard let osVersion, let platform = Product(model: model).platform else { return nil }
        return OSGeneration(platform, osVersion)
    }

    var parsedColor: DeviceColor {
        DeviceColor(code: color)
    }

    private static func currentModel() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [UInt8](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(decoding: model.prefix { $0 != 0 }, as: UTF8.self)
        #else
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        #endif
    }
}

extension AppleDevice: ExpressibleByStringLiteral {
    public init(stringLiteral model: String) {
        self.init(model)
    }
}

/// How large an image to fetch.
public enum AppleDeviceImageSize: Hashable, Sendable {
    /// The device list's image, about 100 pt wide.
    case small
    /// The detail view's image, about 150 pt wide.
    case large

    var fileName: String {
        switch self {
        case .small: "sourcelist"
        case .large: "infobox"
        }
    }
}

/// A color code sorted into the CDN that understands it.
struct DeviceColor: Hashable, Sendable {
    var account: String?
    var findMy: String?

    init(account: String? = nil, findMy: String? = nil) {
        self.account = account
        self.findMy = findMy
    }

    init(code: String?) {
        guard let code = code?.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces),
              !code.isEmpty else {
            self.init()
            return
        }
        let parts = code.split(separator: "-")
        if parts.count == 2, parts.allSatisfy({ $0.count == 6 && $0.allSatisfy(\.isHexDigit) }) {
            self.init(account: code.lowercased())
        } else if (2...3).contains(parts.count), parts.allSatisfy({ $0.count <= 3 && Int($0) != nil }) {
            self.init(findMy: parts.count == 2 ? code + "-0" : code)
        } else {
            self.init(account: code, findMy: code)
        }
    }
}
