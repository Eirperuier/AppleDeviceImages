import Foundation

/// Which Apple product image to fetch.
public struct DeviceImageRequest: Hashable, Sendable {
    /// The model identifier: `iPhone18,1`, `Mac16,1`, `Watch7,1`, `AudioAccessory5,1`, `RealityDevice14,1`,
    /// or for AirPods and Beats the Bluetooth product ID as `Device1,8212` or `AirPods_8212`.
    public var model: String
    public var color: DeviceColor
    /// The operating system generation whose wallpaper the image shows; nil picks the newest one available.
    public var generation: OSGeneration?
    public var style: Style
    /// 1, 2 or 3.
    public var scale: Int

    public init(
        model: String,
        color: DeviceColor = .unspecified,
        generation: OSGeneration? = nil,
        style: Style = .infobox,
        scale: Int = 3
    ) {
        self.model = model
        self.color = color
        self.generation = generation
        self.style = style
        self.scale = scale
    }

    public enum Style: String, Hashable, Sendable {
        /// The small image of a device list (`online-sourcelist`).
        case list = "sourcelist"
        /// The larger image of a device's detail view (`online-infobox`).
        case infobox
    }

    /// The URLs to try, best first: the account CDN at the requested generation, then older and newer
    /// generations, then the Find My CDN, whose images don't follow the operating system.
    public var candidateURLs: [URL] {
        let product = Product(model: model)
        var urls: [URL] = []
        if product.accountNeedsColor == false || color.account != nil {
            let folder = product.accountFolder(color: color.account)
            for generation in generationOrder {
                urls.append(Self.accountURL(generation: generation, folder: folder, style: style, scale: scale))
            }
        }
        for folder in product.findMyFolders(color: color.findMy) {
            urls.append(Self.findMyURL(folder: folder, style: style, scale: scale))
        }
        return urls
    }

    var generationOrder: [OSGeneration] {
        let newest = OSGeneration.newestKnown.rawValue + 1
        let start = min(max(generation?.rawValue ?? newest, 1), newest)
        let older = stride(from: start, through: 1, by: -1)
        let newer = (start + 1)..<(newest + 1)
        return (Array(older) + Array(newer)).map(OSGeneration.init(rawValue:))
    }

    static func accountURL(generation: OSGeneration, folder: String, style: Style, scale: Int) -> URL {
        URL(string: "https://appleid.cdn-apple.com/static/deviceImages-\(generation)/\(folder)/online-\(style.rawValue)\(suffix(scale)).png")!
    }

    static func findMyURL(folder: String, style: Style, scale: Int) -> URL {
        URL(string: "https://statici.icloud.com/fmipmobile/deviceImages-9.0/\(folder)/online-\(style.rawValue)\(suffix(scale)).png")!
    }

    private static func suffix(_ scale: Int) -> String {
        scale > 1 ? "__\(min(scale, 3))x" : ""
    }
}

/// A device's color as the two image CDNs spell it.
///
/// Apple's servers hand these out with each device (an account device list's image URLs, Find My's
/// `deviceColor`); a device reports its own through MobileGestalt.
public struct DeviceColor: Hashable, Sendable {
    /// The account CDN's color: `<cover glass>-<housing>` hex for iPhone, iPad, iPod and HomePod
    /// (`3b3b3c-47ade5`, from `DeviceCoverGlassColor` and `DeviceHousingColor`), a name for Apple Watch
    /// (`AlmSpGry`). Macs, Apple TV and Vision Pro have none.
    public var account: String?
    /// Find My's color: `<DeviceColor>-<DeviceEnclosureColor>-0` (`1-9-0`).
    public var findMy: String?

    public init(account: String? = nil, findMy: String? = nil) {
        self.account = account
        self.findMy = findMy
    }

    /// Find My's color from MobileGestalt's `DeviceColor` and `DeviceEnclosureColor` numbers.
    public init(deviceColor: Int, enclosureColor: Int, account: String? = nil) {
        self.init(account: account, findMy: "\(deviceColor)-\(enclosureColor)-0")
    }

    public static let unspecified = DeviceColor()
}
