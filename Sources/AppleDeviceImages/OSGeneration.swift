import Foundation

/// The yearly generation of Apple's operating systems, which picks the wallpaper a device image shows.
///
/// Apple's account image CDN keeps one folder per generation (`deviceImages-15.0`), shared by every
/// platform: generation 8 is 2018 (iOS 12, macOS 10.14, watchOS 5), 14 is 2024 (iOS 18, macOS 15),
/// 15 is 2025 (the "26" releases). A device has images from its launch generation on; generations after its
/// last OS repeat its last image.
struct OSGeneration: RawRepresentable, Comparable, Hashable, Sendable, CustomStringConvertible {
    var rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The generation of the releases Apple shipped in `year`.
    init(year: Int) {
        self.rawValue = year - 2010
    }

    /// The newest generation seen on Apple's CDN when this package was last checked.
    static let newestKnown = OSGeneration(rawValue: 15)

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
        lhs.rawValue < rhs.rawValue
    }

    var description: String { "\(rawValue).0" }

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
