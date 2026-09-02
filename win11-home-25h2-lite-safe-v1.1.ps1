#requires -Version 5.1
<#
.SYNOPSIS
  Windows 11 Home 25H2 Lite Safe v1.1
.DESCRIPTION
  Conservative optimization toolkit for Intel Gen 4+ / 8 GB RAM / SSD.
  Keeps Defender, Firewall, Windows Update, Store, Search, SysMain and pagefile.
.NOTES
  Run with Windows PowerShell 5.1 as Administrator.
#>

[CmdletBinding()]
param(
    [ValidateSet('Menu','Audit','Safe','Lite','Apps','Restore','Report')]
    [string]$Action = 'Menu'
)

$ErrorActionPreference = 'Continue'
$ScriptVersion = '1.1.0'
$ToolName = 'Win11-Home-25H2-Lite-Safe'
$DataRoot = Join-Path $env:ProgramData $ToolName
$BackupRoot = Join-Path $DataRoot 'Backup'
$LogRoot = Join-Path $DataRoot 'Logs'
$ReportRoot = Join-Path ([Environment]::GetFolderPath('Desktop')) "$ToolName-Reports"

foreach ($Path in @($DataRoot, $BackupRoot, $LogRoot, $ReportRoot)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

$LogFile = Join-Path $LogRoot ("{0}-{1}.log" -f $ToolName, (Get-Date -Format 'yyyyMMdd-HHmmss'))

function Write-Step {
    param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Cyan)
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format 's'), $Message)
}

function Test-Administrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Confirm-Action {
    param([string]$Prompt)
    $Answer = Read-Host "$Prompt [Y/N]"
    return $Answer -match '^(y|yes)$'
}

function Get-SystemDriveMediaType {
    try {
        $SystemDiskNumber = (Get-Partition -DriveLetter $env:SystemDrive.TrimEnd(':') -ErrorAction Stop | Get-Disk).Number
        $PhysicalDisk = Get-PhysicalDisk -ErrorAction Stop | Where-Object DeviceId -eq $SystemDiskNumber | Select-Object -First 1
        if ($PhysicalDisk) { return [string]$PhysicalDisk.MediaType }
    } catch {}
    return 'Unknown'
}

function Get-HardwareAudit {
    $Computer = Get-CimInstance Win32_ComputerSystem
    $OS = Get-CimInstance Win32_OperatingSystem
    $CPU = Get-CimInstance Win32_Processor | Select-Object -First 1
    $TPM = $null
    try { $TPM = Get-Tpm -ErrorAction Stop } catch {}

    $SecureBoot = 'Unknown/Unsupported'
    try { $SecureBoot = [string](Confirm-SecureBootUEFI -ErrorAction Stop) } catch {}

    $RAMGB = [math]::Round($Computer.TotalPhysicalMemory / 1GB, 1)
    $CPUName = $CPU.Name.Trim()
    $IntelGeneration = 'Unknown'
    if ($CPUName -match 'i[3579]-([0-9]{4,5})') {
        $Digits = $Matches[1]
        if ($Digits.Length -eq 4) { $IntelGeneration = [int]$Digits.Substring(0,1) }
        elseif ($Digits.Length -eq 5) { $IntelGeneration = [int]$Digits.Substring(0,2) }
    }

    [pscustomobject]@{
        ComputerName      = $env:COMPUTERNAME
        Manufacturer      = $Computer.Manufacturer
        Model             = $Computer.Model
        Windows           = $OS.Caption
        Version           = $OS.Version
        Build             = $OS.BuildNumber
        CPU               = $CPUName
        IntelGeneration   = $IntelGeneration
        RAM_GB            = $RAMGB
        SystemDriveMedia  = Get-SystemDriveMediaType
        FreeSystemDriveGB = [math]::Round((Get-PSDrive $env:SystemDrive.TrimEnd(':')).Free / 1GB, 1)
        TPM_Present       = if ($TPM) { $TPM.TpmPresent } else { 'Unknown' }
        TPM_Ready         = if ($TPM) { $TPM.TpmReady } else { 'Unknown' }
        SecureBoot        = $SecureBoot
        PagefileAutomatic = $Computer.AutomaticManagedPagefile
        PowerPlan         = ((powercfg.exe /getactivescheme) -join ' ').Trim()
    }
}

function Show-Audit {
    Write-Step "`n=== SYSTEM AUDIT ==="
    $Audit = Get-HardwareAudit
    $Audit | Format-List

    Write-Host 'Assessment:' -ForegroundColor Yellow
    if ($Audit.RAM_GB -lt 7.5) { Write-Host '- RAM is below the expected 8 GB.' -ForegroundColor Red }
    else { Write-Host '- RAM is suitable for the LITE profile.' -ForegroundColor Green }

    if ($Audit.SystemDriveMedia -eq 'HDD') { Write-Host '- System drive is HDD; SSD upgrade is strongly recommended.' -ForegroundColor Red }
    elseif ($Audit.SystemDriveMedia -eq 'SSD') { Write-Host '- SSD detected.' -ForegroundColor Green }
    else { Write-Host '- Drive type could not be detected; verify in Task Manager.' -ForegroundColor Yellow }

    if ($Audit.IntelGeneration -ne 'Unknown' -and [int]$Audit.IntelGeneration -lt 8) {
        Write-Host '- Intel generation is below official Windows 11 CPU support; updates are not guaranteed by Microsoft.' -ForegroundColor Yellow
    }
    return $Audit
}

function New-SafetyBackup {
    Write-Step 'Creating registry backups and restore point...'
    $Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $CurrentBackup = Join-Path $BackupRoot $Stamp
    New-Item -ItemType Directory -Path $CurrentBackup -Force | Out-Null

    & reg.exe export 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' (Join-Path $CurrentBackup 'personalize.reg') /y | Out-Null
    & reg.exe export 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' (Join-Path $CurrentBackup 'visual-effects.reg') /y | Out-Null
    & reg.exe export 'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' (Join-Path $CurrentBackup 'content-delivery.reg') /y | Out-Null

    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Before-$ToolName-$Stamp" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Step 'Restore point created.' Green
    } catch {
        Write-Step "Restore point unavailable: $($_.Exception.Message)" Yellow
    }

    Set-Content -Path (Join-Path $DataRoot 'last-backup.txt') -Value $CurrentBackup
    return $CurrentBackup
}

function Set-CommonSafeSettings {
    Write-Step 'Applying reversible safe settings...'

    $Personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    New-Item $Personalize -Force | Out-Null
    New-ItemProperty -Path $Personalize -Name EnableTransparency -PropertyType DWord -Value 0 -Force | Out-Null

    $VisualEffects = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    New-Item $VisualEffects -Force | Out-Null
    New-ItemProperty -Path $VisualEffects -Name VisualFXSetting -PropertyType DWord -Value 2 -Force | Out-Null

    try {
        $Computer = Get-CimInstance Win32_ComputerSystem
        Set-CimInstance -InputObject $Computer -Property @{ AutomaticManagedPagefile = $true } | Out-Null
    } catch { Write-Step 'Could not set system-managed pagefile.' Yellow }

    powercfg.exe /setactive SCHEME_BALANCED | Out-Null

    $CDM = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    New-Item $CDM -Force | Out-Null
    foreach ($Name in @('ContentDeliveryAllowed','OemPreInstalledAppsEnabled','PreInstalledAppsEnabled','PreInstalledAppsEverEnabled','SilentInstalledAppsEnabled','SubscribedContent-338388Enabled','SubscribedContent-338389Enabled','SubscribedContent-353698Enabled')) {
        New-ItemProperty -Path $CDM -Name $Name -PropertyType DWord -Value 0 -Force | Out-Null
    }
}

function Invoke-SafeProfile {
    Write-Host "`nSAFE changes: transparency/visual effects, consumer suggestions, automatic pagefile, Balanced power." -ForegroundColor Yellow
    Write-Host 'Defender, Update, Firewall, Store, Search, SysMain and services remain enabled.' -ForegroundColor Green
    if (-not (Confirm-Action 'Apply SAFE profile?')) { return }
    New-SafetyBackup | Out-Null
    Set-CommonSafeSettings
    Write-Step 'SAFE profile completed. Restart Windows.' Green
}

function Invoke-LiteProfile {
    Write-Host "`nLITE includes SAFE plus removal of a conservative consumer-app list for the current user." -ForegroundColor Yellow
    Write-Host 'It does not remove provisioned system packages for new users.' -ForegroundColor Green
    if (-not (Confirm-Action 'Apply LITE profile?')) { return }
    New-SafetyBackup | Out-Null
    Set-CommonSafeSettings
    Remove-OptionalApps -Preset
    Write-Step 'Running component cleanup (may take several minutes)...'
    Start-Process -FilePath DISM.exe -ArgumentList '/Online','/Cleanup-Image','/StartComponentCleanup' -Wait -NoNewWindow
    Write-Step 'LITE profile completed. Restart Windows.' Green
}

function Get-OptionalAppCatalog {
    @(
        [pscustomobject]@{Id=1; Name='Clipchamp';             Package='Clipchamp.Clipchamp';                  Default=$true}
        [pscustomobject]@{Id=2; Name='Microsoft News';        Package='Microsoft.BingNews';                  Default=$true}
        [pscustomobject]@{Id=3; Name='Solitaire';             Package='Microsoft.MicrosoftSolitaireCollection';Default=$true}
        [pscustomobject]@{Id=4; Name='Feedback Hub';          Package='Microsoft.WindowsFeedbackHub';        Default=$true}
        [pscustomobject]@{Id=5; Name='Xbox Gaming Overlay';   Package='Microsoft.XboxGamingOverlay';         Default=$true}
        [pscustomobject]@{Id=6; Name='Xbox TCUI';             Package='Microsoft.Xbox.TCUI';                 Default=$true}
        [pscustomobject]@{Id=7; Name='Xbox Identity Provider';Package='Microsoft.XboxIdentityProvider';       Default=$true}
        [pscustomobject]@{Id=8; Name='Xbox Speech Overlay';   Package='Microsoft.XboxSpeechToTextOverlay';    Default=$true}
        [pscustomobject]@{Id=9; Name='Phone Link';            Package='Microsoft.YourPhone';                 Default=$false}
        [pscustomobject]@{Id=10;Name='Windows Maps';          Package='Microsoft.WindowsMaps';               Default=$false}
    )
}

function Remove-OptionalApps {
    param([switch]$Preset)
    $Catalog = Get-OptionalAppCatalog
    if ($Preset) {
        $Selected = $Catalog | Where-Object Default
    } else {
        Write-Host "`nOptional apps (current user only):" -ForegroundColor Cyan
        $Catalog | Format-Table Id, Name, Package -AutoSize
        $Choice = Read-Host 'Enter IDs separated by commas, or Q to cancel'
        if ($Choice -match '^(q|quit)$') { return }
        $IDs = $Choice -split ',' | ForEach-Object { if ($_ -match '^\s*\d+\s*$') { [int]$_ } }
        $Selected = $Catalog | Where-Object { $_.Id -in $IDs }
    }

    if (-not $Selected) { Write-Step 'No applications selected.' Yellow; return }
    Write-Host 'Selected:' -ForegroundColor Yellow
    $Selected | Format-Table Id, Name -AutoSize
    if (-not $Preset -and -not (Confirm-Action 'Remove these apps for the current user?')) { return }

    foreach ($App in $Selected) {
        $Packages = Get-AppxPackage -Name $App.Package -ErrorAction SilentlyContinue
        if (-not $Packages) { Write-Step "Not installed: $($App.Name)" Yellow; continue }
        foreach ($Package in $Packages) {
            try {
                Remove-AppxPackage -Package $Package.PackageFullName -ErrorAction Stop
                Write-Step "Removed: $($App.Name)" Green
            } catch { Write-Step "Could not remove $($App.Name): $($_.Exception.Message)" Yellow }
        }
    }
}

function Restore-Settings {
    Write-Host "`nThis restores Windows visual defaults, consumer suggestions, automatic pagefile and Balanced power." -ForegroundColor Yellow
    Write-Host 'Removed apps are reinstalled separately from Microsoft Store.' -ForegroundColor Yellow
    if (-not (Confirm-Action 'Restore settings?')) { return }

    $Personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    New-Item $Personalize -Force | Out-Null
    New-ItemProperty -Path $Personalize -Name EnableTransparency -PropertyType DWord -Value 1 -Force | Out-Null

    $VisualEffects = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    New-Item $VisualEffects -Force | Out-Null
    New-ItemProperty -Path $VisualEffects -Name VisualFXSetting -PropertyType DWord -Value 0 -Force | Out-Null

    $CDM = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    foreach ($Name in @('ContentDeliveryAllowed','OemPreInstalledAppsEnabled','PreInstalledAppsEnabled','PreInstalledAppsEverEnabled','SilentInstalledAppsEnabled','SubscribedContent-338388Enabled','SubscribedContent-338389Enabled','SubscribedContent-353698Enabled')) {
        New-ItemProperty -Path $CDM -Name $Name -PropertyType DWord -Value 1 -Force | Out-Null
    }

    try {
        $Computer = Get-CimInstance Win32_ComputerSystem
        Set-CimInstance -InputObject $Computer -Property @{ AutomaticManagedPagefile = $true } | Out-Null
    } catch {}
    powercfg.exe /setactive SCHEME_BALANCED | Out-Null
    Write-Step 'Settings restored. Restart Windows.' Green
}

function Export-SystemReport {
    $Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $ReportFile = Join-Path $ReportRoot ("system-report-$Stamp.txt")
    $Audit = Get-HardwareAudit
    $Lines = @(
        "$ToolName v$ScriptVersion",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        '',
        '=== HARDWARE AND WINDOWS ===',
        ($Audit | Format-List | Out-String),
        '=== MEMORY ===',
        (Get-CimInstance Win32_OperatingSystem | Select-Object @{N='TotalVisibleGB';E={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}}, @{N='FreePhysicalGB';E={[math]::Round($_.FreePhysicalMemory/1MB,2)}} | Format-List | Out-String),
        '=== TOP MEMORY PROCESSES ===',
        (Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Name, Id, @{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize | Out-String),
        '=== PROTECTED SERVICES ===',
        (Get-Service -Name wuauserv,bits,WinDefend,mpssvc,WSearch,SysMain -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-String)
    )
    Set-Content -Path $ReportFile -Value $Lines -Encoding UTF8
    Write-Step "Report saved: $ReportFile" Green
}

function Show-Menu {
    do {
        Clear-Host
        Write-Host '====================================================' -ForegroundColor Cyan
        Write-Host " $ToolName v$ScriptVersion"
        Write-Host ' Intel Gen 4+ / 8 GB RAM / SSD' -ForegroundColor Gray
        Write-Host '====================================================' -ForegroundColor Cyan
        Write-Host ' 1. Audit system'
        Write-Host ' 2. Apply SAFE profile'
        Write-Host ' 3. Apply LITE profile (recommended for Gen 4-6)'
        Write-Host ' 4. Remove optional apps manually'
        Write-Host ' 5. Restore settings'
        Write-Host ' 6. Export diagnostic report'
        Write-Host ' 7. Open logs folder'
        Write-Host ' 0. Exit'
        $Choice = Read-Host 'Choose'
        switch ($Choice) {
            '1' { Show-Audit | Out-Null; Pause }
            '2' { Invoke-SafeProfile; Pause }
            '3' { Invoke-LiteProfile; Pause }
            '4' { Remove-OptionalApps; Pause }
            '5' { Restore-Settings; Pause }
            '6' { Export-SystemReport; Pause }
            '7' { Start-Process explorer.exe $LogRoot }
            '0' { return }
            default { Write-Host 'Invalid choice.' -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    } while ($true)
}

if (-not (Test-Administrator)) {
    Write-Host 'Please right-click Windows PowerShell and choose Run as administrator.' -ForegroundColor Red
    exit 1
}

Write-Step "$ToolName v$ScriptVersion started; action=$Action"
switch ($Action) {
    'Menu'    { Show-Menu }
    'Audit'   { Show-Audit | Out-Null }
    'Safe'    { Invoke-SafeProfile }
    'Lite'    { Invoke-LiteProfile }
    'Apps'    { Remove-OptionalApps }
    'Restore' { Restore-Settings }
    'Report'  { Export-SystemReport }
}

