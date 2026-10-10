import Foundation
import Testing
@testable import AppleDeviceImages

@Suite struct GenerationTests {
    @Test(arguments: [
        (OSGeneration.Platform.iOS, "8.4", "4.0"), (.iOS, "12.0", "8.0"), (.iOS, "15.6.1", "11.0"), (.iOS, "18.2", "14.0"),
        (.iOS, "26.1", "15.0"), (.iOS, "27.0.1", "27.0"), (.iOS, "28.0", "28.0"),
        (.macOS, "10.14", "8.0"), (.macOS, "13.4", "12.0"), (.macOS, "15.0", "14.0"), (.macOS, "26.0", "15.0"),
        (.macOS, "27.0", "27.0"), (.watchOS, "5.0", "8.0"), (.watchOS, "10.6", "13.0"), (.watchOS, "26.0", "15.0"),
        (.watchOS, "27.0", "27.0"), (.tvOS, "16.0", "12.0"), (.visionOS, "1.0", "13.0"), (.visionOS, "26.0", "15.0"),
    ])
    func versionGivesTheCDNFolder(platform: OSGeneration.Platform, version: String, folder: String) {
        #expect(OSGeneration(platform, version)?.description == folder)
    }

    @Test(arguments: [
        ("iPhone18,1", "18.6", "14.0"), ("Watch7,1", "10.0", "13.0"), ("Mac16,1", "15.2", "14.0"),
        ("AppleTV14,1", "17.0", "13.0"), ("RealityDevice14,1", "2.0", "14.0"), ("iPad16,3", "26.0", "15.0"),
        ("Mac18,5", "27.0", "27.0"),
    ])
    func theModelTellsWhichOSTheVersionIsOf(model: String, version: String, folder: String) {
        #expect(AppleDevice(model, osVersion: version).generation?.description == folder)
    }

    @Test func theDevicesGenerationComesFirstThenOlderThenNewer() {
        let order = AppleDevice("Mac15,6", osVersion: "14.1").generationOrder.map(\.description)
        #expect(Array(order.prefix(13)) == ["13.0", "12.0", "11.0", "10.0", "9.0", "8.0", "7.0", "6.0", "5.0", "4.0", "14.0", "15.0", "27.0"])
    }

    @Test func noVersionStartsAtTheNewest() {
        let order = AppleDevice("Mac15,6").generationOrder
        #expect(order.first! >= OSGeneration.newestKnown)
        #expect(order.last == OSGeneration.oldest)
    }

    @Test func aVersionNewerThanAnyKnownIsTriedFirst() {
        let order = AppleDevice("iPhone18,1", osVersion: "29.0").generationOrder.map(\.description)
        #expect(Array(order.prefix(4)) == ["29.0", "28.0", "27.0", "15.0"])
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
        #expect(urls.first == "https://appleid.cdn-apple.com/static/deviceImages-27.0/AirPods/AirPods_8212/online-infobox.png")
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
        (AppleDevice("AppleTV14,1", osVersion: "26.0"), "appleid.cdn-apple.com/static/deviceImages-15.0/AppleTV/AppleTV14,1/"),
        (AppleDevice("AppleTV14,1", osVersion: "27.0"), "appleid.cdn-apple.com/static/deviceImages-27.0/AppleTV/AppleTV14,1/"),
        // No 28 images yet, so the newest before it serves.
        (AppleDevice("Mac18,5", osVersion: "28.0"), "appleid.cdn-apple.com/static/deviceImages-27.0/Mac/Mac18,5/"),
        (AppleDevice("Device1,8212"), "appleid.cdn-apple.com/static/deviceImages-27.0/AirPods/AirPods_8212/"),
        (AppleDevice("Device1,8245"), "statici.icloud.com/fmipmobile/deviceImages-9.0/Accessory/AirPods_8245/"),
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
