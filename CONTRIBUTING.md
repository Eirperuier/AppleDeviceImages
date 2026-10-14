# Contributing

## Add a color

Apple's servers know each color by a code no one has published. The [color table](Colors/README.md) found most of them by comparing images, but some colors only a real device can settle. If you own one of the [wanted colors](Colors/README.md#wanted), or any Apple device at all, its picture's address helps. One iPhone color usually fills in every iPhone model with the same color.

1. On a computer, sign in at [account.apple.com](https://account.apple.com) and open **Devices**.
2. Right-click a device's picture and choose **Copy Image Address**.
3. [Open an "Add a color" issue](https://github.com/Eirperuier/AppleDeviceImages/issues/new?template=color.yml) and paste it, with the color's name if you know it.

For several devices at once, open the browser's console on that page (Safari: Develop › Show JavaScript Console; Chrome: View › Developer › JavaScript Console), run this, and paste the result:

```js
copy([...new Set([...document.images].map(i => i.currentSrc || i.src).filter(s => s.includes('deviceImages')))].join('\n'))
```

An address holds only the model and its color, such as `https://appleid.cdn-apple.com/static/deviceImages-14.0/iPhone/iPhone13,1-3b3b3c-a2d7c2/online-sourcelist__2x.png`: an iPhone 12 mini, black front glass, green housing. Nothing in it identifies you or the device.

A workflow then checks the address against Apple's servers, tries the color's value on every other model, replies on the issue with what it found, and opens a pull request that updates the table.

## Other changes

Issues and pull requests are welcome. `swift test` runs the tests; `APPLE_DEVICE_IMAGES_NETWORK=1 swift test` adds the ones that fetch from Apple's servers.

## Maintaining the color table

`Scripts/colors.py` keeps `Colors/colors.json` and writes `Colors/README.md` from it. It needs Pillow and NumPy (`pip install pillow numpy`).

```sh
python3 Scripts/colors.py add 'https://appleid.cdn-apple.com/…/online-infobox.png' 'Cosmic Orange'
python3 Scripts/colors.py scan 'iPhone 18 Pro'   # new products, once AppleDB lists them; no names rescans all (slow)
python3 Scripts/colors.py report                 # after editing colors.json by hand
```

The workflow needs the `color` label and, under Settings › Actions › General, "Allow GitHub Actions to create and approve pull requests". When two color pull requests conflict, merge one and edit the other's issue (any change) to run the workflow again.
