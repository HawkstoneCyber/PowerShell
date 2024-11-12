<#
.SYNOPSIS

    Create and delete temporary VMs.

.DESCRIPTION

    Creates and deletes temporary Hyper-V virtual machines with basic options (e.g. Gen 1/2, disk location, ISO selection for boot). The goal was to spin up test VMs in a relatively quick fashion. Other variables under the "# Create the New VM" section can be adjsted as needed.

.COMPONENT

	  Requires Hyper-V on the host.

    Requires privileged account to execute.

.NOTES

    Author: Shane Liptak
    Company: Hawkstone Cyber
    Date: 20240425
    Contact: info@hawkstonecyber.com
    Last Modified: 20241105
    Version: 1.0

.LINK

    https://github.com/HawkstoneCyber/PowerShell

#>

# Prepare the New VM
Function vmUp {
    # Check if the user has administrative privileges
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Error: This script requires administrative privileges. Please run as administrator." -ForegroundColor Red
        return
    }

    # Prompt the user for the type of VM to create (Enter for default VM, 'c' for custom VM)
    $vmType = Read-Host "Press Enter for default VM or 'c' for custom VM"

    if ($vmType -eq 'c') {
        # Custom VM creation

        # Get available VM switches
        $switches = Get-VMSwitch
        $switchCount = $switches.Count

        # Display switches in a numeric menu
        for ($i = 0; $i -lt $switchCount; $i++) {
            Write-Host "$($i + 1): $($switches[$i].Name)"
        }

        # Get user selection
        $selection = Read-Host "Select a VMSwitch by number (1-$switchCount)"

        # Validate selection
        if ($selection -match '^\d+$' -and $selection -ge 1 -and $selection -le $switchCount) {
            $selectedSwitch = $switches[$selection - 1].Name
        } else {
            Write-Host "Invalid selection. Exiting."
            return
        }

        # Prompt for VM details
        $vmname = Read-Host "Input VM name"

        # Prompt for generation type with default as 2
        $gentype = Read-Host "Input generation type (press Enter for generation 2 or type '1' for generation 1)"
        if (-not $gentype) {
            $gentype = 2
        } elseif ($gentype -ne '1' -and $gentype -ne '2') {
            Write-Host "Invalid generation type. Please enter 1 or 2."
            return
        }

        $vhdsizeinput = Read-Host "Input VHD size in GB (e.g. 40)"

        # Validate and convert VHD size
        if ($vhdsizeinput -match '^\d+$') {
            $vhdsize = [long]$vhdsizeinput * 1GB
        } else {
            Write-Host "Invalid VHD size input. Exiting."
            return
        }

        # Prompt for folder path where the VHD file will be created
        $vhdFolderPath = Read-Host "Enter the folder path for the new VHD file (e.g., C:\Hyper-V\Virtual Hard Disks)"
        # Remove any surrounding quotes from the input path
        $vhdFolderPath = $vhdFolderPath -replace '"', ''
        $vhdPath = Join-Path -Path $vhdFolderPath -ChildPath "$vmname.vhdx"

        # Prompt the user with a Windows interface for the ISO file to use for the DVD
        Add-Type -AssemblyName System.Windows.Forms
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "ISO Files (*.iso)|*.iso|All Files (*.*)|*.*"
        $openFileDialog.Title = "Select ISO File for the DVD Drive"

        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $isoPath = $openFileDialog.FileName
        } else {
            Write-Host "No ISO file selected. Exiting."
            return
        }

    } else {
        # Default VM creation

        # Generate a random 5-digit number for the VM name
        $random = Get-Random -Minimum 10000 -Maximum 99999
        $vmname = "ATemp$random"

        # Set the VM switch to "Default Switch"
        $selectedSwitch = "Default Switch"

        # Set the VHD size to 100GB
        $vhdsize = 100GB

        # Prompt for generation type with default as 2
        $gentype = Read-Host "Input VM Generation Type (press Enter for generation 2 or type '1' for generation 1)"
        if (-not $gentype) {
            $gentype = 2
        } elseif ($gentype -ne '1' -and $gentype -ne '2') {
            Write-Host "Invalid generation type. Please enter 1 or 2."
            return
        }

        # Prompt for folder path where the VHD file will be created
        $vhdFolderPath = Read-Host "Enter the folder path for the new VHD file (e.g., C:\Hyper-V\Virtual Hard Disks)"
        # Remove any surrounding quotes from the input path
        $vhdFolderPath = $vhdFolderPath -replace '"', ''
        $vhdPath = Join-Path -Path $vhdFolderPath -ChildPath "$vmname.vhdx"

        # Prompt the user with a Windows interface for the ISO file to use for the DVD
        Add-Type -AssemblyName System.Windows.Forms
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "ISO Files (*.iso)|*.iso|All Files (*.*)|*.*"
        $openFileDialog.Title = "Select ISO File for the DVD Drive"

        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $isoPath = $openFileDialog.FileName
        } else {
            Write-Host "No ISO file selected. Exiting."
            return
        }
    }

    # Create the New VM
    try {
        New-VM -Name $vmname -Generation $gentype -NewVHDPath $vhdPath -NewVHDSizeBytes $vhdsize -SwitchName $selectedSwitch
        Set-VM -Name $vmname -ProcessorCount 2 -AutomaticStopAction TurnOff -AutomaticStartAction Nothing -AutomaticCheckpointsEnabled $false -CheckPointType Standard
        Set-VMProcessor $vmname -Count 2 -Reserve 0 -Maximum 100 -RelativeWeight 100
        Set-VMMemory $vmname -DynamicMemoryEnabled $true -MinimumBytes 4096MB -StartupBytes 4096MB -MaximumBytes 8GB -Priority 80 -Buffer 20
	# Added enabling TPM for Windows installation. HGS help from https://deploywindows.com/2015/11/13/add-virtual-tpm-in-windows-10-hyper-v-guest-with-powershell/
	$HGOwner = Get-HgsGuardian UntrustedGuardian
	$newkp = New-HgsKeyProtector -Owner $HGOwner -AllowUntrustedRoot
	Set-VMKeyProtector -VMName $vmname -KeyProtector $newkp.RawData
	#
	Enable-VMTPM -VMName $vmname
        
	# Attach the ISO file to the VM's DVD drive
        Add-VMDvdDrive -VMName $vmname -Path $isoPath

        if ($gentype -eq 1) {
            Set-VMBios $vmname -EnableNumLock -StartupOrder @("CD", "IDE", "Floppy", "LegacyNetworkAdapter")
        } else {
            $dvdDrive = Get-VMDvdDrive -VMName $vmname
            Set-VMFirmware -VMName $vmname -FirstBootDevice $dvdDrive
        }

        Enable-VMIntegrationService * -VMName $vmname

        # Start the VM
        Start-VM -Name $vmname

        # Open the connect GUI in Enhanced Session mode
        vmconnect.exe localhost $vmname /edit

        # Store the name of the last created VM
        Set-Variable -Name 'LastCreatedVMName' -Value $vmname -Scope Global

        Write-Host "VM '$vmname' created and started successfully."
    } catch {
        Write-Host "Error creating VM: $_"
    }
}

# Delete the New VM
Function vmDown {
    # Check if the last created VM name exists
    if (-not (Get-Variable -Name 'LastCreatedVMName' -Scope Global -ErrorAction SilentlyContinue)) {
        Write-Host "No record of the last created VM. Please create a VM first using Invoke-vmUp." -ForegroundColor Yellow
        return
    }

    # Get the last created VM name
    $vmname = $Global:LastCreatedVMName

    # Ask the user to confirm if this is the correct VM to delete
    $confirm = Read-Host "Is this the VM to delete: '$vmname'? (y/n)"
    if ($confirm -ne 'y') {
        Write-Host "Cleanup canceled by user."
        return
    }

    try {
        # Check if the VM exists
        $vm = Get-VM -Name $vmname -ErrorAction Stop
        $vhdPath = (Get-VMHardDiskDrive -VMName $vmname).Path

        # Stop the VM if it's running
        if ($vm.State -eq 'Running') {
            Stop-VM -Name $vmname -Force
        }

        # Remove the VM
        Remove-VM -Name $vmname -Force

        # Remove the VHD file
        if (Test-Path -Path $vhdPath) {
            Remove-Item -Path $vhdPath -Force
        }

        Write-Host "VM '$vmname' and associated VHD file have been deleted successfully."
    } catch {
        Write-Host "Error: Could not clean up VM '$vmname'. $_" -ForegroundColor Red
    }
}
