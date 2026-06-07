# Get-InstalledApps

A fast, registry-based `Get-InstalledApps` function for PowerShell.

Lists installed software by reading the Windows registry uninstall keys instead of using `Win32_Product` — which is slow and triggers an MSI self-repair (consistency check) on every installed product just by being queried.

This reads the registry directly, so it's fast and has no side effects. It also picks up 32-bit apps that `Win32_Product` often misses.

## What it does

- Reads the three uninstall hives: 64-bit HKLM, 32-bit HKLM (WOW6432Node), and the current user's HKCU
- Returns **Name, Version, Publisher, InstallDate** for each app
- Skips system components and update entries, so the list matches what you see in **Apps & features**
- Optional `-Name` wildcard filter
- Fully self-contained — no dependencies, no modules to install
- Safe under `Set-StrictMode -Version Latest` (every registry read is guarded)

## Usage

Dot-source the file or just paste the function into your session, then:

```powershell
# all installed apps
Get-InstalledApps

# filter by name (wildcards supported)
Get-InstalledApps -Name *chrome*

# ten most recently installed
Get-InstalledApps | Sort-Object InstallDate -Descending | Select-Object -First 10
```

## Requirements

- Windows
- PowerShell 5.1+ (works on PowerShell 7 too)

## Notes

This currently reads the **current user's** HKCU hive only — it doesn't enumerate other users' hives when run as admin. If that matters for your use case, that part is easy to extend.

## License

MIT — free to use, modify, and share. Provided "as is", without warranty.
