# Guida Setup GitHub — GestionePuntiRipristino

## 1. Crea il repository su GitHub

1. Vai su https://github.com/new
2. Nome repo: `GestionePuntiRipristino`
3. Descrizione: `Tool grafico per gestire i punti di ripristino di Windows 11`
4. Pubblico o privato (a scelta)
5. **Non** inizializzare con README, .gitignore o license (li abbiamo già)

## 2. Carica i file

```bash
# Inizializza git nella cartella locale
cd C:\OttimizzaWindows
git init

# Aggiungi tutti i file del progetto standalone
git add GestionePuntiRipristino.ps1
git add README.md
git add GITHUB_SETUP_GUIDE.md

# (opzionale) Aggiungi anche la presentazione
git add presentation.html

# Primo commit
git commit -m "Initial commit: Gestione Punti Ripristino v1.0"

# Collega il repository remoto
git remote add origin https://github.com/<TUO_USERNAME>/GestionePuntiRipristino.git

# Push su GitHub
git push -u origin main
```

> Se il branch locale si chiama `master` invece di `main`:
> ```bash
> git branch -m master main
> git push -u origin main
> ```

## 3. (opzionale) Crea una release

1. Su GitHub, vai a **Releases** → **Create a new release**
2. Tag: `v1.0`
3. Titolo: `v1.0 — Prima release stabile`
4. Allega `GestionePuntiRipristino.ps1` come asset

## 4. Struttura consigliata del repo

```
GestionePuntiRipristino/
├── GestionePuntiRipristino.ps1   # Script principale
├── README.md                      # Documentazione
├── GITHUB_SETUP_GUIDE.md          # Questa guida
└── presentation.html              # Presentazione (opzionale)
```

## 5. .gitignore (opzionale)

Se vuoi tenere il repo pulito, crea un file `.gitignore` con:

```
# Windows
Thumbs.db
*.log
Backup/
UndoManifest.json
UndoManifest.sha256

# PowerShell
*.ps1xml
```

## 6. Verifica finale

```bash
git status
git log --oneline
```
