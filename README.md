# GestionePuntiRipristino

Graphical tool for Windows 11 to create, view, modify and delete system restore points.

## Requirements

- **Windows 11** (also works on Windows 10)
- **PowerShell 5.1+**
- **Run as Administrator** (required for Volume Shadow Copy interaction)

## Installation

Download `GestionePuntiRipristino.ps1` and run as Administrator:

```powershell
.\GestionePuntiRipristino.ps1
```

Or from Explorer: right-click → **Run with PowerShell**.

## Features

- **List restore points** — shows all existing points with date and description
- **Delete** — removes a specific point with confirmation
- **Create** — creates a new restore point
- **Edit description** — customize point descriptions (saved in HKCU\Software\OttimizzaWindows)
- **Launch System Restore** — opens the native Windows interface (`rstrui.exe`)

## Security

- Strict UUID validation before every `vssadmin` operation
- Processes run via `Process.Start` without shell intermediaries
- 30-second timeout prevents hangs
- Audit logging to Windows Event Log (source: `OttimizzaWindows`)
- Descriptions stored in Registry (HKCU), not temp files

## License

MIT
