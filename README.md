# AppleDeviceImages

The picture of a specific Apple product: its model, its color, and the wallpaper of the OS it runs. These are the same images Settings shows in your Apple Account's device list.

<p align="center">
  <img src="https://appleid.cdn-apple.com/static/deviceImages-27.0/iPhone/iPhone18,1-3b3b3c-47ade5/online-infobox__3x.png" height="110" alt="iPhone 17 Pro">
  <img src="https://statici.icloud.com/fmipmobile/deviceImages-9.0/iPad/iPad16,3/online-infobox__3x.png" height="110" alt="iPad Pro">
  <img src="https://appleid.cdn-apple.com/static/deviceImages-27.0/Mac/Mac16,1/online-infobox__3x.png" height="110" alt="MacBook Pro">
  <img src="https://appleid.cdn-apple.com/static/deviceImages-27.0/Watch/Watch7,1-AlmPink/online-infobox__3x.png" height="110" alt="Apple Watch Series 9">
  <img src="https://appleid.cdn-apple.com/static/deviceImages-27.0/AirPods/AirPods_8212/online-infobox__3x.png" height="110" alt="AirPods Pro">
  <img src="https://appleid.cdn-apple.com/static/deviceImages-27.0/AppleTV/AppleTV14,1/online-infobox__3x.png" height="110" alt="Apple TV 4K">
  <img src="https://statici.icloud.com/fmipmobile/deviceImages-9.0/HomePod/AudioAccessory5,1/online-infobox__3x.png" height="110" alt="HomePod mini">
  <img src="https://appleid.cdn-apple.com/static/deviceImages-27.0/RealityDevice/RealityDevice14,1/online-infobox__3x.png" height="110" alt="Apple Vision Pro">
</p>

```swift
AppleDeviceImage("iPhone18,1")
```

## Installation

Add the package in Xcode (File › Add Package Dependencies…) or in `Package.swift`:

```swift
.package(url: "https://github.com/Eirperuier/AppleDeviceImages.git", from: "0.1.0")
```

It runs on iOS 15, macOS 12, tvOS 15, watchOS 8 and visionOS 1 or later.

## Usage

### SwiftUI

```swift
import AppleDeviceImages

AppleDeviceImage("Mac16,1")                       // resizable, fits its frame
    .frame(width: 120)

AppleDeviceImage(.current)                        // the device it runs on

AppleDeviceImage(AppleDevice("iPhone18,1", color: "3b3b3c-47ade5", osVersion: "27.0"))
```

`AppleDeviceImage` works like `AsyncImage`. You can shape the image and choose what shows while it loads:

```swift
AppleDeviceImage("Watch7,1", size: .small) { image in
    image.resizable().scaledToFit().shadow(radius: 2)
} placeholder: {
    Color.secondary.opacity(0.1)
}
```

### Anywhere else

```swift
let device = AppleDevice("iPhone18,1", color: "3b3b3c-47ade5", osVersion: "27.0")

let image = try await device.image()    // UIImage, or NSImage on macOS
let png   = try await device.imageData()
let url   = try await device.imageURL()
```

### Describing a device

| | Example | |
|---|---|---|
| `model` | `"iPhone18,1"`, `"Mac16,1"`, `"Watch7,1"`, `"Device1,8212"` | The model identifier; for AirPods and Beats, `Device1,` plus the Bluetooth product ID |
| `color` | `"3b3b3c-47ade5"`, `"AlmPink"`, `"1-9"` | Optional. Any of Apple's color codes ([below](#colors)); leave it out for the default color |
| `osVersion` | `"27.0"`, `"18.6"` | Optional. Picks the wallpaper; leave it out for the newest |

`AppleDevice.current` fills in this device's model and OS version.

Sizes are `.small` (the device list's image) and `.large` (the detail view's, the default). The scale follows the screen.

On macOS, `device.systemIcon` returns the system's own 1024 px icon for the model, offline. `image()` falls back to it when no CDN has the device, as for Apple Pencil or Studio Display.

## The wallpaper follows the OS

Apple renders each device with the wallpaper of the OS it runs. Pass `osVersion` to get the matching image.

<table>
  <tr>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-8.0/iPhone/iPhone11,8-3b3b3c-dcdede/online-infobox__3x.png" width="100"><br>iOS 12</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-9.0/iPhone/iPhone11,8-3b3b3c-dcdede/online-infobox__3x.png" width="100"><br>iOS 13</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-10.0/iPhone/iPhone11,8-3b3b3c-dcdede/online-infobox__3x.png" width="100"><br>iOS 14</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-11.0/iPhone/iPhone11,8-3b3b3c-dcdede/online-infobox__3x.png" width="100"><br>iOS 15</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-12.0/iPhone/iPhone11,8-3b3b3c-dcdede/online-infobox__3x.png" width="100"><br>iOS 16</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-13.0/iPhone/iPhone11,8-3b3b3c-dcdede/online-infobox__3x.png" width="100"><br>iOS 17</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-14.0/iPhone/iPhone11,8-3b3b3c-dcdede/online-infobox__3x.png" width="100"><br>iOS 18</td>
  </tr>
</table>

<table>
  <tr>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-12.0/Mac/Mac14,6/online-infobox__3x.png" width="160"><br>macOS 13</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-13.0/Mac/Mac14,6/online-infobox__3x.png" width="160"><br>macOS 14</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-14.0/Mac/Mac14,6/online-infobox__3x.png" width="160"><br>macOS 15</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-15.0/Mac/Mac14,6/online-infobox__3x.png" width="160"><br>macOS 26</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-27.0/Mac/Mac14,6/online-infobox__3x.png" width="160"><br>macOS 27</td>
  </tr>
</table>

<table>
  <tr>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-15.0/iPhone/iPhone18,1-3b3b3c-47ade5/online-infobox__3x.png" width="100"><br>iOS 26</td>
    <td align="center"><img src="https://appleid.cdn-apple.com/static/deviceImages-27.0/iPhone/iPhone18,1-3b3b3c-47ade5/online-infobox__3x.png" width="100"><br>iOS 27</td>
  </tr>
</table>

```swift
AppleDevice("iPhone11,8", color: "3b3b3c-dcdede", osVersion: "16.0")   // the iOS 16 image above
```

## Colors

Each product line encodes color its own way. Pass whichever code you have; the package recognizes the form.

| Product | Code | Example | Where it comes from |
|---|---|---|---|
| iPhone, iPad, iPod, HomePod | cover glass and housing hex | `3b3b3c-47ade5` (17 Pro, Deep Blue) | MobileGestalt `DeviceCoverGlassColor`, `DeviceHousingColor`; Apple Account device lists |
| Apple Watch | material and color | `AlmPink`, `AlmSpGry`, `CeramicWhite` | Apple Account device lists |
| Any, Find My images only | `DeviceColor`-`DeviceEnclosureColor` | `1-9` | MobileGestalt; Find My's `deviceColor`; the number in the macOS icon's name (`com.apple.iphone-17-pro-9.icns`) |
| AirPods Max (USB-C, 2) | Find My's number | `19` | `18` Midnight, `19` Starlight, `20` Blue, `21` Orange, `22` Purple |
| Mac | macOS's color number | `7` (MacBook Air M2, Midnight) | The `@ECOLOR=` in the model's icon tags in CoreTypes. Find My has the color for the Macs of 2021 and 2022 (as `0-7-0`), and `systemIcon` for every Mac sold in colors; the account CDN only has the default color. Intel Macs' icons use red, green and blue: `235,215,191` |
| Apple TV, Vision Pro, other AirPods | none | | |

The [color table](Colors/README.md) lists both codes for every color of every iPhone, iPad, iPod touch, HomePod and Apple Watch since 2013, with pictures. A few are still missing; if you own one, [adding it](CONTRIBUTING.md#add-a-color) takes a minute.

The OS-specific wallpapers come from Apple's account image CDN, which only has iPhones, iPads, Watches and HomePods in a color. Without a color code the package uses Find My's image of the model instead: the default color, with no OS-specific wallpaper.

A device's own color can only be read through private API (MobileGestalt) or over USB (`ideviceinfo`), so `AppleDevice.current` doesn't include it.

## Coverage

As checked in October 2026 against every model macOS 27 knows, and the products launched on October 13:

| Product line | OS wallpapers | Image | macOS icon |
|---|---|---|---|
| iPhone, iPad, iPod touch, Apple Watch | ✓ with a color | ✓ | ✓ |
| Mac, Apple TV, Vision Pro | ✓ | ✓ | ✓ |
| HomePod | ✓ with a color | ✓ | ✓ |
| AirPods, AirPods Pro, AirPods Max | most models | every model; AirPods Max in color | ✓ |
| Beats | | a few | ✓ |
| Apple Pencil, AirTag, Studio Display, Studio Display XDR | | | ✓ |
| HomeView | not yet | not yet | |

All 112 Macs since 2013 have images: every MacBook Air, MacBook Pro, MacBook Neo, iMac, iMac Pro, Mac mini, Mac Studio and Mac Pro. The two 13-inch MacBook Pros of 2020 with Intel chips (`MacBookPro16,2`, `16,3`) only have Find My's image, without wallpapers.

Neither CDN has the HomeView hub (`HomeAccessory17,1`, wall mounted `17,2`), the Apple TV 4K (4th generation, `AppleTV18,1`) or HomePod mini 2 (`AudioAccessory11,1`) yet; Apple adds images around when devices go on sale. The package already asks for them, trying both `HomeView` and `HomeAccessory` as HomeView's folder.

> [!IMPORTANT]
> The images come from Apple's servers through URLs Apple doesn't document, and they belong to Apple. They may change or disappear without notice. Check that your use is allowed before shipping it.

## How it works

Two CDNs serve these images.

### Apple's account CDN (what Settings shows)

```
https://appleid.cdn-apple.com/static/deviceImages-<version>/<Family>/<Model>[-<color>]/online-{sourcelist,infobox}[__2x|__3x].png
```

`<version>` names the year of the OS release, the same on every platform:

| Year | 2014–2024 | 2025 | 2026 on |
|---|---|---|---|
| Folder | the year − 2010: `4.0` (iOS 8) … `8.0` (iOS 12, macOS 10.14, watchOS 5) … `14.0` (iOS 18, macOS 15) | `15.0` (the 26 releases) | the OS version: `27.0`, presumably `28.0`, … |

There is no `16.0` to `26.0`. Devices launched in 2026, such as the Mac mini `Mac18,5`, only appear under `27.0`.

A device has images from the year it launched in onward. Years past its last OS repeat its last image, so an iPhone XR under `27.0` shows its iOS 18 picture.

The families are:
- `iPhone`, `iPad`, `iPod`, `Watch`, `AppleTV`, `RealityDevice`
- `HomePod` (models `AudioAccessoryN,N`)
- `Mac` for Apple silicon Macs, and `MacBookPro`, `iMac`, … for Intel ones
- `AirPods` (models `AirPods_<product ID>`)

A missing image answers 404. Clients it doesn't recognize, curl's default User-Agent among them, get 403 instead.

### Find My's CDN

```
https://statici.icloud.com/fmipmobile/deviceImages-9.0/<Family>/<Model>[-<DeviceColor>-<EnclosureColor>-0]/online-{sourcelist,infobox}[__2x|__3x].png
```

There is one image per model and color, with no OS wallpapers. Macs are filed by family (`MacBookPro/Mac16,1`), and AirPods and Beats as `Accessory/AirPods_<product ID>`. A missing image redirects to apple.com.

### Resolving a device

`device.imageURLCandidates()` lists every URL the image may be at, best first:

1. The account CDN at the device's OS year, then older years, then newer ones. "Newer" reaches the newest year this package knows (2026) or the year of the OS it runs on, whichever is later. Without an OS version, the newest year comes first. So images for a new OS are picked up as soon as Apple publishes them, provided Apple keeps naming folders after the OS version.
2. Find My in the device's color, then in the default color.

`image()`, `imageData()` and `imageURL()` try them in order and keep the result for the next call.

## Maintenance

`Scripts/ScanMacFamilies.swift` rebuilds the table of Mac models' Find My families from macOS's model list. Run it on the newest macOS after new Macs ship:

```sh
swift Scripts/ScanMacFamilies.swift
```

Without it, new Macs still work; they just try every family.

`Scripts/colors.py` keeps the [color table](Colors/README.md); see [CONTRIBUTING](CONTRIBUTING.md#maintaining-the-color-table).

To also run the tests that fetch from the CDNs:

```sh
APPLE_DEVICE_IMAGES_NETWORK=1 swift test
```

## Contributing

The color table grows from codes read on real devices. See [CONTRIBUTING](CONTRIBUTING.md) for how to add yours.

## Prior work

- [insidegui's notes on the iCloud device image URL format](https://gist.github.com/insidegui/a18124c0c573a4eb656f5c485ea7dae4) and its comments, which trace the color codes through the CDN's versions
- [AppleDB](https://github.com/littlebyteorg/appledb), whose device files name every color
- [FutureTap's DeviceColors sheet](https://docs.google.com/spreadsheets/d/0AnwN2mJZodDbdEloX3FRc21CWGt0NUR1R2o5ZTdQMlE), with housing and glass hex values of older models
- [MunkiReport](https://github.com/munkireport) and [munki-manager](https://github.com/joncrain/munki-manager), which build Find My URLs for Macs

## License

MIT
