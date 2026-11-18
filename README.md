# StorageKitInspector

StorageKitInspector is a macOS storage browser and StorageKit runtime research tool.

The default app window lets you choose a folder, sort its immediate contents by their recursively calculated size, and move selected items to the macOS Trash. Command-line scenarios continue to inspect StorageKit runtime objects and export reports.

It explores selected private StorageKit object graphs, records discovered classes and relationships, and exports JSON reports for later analysis.

## Status

This project uses private Apple frameworks:

- `/System/Library/PrivateFrameworks/StorageKit.framework`
- `/System/Library/PrivateFrameworks/StorageManagement.framework`

It is intended for local research and diagnostics. It is not suitable for App Store distribution.

## Requirements

- macOS
- Swift 6.4 or newer (Xcode Command Line Tools are sufficient)

## Build

Build a macOS arm64 `.app` bundle, drag-and-drop DMG, and ZIP archive:

```sh
chmod +x Scripts/package-app.sh
Scripts/package-app.sh
```

The bundle and release archive are created at:

```text
dist/StorageKitInspector.app
dist/StorageKitInspector-macOS-arm64.dmg
dist/StorageKitInspector-macOS-arm64.zip
```

To install from the DMG, open it and drag `StorageKitInspector.app` onto the Applications shortcut.

The app bundle is ad-hoc signed and is not notarized. macOS may require opening it from Finder with Control-click → Open the first time.

## Run

Launch the app UI by running the executable without arguments:

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

The research report GUI shows the same data in tabs:

- Summary
- Classes
- Tree
- Relationships
- Errors

## Safety

The explorer intentionally avoids mutating selectors and blocks known unstable Foundation/runtime paths during automated traversal. It also restricts recursive object exploration to StorageKit-related class prefixes.

The storage browser sends ordinary deletions to Trash and asks for confirmation. It also offers an explicitly irreversible action for items inside the current user's home folder: it lists processes reported by `lsof`, sends `SIGTERM`, escalates still-running matching user processes to `SIGKILL`, then permanently removes the selected items. System-owned and protected paths are excluded. Forced termination can lose unsaved work.
