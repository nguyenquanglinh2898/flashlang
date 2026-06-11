# FlashLang

This app helps you learn English passively by displaying notifications about new words you've previously added at your preferred times.

## Build APKs

Build the phone APK only:

```bash
bash scripts/build_phone_release.sh
```

Output:

```text
build/app/outputs/apk/release/flashlang-phone-release.apk
```

Build the Wear OS APK only:

```bash
bash scripts/build_watch_release.sh
```

Output:

```text
build/wear/outputs/apk/release/flashlang-watch-release.apk
```

## Debug Install

Do not use `flutter run` for the watch. `flutter run` always launches the Flutter phone app from `android/app`, even if you pick a Wear device.

Install the phone debug app:

```bash
bash scripts/install_phone_debug.sh <adb-serial-optional>
```

Install the watch debug app:

```bash
bash scripts/install_watch_debug.sh <adb-serial-optional>
```

Run the watch app in the closest equivalent to `flutter run`:

```bash
bash scripts/run_watch_debug.sh
```

This command now auto-detects the connected Wear OS device and installs the watch build there.

List connected Android and Wear OS devices:

```bash
bash scripts/list_android_devices.sh
```
