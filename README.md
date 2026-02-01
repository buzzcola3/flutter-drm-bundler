# FlutterPi-plugin-bridge-tool
A tool to make developing &amp; distributing flutter apps for https://github.com/ardera/flutter-pi easier.

## 📰 News
- Building & Running apps on [meta-flutter](https://github.com/meta-flutter/meta-flutter) yocto distros works now,
  via the `--fs-layout=meta-flutter` option to `FlutterPi-plugin-bridge-tool devices add`, `FlutterPi-plugin-bridge-tool build`.
- RISC-V 64-bit is now supported as a target & host platform.
- The flutter-pi binary to bundle can now be explicitly specified using
  `--flutterpi-binary=...`

## Setup
This fork is not published on pub.dev. Build the tool locally:

```shell
flutter pub get
dart compile exe bin/flutterpi_tool.dart -o build/flutterpi_tool
```

Use the local executable:

```shell
./build/flutterpi_tool --help
```

## Usage
```console
$ ./build/flutterpi_tool --help
FlutterPi-plugin-bridge-tool - a tool to make development & distribution of flutter-pi apps easier.

Usage: flutterpi_tool <command> [arguments]

Global options:
-h, --help         Print this usage information.
-d, --device-id    Target device id or name (prefixes allowed).

Other options
    --verbose      Enable verbose logging.

Available commands:

Flutter-Pi Tool
  precache   Populate the FlutterPi-plugin-bridge-tool cache of binary artifacts.

Project
  build      Builds a flutter-pi asset bundle.
  run        Run your Flutter app on an attached device.

Tools & Devices
  devices    List & manage FlutterPi-plugin-bridge-tool devices.

Run "./build/flutterpi_tool help <command>" for more information about a command.
```

## Build any Flutter app with Linux plugins (short steps)
1. Build FlutterPi-plugin-bridge with the GTK shim enabled.
  - Optional: build plugin(s) into the binary using repo-specific CMake flags (e.g. `-DBUILD_OPENAUTOFLUTTER_PLUGIN=ON`).
2. Build your app’s Linux plugin .so files:
  - `flutter build linux --debug` (or `--release`) in your app.
3. Create the flutter-pi bundle with this tool:
  - `./build/flutterpi_tool build --arch=arm64 --cpu=generic --debug --flutterpi-binary=/path/to/flutter-pi`
4. Run the bundle with the generated run script (sets LD_LIBRARY_PATH and uses bundled flutter-pi):
  - `cd build/flutter-pi/arm64-generic`
  - `./run_bundle.sh . --debug`

Notes:
- Plugins are discovered from `.flutter-plugins-dependencies` and the built `.so` files.
- For KMS/DRM, run on a VT (no desktop) or ensure DRM permissions are correct.

## Examples
### 1. Adding a device
```console
$ ./build/flutterpi_tool devices add pi@pi5
Device "pi5" has been added successfully.
```

### 2. Adding a device with an explicit display size of 285x190mm, and a custom device name
```console
$ ./build/flutterpi_tool devices add pi@pi5 --display-size=285x190 --id=my-pi
Device "my-pi" has been added successfully.
```

### 3. Adding a device that uses [meta-flutter](https://github.com/meta-flutter/meta-flutter)
```console
$ ./build/flutterpi_tool devices add root@my-yocto-device --fs-layout=meta-flutter
```

### 4. Listing devices
```console
$ ./build/flutterpi_tool devices
Found 1 wirelessly connected device:
  pi5 (mobile) • pi5 • linux-arm64 • Linux

If you expected another device to be detected, try increasing the time to wait
for connected devices by using the "FlutterPi-plugin-bridge-tool devices list" command with
the "--device-timeout" flag.
...
```

### 5. Creating and running an app on a remote device
```console
$ flutter create hello_world && cd hello_world

$ ./build/flutterpi_tool run -d pi5
Launching lib/main.dart on pi5 in debug mode...
Building Flutter-Pi bundle...
Installing app on device...
...
```

### 6. Running the same app in profile mode
```
$ ./build/flutterpi_tool run -d pi5 --profile
```
