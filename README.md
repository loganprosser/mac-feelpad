# Feelpad

A macOS menu-bar app that makes a Force Touch trackpad feel textured. Slide a finger across the glass and you feel ridges, a grid, or sand, even though the surface is flat.

Status: early prototype.

## Install

Paste this into Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/loganprosser/mac-feelpad/main/install.sh | bash
```

It downloads the latest release into Applications and opens it. Run it again to update. You can [read the script](install.sh) first; it is about 20 lines.

Or install by hand: download `Feelpad.zip` from [Releases](https://github.com/loganprosser/mac-feelpad/releases), unzip it, and drag `Feelpad.app` to Applications. The app is not signed with an Apple Developer ID, so the first time you open it macOS blocks it. Go to System Settings, then Privacy & Security, and click Open Anyway.

Feelpad appears as a hand icon in the menu bar, with no Dock icon. It does not start by itself after a restart yet. To start it at login, add it in System Settings, then General, then Login Items.

## Requirements

- Apple silicon Mac (M1 or newer) with a Force Touch trackpad, which includes every Apple silicon MacBook Air and MacBook Pro
- macOS 15 or later
- Tested only on one M3 Max MacBook Pro running macOS 26.6

To check a Mac's trackpad, run `ioreg -r -c AppleMultitouchDevice -l | grep ActuationSupported` and look for `Yes`.

## Usage

Click the menu-bar icon:

- Master switch: turns the texture on or off.
- Material: Ridges, Grid, or Sand.
- Strength: how hard each pulse is.
- Spacing: distance between texture features, 1 to 12 mm.
- One-finger movement and Two-finger scrolling: choose where the texture is active.
- Test pulse: fires one pulse so you can check strength.
- Quit Feelpad.

Settings are saved and restored the next time Feelpad opens.

The texture follows the number of fingers touching the pad. A thumb resting on the pad while another finger moves counts as two fingers, so you get the two-finger texture (and it moves at half the speed of your finger). Three or more fingers turn the texture off.

## Troubleshooting

- "No haptic trackpad found": this Mac's trackpad has no haptic actuator, or macOS did not expose it. Check with the `ioreg` command above.
- You feel nothing: press Test pulse, raise Strength, and make sure the master switch and the movement or scrolling toggle are on.
- It stopped working after a macOS update: the private framework may have changed. Please [open an issue](https://github.com/loganprosser/mac-feelpad/issues) with your Mac model and macOS version.

## Uninstall

Quit Feelpad from its menu and delete `Feelpad.app` from Applications. To also remove its saved settings, run `defaults delete org.feelpad.Feelpad`.

## Privacy

Feelpad has no network code. Touch positions are processed in memory on your Mac and never stored or sent anywhere. The only thing saved is your settings.

## How it works

Touch stream, then texture engine, then actuator.

1. Raw finger positions come from Apple's private MultitouchSupport framework.
2. The texture engine maps each position onto a texture laid over the glass in millimetres. When a finger crosses a feature, it asks for a pulse.
3. The trackpad's haptic actuator fires the pulse, also through the private framework.

The app does not request Accessibility permission by design (it uses no event tap). Permission behaviour across macOS versions is unverified.

## Caveats

- The framework is private. Any macOS update can break this.
- It cannot ship on the Mac App Store.
- An external Magic Trackpad is untested. When one is connected, Feelpad uses the built-in trackpad.
- The strength ladder is tuned by feel, not measured.
- Battery impact has not been measured.

## Build from source

Needs Apple Command Line Tools (`xcode-select --install`); Xcode is not needed.

```sh
./scripts/test.sh
./scripts/bundle.sh
open dist/Feelpad.app
```

`scripts/test.sh` is `swift test` plus a plugin path that Command Line Tools installs need for Swift Testing.

Code layout:

- `Sources/MTBridge`: C wrapper around the private framework (touch stream and actuator).
- `Sources/FeelCore`: settings and the texture engine. Pure Swift, unit-tested in `Tests/FeelCoreTests`.
- `Sources/Feelpad`: the menu-bar app and the service that connects touches to pulses.

To publish a release that the installer picks up, commit and push, then run `./scripts/release.sh 0.2.0` with the next version number (needs the GitHub CLI, `gh`).

## Contributing

Issues and pull requests are welcome. Good first ideas: new materials, tuning the strength ladder, start at login, and sound. Please run `./scripts/test.sh` before opening a pull request.

## Clean-room note

This is an independent implementation of the idea. It contains no code or assets from any commercial product. It is not affiliated with Apple.

## Credits and references

Prior open-source work on this private API:

- [niw/HapticKey](https://github.com/niw/HapticKey) (MIT)
- [Kyome22/OpenMultitouchSupport](https://github.com/Kyome22/OpenMultitouchSupport) (MIT)
- [MatMercer/mactic](https://github.com/MatMercer/mactic) (research notes)

## License

MIT, see [LICENSE](LICENSE).
