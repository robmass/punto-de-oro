# Sideloading onto the watch

Punto de Oro is installed straight onto the watch from the command line, signed by the free
Personal Team `PYTG8F6332`. A free-team build expires after **7 days**, so re-install it at
least once a week.

## One-time prerequisites

1. **Developer Mode on the iPhone.** Cable the paired iPhone to the Mac, then turn on
   Settings → Privacy & Security → Developer Mode on the phone and restart when asked.
2. **Developer Mode on the watch.** The toggle only appears on the watch once the iPhone has
   been cabled to the Mac with its own Developer Mode on. Turn on
   Settings → Privacy & Security → Developer Mode on the watch and restart when asked.
3. **Watch on the same Wi-Fi as the Mac.** In the Watch app on the iPhone, turn off the
   "Mirror iPhone" airplane-mode setting so the watch keeps its own Wi-Fi.
4. **Trust the developer.** After the first install, trust the Personal Team's developer
   profile on the watch if prompted.

## Build, install, launch

```sh
xcodegen generate        # only after editing project.yml
xcodebuild -project PuntoDeOro.xcodeproj -scheme PuntoDeOro \
  -destination 'generic/platform=watchOS' -derivedDataPath build \
  -allowProvisioningUpdates build

xcrun devicectl list devices    # find the watch's UDID
xcrun devicectl device install app --device <udid> build/Build/Products/Debug-watchos/PuntoDeOro.app
xcrun devicectl device process launch --device <udid> com.robmass.PuntoDeOro
```

## Tests

Run the tests on the Series 9 (45mm) simulator, which needs no watch:

```sh
xcodebuild test -project PuntoDeOro.xcodeproj -scheme PuntoDeOro \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -derivedDataPath build
```

One-time setup, if the simulator is missing:

```sh
xcodebuild -downloadPlatform watchOS
xcrun simctl create "Apple Watch Series 9 (45mm)" \
  com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-9-45mm \
  com.apple.CoreSimulator.SimRuntime.watchOS-27-0
```

To run them on the watch instead, use `-destination 'platform=watchOS,id=<udid>'` and add
`-allowProvisioningUpdates`. The watch must be **unlocked with its screen on**. Otherwise
launching the app or the test runner fails with *"Navigation away from clock is not allowed
due to one or more active system states"*.
