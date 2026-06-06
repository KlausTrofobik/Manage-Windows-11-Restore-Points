# GestionePuntiRipristino

Tool grafico per Windows 11 che permette di creare, visualizzare, modificare ed eliminare punti di ripristino del sistema.

## Requisiti

- **Windows 11** (funziona anche su Windows 10)
- **PowerShell 5.1+**
- **Esecuzione come Amministratore** (necessaria per interagire con Volume Shadow Copy)

## Installazione

Scarica `GestionePuntiRipristino.ps1` ed eseguilo come Amministratore:

```powershell
.\GestionePuntiRipristino.ps1
```

Oppure da Explorer: tasto destro → **Esegui con PowerShell**.

## Funzionalità

- **Elenco punti di ripristino** — mostra tutti i punti esistenti con data e descrizione
- **Eliminazione** — rimuove un punto specifico con conferma
- **Creazione** — crea un nuovo punto di ripristino
- **Modifica descrizione** — personalizza la descrizione dei punti (salvata in HKCU\Software\OttimizzaWindows)
- **Avvia Ripristino Sistema** — apre l'interfaccia nativa di Windows (`rstrui.exe`)

## Sicurezza

- Validazione UUID rigida prima di ogni operazione con `vssadmin`
- Processi eseguiti con `Process.Start` senza shell intermedi
- Timeout massimo di 30 secondi per evitare blocchi
- Audit logging su Windows Event Log (sorgente: `OttimizzaWindows`)
- Descrizioni salvate nel Registry (HKCU), non in file temporanei

## Licenza

MIT
