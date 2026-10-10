import Foundation

/// The yearly generation of Apple's operating systems, which picks the wallpaper a device image shows.
///
/// Apple's account image CDN keeps one folder per generation (`deviceImages-15.0`), shared by every
/// platform: generation 8 is 2018 (iOS 12, macOS 10.14, watchOS 5), 14 is 2024 (iOS 18, macOS 15),
/// 15 is 2025 (the "26" releases). A device only has images for the generations it ran.
public struct OSGeneration: RawRepresentable, Comparable, Hashable, Sendable, CustomStringConvertible {
    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The generation of the releases Apple shipped in `year`.
    public init(year: Int) {
        self.rawValue = year - 2010
    }

    /// The newest generation seen on Apple's CDN when this package was last checked.
    public static let newestKnown = OSGeneration(rawValue: 15)

    /// The generation of an operating system release, or nil for a version that predates the scheme.
    public init?(_ platform: Platform, _ version: OperatingSystemVersion) {
        guard let year = platform.releaseYear(of: version), year >= 2011 else { return nil }
        self.init(year: year)
    }

    /// The generation of a version string such as `"15.6.1"`, as account device lists report it.
    public init?(_ platform: Platform, _ version: String) {
        let parts = version.split(separator: ".").map { Int($0) }
        guard let major = parts.first ?? nil else { return nil }
        let minor = parts.count > 1 ? parts[1] ?? 0 : 0
        self.init(platform, OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: 0))
    }

    /// The generation of the system this code runs on.
    public static var current: OSGeneration? {
        OSGeneration(.current, ProcessInfo.processInfo.operatingSystemVersion)
    }

    public static func < (lhs: OSGeneration, rhs: OSGeneration) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String { "\(rawValue).0" }

    /// An Apple operating system, for turning its version into a generation.
    public enum Platform: Sendable, CaseIterable {
        case iOS, iPadOS, macOS, watchOS, tvOS, visionOS, audioOS

        /// The platform this code runs on.
        public static var current: Platform {
            #if os(macOS)
            .macOS
            #elseif os(watchOS)
            .watchOS
            #elseif os(tvOS)
            .tvOS
            #elseif os(visionOS)
            .visionOS
            #else
            .iOS
            #endif
        }

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
