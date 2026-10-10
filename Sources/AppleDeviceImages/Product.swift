/// How a model identifier maps onto the CDNs' folders.
struct Product: Hashable, Sendable {
    /// The model as the CDNs spell it (`AirPods_8212` for `Device1,8212`).
    let model: String
    let kind: Kind

    enum Kind: Hashable, Sendable {
        /// A family named by the identifier's letters: iPhone, iPad, iPod, Watch, AppleTV, RealityDevice,
        /// and Macs from before 2023 (`MacBookPro15,1`).
        case named(String)
        /// A HomePod (`AudioAccessory5,1`).
        case homePod
        /// A Mac with a `MacNN,N` identifier; the account CDN files it under `Mac`, Find My under its family.
        case mac
        /// AirPods or Beats, by Bluetooth product ID.
        case audio(productID: Int)
    }

    init(model: String) {
        let letters = String(model.prefix { $0.isLetter })
        if let productID = Self.audioProductID(model) {
            self.model = "AirPods_\(productID)"
            self.kind = .audio(productID: productID)
        } else if letters == "AudioAccessory" {
            self.model = model
            self.kind = .homePod
        } else if letters == "Mac" {
            self.model = model
            self.kind = .mac
        } else {
            self.model = model
            self.kind = .named(letters == "iMacPro" ? "iMac" : letters)
        }
    }

    /// Whether the account CDN only has this product in a color: iPhone, iPad, iPod, Apple Watch and HomePod.
    var accountNeedsColor: Bool {
        switch kind {
        case .homePod: true
        case .named(let family): ["iPhone", "iPad", "iPod", "Watch"].contains(family)
        case .mac, .audio: false
        }
    }

    func accountFolder(color: String?) -> String {
        let family = switch kind {
        case .named(let family): family
        case .homePod: "HomePod"
        case .mac: "Mac"
        case .audio: "AirPods"
        }
        return "\(family)/\(model)\(color.map { "-\($0)" } ?? "")"
    }

    /// Find My folders to try: in the color first, then in the default one.
    func findMyFolders(color: String?) -> [String] {
        let folders: [String] = switch kind {
        case .named(let family):
            ["\(family)/\(model)"]
        case .homePod:
            ["HomePod/\(model)"]
        case .mac:
            Self.macFamilies(model).map { "\($0)/\(model)" }
        case .audio(let productID):
            ["Accessory/AirPods_\(productID)", "Accessory/Beats_\(productID)"]
        }
        if case .audio = kind { return folders }
        guard let color else { return folders }
        return folders.map { "\($0)-\(color)" } + folders
    }

    /// Find My's folders for a `MacNN,N` model: the one it was last found under first, then the rest.
    static func macFamilies(_ model: String) -> [String] {
        let all = ["MacBookPro", "MacBookAir", "Macmini", "iMac", "MacStudio", "MacPro", "MacBook", "Mac"]
        guard let known = macFamily[model] else { return all }
        return [known] + all.filter { $0 != known }
    }

    private static func audioProductID(_ model: String) -> Int? {
        for prefix in ["Device1,", "AirPods_", "Beats_"] where model.hasPrefix(prefix) {
            return Int(model.dropFirst(prefix.count))
        }
        return nil
    }
}
