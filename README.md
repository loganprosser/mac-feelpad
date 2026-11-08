# Feelpad

A macOS menu-bar app that makes a Force Touch trackpad feel textured. Slide a finger across the glass and you feel ridges, a grid, or sand, even though the surface is flat.

Status: early prototype.

## Requirements

- Apple silicon Mac with a Force Touch trackpad
- macOS 15 or later
- Tested only on one M3 Max MacBook Pro running macOS 26.6
- To build: Apple Command Line Tools (Xcode is not needed), Swift 6

## Build and run

```sh
./scripts/test.sh
./scripts/bundle.sh
open dist/Feelpad.app
```

`scripts/test.sh` is `swift test` plus a plugin path that Command Line Tools installs need for Swift Testing.

The bundle is ad-hoc signed, so it runs on the machine that built it. It appears as an icon in the menu bar, with no Dock icon.

## Usage

Click the menu-bar icon:

- Master switch: turns the texture on or off.
- Material: Ridges, Grid, or Sand.
- Strength: how hard each pulse is.
- Spacing: distance between texture features, 1 to 12 mm.
- One-finger movement and Two-finger scrolling: choose where the texture is active.
- Test pulse: fires one pulse so you can check strength.
- Quit Feelpad.

## How it works

Touch stream, then texture engine, then actuator.

1. Raw finger positions come from Apple's private MultitouchSupport framework.
2. The texture engine maps each position onto a texture laid over the glass in millimetres. When a finger crosses a feature, it asks for a pulse.
3. The trackpad's haptic actuator fires the pulse, also through the private framework.

The app does not request Accessibility permission by design (it uses no event tap). Permission behaviour across macOS versions is unverified.

## Caveats

- The framework is private. Any macOS update can break this.
- It cannot ship on the Mac App Store.
- An external Magic Trackpad is untested.
- The strength ladder is tuned by feel, not measured.

## Clean-room note

This is an independent implementation of the idea. It contains no code or assets from any commercial product. It is not affiliated with Apple.

## Credits and references

Prior open-source work on this private API:

- [niw/HapticKey](https://github.com/niw/HapticKey) (MIT)
- [Kyome22/OpenMultitouchSupport](https://github.com/Kyome22/OpenMultitouchSupport) (MIT)
- [MatMercer/mactic](https://github.com/MatMercer/mactic) (research notes)

## Contributing

Ideas welcome: new materials, tuning the strength ladder, and sound.

## License

MIT, see [LICENSE](LICENSE).
