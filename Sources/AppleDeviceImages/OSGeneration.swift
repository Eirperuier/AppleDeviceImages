import Foundation

/// A year's OS releases, whose wallpaper a device image shows.
///
/// Apple's account image CDN keeps one folder per year, shared by every platform: `8.0` for 2018 (iOS 12,
/// macOS 10.14, watchOS 5) up to `14.0` for 2024 (iOS 18, macOS 15), `15.0` for 2025 (the 26 releases), and
/// from 2026 on the OS version itself (`27.0`). A device has images from its launch year on; years after its
/// last OS repeat its last image.
struct OSGeneration: Comparable, Hashable, Sendable, CustomStringConvertible {
    var year: Int

    init(year: Int) {
        self.year = year
    }

    /// The oldest year the account CDN has images for (iOS 8).
    static let oldest = OSGeneration(year: 2014)

    /// The newest year seen on Apple's CDN when this package was last checked.
    static let newestKnown = OSGeneration(year: 2026)

    /// The generation of an operating system release, or nil for a version that predates the scheme.
    init?(_ platform: Platform, _ version: OperatingSystemVersion) {
        guard let year = platform.releaseYear(of: version), year >= 2011 else { return nil }
        self.init(year: year)
    }

    /// The generation of a version string such as `"15.6.1"`, as account device lists report it.
    init?(_ platform: Platform, _ version: String) {
        let parts = version.split(separator: ".").map { Int($0) }
        guard let major = parts.first ?? nil else { return nil }
        let minor = parts.count > 1 ? parts[1] ?? 0 : 0
        self.init(platform, OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: 0))
    }

    static func < (lhs: OSGeneration, rhs: OSGeneration) -> Bool {
        lhs.year < rhs.year
    }

    /// The CDN folder's version: `14.0`, `15.0`, `27.0`.
    var description: String {
        year <= 2025 ? "\(year - 2010).0" : "\(year - 1999).0"
    }

    /// An Apple operating system, for turning its version into a generation.
    enum Platform: Sendable {
        case iOS, iPadOS, macOS, watchOS, tvOS, visionOS, audioOS

        func releaseYear(of version: OperatingSystemVersion) -> Int? {
            let major = version.majorVersion
            // From 2025 every platform is numbered after the following year.
            if major >= 26 { return major + 1999 }
            switch self {
            case .iOS, .iPadOS, .tvOS, .audioOS:
                return major + 2006
            case .macOS:
                if major == 10 { return version.minorVersion + 2004 }
                return major >= 11 ? major + 2009 : nil
            case .watchOS:
                return major + 2013
            case .visionOS:
                return major + 2022
            }
        }
    }
}
