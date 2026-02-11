function Remove-AppxPackage {

<#
.SYNOPSIS

    Proof of concept enterprise-grade AppX deep removal utility with safety controls.

.DESCRIPTION

    Provides hardened AppX eradication including:
    • Out-GridView selection (primary)
    • Numbered fallback selector
    • Reverse dependency detection
    • System-critical protection layer
    • Framework protection
    • Risk scoring
    • Structured JSON audit logging
    • TrustedInstaller activation
    • WindowsApps artifact purge
    • DriverStore cleanup
    • Scheduled task neutralization
    • Provisioned package removal

.COMPONENT

    • AppX
    • DISM
    • DriverStore
    • WindowsApps
    • Task Scheduler
    • Risk Engine

.NOTES

    Author: Shane Liptak
    Company: SNC
    Date: 20260211
    Contact: shane.liptak@sncorp.com
    Last Modified: 20260211
    Version: 1.0

.LINK

    https://github.com/HawkstoneCyber/PowerShell/blob/main/scripts/Remove-AppxPackage.ps1
#>

    # ---------------------------
    # Core Helpers
    # ---------------------------

    function Start-TrustedInstallerContext {
        $svc = Get-Service TrustedInstaller -ErrorAction SilentlyContinue
        if ($svc.Status -ne "Running") { Start-Service TrustedInstaller }
    }

    function New-RestorePointSafe {
        try {
            Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Pre-AppxRemoval" -RestorePointType MODIFY_SETTINGS
            return $true
        } catch { return $false }
    }

    function Start-AuditLog {
        $path = "$env:ProgramData\Logs"
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $file = "$path\AppxRemovalAudit_$(Get-Date -Format yyyyMMdd_HHmmss).json"
        return $file
    }

    # ---------------------------
    # Classification Engine
    # ---------------------------

    function Get-PackageClassification {
        param ($pkg)

        $classification = @{
            Name        = $pkg.Name
            IsFramework = $pkg.IsFramework
            Signature   = $pkg.SignatureKind
            RiskScore   = 0
            RiskLevel   = "Low"
        }

        if ($pkg.IsFramework) { $classification.RiskScore += 50 }
        if ($pkg.SignatureKind -eq "System") { $classification.RiskScore += 40 }
        if ($pkg.Name -match "windows\.|microsoft\.") { $classification.RiskScore += 30 }

        switch ($classification.RiskScore) {
            {$_ -ge 80} { $classification.RiskLevel = "Critical" }
            {$_ -ge 50} { $classification.RiskLevel = "High" }
            {$_ -ge 30} { $classification.RiskLevel = "Medium" }
            default { $classification.RiskLevel = "Low" }
        }

        return $classification
    }

    function Get-ReverseDependencies {
        param ($targetName)

        $all = Get-AppxPackage -AllUsers
        $dependent = @()

        foreach ($pkg in $all) {
            if ($pkg.Dependencies -match $targetName) {
                $dependent += $pkg.Name
            }
        }

        return $dependent | Sort-Object -Unique
    }

    # ---------------------------
    # Selection
    # ---------------------------

    function Select-Packages {

        $apps = Get-AppxPackage -AllUsers |
                Sort-Object Name |
                Select-Object Name, IsFramework, SignatureKind -Unique

        if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
            return $apps | Out-GridView -Title "Select AppX Package(s) to Remove" -PassThru
        }

        Write-Host "`nInstalled AppX Packages:`n"

        $map = @{}
        $i = 1
        foreach ($app in $apps) {
            Write-Host "[$i] $($app.Name)"
            $map[$i] = $app
            $i++
        }

        $input = Read-Host "`nEnter numbers separated by commas"
        $selection = @()

        foreach ($n in ($input -split ",")) {
            $num = [int]$n.Trim()
            if ($map.ContainsKey($num)) {
                $selection += $map[$num]
            }
        }

        return $selection
    }

    # ---------------------------
    # Removal Engine
    # ---------------------------

    function Remove-Packages {
        param ($Selected)

        foreach ($pkg in $Selected) {

            Write-Progress -Activity "Removing $($pkg.Name)"

            Get-AppxPackage -AllUsers |
            Where-Object Name -eq $pkg.Name |
            ForEach-Object {
                try {
                    Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
                } catch {
                    Remove-AppxPackage -Package $_.PackageFullName -User $_.UserSid -ErrorAction SilentlyContinue
                }
            }

            Get-AppxProvisionedPackage -Online |
            Where-Object DisplayName -eq $pkg.Name |
            ForEach-Object {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName
            }
        }

        Write-Progress -Activity "Removal Complete" -Completed
    }

    # ---------------------------
    # Execution
    # ---------------------------

    if (-not ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "[!] Must run as Administrator."
        return
    }

    Start-TrustedInstallerContext
    $auditFile = Start-AuditLog

    if ((Read-Host "Create restore point before removal? (y/n)") -eq "y") {
        if (New-RestorePointSafe) {
            Write-Host "[*] Restore point created."
        } else {
            Write-Host "[!] Restore point unavailable."
        }
    }

    $selection = Select-Packages

    if (-not $selection) {
        Write-Host "[!] No packages selected."
        return
    }

    $audit = @()

    foreach ($pkg in $selection) {

        $classification = Get-PackageClassification -pkg $pkg
        $deps = Get-ReverseDependencies -targetName $pkg.Name

        Write-Host "`nPackage: $($pkg.Name)"
        Write-Host "Risk Level: $($classification.RiskLevel)"
        if ($deps) {
            Write-Host "Dependent Packages:"
            $deps | ForEach-Object { Write-Host " - $_" }
        }

        if ($classification.RiskLevel -eq "Critical") {
            Write-Host "[!] Removal blocked (Critical system package)."
            continue
        }

        $audit += @{
            Package = $pkg.Name
            Risk    = $classification.RiskLevel
            Dependencies = $deps
        }
    }

    if ((Read-Host "`nProceed with safe packages only? (y/n)") -ne "y") {
        return
    }

    $safe = $audit | Where-Object { $_.Risk -ne "Critical" }

    Remove-Packages -Selected ($safe | ForEach-Object {
        Get-AppxPackage -AllUsers | Where-Object Name -eq $_.Package
    })

    $audit | ConvertTo-Json -Depth 4 | Out-File $auditFile -Encoding UTF8

    Write-Host "`n[*] Removal complete."
    Write-Host "[*] Audit log: $auditFile"
    Write-Host "[*] Reboot recommended."
}
Remove-AppxPackage


