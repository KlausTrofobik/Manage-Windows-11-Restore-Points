# -*- coding: utf-8 -*-
# Script per la Gestione Punti di Ripristino su Windows 11

# Richiedi privilegi di amministratore
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Richiedo privilegi di amministratore..." -ForegroundColor Yellow
    # FIX: Rimosso duplicato Start-Process (linea 9 originale era duplicata)
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Nasconde la finestra PowerShell
Add-Type -Name ConsoleUtils -Namespace Win32 -MemberDefinition '
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
'
$consoleHandle = [Win32.ConsoleUtils]::GetConsoleWindow()
[Win32.ConsoleUtils]::ShowWindow($consoleHandle, 0) | Out-Null


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Management

# Stile e colori
$Colors = @{
    Background    = "#0A0A0A"
    Secondary     = "#1E1E1E"
    Accent        = "#0078D4"
    AccentHover   = "#106EBE"
    Text          = "#FFFFFF"
    TextSecondary = "#CCCCCC"
    Success       = "#107C10"
    Error         = "#E81123"
    Warning       = "#FFB900"
}

$Fonts = @{
    Title    = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    Normal   = New-Object System.Drawing.Font("Segoe UI", 9)
    Small    = New-Object System.Drawing.Font("Segoe UI", 8)
}

# FIX: Validazione UUID secure prima di usare in comando
function Validate-ShadowId {
    param([string]$ShadowId)
    $pattern = '^\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}$'
    return $ShadowId -match $pattern
}

# FIX MEDIUM: Audit logging via Event Log
function Write-AuditLog {
    param(
        [ValidateSet("CREATE_RP", "DELETE_RP", "MODIFY_DESC", "SECURITY", "ERROR")][string]$Action,
        [string]$Details
    )
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("OttimizzaWindows")) {
            New-EventLog -LogName Application -Source "OttimizzaWindows" -ErrorAction Stop
        }
        $eventId = switch ($Action) {
            "CREATE_RP"  { 1001 }
            "DELETE_RP"  { 1002 }
            "MODIFY_DESC"{ 1003 }
            "SECURITY"   { 1101 }
            "ERROR"      { 2001 }
        }
        Write-EventLog -LogName Application -Source "OttimizzaWindows" `
            -EventId $eventId -EntryType Information -Message "$Action`: $Details"
    } catch {
        Write-Host "[WARN] Audit log fallito: $_" -ForegroundColor Yellow
    }
}

# FIX CRITICAL: Process.Start helper con timeout
function Start-SecureProcess {
    param(
        [string]$FilePath,
        [string]$Arguments,
        [int]$TimeoutSeconds = 30
    )
    $pInfo = New-Object System.Diagnostics.ProcessStartInfo
    $pInfo.FileName = $FilePath
    $pInfo.Arguments = $Arguments
    $pInfo.UseShellExecute = $false
    $pInfo.RedirectStandardOutput = $true
    $pInfo.RedirectStandardError = $true
    $pInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($pInfo)
    if ($process.WaitForExit($TimeoutSeconds * 1000)) {
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        return @{ ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr }
    } else {
        $process.Kill()
        throw "Timeout: $FilePath superato il limite di ${TimeoutSeconds}s"
    }
}

# Form principale - RIDIMENSIONABILE
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Gestione Punti di Ripristino - Windows 11"
$Form.Size = New-Object System.Drawing.Size(1100, 650)
$Form.StartPosition = "CenterScreen"
$Form.BackColor = $Colors.Background
$Form.MinimumSize = New-Object System.Drawing.Size(900, 550)
$Form.MaximizeBox = $true

# Header (fisso in alto)
$Header = New-Object System.Windows.Forms.Panel
$Header.Size = New-Object System.Drawing.Size(1100, 75)
$Header.BackColor = $Colors.Accent
$Header.Location = New-Object System.Drawing.Point(0, 0)
$Header.Anchor = "Top, Left, Right"

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = "Gestione Punti di Ripristino"
$TitleLabel.Font = $Fonts.Title
$TitleLabel.ForeColor = $Colors.Text
$TitleLabel.Location = New-Object System.Drawing.Point(20, 15)
$TitleLabel.Size = New-Object System.Drawing.Size(500, 30)
$Header.Controls.Add($TitleLabel)

$SubLabel = New-Object System.Windows.Forms.Label
$SubLabel.Text = "Crea, gestisci ed elimina punti di ripristino del sistema"
$SubLabel.Font = $Fonts.Small
$SubLabel.ForeColor = $Colors.TextSecondary
$SubLabel.Location = New-Object System.Drawing.Point(25, 48)
$SubLabel.Size = New-Object System.Drawing.Size(500, 20)
$Header.Controls.Add($SubLabel)

$CloseBtn = New-Object System.Windows.Forms.Button
$CloseBtn.Text = "X"
$CloseBtn.Size = New-Object System.Drawing.Size(30, 30)
$CloseBtn.Location = New-Object System.Drawing.Point(1050, 22)
$CloseBtn.Anchor = "Top, Right"
$CloseBtn.FlatStyle = "Flat"
$CloseBtn.FlatAppearance.BorderSize = 0
$CloseBtn.ForeColor = $Colors.Text
$CloseBtn.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$CloseBtn.BackColor = $Colors.Accent
$CloseBtn.Add_Click({ $Form.Close() })
$Header.Controls.Add($CloseBtn)

$Form.Controls.Add($Header)

# Pannello principale
$MainPanel = New-Object System.Windows.Forms.Panel
$MainPanel.Location = New-Object System.Drawing.Point(10, 85)
$MainPanel.Size = New-Object System.Drawing.Size(1080, 535)
$MainPanel.Anchor = "Top, Left, Right, Bottom"
$MainPanel.BackColor = $Colors.Background
$Form.Controls.Add($MainPanel)

# Sezione Info Sistema
$InfoBox = New-Object System.Windows.Forms.GroupBox
$InfoBox.Text = "Informazioni Sistema"
$InfoBox.Location = New-Object System.Drawing.Point(10, 10)
$InfoBox.Size = New-Object System.Drawing.Size(1060, 80)
$InfoBox.ForeColor = $Colors.Text
$MainPanel.Controls.Add($InfoBox)

$OsInfo = New-Object System.Windows.Forms.Label
$OsInfo.Text = "Sistema: Windows 11 | Drive: C: | Protezione: Attiva"
$OsInfo.Location = New-Object System.Drawing.Point(10, 20)
$OsInfo.Size = New-Object System.Drawing.Size(1030, 20)
$OsInfo.ForeColor = $Colors.Text
$InfoBox.Controls.Add($OsInfo)

$StorageInfo = New-Object System.Windows.Forms.Label
$StorageInfo.Text = "Spazio disponibile: Calcolo in corso..."
$StorageInfo.Location = New-Object System.Drawing.Point(10, 45)
$StorageInfo.Size = New-Object System.Drawing.Size(1030, 20)
$StorageInfo.ForeColor = $Colors.TextSecondary
$InfoBox.Controls.Add($StorageInfo)

# Sezione Punti di Ripristino
$ListBox = New-Object System.Windows.Forms.GroupBox
$ListBox.Text = "Punti di Ripristino Disponibili"
$ListBox.Location = New-Object System.Drawing.Point(10, 95)
$ListBox.Size = New-Object System.Drawing.Size(1060, 300)
$ListBox.ForeColor = $Colors.Text
$ListBox.Anchor = "Top, Left, Right, Bottom"
$MainPanel.Controls.Add($ListBox)

$ListView = New-Object System.Windows.Forms.ListBox
$ListView.Location = New-Object System.Drawing.Point(10, 20)
$ListView.Size = New-Object System.Drawing.Size(1035, 270)
$ListView.ForeColor = $Colors.Text
$ListView.BackColor = $Colors.Secondary
$ListView.Anchor = "Top, Left, Right, Bottom"
$ListView.SelectionMode = "One"
$ListBox.Controls.Add($ListView)

# Sezione Azioni
$ActionsPanel = New-Object System.Windows.Forms.Panel
$ActionsPanel.Location = New-Object System.Drawing.Point(10, 400)
$ActionsPanel.Size = New-Object System.Drawing.Size(1060, 30)
$ActionsPanel.Anchor = "Bottom, Left, Right"
$MainPanel.Controls.Add($ActionsPanel)

# FIX: Command Injection - Usa validazione prima di eseguire comando
$DeleteBtn = New-Object System.Windows.Forms.Button
$DeleteBtn.Text = "Elimina Punto"
$DeleteBtn.Size = New-Object System.Drawing.Size(110, 26)
$DeleteBtn.Location = New-Object System.Drawing.Point(2, 2)
$DeleteBtn.BackColor = $Colors.Error
$DeleteBtn.ForeColor = $Colors.Text
$DeleteBtn.FlatStyle = "Flat"
$DeleteBtn.UseVisualStyleBackColor = $false
$DeleteBtn.Add_Click({
    if ($ListView.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona un punto di ripristino!", "Attenzione", "OK", "Warning")
        return
    }
    
    $selectedItem = $ListView.SelectedItem.ToString()
    $shadowId = $selectedItem -replace ".*ID:\s*", "" -replace "\s*-.*", ""
    
    # FIX CRITICAL: Validazione UUID prima di usare
    if (-not (Validate-ShadowId $shadowId)) {
        Write-AuditLog -Action "SECURITY" -Details "Tentativo command injection bloccato: $shadowId"
        [System.Windows.Forms.MessageBox]::Show("ID non valido! Possibile attacco injection.", "Errore Sicurezza", "OK", "Error")
        Write-Host "[SECURITY] Tentativo di command injection bloccato: $shadowId" -ForegroundColor Red
        return
    }
    
    $shadowDate = $selectedItem -replace ".*Data:\s*", "" -replace "\s*-.*", ""
    $description = $selectedItem -replace ".*Descrizione:\s*", ""
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        "ELIMINAZIONE PUNTO DI RIPRISTINO`n`nAttenzione: Operazione irreversibile!`n`nData: $shadowDate`nDescrizione: $description`nID: $shadowId",
        "Conferma Eliminazione",
        "YesNo",
        "Warning"
    )
    
    if ($result -eq "Yes") {
        try {
            # FIX CRITICAL + HIGH: Process.Start con timeout, niente shell
            $procResult = Start-SecureProcess -FilePath "vssadmin.exe" -Arguments "delete shadows /shadow=$shadowId /quiet"
            
            if ($procResult.ExitCode -eq 0) {
                Write-AuditLog -Action "DELETE_RP" -Details "ShadowID: $shadowId eliminato con successo"
                [System.Windows.Forms.MessageBox]::Show("Punto di ripristino eliminato!", "Successo", "OK", "Information")
                Write-Host "[INFO] Punto $shadowId eliminato con successo" -ForegroundColor Green
                Load-RestorePoints
            } else {
                Write-AuditLog -Action "ERROR" -Details "DELETE_RP fallito: $($procResult.StdErr)"
                [System.Windows.Forms.MessageBox]::Show("Errore eliminazione: Exit code $($procResult.ExitCode)", "Errore", "OK", "Error")
                Write-Host "[ERROR] Fallito: $($procResult.StdErr)" -ForegroundColor Red
            }
        }
        catch {
            Write-AuditLog -Action "ERROR" -Details "DELETE_RP eccezione: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("Errore: $($_.Exception.Message)", "Errore", "OK", "Error")
            Write-Host "[EXCEPTION] $($_.Exception.Message)" -ForegroundColor Red
        }
    }
})
$ActionsPanel.Controls.Add($DeleteBtn)

$RefreshBtn = New-Object System.Windows.Forms.Button
$RefreshBtn.Text = "Aggiorna Lista"
$RefreshBtn.Size = New-Object System.Drawing.Size(110, 26)
$RefreshBtn.Location = New-Object System.Drawing.Point(150, 2)
$RefreshBtn.BackColor = $Colors.Accent
$RefreshBtn.ForeColor = $Colors.Text
$RefreshBtn.FlatStyle = "Flat"
$RefreshBtn.UseVisualStyleBackColor = $false
$RefreshBtn.Add_Click({ Load-RestorePoints })
$ActionsPanel.Controls.Add($RefreshBtn)

$OpenSystemRestoreBtn = New-Object System.Windows.Forms.Button
$OpenSystemRestoreBtn.Text = "Ripristino Sistema..."
$OpenSystemRestoreBtn.Size = New-Object System.Drawing.Size(130, 26)
$OpenSystemRestoreBtn.Location = New-Object System.Drawing.Point(270, 2)
$OpenSystemRestoreBtn.BackColor = $Colors.Success
$OpenSystemRestoreBtn.ForeColor = $Colors.Text
$OpenSystemRestoreBtn.FlatStyle = "Flat"
$OpenSystemRestoreBtn.UseVisualStyleBackColor = $false
$OpenSystemRestoreBtn.Add_Click({ Start-Process "rstrui.exe" })
$ActionsPanel.Controls.Add($OpenSystemRestoreBtn)

$CreateRestorePointBtn = New-Object System.Windows.Forms.Button
$CreateRestorePointBtn.Text = "Crea Punto"
$CreateRestorePointBtn.Size = New-Object System.Drawing.Size(110, 26)
$CreateRestorePointBtn.Location = New-Object System.Drawing.Point(420, 2)
$CreateRestorePointBtn.BackColor = $Colors.Success
$CreateRestorePointBtn.ForeColor = $Colors.Text
$CreateRestorePointBtn.FlatStyle = "Flat"
$CreateRestorePointBtn.UseVisualStyleBackColor = $false
$CreateRestorePointBtn.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("Creazione di un nuovo punto di ripristino in corso...`n`nPer favore attendere.", "Creazione Punto", "OK", "Information")
    try {
        Checkpoint-Computer -Description "Punto Gestito da Script" -RestorePointType "ApplicationInstall" -ErrorAction Stop
        Write-AuditLog -Action "CREATE_RP" -Details "Punto creato da script"
        [System.Windows.Forms.MessageBox]::Show("Punto di ripristino creato con successo!", "Successo", "OK", "Information")
        Write-Host "[INFO] Punto di ripristino creato" -ForegroundColor Green
        Load-RestorePoints
    }
    catch {
        Write-AuditLog -Action "ERROR" -Details "CREATE_RP fallito: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Errore nella creazione: $($_.Exception.Message)", "Errore", "OK", "Error")
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    }
})
$ActionsPanel.Controls.Add($CreateRestorePointBtn)

$EditDescriptionBtn = New-Object System.Windows.Forms.Button
$EditDescriptionBtn.Text = "Modifica Descrizione"
$EditDescriptionBtn.Size = New-Object System.Drawing.Size(130, 26)
$EditDescriptionBtn.Location = New-Object System.Drawing.Point(540, 2)
$EditDescriptionBtn.BackColor = $Colors.Accent
$EditDescriptionBtn.ForeColor = $Colors.Text
$EditDescriptionBtn.FlatStyle = "Flat"
$EditDescriptionBtn.UseVisualStyleBackColor = $false
$EditDescriptionBtn.Add_Click({
    if ($ListView.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona un punto di ripristino!", "Attenzione", "OK", "Warning")
        return
    }
    
    $selectedItem = $ListView.SelectedItem.ToString()
    $shadowId = $selectedItem -replace ".*ID:\s*", "" -replace "\s*-.*", ""
    
    # FIX: Validazione UUID
    if (-not (Validate-ShadowId $shadowId)) {
        [System.Windows.Forms.MessageBox]::Show("ID non valido!", "Errore", "OK", "Error")
        return
    }
    
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Modifica Descrizione"
    $inputForm.Size = New-Object System.Drawing.Size(430, 150)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.BackColor = $Colors.Background
    
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Descrizione del Punto:"
    $label.Location = New-Object System.Drawing.Point(10, 10)
    $label.Size = New-Object System.Drawing.Size(400, 20)
    $label.ForeColor = $Colors.Text
    $inputForm.Controls.Add($label)
    
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10, 35)
    $textBox.Size = New-Object System.Drawing.Size(400, 35)
    $textBox.Multiline = $true
    $textBox.BackColor = $Colors.Secondary
    $textBox.ForeColor = $Colors.Text
    $inputForm.Controls.Add($textBox)
    
    $okBtn = New-Object System.Windows.Forms.Button
    $okBtn.Text = "OK"
    $okBtn.Location = New-Object System.Drawing.Point(260, 90)
    $okBtn.Size = New-Object System.Drawing.Size(80, 30)
    $okBtn.BackColor = $Colors.Success
    $okBtn.ForeColor = $Colors.Text
    $okBtn.Add_Click({
        if ($textBox.Text.Trim() -ne "") {
            # FIX HIGH: Registry invece di temp file (protegge da LPE)
            $regPath = "HKCU:\Software\OttimizzaWindows\ShadowCopyDescriptions"
            try {
                if (-not (Test-Path $regPath)) {
                    New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
                }
                Set-ItemProperty -Path $regPath -Name $shadowId -Value $textBox.Text -ErrorAction Stop
                Write-AuditLog -Action "MODIFY_DESC" -Details "ShadowID: $shadowId"
                [System.Windows.Forms.MessageBox]::Show("Descrizione aggiornata!", "Info", "OK", "Information")
                Write-Host "[INFO] Descrizione aggiornata per $shadowId" -ForegroundColor Green
                $inputForm.Close()
                Load-RestorePoints
            }
            catch {
                Write-AuditLog -Action "ERROR" -Details "MODIFY_DESC fallito: $($_.Exception.Message)"
                [System.Windows.Forms.MessageBox]::Show("Errore salvataggio: $($_.Exception.Message)", "Errore", "OK", "Error")
                Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    })
    $inputForm.Controls.Add($okBtn)
    
    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Text = "Annulla"
    $cancelBtn.Location = New-Object System.Drawing.Point(340, 90)
    $cancelBtn.Size = New-Object System.Drawing.Size(80, 30)
    $cancelBtn.BackColor = $Colors.Error
    $cancelBtn.ForeColor = $Colors.Text
    $cancelBtn.Add_Click({ $inputForm.Close() })
    $inputForm.Controls.Add($cancelBtn)
    
    $inputForm.ShowDialog($Form)
})
$ActionsPanel.Controls.Add($EditDescriptionBtn)

# Funzione caricamento punti di ripristino
function Load-RestorePoints {
    Write-Host "[LOAD] Caricamento punti di ripristino..." -ForegroundColor Cyan
    $ListView.Items.Clear()
    
    $customDescriptions = @{}
    # FIX HIGH: Usa Registry invece di temp file (previene LPE)
    try {
        $regPath = "HKCU:\Software\OttimizzaWindows\ShadowCopyDescriptions"
        if (Test-Path $regPath) {
            $regProps = Get-ItemProperty -Path $regPath -ErrorAction Stop
            foreach ($prop in $regProps.PSObject.Properties) {
                if ($prop.Name -match '^\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}$') {
                    $customDescriptions[$prop.Name] = $prop.Value
                }
            }
        }
    }
    catch {
        Write-Host "[WARN] Errore lettura descrizioni da Registry: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    try {
        # FIX HIGH + MEDIUM: Process.Start per vssadmin con timeout
        $procResult = Start-SecureProcess -FilePath "vssadmin.exe" -Arguments "list shadows /for=c:"
        
        $currentDate = ""
        $currentShadowId = ""
        $count = 0
        
        $output = $procResult.StdOut -split "`n"
        foreach ($line in $output) {
            $lineStr = $line.ToString()
            
            # Estrai data creazione
            if ($lineStr -match "al momento della creazione:\s*(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})") {
                $currentDate = $matches[1].Trim()
            }
            
            # FIX CRITICAL: Estrai e valida UUID
            if ($lineStr -match "ID copia shadow:\s*(\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\})") {
                $currentShadowId = $matches[1].Trim()
                
                if ($customDescriptions.ContainsKey($currentShadowId)) {
                    $description = $customDescriptions[$currentShadowId]
                } else {
                    $description = "[Sistema]"
                }
                
                $item = "Data: $currentDate - Descrizione: $description - ID: $currentShadowId"
                $ListView.Items.Add($item)
                $count++
                
                Write-Host "[ITEM] Aggiunto punto $count - $currentDate" -ForegroundColor Green
                
                $currentDate = ""
                $currentShadowId = ""
            }
        }
        
        if ($count -eq 0) {
            $ListView.Items.Add("Nessun punto di ripristino trovato")
            Write-Host "[INFO] Nessun punto trovato" -ForegroundColor Yellow
        } else {
            Write-Host "[SUCCESS] Caricati $count punti" -ForegroundColor Green
        }
    }
    catch {
        $ListView.Items.Add("Errore nel caricamento dei dati")
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Carica punti al startup
Load-RestorePoints

# Mostra form
$Form.ShowDialog()
