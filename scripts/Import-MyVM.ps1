function Import-MyVM {
<#
.SYNOPSIS
    Interactive Hyper-V VM importer with compatibility checking.

.DESCRIPTION
    This function scans a user-specified directory for .vmcx files, checks if the corresponding VMId is already installed, and if not, allows the user to import the VM.
    If the import fails due to incompatibility, it uses Compare-VM to resolve issues and attempts a corrected import.

.PARAMETER vmcxDirectory
    The directory path containing exported .vmcx files, where each filename is assumed to match the VMId.

.EXAMPLE
    Import-MyVM -vmcxDirectory "D:\VM\Exported\Virtual Machines"

.NOTES
    Author: Shane Liptak
    Company: Hawkstone Cyber LLC
    Date: 20251004
    Contact: shane@hawkstonecyber.com
    Last Modified: 20251004
    Version: 1.0
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$vmcxDirectory
    )

    # Validate directory
    if (-not (Test-Path $vmcxDirectory)) {
        Write-Error "Directory does not exist: $vmcxDirectory"
        return
    }

    # Retrieve list of installed VM IDs
    $existingVMs = Get-VM | Select-Object VMName, VMId

    # Get all .vmcx files
    $vmcxFiles = Get-ChildItem -Path $vmcxDirectory -Filter *.vmcx

    foreach ($file in $vmcxFiles) {
        try {
            [Guid]$vmId = [Guid]::Parse($file.BaseName)
        } catch {
            Write-Warning "Skipping file '$($file.Name)' - invalid GUID filename."
            continue
        }

        $vmName = [System.IO.Path]::GetFileNameWithoutExtension($file.FullName)
        $vmExists = $existingVMs | Where-Object { $_.VMId -eq $vmId }

        if (-not $vmExists) {
            Write-Host "`nVM '$vmName' (ID: $vmId) not found on this system."
            $userInput = Read-Host "Import this VM? (y/n)"
            if ($userInput -ne 'y') {
                Write-Host "Skipping VM '$vmName'..."
                continue
            }

            $importChoice = Read-Host "Register in place (r) or generate new ID (g)? (r/g)"
            $tryRegister = $importChoice -eq 'r'

            try {
                if ($tryRegister) {
                    Write-Host "Attempting to register VM '$vmName' in place..."
                    Import-VM -Path $file.FullName -Register -ErrorAction Stop
                } else {
                    Write-Host "Attempting to import VM '$vmName' with new ID..."
                    Import-VM -Path $file.FullName -ErrorAction Stop
                }
                Write-Host "✅ Successfully imported '$vmName'."
            } catch {
                Write-Warning "⚠️ Import failed for '$vmName'. Attempting compatibility repair..."

                $report = Compare-VM -Path $file.FullName
                if ($report.Incompatibilities.Count -gt 0) {
                    Write-Host "`nIncompatibilities detected for '$vmName':"
                    $report.Incompatibilities | Format-Table -AutoSize

                    # Try disconnecting NIC if needed
                    if ($report.Incompatibilities[0].Source) {
                        $report.Incompatibilities[0].Source | Disconnect-VMNetworkAdapter -ErrorAction SilentlyContinue
                        Write-Host "Disconnected incompatible network adapter."
                    }

                    $report = Compare-VM -Path $file.FullName  # regenerate report
                }

                try {
                    Import-VM -CompatibilityReport $report -ErrorAction Stop
                    Write-Host "✅ VM '$vmName' imported using compatibility report."
                } catch {
                    Write-Error "❌ Final import attempt for '$vmName' failed: $($_.Exception.Message)"
                }
            }
        } else {
            Write-Host "✅ VM '$vmName' with ID '$vmId' already exists."
        }
    }
}
Import-MyVM