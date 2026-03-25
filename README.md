# NativeTouch

NativeTouch is a macOS utility to map specialized HID touch devices (Anmite / Prechen) as virtual mouse input across multiple displays.

## 🚀 What it does

- Detects Anmite and Prechen HID devices by vendor/product IDs.
- Converts touch events into mouse movement, click, scroll, and drag actions.
- Supports a “iOS-like” scroll mode (drag-style scrolling over target monitor) with inertia.
- Offers per-device settings in macOS menu bar:
  - Target monitor selection
  - iOS Scroll Mode toggle
  - Restore cursor position on touch-up
  - Invert X/Y axes
  - Swap X/Y axes
- Keeps a background accessory app (no dock icon) and prevents App Nap for uninterrupted operation.

## 🧩 Requirements

- macOS (Intel or Apple Silicon with compatibility of Swift frameworks)
- Xcode command-line tools installed (`xcode-select --install`)
- Privacy permissions:
  - Accessibility
  - Input Monitoring
  - (Optionally) Full Disk Access not required

## 🛠️ Build & Run

From project root:

```bash
./build.sh
open NativeTouch.app
```

`build.sh`:
- Compiles Swift sources in `src/*.swift`
- Creates `NativeTouch.app` bundle
- Converts icons from `icons/AppIcons/Assets.xcassets/AppIcon.appiconset` -> `NativeTouch.icns`
- Copies icon to `NativeTouch.app/Contents/Resources/` and sets `CFBundleIconFile` in `Info.plist`
- Generates `Info.plist` with required metadata
- Registers app with LaunchServices
- Applies ad-hoc codesign
- Resets TCC permissions with `tccutil reset All io.xperiments.nativetouch`

## ⚠️ First run

Upon first launch, grant these requests in System Settings > Privacy & Security:

1. Accessibility
2. Input Monitoring

If prompted to restart or re-open NativeTouch, follow instructions.

## 📁 Project structure

- `build.sh` – build script and permissions reset flow
- `src/main.swift` – main app lifecycle and HID listener
- `src/Config.swift` – vendor/product constants and logging
- `src/EventHandlers.swift` – touch handling, mode behavior, pointer generation
- `src/AppDelegate.swift` – menu and preference toggles, display change handling
- `NativeTouch.app/` – generated app bundle (build artifact)

## 🔧 Settings

Access the menu bar icon to adjust behavior per connected device.

- `Target Monitor` selects target display
- `iOS Scroll Mode` for touch drag scrolling
- `Restore on Touch Up` resets cursor return behavior
- `Invert X / Invert Y / Swap X/Y` for coordinate correction

## 💡 Advanced notes

- Uses `IOHIDManagerOpen(..., kIOHIDOptionsTypeSeizeDevice)` when possible to avoid OS device conflicts.
- Uses `CGEvent` injection for mouse and scrolling events.
- Maintains momentum and prevents accidental drag or text-select jitter.

## 🎮 HID Reports & Device Compatibility

NativeTouch is fundamentally a raw coordinate and tap interpreter, making it highly compatible with a large variety of generic touch displays and absolute pointing devices not officially supported by macOS. 

Specifically, the engine listens for the following **HID Usage Pages** and **Usages**:
- **Movement (Absolute Coordinates)**:
  - `Usage Page: 0x01` (Generic Desktop)
  - `Usage: 0x30` (X Axis) and `0x31` (Y Axis)
  - The raw integer values are normalized using the logical minimum and maximum values defined in the device's HID descriptor (`IOHIDElementGetLogicalMin/Max`), meaning it adapts automatically to screens of different physical resolutions.
- **Touch / Click Events**:
  - `Usage Page: 0x0D` (Digitizer) with `Usage: 0x42` (Tip Switch) — Standard for most modern touchscreen panels.
  - *Fallback*: `Usage Page: 0x09` (Button) with `Usage: 0x01` (Button 1) — Used by some older or more generic panels that identify simply as absolute mice.

### Adding your own device
Because it relies on these universal industry-standard HID descriptors, adapting NativeTouch for **other brands and models** is incredibly easy. 
If your touch monitor misbehaves on macOS but acts as standard USB HID, you can add it perfectly by simply putting its Vendor ID and Product ID into the `~/Library/Application Support/NativeTouch/devices.json` configuration file. No code changes required!

## 🐛 Troubleshooting

- If mapping seems stuck, quit and relaunch tools:
  - `killall NativeTouch`
  - `open NativeTouch.app`
- If permissions misbehave, run:
  - `tccutil reset All io.xperiments.nativetouch`
  - Re-open app and re-grant permissions.

## 📦 Packaging

The app is not signed on App Store for distribution. For local use, use ad-hoc signing in `build.sh`.

## 🤝 Contribution

Fork this repo, implement features, and open PR with details.

---

*Generated from source analysis on March 20, 2026.*
