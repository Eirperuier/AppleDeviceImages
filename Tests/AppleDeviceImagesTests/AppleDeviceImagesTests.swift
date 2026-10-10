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

    @Test(arguments: [
        ("iPhone18,1", "18.6", 14), ("Watch7,1", "10.0", 13), ("Mac16,1", "15.2", 14),
        ("AppleTV14,1", "17.0", 13), ("RealityDevice14,1", "2.0", 14), ("iPad16,3", "26.0", 15),
    ])
    func theModelTellsWhichOSTheVersionIsOf(model: String, version: String, generation: Int) {
        #expect(AppleDevice(model, osVersion: version).generation?.rawValue == generation)
    }

    @Test func theDevicesGenerationComesFirstThenOlderThenNewer() {
        let order = AppleDevice("Mac15,6", osVersion: "14.1").generationOrder
        #expect(order.map(\.rawValue) == [13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 14, 15, 16])
    }

    @Test func noVersionStartsAfterTheNewestKnown() {
        let order = AppleDevice("Mac15,6").generationOrder
        #expect(order.first?.rawValue == OSGeneration.newestKnown.rawValue + 1)
        #expect(order.last?.rawValue == 1)
    }
}

@Suite struct ColorTests {
    @Test(arguments: [
        ("3b3b3c-47ade5", "3b3b3c-47ade5", nil), ("#3B3B3C-#47ADE5", "3b3b3c-47ade5", nil),
        ("1-9-0", nil, "1-9-0"), ("1-9", nil, "1-9-0"),
        ("AlmPink", "AlmPink", "AlmPink"), ("", nil, nil),
    ] as [(String, String?, String?)])
    func aCodeGoesToTheCDNThatReadsIt(code: String, account: String?, findMy: String?) {
        #expect(DeviceColor(code: code) == DeviceColor(account: account, findMy: findMy))
    }
}

@Suite struct CandidateTests {
    @Test func iPhoneInAColorTriesTheAccountCDNThenFindMy() {
        let urls = AppleDevice("iPhone18,1", color: "3b3b3c-47ade5", osVersion: "26.0").imageURLCandidates(scale: 3)
            .map(\.absoluteString)
        #expect(urls.first == "https://appleid.cdn-apple.com/static/deviceImages-15.0/iPhone/iPhone18,1-3b3b3c-47ade5/online-infobox__3x.png")
        #expect(urls.last == "https://statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iPhone18,1/online-infobox__3x.png")
    }

    @Test func aFindMyColorIsTriedBeforeTheDefault() {
        let urls = AppleDevice("iPhone18,1", color: "1-9").imageURLCandidates(scale: 3).map(\.absoluteString)
        #expect(urls == [
            "https://statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iPhone18,1-1-9-0/online-infobox__3x.png",
            "https://statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iPhone18,1/online-infobox__3x.png",
        ])
    }

    @Test func newMacsAreUnderMacOnTheAccountCDNAndTheirFamilyOnFindMy() {
        let urls = AppleDevice("Mac16,1", osVersion: "15.0").imageURLCandidates(size: .small, scale: 2)
            .map(\.absoluteString)
        #expect(urls.first == "https://appleid.cdn-apple.com/static/deviceImages-14.0/Mac/Mac16,1/online-sourcelist__2x.png")
        #expect(urls.first { $0.contains("statici") } == "https://statici.icloud.com/fmipmobile/deviceImages-9.0/MacBookPro/Mac16,1/online-sourcelist__2x.png")
    }

    @Test func anUnknownMacTriesEveryFamily() {
        let findMy = AppleDevice("Mac99,1").imageURLCandidates().filter { $0.host == "statici.icloud.com" }
        #expect(findMy.count == 8)
    }

    @Test func airPodsGoByProductID() {
        let urls = AppleDevice("Device1,8212").imageURLCandidates(scale: 1).map(\.absoluteString)
        #expect(urls.first == "https://appleid.cdn-apple.com/static/deviceImages-16.0/AirPods/AirPods_8212/online-infobox.png")
        #expect(urls.suffix(2) == [
            "https://statici.icloud.com/fmipmobile/deviceImages-9.0/Accessory/AirPods_8212/online-infobox.png",
            "https://statici.icloud.com/fmipmobile/deviceImages-9.0/Accessory/Beats_8212/online-infobox.png",
        ])
    }

    @Test func homePodWithoutAColorGoesToFindMy() {
        let urls = AppleDevice("AudioAccessory5,1").imageURLCandidates(scale: 3).map(\.absoluteString)
        #expect(urls == ["https://statici.icloud.com/fmipmobile/deviceImages-9.0/HomePod/AudioAccessory5,1/online-infobox__3x.png"])
    }

    @Test func theCurrentDeviceHasAModelAndVersion() {
        let device = AppleDevice.current
        #expect(!device.model.isEmpty)
        #expect(device.generation != nil)
    }
}

/// Hits Apple's CDNs; run with `APPLE_DEVICE_IMAGES_NETWORK=1 swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["APPLE_DEVICE_IMAGES_NETWORK"] == "1"))
struct NetworkTests {
    @Test(arguments: [
        (AppleDevice("iPhone18,1", color: "3b3b3c-47ade5", osVersion: "26.0"),
         "appleid.cdn-apple.com/static/deviceImages-15.0/iPhone/iPhone18,1-3b3b3c-47ade5/"),
        (AppleDevice("iPhone18,1"), "statici.icloud.com/fmipmobile/deviceImages-9.0/iPhone/iPhone18,1/"),
        (AppleDevice("Mac15,6", osVersion: "15.1"), "appleid.cdn-apple.com/static/deviceImages-14.0/Mac/Mac15,6/"),
        (AppleDevice("Watch7,1", color: "AlmPink", osVersion: "11.0"),
         "appleid.cdn-apple.com/static/deviceImages-14.0/Watch/Watch7,1-AlmPink/"),
        (AppleDevice("Watch7,1"), "statici.icloud.com/fmipmobile/deviceImages-9.0/Watch/Watch7,1/"),
        // Generation 16 has no images yet, so the newest before it serves.
        (AppleDevice("AppleTV14,1", osVersion: "27.0"), "appleid.cdn-apple.com/static/deviceImages-15.0/AppleTV/AppleTV14,1/"),
        (AppleDevice("Device1,8212"), "appleid.cdn-apple.com/static/deviceImages-15.0/AirPods/AirPods_8212/"),
        (AppleDevice("Device1,8240"), "statici.icloud.com/fmipmobile/deviceImages-9.0/Accessory/AirPods_8240/"),
    ])
    func findsTheImage(device: AppleDevice, expectedPrefix: String) async throws {
        let url = try await device.imageURL()
        #expect(url.absoluteString.hasPrefix("https://" + expectedPrefix))
        let image = try await device.image()
        #expect(image.size.width > 0)
    }

    @Test func aModelNoCDNHasIsNotFound() async {
        await #expect(throws: AppleDeviceImageError.self) {
            try await AppleDevice("Device1,1106", osVersion: "26.0").imageData()
        }
    }
}

#if os(macOS)
@Suite struct SystemIconTests {
    @Test func knownModelHasAnIcon() {
        #expect(AppleDevice("iPhone15,2").systemIcon != nil)
    }

    @Test func unknownModelHasNone() {
        #expect(AppleDevice("NotADevice9,9").systemIcon == nil)
    }
}
#endif
