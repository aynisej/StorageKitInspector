# StorageKitInspector

StorageKitInspector is a macOS StorageKit runtime research tool with a native AppKit report viewer.

It explores selected private StorageKit object graphs, records discovered classes and relationships, and exports JSON reports for later analysis.

## Status

This project uses private Apple frameworks:

- `/System/Library/PrivateFrameworks/StorageKit.framework`
- `/System/Library/PrivateFrameworks/StorageManagement.framework`

It is intended for local research and diagnostics. It is not suitable for App Store distribution.

## Requirements

- macOS
- Xcode

## Build

Open `StorageKitInspector.xcodeproj` in Xcode and build the `StorageKitInspector` scheme.

From the command line:

```sh
xcodebuild -project StorageKitInspector.xcodeproj -scheme StorageKitInspector -configuration Release build
```

Build a `.app` bundle for GitHub Releases:

```sh
chmod +x Scripts/package-app.sh
Scripts/package-app.sh
```

The bundle is created at:

```text
dist/StorageKitInspector.app
```

## Run

The default run mode explores disk-related StorageKit objects and opens the native GUI:

```sh
StorageKitInspector
```

Available scenarios:

```sh
StorageKitInspector disk
StorageKitInspector apfs
StorageKitInspector filesystem
StorageKitInspector analytics
StorageKitInspector manager
StorageKitInspector all
StorageKitInspector classes
```

Run without the GUI:

```sh
StorageKitInspector disk --no-gui
```

Inspect a single runtime class:

```sh
StorageKitInspector --inspect SKManager
```

## Output

Scenario runs write reports into `ExplorerExports/`:

- `<scenario>-tree.json`
- `<scenario>-relationships.json`
- `<scenario>-report.json`
- `<scenario>-report.html`

The native GUI shows the same data in tabs:

- Summary
- Classes
- Tree
- Relationships
- Errors

## Safety

The explorer intentionally avoids mutating selectors and blocks known unstable Foundation/runtime paths during automated traversal. It also restricts recursive object exploration to StorageKit-related class prefixes.
