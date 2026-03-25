# NativeTouch

NativeTouch is a lightweight macOS utility that lets compatible touch screens and digitizers control your cursor in a predictable way.

Instead of built-in touch behavior that may feel noisy and inconsistent, NativeTouch maps touch input to pointer movement, clicks, dragging, and optional scrolling using a dedicated touchscreen profile.

## Features

- Auto-discover touch/digitizer devices and handle hot-plug connect/disconnect
- Per-device settings with menu bar status and quick enable/disable
- Target monitor selector (map touch to specific display)
- Normalized tap, drag, and click gestures
- Long-press for right-click behavior
- Optional scroll mode with momentum support
- Invert X/Y, swap axes, and restore cursor position on release
- Optional launch at login integration

## Supported Interactions

- Left click
- Right click (long press)
- Drag and cursor movement
- Scroll gestures from touch motion

## Limitations

- Not a general mouse emulator for every USB HID input
- Not designed for handwriting/pen pressure functionality
- Not a gesture ioctl layer (no pinch/zoom/two-finger Scroll) beyond the defined touch-to-pointer mapping

## Install

1. Clone repository:

```bash
git clone https://github.com/xperiments/NativeTouch.git
cd NativeTouch
```

2. Build:

```bash
./build.sh
```

3. Open app:

```bash
open NativeTouch.app
```

> Do not run the app with `sudo`.

4. Grant Accessibility permissions when prompted.

## Package for distribution

```bash
./pack.sh
```

This creates `NativeTouch.zip` containing `install.command` and the app bundle.

## Development notes

- Main code paths:
  - `src/main.swift` sets up IOHID manager and run loop
  - `src/TouchState.swift` stores device profiles/configuration
  - `src/TouchHIDHandlers.swift` handles device add/remove/input callbacks
- `src/MenuBuilder.swift` and `src/SettingsWindowController.swift` handle the UI and settings panel

## Troubleshooting

- If the app captures your normal mouse, make sure the device is recognized as digitizer during discovery and not a standard mouse/trackball.
- If touch behaves incorrectly, adjust `ScrollMode`, axis invert, and display target in settings.

## Contributing

- Improve HID filtering
- Add more device-specific presets
- Add proper from-scratch gestures and multi-touch emulation

## License

MIT License

Copyright (c) 2026 Pedro Casaubon

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

