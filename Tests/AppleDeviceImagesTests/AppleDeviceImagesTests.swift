import Foundation
import Testing
@testable import AppleDeviceImages

@Suite struct GenerationTests {
    @Test(arguments: [
        (OSGeneration.Platform.iOS, "12.0", 8), (.iOS, "15.6.1", 11), (.iOS, "18.2", 14), (.iOS, "26.1", 15),
        (.macOS, "10.14", 8), (.macOS, "13.4", 12), (.macOS, "15.0", 14), (.macOS, "26.0", 15),
        (.watchOS, "5.0", 8), (.watchOS, "10.6", 13), (.watchOS, "26.0", 15),
        (.tvOS, "16.0", 12), (.visionOS, "1.0", 13), (.visionOS, "26.0", 15), (.iOS, "27.0", 16),
    ])
    func versionGivesGeneration(platform: OSGeneration.Platform, version: String, generation: Int) {
        #expect(OSGeneration(platform, version)?.rawValue == generation)
    }

    @Test func requestedGenerationComesFirstThenOlderThenNewer() {
        let order = DeviceImageRequest(model: "Mac15,6", generation: OSGeneration(rawValue: 13)).generationOrder
        #expect(order.map(\.rawValue) == [13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 14, 15, 16])
    }

    @Test func noGenerationStartsAfterTheNewestKnown() {
        let order = DeviceImageRequest(model: "Mac15,6").generationOrder
        #expect(order.first?.rawValue == OSGeneration.newestKnown.rawValue + 1)
        #expect(order.last?.rawValue == 1)
    }
}

@Suite struct CandidateTests {
    @Test func iPhoneInAColorTriesTheAccountCDNThenFindMy() {
        let request = DeviceImageRequest(
            model: "iPhone18,1",
            color: DeviceColor(deviceColor: 1, enclosureColor: 9, account: "3b3b3c-47ade5"),
            generation: OSGeneration(rawValue: 15)
        )
        let urls = request.candidateURLs.map(\.absoluteString)
        #expect(urls.first == "https://appleid.cdn-apple.com/static/deviceImages-15.0/iPhone/iPhone18,1-3b3b3c-47ade5/online-infobox__3x.png")
        #expect(urls.suffix(2) == [
            "https://statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iPhone18,1-1-9-0/online-infobox__3x.png",
            "https://statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iPhone18,1/online-infobox__3x.png",
        ])
    }

    @Test func iPhoneWithoutAnAccountColorGoesStraightToFindMy() {
        let urls = DeviceImageRequest(model: "iPhone18,1").candidateURLs
        #expect(urls.allSatisfy { $0.host == "statici.icloud.com" })
    }

    @Test func newMacsAreUnderMacOnTheAccountCDNAndTheirFamilyOnFindMy() {
        let urls = DeviceImageRequest(model: "Mac16,1", generation: OSGeneration(rawValue: 14), style: .list, scale: 2)
            .candidateURLs.map(\.absoluteString)
        #expect(urls.first == "https://appleid.cdn-apple.com/static/deviceImages-14.0/Mac/Mac16,1/online-sourcelist__2x.png")
        #expect(urls.first { $0.contains("statici") } == "https://statici.icloud.com/fmipmobile/deviceImages-9.0/MacBookPro/Mac16,1/online-sourcelist__2x.png")
    }

    @Test func anUnknownMacTriesEveryFamily() {
        let findMy = DeviceImageRequest(model: "Mac99,1").candidateURLs.filter { $0.host == "statici.icloud.com" }
        #expect(findMy.count == 8)
    }

    @Test func airPodsGoByProductID() {
        let urls = DeviceImageRequest(model: "Device1,8212", scale: 1).candidateURLs.map(\.absoluteString)
        #expect(urls.first == "https://appleid.cdn-apple.com/static/deviceImages-16.0/AirPods/AirPods_8212/online-infobox.png")
        #expect(urls.suffix(2) == [
            "https://statici.icloud.com/fmipmobile/deviceImages-9.0/Accessory/AirPods_8212/online-infobox.png",
            "https://statici.icloud.com/fmipmobile/deviceImages-9.0/Accessory/Beats_8212/online-infobox.png",
        ])
    }

    @Test func homePodIsFiledUnderHomePod() {
        let urls = DeviceImageRequest(model: "AudioAccessory5,1").candidateURLs.map(\.absoluteString)
        #expect(urls == ["https://statici.icloud.com/fmipmobile/deviceImages-9.0/HomePod/AudioAccessory5,1/online-infobox__3x.png"])
    }
}

/// Hits Apple's CDNs; run with `APPLE_DEVICE_IMAGES_NETWORK=1 swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["APPLE_DEVICE_IMAGES_NETWORK"] == "1"))
struct NetworkTests {
    @Test(arguments: [
        (DeviceImageRequest(model: "iPhone18,1", color: DeviceColor(account: "3b3b3c-47ade5"), generation: OSGeneration(rawValue: 15)),
         "appleid.cdn-apple.com/static/deviceImages-15.0/iPhone/iPhone18,1-3b3b3c-47ade5/"),
        (DeviceImageRequest(model: "iPhone18,1"), "statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iPhone18,1/"),
        (DeviceImageRequest(model: "Mac15,6", generation: OSGeneration(rawValue: 14)),
         "appleid.cdn-apple.com/static/deviceImages-14.0/Mac/Mac15,6/"),
        (DeviceImageRequest(model: "Watch7,1", color: DeviceColor(account: "AlmPink"), generation: OSGeneration(.watchOS, "11.0")),
         "appleid.cdn-apple.com/static/deviceImages-14.0/Watch/Watch7,1-AlmPink/"),
        // Generation 16 doesn't exist yet, so the newest one before it serves.
        (DeviceImageRequest(model: "AppleTV14,1", generation: OSGeneration(rawValue: 16)),
         "appleid.cdn-apple.com/static/deviceImages-15.0/AppleTV/AppleTV14,1/"),
        (DeviceImageRequest(model: "Watch7,1"), "statici.icloud.com/fmipmobile/deviceImages-9.0/Watch/Watch7,1/"),
        (DeviceImageRequest(model: "AppleTV14,1"), "appleid.cdn-apple.com/static/deviceImages-15.0/AppleTV/AppleTV14,1/"),
        (DeviceImageRequest(model: "Device1,8212"), "appleid.cdn-apple.com/static/deviceImages-15.0/AirPods/AirPods_8212/"),
        (DeviceImageRequest(model: "Device1,8240"), "statici.icloud.com/fmipmobile/deviceImages-9.0/Accessory/AirPods_8240/"),
    ])
    func findsTheImage(request: DeviceImageRequest, expectedPrefix: String) async throws {
        let (url, data) = try await DeviceImageLoader().image(for: request)
        #expect(url.absoluteString.hasPrefix("https://" + expectedPrefix))
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func aModelNoCDNHasIsNotFound() async {
        await #expect(throws: DeviceImageError.self) {
            try await DeviceImageLoader().image(for: DeviceImageRequest(model: "Device1,1106", generation: OSGeneration(rawValue: 15)))
        }
    }
}

#if os(macOS)
@Suite struct SystemIconTests {
    @Test func knownModelHasAnIcon() {
        #expect(SystemDeviceIcon.image(forModel: "iPhone15,2") != nil)
    }

    @Test func unknownModelHasNone() {
        #expect(SystemDeviceIcon.image(forModel: "NotADevice9,9") == nil)
    }
}
#endif
