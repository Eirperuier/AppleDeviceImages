# AppleDeviceImages

Images of a specific Apple product (model, color, and the wallpaper of the OS it runs) as Settings shows them in the Apple Account device list, from the CDNs Apple's own apps use.

```swift
import AppleDeviceImages

let request = DeviceImageRequest(
    model: "iPhone18,1",
    color: DeviceColor(deviceColor: 1, enclosureColor: 9, account: "3b3b3c-47ade5"),
    generation: OSGeneration(.iOS, "26.1"),
    style: .infobox,
    scale: 3
)
let (url, png) = try await DeviceImageLoader.shared.image(for: request)
```

On macOS, `SystemDeviceIcon.image(forModel: "iPhone18,1")` returns the system's own 1024 px icon offline.

> [!IMPORTANT]
> Neither CDN is a documented API, and the images belong to Apple. They can change or disappear without notice. Check that your use is allowed before shipping it.

## Where the images come from

### Account CDN: the Settings device list

```
https://appleid.cdn-apple.com/static/deviceImages-<generation>.0/<Family>/<Model>[-<color>]/online-<style>[__2x|__3x].png
```

Apple's account servers return these URLs with each device (`listImageLocation`, `infoboxImageLocation`, …). Settings, iCloud and the Apple Account web pages show them.

**Generation** is the year of the OS whose wallpaper the device shows. It is the same across platforms: `year − 2010`.

| Generation | 4 | … | 8 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|
| Releases | iOS 8 (2014) | … | iOS 12, macOS 10.14, watchOS 5 | iOS 15 | iOS 16, macOS 13, tvOS 16 | iOS 17, watchOS 10, visionOS 1 | iOS 18, macOS 15 | the 26 releases |

A device has images from the generation it launched with up to the newest one. Generations after the last OS it supports repeat its last image. The server picks the generation from the OS the device reports. `OSGeneration(platform, version)` does that mapping.

| Family | Model | Color |
|---|---|---|
| `iPhone`, `iPad`, `iPod` | `iPhone18,1` | Required (except early models): `<cover glass>-<housing>` hex, e.g. `3b3b3c-47ade5` |
| `Watch` | `Watch7,1` | Required: material and color, e.g. `AlmSpGry`, `AlmPink`, `CeramicWhite` |
| `HomePod` | `AudioAccessory5,1` | Required: hex pair as for iPhone |
| `Mac` | `Mac16,1` (Apple silicon) | None |
| `MacBookPro`, `iMac`, … | `MacBookPro15,1` (Intel) | None |
| `AppleTV` | `AppleTV14,1` | None |
| `RealityDevice` | `RealityDevice14,1` | None |
| `AirPods` | `AirPods_8212` (Bluetooth product ID) | None |

A missing image answers 404. Requests with a non-browser `User-Agent` (curl's default) get 403 on cache misses, whether or not the image exists. `URLSession`'s default agent is fine.

### Find My CDN: one image per model and color

```
https://statici.icloud.com/fmipmobile/deviceImages-9.0/<Family>/<Model>[-<DeviceColor>-<DeviceEnclosureColor>-0]/online-<style>[__2x|__3x].png
```

- **No wallpaper generations.** The image doesn't follow the OS version.
- **The color is optional.** Leaving it out gives the default color. The numbers are MobileGestalt's `DeviceColor` and `DeviceEnclosureColor`. On macOS they match the suffix of the device's icon in `CoreTypes.bundle` (`com.apple.iphone-17-pro-9.icns` → `1-9-0`).
- **Macs are filed by family** (`MacBookPro/Mac16,1`).
- **AirPods and Beats** are filed as `Accessory/AirPods_<product ID>` and `Accessory/Beats_<product ID>`.
- **A missing image** redirects to apple.com.

## How a request is resolved

`DeviceImageRequest.candidateURLs` lists, best first:

1. **Account CDN at the requested generation**, then older generations, then newer ones; with no generation given, newest first. This step is skipped for families that need a color when no account color is given.
2. **Find My CDN**, in the color first and then in the default one.

`DeviceImageLoader` fetches them in order and returns the first image. It remembers which URL worked for each request.

## Coverage

As checked in October 2026 against the models macOS 27's CoreTypes knows:

| Product line | Account CDN | Find My CDN | macOS icon |
|---|---|---|---|
| iPhone, iPad, iPod touch | ✓ with color | ✓ | ✓ |
| Apple Watch | ✓ with color | ✓ | ✓ |
| Mac | ✓ | ✓ | ✓ |
| Apple TV, HomePod, Vision Pro | ✓ | ✓ | ✓ |
| AirPods | most product IDs | most product IDs | ✓ |
| Beats | – | a few | ✓ |
| Apple Pencil, AirTag, Studio Display | – | – | ✓ |

## Getting a device's color

- **Account device lists.** The image URLs already contain the color.
- **Find My.** Device records carry `deviceColor` and `rawDeviceModel`.
- **On the device.** MobileGestalt's `DeviceCoverGlassColor` and `DeviceHousingColor` give the hex pair; `DeviceColor` and `DeviceEnclosureColor` give the numbers. These are private APIs, so this package doesn't call them.
- **Over USB.** `ideviceinfo` / lockdownd report the same keys.

## Maintenance

`Scripts/ScanMacFamilies.swift` rebuilds the `MacNN,N` → Find My family table from the local CoreTypes and the CDN. Run it on the newest macOS after new Macs ship:

```sh
swift Scripts/ScanMacFamilies.swift
```

Unknown Mac models still work without it; they just try every family.

Run the tests that hit the CDNs with:

```sh
APPLE_DEVICE_IMAGES_NETWORK=1 swift test
```

## Prior work

- [insidegui's notes on the iCloud device image URL format](https://gist.github.com/insidegui/a18124c0c573a4eb656f5c485ea7dae4) and its comments, which trace the color codes through their versions
- [MunkiReport](https://github.com/munkireport) and [munki-manager](https://github.com/joncrain/munki-manager), which build Find My URLs for Macs

## License

MIT
