# GestionePuntiRipristino

Grafisches Tool für Windows 11 zum Erstellen, Anzeigen, Ändern und Löschen von Systemwiederherstellungspunkten.

## Anforderungen

- **Windows 11** (funktioniert auch unter Windows 10)
- **PowerShell 5.1+**
- **Als Administrator ausführen** (erforderlich für Volume Shadow Copy)

## Installation

Laden Sie `GestionePuntiRipristino.ps1` herunter und führen Sie es als Administrator aus:

```powershell
.\GestionePuntiRipristino.ps1
```

Oder im Explorer: Rechtsklick → **Mit PowerShell ausführen**.

## Funktionen

- **Wiederherstellungspunkte auflisten** — zeigt alle vorhandenen Punkte mit Datum und Beschreibung
- **Löschen** — entfernt einen bestimmten Punkt mit Bestätigung
- **Erstellen** — erstellt einen neuen Wiederherstellungspunkt
- **Beschreibung bearbeiten** — personalisiert Punktbeschreibungen (gespeichert in HKCU\Software\OttimizzaWindows)
- **Systemwiederherstellung starten** — öffnet die native Windows-Oberfläche (`rstrui.exe`)

## Sicherheit

- Strenge UUID-Validierung vor jedem `vssadmin`-Befehl
- Prozesse via `Process.Start` ohne Shell-Intermediäre
- 30-Sekunden-Timeout verhindert Hänger
- Audit-Logging im Windows-Ereignisprotokoll (Quelle: `OttimizzaWindows`)
- Beschreibungen in der Registry (HKCU) gespeichert, nicht in temporären Dateien

## Lizenz

MIT
