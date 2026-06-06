# -*- coding: utf-8 -*-
# Gestione Punti di Ripristino - Windows 11

# Elevazione robusta
$psPath = (Get-Command powershell).Source
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Richiedo privilegi di amministratore..." -ForegroundColor Yellow
    Start-Process -FilePath $psPath -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") -Verb RunAs
    exit
}

Add-Type -Name ConsoleUtils -Namespace Win32 -MemberDefinition '
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
'
$consoleHandle = [Win32.ConsoleUtils]::GetConsoleWindow()
[Win32.ConsoleUtils]::ShowWindow($consoleHandle, 0) | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$langDir = Join-Path $scriptDir "lang"

$script:langData = @{}
$script:currentLang = "it"
$script:Lang = @{}   # alias veloce per lookup

function Write-Log {
    param([string]$Key, [string]$ForegroundColor = "Gray", [object[]]$Params = @())
    $msg = if ($script:Lang.ContainsKey($Key)) { $script:Lang[$Key] } else { $Key }
    if ($Params.Count -gt 0) { $msg = [string]::Format($msg, $Params) }
    Write-Host $msg -ForegroundColor $ForegroundColor
}

function Load-Language {
    param([string]$LanguageCode)
    $langFile = Join-Path $langDir "$LanguageCode.json"
    if (Test-Path $langFile) {
        $content = Get-Content $langFile -Raw -Encoding UTF8
        $json = $content | ConvertFrom-Json
        $script:langData = @{}
        $json.PSObject.Properties | ForEach-Object { $script:langData[$_.Name] = $_.Value }
        $script:currentLang = $LanguageCode
        $script:Lang = $script:langData
        $regPath = "HKCU:\Software\OttimizzaWindows\RestorePointManager"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "Language" -Value $LanguageCode -Force
        return $true
    }
    return $false
}

$savedLang = $null
$regPath = "HKCU:\Software\OttimizzaWindows\RestorePointManager"
if (Test-Path $regPath) {
    try { $savedLang = (Get-ItemProperty -Path $regPath -Name "Language" -ErrorAction Stop).Language } catch {}
}
$targetLang = if ($savedLang) { $savedLang } else { "it" }
if (-not (Load-Language $targetLang)) { Load-Language "it" }

$Colors = @{
    Background    = "#0A0A0A"
    Secondary     = "#1E1E1E"
    Accent        = "#0078D4"
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

function Validate-ShadowId {
    param([string]$ShadowId)
    return $ShadowId -match '^\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}$'
}

function Write-AuditLog {
    param(
        [ValidateSet("CREATE_RP","DELETE_RP","MODIFY_DESC","SECURITY","ERROR")][string]$Action,
        [string]$Details
    )
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("OttimizzaWindows")) {
            New-EventLog -LogName Application -Source "OttimizzaWindows" -ErrorAction Stop
        }
        $eventId = switch ($Action) {
            "CREATE_RP"  { 1001 }; "DELETE_RP"  { 1002 }; "MODIFY_DESC"{ 1003 }
            "SECURITY"   { 1101 }; "ERROR"      { 2001 }
        }
        Write-EventLog -LogName Application -Source "OttimizzaWindows" `
            -EventId $eventId -EntryType Information -Message "$Action`: $Details"
    } catch {
        Write-Log "log.audit_fail" "Yellow" @($_.Exception.Message)
    }
}

function Start-SecureProcess {
    param([string]$FilePath, [string]$Arguments, [int]$TimeoutSeconds = 30)
    $pInfo = New-Object System.Diagnostics.ProcessStartInfo
    $pInfo.FileName = $FilePath
    $pInfo.Arguments = $Arguments
    $pInfo.UseShellExecute = $false
    $pInfo.RedirectStandardOutput = $true
    $pInfo.RedirectStandardError = $true
    $pInfo.CreateNoWindow = $true
    $process = $null
    try {
        $process = [System.Diagnostics.Process]::Start($pInfo)
        if ($process -eq $null) { throw "Impossibile avviare $FilePath" }
        if ($process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.WaitForExit()
            return @{
                ExitCode = $process.ExitCode
                StdOut   = $process.StandardOutput.ReadToEnd()
                StdErr   = $process.StandardError.ReadToEnd()
            }
        } else {
            $process.Kill()
            $process.WaitForExit(5000)
            throw "Timeout: $FilePath ha superato il limite di ${TimeoutSeconds}s"
        }
    } finally {
        if ($process -ne $null) { $process.Dispose() }
    }
}

function Get-ShadowCopies {
    try {
        $cimShadows = Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction Stop
        $result = @()
        foreach ($s in $cimShadows) {
            $result += @{
                ID   = "{$($s.ID)}"
                Date = $s.InstallDate.ToString("dd/MM/yyyy HH:mm:ss")
            }
        }
        return $result
    } catch {
        Write-Log "log.wmi_error" "Red" @($_.Exception.Message)
        return @()
    }
}

function Show-LanguageSettings {
    $settingsForm = New-Object System.Windows.Forms.Form
    $settingsForm.Text = $script:Lang["settings.title"]
    $settingsForm.Size = New-Object System.Drawing.Size(350, 260)
    $settingsForm.StartPosition = "CenterParent"
    $settingsForm.BackColor = $Colors.Background
    $settingsForm.FormBorderStyle = "FixedDialog"
    $settingsForm.MaximizeBox = $false
    $settingsForm.MinimizeBox = $false

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $script:Lang["settings.language"]
    $titleLabel.Font = $Fonts.Normal
    $titleLabel.ForeColor = $Colors.Text
    $titleLabel.Location = New-Object System.Drawing.Point(15, 15)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 20)
    $settingsForm.Controls.Add($titleLabel)

    $langs = @("it", "en", "es", "fr", "de", "ru", "zh-cn")
    $langNames = @()
    foreach ($l in $langs) { $langNames += $script:Lang["languages.$l"] }

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(15, 40)
    $listBox.Size = New-Object System.Drawing.Size(300, 120)
    $listBox.BackColor = $Colors.Secondary
    $listBox.ForeColor = $Colors.Text
    $listBox.BorderStyle = "FixedSingle"
    foreach ($name in $langNames) { $listBox.Items.Add($name) | Out-Null }
    $selectedIdx = [array]::IndexOf($langs, $script:currentLang)
    if ($selectedIdx -ge 0) { $listBox.SelectedIndex = $selectedIdx }
    $settingsForm.Controls.Add($listBox)

    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Text = $script:Lang["settings.info"]
    $infoLabel.Font = $Fonts.Small
    $infoLabel.ForeColor = $Colors.TextSecondary
    $infoLabel.Location = New-Object System.Drawing.Point(15, 168)
    $infoLabel.Size = New-Object System.Drawing.Size(300, 20)
    $settingsForm.Controls.Add($infoLabel)

    $okBtn = New-Object System.Windows.Forms.Button
    $okBtn.Text = $script:Lang["btn.ok"]
    $okBtn.Location = New-Object System.Drawing.Point(170, 195)
    $okBtn.Size = New-Object System.Drawing.Size(70, 25)
    $okBtn.BackColor = $Colors.Success
    $okBtn.ForeColor = $Colors.Text
    $okBtn.FlatStyle = "Flat"
    $okBtn.Add_Click({
        if ($listBox.SelectedIndex -ge 0) {
            $newLang = $langs[$listBox.SelectedIndex]
            Load-Language $newLang
            [System.Windows.Forms.MessageBox]::Show($script:Lang["settings.lang_changed"], $script:Lang["settings.title"],
                [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $settingsForm.Close()
        }
    })
    $settingsForm.Controls.Add($okBtn)

    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Text = $script:Lang["btn.cancel"]
    $cancelBtn.Location = New-Object System.Drawing.Point(245, 195)
    $cancelBtn.Size = New-Object System.Drawing.Size(70, 25)
    $cancelBtn.BackColor = $Colors.Error
    $cancelBtn.ForeColor = $Colors.Text
    $cancelBtn.FlatStyle = "Flat"
    $cancelBtn.Add_Click({ $settingsForm.Close() })
    $settingsForm.Controls.Add($cancelBtn)

    $settingsForm.ShowDialog($Form)
}

$Form = New-Object System.Windows.Forms.Form
$Form.Text = $script:Lang["form.title"]
$Form.Size = New-Object System.Drawing.Size(1100, 650)
$Form.StartPosition = "CenterScreen"
$Form.BackColor = $Colors.Background
$Form.MinimumSize = New-Object System.Drawing.Size(900, 550)
$Form.MaximizeBox = $true

$Header = New-Object System.Windows.Forms.Panel
$Header.Size = New-Object System.Drawing.Size(1100, 75)
$Header.BackColor = $Colors.Accent
$Header.Location = New-Object System.Drawing.Point(0, 0)
$Header.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$TitleLabel = New-Object System.Windows.Forms.Label
$TitleLabel.Text = $script:Lang["form.title"]
$TitleLabel.Font = $Fonts.Title
$TitleLabel.ForeColor = $Colors.Text
$TitleLabel.Location = New-Object System.Drawing.Point(20, 15)
$TitleLabel.Size = New-Object System.Drawing.Size(500, 30)
$Header.Controls.Add($TitleLabel)

$SubLabel = New-Object System.Windows.Forms.Label
$SubLabel.Text = $script:Lang["form.subtitle"]
$SubLabel.Font = $Fonts.Small
$SubLabel.ForeColor = $Colors.TextSecondary
$SubLabel.Location = New-Object System.Drawing.Point(25, 48)
$SubLabel.Size = New-Object System.Drawing.Size(500, 20)
$Header.Controls.Add($SubLabel)

$SettingsBtn = New-Object System.Windows.Forms.Button
$SettingsBtn.Text = "⚙"
$SettingsBtn.Size = New-Object System.Drawing.Size(30, 30)
$SettingsBtn.Location = New-Object System.Drawing.Point(1015, 22)
$SettingsBtn.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$SettingsBtn.FlatStyle = "Flat"
$SettingsBtn.FlatAppearance.BorderSize = 0
$SettingsBtn.ForeColor = $Colors.Text
$SettingsBtn.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$SettingsBtn.BackColor = $Colors.Accent
$SettingsBtn.Add_Click({ Show-LanguageSettings })
$Header.Controls.Add($SettingsBtn)

$CloseBtn = New-Object System.Windows.Forms.Button
$CloseBtn.Text = "✕"
$CloseBtn.Size = New-Object System.Drawing.Size(30, 30)
$CloseBtn.Location = New-Object System.Drawing.Point(1050, 22)
$CloseBtn.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$CloseBtn.FlatStyle = "Flat"
$CloseBtn.FlatAppearance.BorderSize = 0
$CloseBtn.ForeColor = $Colors.Text
$CloseBtn.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$CloseBtn.BackColor = $Colors.Accent
$CloseBtn.Add_Click({ $Form.Close() })
$Header.Controls.Add($CloseBtn)

$Form.Controls.Add($Header)

$MainPanel = New-Object System.Windows.Forms.Panel
$MainPanel.Location = New-Object System.Drawing.Point(10, 85)
$MainPanel.Size = New-Object System.Drawing.Size(1080, 535)
$MainPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$MainPanel.BackColor = $Colors.Background
$Form.Controls.Add($MainPanel)

$InfoBox = New-Object System.Windows.Forms.GroupBox
$InfoBox.Text = $script:Lang["info.title"]
$InfoBox.Location = New-Object System.Drawing.Point(10, 10)
$InfoBox.Size = New-Object System.Drawing.Size(1060, 80)
$InfoBox.ForeColor = $Colors.Text
$MainPanel.Controls.Add($InfoBox)

$OsInfo = New-Object System.Windows.Forms.Label
$OsInfo.Text = $script:Lang["info.os"]
$OsInfo.Location = New-Object System.Drawing.Point(10, 20)
$OsInfo.Size = New-Object System.Drawing.Size(1030, 20)
$OsInfo.ForeColor = $Colors.Text
$InfoBox.Controls.Add($OsInfo)

$StorageInfo = New-Object System.Windows.Forms.Label
$StorageInfo.Text = $script:Lang["info.storage"]
$StorageInfo.Location = New-Object System.Drawing.Point(10, 45)
$StorageInfo.Size = New-Object System.Drawing.Size(1030, 20)
$StorageInfo.ForeColor = $Colors.TextSecondary
$InfoBox.Controls.Add($StorageInfo)

$ListBox = New-Object System.Windows.Forms.GroupBox
$ListBox.Text = $script:Lang["list.title"]
$ListBox.Location = New-Object System.Drawing.Point(10, 95)
$ListBox.Size = New-Object System.Drawing.Size(1060, 300)
$ListBox.ForeColor = $Colors.Text
$ListBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$MainPanel.Controls.Add($ListBox)

$ListView = New-Object System.Windows.Forms.ListBox
$ListView.Location = New-Object System.Drawing.Point(10, 20)
$ListView.Size = New-Object System.Drawing.Size(1035, 270)
$ListView.ForeColor = $Colors.Text
$ListView.BackColor = $Colors.Secondary
$ListView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$ListView.SelectionMode = "One"
$ListBox.Controls.Add($ListView)

$ActionsPanel = New-Object System.Windows.Forms.Panel
$ActionsPanel.Location = New-Object System.Drawing.Point(10, 400)
$ActionsPanel.Size = New-Object System.Drawing.Size(1060, 30)
$ActionsPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$MainPanel.Controls.Add($ActionsPanel)

$DeleteBtn = New-Object System.Windows.Forms.Button
$DeleteBtn.Text = $script:Lang["btn.delete"]
$DeleteBtn.Size = New-Object System.Drawing.Size(110, 26)
$DeleteBtn.Location = New-Object System.Drawing.Point(2, 2)
$DeleteBtn.BackColor = $Colors.Error
$DeleteBtn.ForeColor = $Colors.Text
$DeleteBtn.FlatStyle = "Flat"
$DeleteBtn.UseVisualStyleBackColor = $false
$DeleteBtn.Add_Click({
    if ($ListView.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show($script:Lang["msg.select_point"], $script:Lang["msg.attention"],
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    $selectedItem = $ListView.SelectedItem.ToString()
    $shadowId = $selectedItem -replace ".*ID:\s*", "" -replace "\s*-.*", ""
    if (-not (Validate-ShadowId $shadowId)) {
        Write-AuditLog -Action "SECURITY" -Details "Tentativo command injection bloccato: $shadowId"
        [System.Windows.Forms.MessageBox]::Show($script:Lang["msg.invalid_id"], $script:Lang["msg.security_error"],
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Write-Log "log.security_block" "Red" @($shadowId)
        return
    }
    $shadowDate = $selectedItem -replace ".*Data:\s*", "" -replace "\s*-.*", ""
    $description = $selectedItem -replace ".*Descrizione:\s*", ""
    $confirmText = $script:Lang["msg.confirm_delete_text"]
    $result = [System.Windows.Forms.MessageBox]::Show(
        "$confirmText`n`nData: $shadowDate`nDescrizione: $description`nID: $shadowId",
        $script:Lang["msg.confirm_delete_title"],
        [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            $procResult = Start-SecureProcess -FilePath "vssadmin.exe" -Arguments "delete shadows /shadow=$shadowId /quiet"
            if ($procResult.ExitCode -eq 0) {
                Write-AuditLog -Action "DELETE_RP" -Details "ShadowID: $shadowId"
                [System.Windows.Forms.MessageBox]::Show($script:Lang["msg.deleted"], $script:Lang["msg.success"],
                    [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                Write-Log "log.deleted" "Green" @($shadowId)
                Load-RestorePoints
            } else {
                Write-AuditLog -Action "ERROR" -Details "DELETE_RP fallito: $($procResult.StdErr)"
                [System.Windows.Forms.MessageBox]::Show("$($script:Lang["msg.delete_error"]): $($procResult.ExitCode)", $script:Lang["msg.error"],
                    [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        } catch {
            Write-AuditLog -Action "ERROR" -Details "DELETE_RP: $($_.Exception.Message)"
            [System.Windows.Forms.MessageBox]::Show("$($script:Lang["msg.error"]): $($_.Exception.Message)", $script:Lang["msg.error"],
                [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})
$ActionsPanel.Controls.Add($DeleteBtn)

$RefreshBtn = New-Object System.Windows.Forms.Button
$RefreshBtn.Text = $script:Lang["btn.refresh"]
$RefreshBtn.Size = New-Object System.Drawing.Size(110, 26)
$RefreshBtn.Location = New-Object System.Drawing.Point(150, 2)
$RefreshBtn.BackColor = $Colors.Accent
$RefreshBtn.ForeColor = $Colors.Text
$RefreshBtn.FlatStyle = "Flat"
$RefreshBtn.UseVisualStyleBackColor = $false
$RefreshBtn.Add_Click({ Load-RestorePoints })
$ActionsPanel.Controls.Add($RefreshBtn)

$OpenSystemRestoreBtn = New-Object System.Windows.Forms.Button
$OpenSystemRestoreBtn.Text = $script:Lang["btn.restore"]
$OpenSystemRestoreBtn.Size = New-Object System.Drawing.Size(130, 26)
$OpenSystemRestoreBtn.Location = New-Object System.Drawing.Point(270, 2)
$OpenSystemRestoreBtn.BackColor = $Colors.Success
$OpenSystemRestoreBtn.ForeColor = $Colors.Text
$OpenSystemRestoreBtn.FlatStyle = "Flat"
$OpenSystemRestoreBtn.UseVisualStyleBackColor = $false
$OpenSystemRestoreBtn.Add_Click({ Start-Process "rstrui.exe" })
$ActionsPanel.Controls.Add($OpenSystemRestoreBtn)

$CreateRestorePointBtn = New-Object System.Windows.Forms.Button
$CreateRestorePointBtn.Text = $script:Lang["btn.create"]
$CreateRestorePointBtn.Size = New-Object System.Drawing.Size(110, 26)
$CreateRestorePointBtn.Location = New-Object System.Drawing.Point(420, 2)
$CreateRestorePointBtn.BackColor = $Colors.Success
$CreateRestorePointBtn.ForeColor = $Colors.Text
$CreateRestorePointBtn.FlatStyle = "Flat"
$CreateRestorePointBtn.UseVisualStyleBackColor = $false
$CreateRestorePointBtn.Add_Click({
    [System.Windows.Forms.MessageBox]::Show($script:Lang["msg.creating"], $script:Lang["msg.creating_title"],
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    try {
        Checkpoint-Computer -Description "Punto Gestito da Script" -RestorePointType "ApplicationInstall" -ErrorAction Stop
        Write-AuditLog -Action "CREATE_RP" -Details "Punto creato da script"
        [System.Windows.Forms.MessageBox]::Show($script:Lang["msg.created"], $script:Lang["msg.success"],
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        Write-Log "log.created" "Green"
        Load-RestorePoints
    } catch {
        Write-AuditLog -Action "ERROR" -Details "CREATE_RP: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("$($script:Lang["msg.create_error"]): $($_.Exception.Message)", $script:Lang["msg.error"],
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})
$ActionsPanel.Controls.Add($CreateRestorePointBtn)

$EditDescriptionBtn = New-Object System.Windows.Forms.Button
$EditDescriptionBtn.Text = $script:Lang["btn.editdesc"]
$EditDescriptionBtn.Size = New-Object System.Drawing.Size(130, 26)
$EditDescriptionBtn.Location = New-Object System.Drawing.Point(540, 2)
$EditDescriptionBtn.BackColor = $Colors.Accent
$EditDescriptionBtn.ForeColor = $Colors.Text
$EditDescriptionBtn.FlatStyle = "Flat"
$EditDescriptionBtn.UseVisualStyleBackColor = $false
$EditDescriptionBtn.Add_Click({
    if ($ListView.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show($script:Lang["msg.select_point"], $script:Lang["msg.attention"],
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    $selectedItem = $ListView.SelectedItem.ToString()
    $shadowId = $selectedItem -replace ".*ID:\s*", "" -replace "\s*-.*", ""
    if (-not (Validate-ShadowId $shadowId)) {
        [System.Windows.Forms.MessageBox]::Show($script:Lang["msg.invalid_id"], $script:Lang["msg.error"],
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = $script:Lang["input.desc_title"]
    $inputForm.Size = New-Object System.Drawing.Size(430, 150)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.BackColor = $Colors.Background

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $script:Lang["input.desc_label"]
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
    $okBtn.Text = $script:Lang["btn.ok"]
    $okBtn.Location = New-Object System.Drawing.Point(260, 90)
    $okBtn.Size = New-Object System.Drawing.Size(80, 30)
    $okBtn.BackColor = $Colors.Success
    $okBtn.ForeColor = $Colors.Text
    $okBtn.Add_Click({
        $newDesc = $textBox.Text.Trim()
        if ($newDesc -ne "") {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($newDesc)
            if ($bytes.Length -gt 1024) {
                [System.Windows.Forms.MessageBox]::Show("Descrizione troppo lunga (max 1024 byte).", $script:Lang["msg.error"],
                    [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
            $regPath = "HKCU:\Software\OttimizzaWindows\ShadowCopyDescriptions"
            try {
                if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null }
                Set-ItemProperty -Path $regPath -Name $shadowId -Value $newDesc -ErrorAction Stop
                Write-AuditLog -Action "MODIFY_DESC" -Details "ShadowID: $shadowId"
                [System.Windows.Forms.MessageBox]::Show($script:Lang["msg.desc_updated"], $script:Lang["msg.info"],
                    [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                Write-Log "log.desc_updated_log" "Green" @($shadowId)
                $inputForm.Close()
                Load-RestorePoints
            } catch {
                Write-AuditLog -Action "ERROR" -Details "MODIFY_DESC: $($_.Exception.Message)"
                [System.Windows.Forms.MessageBox]::Show("$($script:Lang["msg.desc_save_error"]): $($_.Exception.Message)", $script:Lang["msg.error"],
                    [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    })
    $inputForm.Controls.Add($okBtn)

    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Text = $script:Lang["btn.cancel"]
    $cancelBtn.Location = New-Object System.Drawing.Point(340, 90)
    $cancelBtn.Size = New-Object System.Drawing.Size(80, 30)
    $cancelBtn.BackColor = $Colors.Error
    $cancelBtn.ForeColor = $Colors.Text
    $cancelBtn.Add_Click({ $inputForm.Close() })
    $inputForm.Controls.Add($cancelBtn)

    $inputForm.ShowDialog($Form)
})
$ActionsPanel.Controls.Add($EditDescriptionBtn)

function Load-RestorePoints {
    Write-Log "log.loading" "Cyan"
    $ListView.Items.Clear()

    $customDescriptions = @{}
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
    } catch {
        Write-Log "log.registry_warn" "Yellow" @($_.Exception.Message)
    }

    $shadows = Get-ShadowCopies
    if ($shadows.Count -eq 0) {
        $ListView.Items.Add($script:Lang["list.empty"])
        Write-Log "log.empty" "Yellow"
        return
    }

    $count = 0
    foreach ($s in $shadows) {
        $description = if ($customDescriptions.ContainsKey($s.ID)) { $customDescriptions[$s.ID] } else { $script:Lang["list.default_desc"] }
        $item = "Data: $($s.Date) - Descrizione: $description - ID: $($s.ID)"
        $ListView.Items.Add($item)
        $count++
        Write-Log "log.item_added" "Green" @($count, $s.Date)
    }
    Write-Log "log.loaded" "Green" @($count)
}

Load-RestorePoints
$Form.ShowDialog()
