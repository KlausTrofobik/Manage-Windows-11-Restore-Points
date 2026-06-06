# GestionePuntiRipristino

Outil graphique pour Windows 11 permettant de créer, visualiser, modifier et supprimer des points de restauration système.

## Prérequis

- **Windows 11** (fonctionne aussi sur Windows 10)
- **PowerShell 5.1+**
- **Exécuter en tant qu'Administrateur** (nécessaire pour interagir avec Volume Shadow Copy)

## Installation

Téléchargez `GestionePuntiRipristino.ps1` et exécutez-le en tant qu'Administrateur :

```powershell
.\GestionePuntiRipristino.ps1
```

Ou depuis l'Explorateur : clic droit → **Exécuter avec PowerShell**.

## Fonctionnalités

- **Lister les points** — affiche tous les points existants avec date et description
- **Supprimer** — supprime un point spécifique avec confirmation
- **Créer** — crée un nouveau point de restauration
- **Modifier la description** — personnalise les descriptions (enregistrées dans HKCU\Software\OttimizzaWindows)
- **Lancer la Restauration** — ouvre l'interface native Windows (`rstrui.exe`)

## Sécurité

- Validation UUID stricte avant chaque opération `vssadmin`
- Processus exécutés avec `Process.Start` sans interpréteur shell
- Timeout de 30 secondes pour éviter les blocages
- Journalisation dans Windows Event Log (source : `OttimizzaWindows`)
- Descriptions stockées dans le Registre (HKCU), pas dans des fichiers temporaires

## Licence

MIT
