First macOS arm64 application release.

### Features
- Browse a selected folder and sort its contents by recursively calculated size.
- Move selected items to Trash with a confirmation prompt.
- Permanently remove selected items from the current user's home folder after listing processes that have them open. The app sends `SIGTERM` and escalates to `SIGKILL` for matching user processes that remain active.
- Keep the StorageKit runtime research scenarios and report exports available from the command line.

### Install
Download and unzip `StorageKitInspector-macOS-arm64.zip`, then move `StorageKitInspector.app` to Applications. The app is ad-hoc signed and not notarized; macOS may require Control-click → Open the first time.
