# Realme Buds Controller

## Installation

Open `Realme Buds Controller.dmg`, then drag
`Realme Buds Controller.app` into the Applications folder.

## Signing status

The app in this build was signed with: **Ad-hoc**.

This build is not notarized. No notarization has been claimed or performed.

An ad-hoc signed app is not suitable for distribution to other Macs.
It must be installed and opened on the Mac used for local testing.

No notarization claim is made unless notarization is separately performed and
recorded by the distributor.

## Developer ID and notarization

For distribution to other Macs:

1. Install an Apple Developer "Developer ID Application" certificate.
2. Set `SIGNING_IDENTITY` to that exact identity when running `build.sh`.
3. Submit the resulting DMG or app with `notarytool`:
   `xcrun notarytool submit "dist/Realme Buds Controller.dmg" --apple-id ... --team-id ... --password ... --wait`
4. Staple the ticket:
   `xcrun stapler staple "dist/Realme Buds Controller.dmg"`
   `xcrun stapler staple "dist/Realme Buds Controller.app"`
5. Verify:
   `spctl -a -t exec -vv "dist/Realme Buds Controller.app"`
   `spctl -a -t open --context context:primary-signature -vv "dist/Realme Buds Controller.dmg"`

## Bluetooth permission

On first launch, macOS may ask for Bluetooth access. Approve it in:

System Settings > Privacy & Security > Bluetooth

## Preferences

User preferences are stored under:

`~/Library/Application Support/Realme Buds Controller/preferences.json`

This location persists across app upgrades. Appearance preferences are
also stored in the application-support preference file and retain legacy
UserDefaults compatibility.

## Runtime dependencies

The app is a native macOS executable. It does not require Xcode, VS Code,
Copilot, SwiftPM, or the development-folder resource paths at runtime.

Product resources are included inside the application bundle.
