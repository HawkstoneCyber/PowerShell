<#
.SYNOPSIS

    Windows organic credential management (Generic Credentials) using PowerShell.

.DESCRIPTION

    Manage Windows credentials (Generic Credentials) using PowerShell. Add, copy, create test credentials, show password, generate strong password, and backup / restore (using credwiz) credentials.

.COMPONENT

	•     TUN.CredentialManager Module.

.NOTES

    Author: Shane Liptak
    Company: SNC
    Date: 20250303
    Contact: shane@hawkstonecyber.com
    Last Modified: 20250417
    Version: 1.1

.LINK

    https://github.com/HawkstoneCyber/PowerShell

#>

# Main Menu
FUNCTION credman {
# Main loop
while ($true) {
	cls
	Write-Host "Credential Manager" -f cyan
	Write-Host "----------------------------------------------------------------------" -f white
	Write-Host "1 Show Credentials" -f cyan
	Write-Host "2 Add Credential" -f cyan
	Write-Host "3 Copy Credential" -f cyan
	Write-Host "4 Create Temp Test Credential" -f cyan
	Write-Host "5 Delete Credential" -f cyan
	Write-Host "6 Show Credential Password" -f cyan
	Write-Host "7 Create Strong Password" -f cyan
	Write-Host "8 Backup / Restore Credential dB" -f cyan
	Write-Host " " -f black
    $choice = Read-Host "Please enter your choice (1-8) or enter to exit"

    switch ($choice) {
        "" { try {
            Write-Host "Exiting..."
		} catch {
		} finally {
			[Windows.ApplicationModel.DataTransfer.Clipboard, Windows, ContentType = WindowsRuntime]::ClearHistory() > $null
			Start-Sleep -s 2
        }
	break
	}
		
	1 { show-creds }
	2 { add-cred }
        3 { copy-cred }
        4 { test-cred }
        5 { del-cred }
        6 { show-pass }
	7 { gen-pass }
	8 { credwiz }
		
    default {
        Write-Host "Invalid selection, please try again."
    }
    }

    if ($choice -eq "") {
		break
    }
    
    # Pause before showing the menu again
    Read-Host "Press Enter to continue..."
}
}

#Show All Credentials
FUNCTION show-creds {
    $allCreds = Get-StoredCredential -AsCredentialObject -ErrorAction SilentlyContinue
    if ($allCreds -eq $null) {
        Write-Host "No stored credentials."
    } else {
        Write-Host "Stored credentials" -f cyan
        Write-Host "" -f Black
        $sortedCreds = $allCreds | Sort-Object -Property TargetName
        $sortedCreds | ForEach-Object {
            if ($_.TargetName -match "target=(.+)") {
                Write-Host $matches[1]
            } else {
                Write-Host $_.TargetName
            }
        }
    }
}

# Add New Credentials
FUNCTION add-cred {
    $targetName = Read-Host "Input New Target Name for Windows Credential Manager"
	$userName = Read-Host "Input New User Name for Windows Credential Manager"

    # Define the persistence options
    $persistenceOptions = @("Session", "LocalMachine", "Enterprise")

    # Display the persistence options as a numbered list
    Write-Host "Select credential persistence:"
    for ($i = 0; $i -lt $persistenceOptions.Count; $i++) {
        Write-Host "$($i + 1). $($persistenceOptions[$i])"
    }

    # Prompt the user to select the number for the persistence value
    $selection = Read-Host "Enter the number of the persistence value"

    # Validate the user's input
    if ([string]::IsNullOrWhiteSpace($selection) -or -not $selection -match '^\d+$' -or [int]$selection -lt 1 -or [int]$selection -gt $persistenceOptions.Count) {
        Write-Host "Invalid selection. Cancelling the function."
        return
    }

    # Convert the selection to an integer
    $selection = [int]$selection

    # Get the selected persistence value
    $persistence = $persistenceOptions[$selection - 1]

    # Prompt the user to input the credential
    $credentialPw = Get-Credential -UserName $userName -Message "Enter username and password/key"
	$credentialPwPlaintext = $credentialPw.GetNetworkCredential().Password
	New-StoredCredential -Target $targetName -Persist $persistence -UserName $userName -Password $credentialPwPlaintext

    # Verify if the credential was successfully stored
    Get-StoredCredential -Target $targetName
    Write-Host "New credential securely stored."
}

# Copy Credentials
# The clipboard history erase only works with Windows 10 / PowerShell 5 combination. All others require manual history erasing unless history is disabled.)
FUNCTION copy-cred {
    [CmdletBinding()]
    param ()

    Add-Type -AssemblyName System.Windows.Forms

    $searchString = Read-Host "Enter a part of the target name to search for, or press Enter to view all credentials"
    $credentials = Get-StoredCredential -AsCredentialObject

    if (-not $credentials) {
        Write-Host "No credentials found." -ForegroundColor Red
        return
    }

    $credentials = $credentials | Sort-Object TargetName

    if (-not [string]::IsNullOrEmpty($searchString)) {
        $credentials = $credentials | Where-Object { $_.TargetName -like "*$searchString*" }
    }

    $credentials | ForEach-Object -Begin { $i = 1 } -Process {
        $displayTargetName = $_.TargetName -replace "^.*=", ""
        Write-Host "$i. $displayTargetName" -ForegroundColor Cyan
        $i++
    }

    if ($credentials.Count -eq 0) {
        Write-Host "No matching credentials found." -ForegroundColor Red
        return
    }

    $selection = Read-Host "Select the number of the credential to copy the username (or press Enter to exit)"
    if ([string]::IsNullOrEmpty($selection)) {
        Write-Host "Exiting..."
        return
    }

    if ($selection -notmatch '^\d+$') {
        Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
        return
    }

    $selection = [int]$selection
    if ($selection -lt 1 -or $selection -gt $credentials.Count) {
        Write-Host "Selection is out of range. Please select a valid number." -ForegroundColor Red
        return
    }

    $selectedCredential = $credentials[$selection - 1]
    $username = $selectedCredential.UserName

    if ($username -is [string]) {
        $username | Set-Clipboard
        $Seconds = 10
        for ($i = $Seconds; $i -ge 0; $i--) {
            Write-Progress -Activity "Username copied to clipboard (countdown to clipboard wipe)..." -Status "Time remaining: $i seconds" -PercentComplete (($Seconds - $i) / $Seconds * 100)
            Start-Sleep -Seconds 1
        }

        $securepassword = $selectedCredential.Password
        $securepassword | Set-Clipboard
        $Seconds = 10
        for ($i = $Seconds; $i -ge 0; $i--) {
            Write-Progress -Activity "Password copied to clipboard (countdown to clipboard wipe)..." -Status "Time remaining: $i seconds" -PercentComplete (($Seconds - $i) / $Seconds * 100)
            Start-Sleep -Seconds 1
        }

        # Detect Windows version
        $winVer = [System.Environment]::OSVersion.Version
        $isWin11 = $winVer.Major -eq 10 -and $winVer.Build -ge 22000
        $isWin10 = $winVer.Major -eq 10 -and $winVer.Build -lt 22000
        $isPowerShell5 = $PSVersionTable.PSVersion.Major -eq 5

        if ($isWin10 -and $isPowerShell5) {
            try {
                [Windows.ApplicationModel.DataTransfer.Clipboard, Windows, ContentType = WindowsRuntime]::ClearHistory() > $null
                Write-Host "`nClipboard history erased!" -ForegroundColor Green
            } catch {
                Write-Host "`nClipboard history clear failed." -ForegroundColor Red
            }
        } elseif ($isWin11) {
            Write-Host "`nWindows 11 detected. Clipboard content has been cleared." -ForegroundColor Yellow
            Write-Host "Note: Clipboard *history* must be cleared manually via:" -ForegroundColor Yellow
            Write-Host "Settings > System > Clipboard > Clear" -ForegroundColor Cyan
        } else {
            [System.Windows.Forms.Clipboard]::Clear()
            Write-Host "`nClipboard content cleared!" -ForegroundColor Green
        }
    } else {
        Write-Host "Failed to retrieve the username from the selected credential." -ForegroundColor Red
    }
}

#Delete Specific Credentials
FUNCTION del-cred {
    [CmdletBinding()]
    param ()

    $searchString = Read-Host "Enter a part of the target name to search for, or press Enter to view all credentials"

    $credentials = Get-StoredCredential -AsCredentialObject

    if ($null -eq $credentials -or $credentials.Count -eq 0) {
        Write-Host "No credentials found." -f Red
        return
    }

    # Sort credentials alphabetically by TargetName
    $credentials = $credentials | Sort-Object TargetName

    # Filter credentials based on search string
    if (-not [string]::IsNullOrEmpty($searchString)) {
        $credentials = $credentials | Where-Object { $_.TargetName -like "*$searchString*" }
    }

    # Display filtered and sorted credentials with numbering
    $credentials | ForEach-Object -Begin { $i = 1 } -Process {
        $displayTargetName = $_.TargetName -replace "^.*=", ""
        Write-Host "$i. $displayTargetName" -f Cyan
        $i++
    }

    if ($credentials.Count -eq 0) {
        Write-Host "No matching credentials found." -f Red
        return
    }

    $selection = Read-Host "Select the number of the credential to delete (or press Enter to exit)"

    if ([string]::IsNullOrEmpty($selection)) {
        Write-Host "Exiting..."
        return
    }

    if ($selection -match '^\d+$') {
        $selection = [int]$selection

        if ($selection -gt 0 -and $selection -le $credentials.Count) {
            $selectedCredential = $credentials[$selection - 1]
        } else {
            Write-Host "Selection is out of range. Please select a valid number." -f Red
            return
        }
    } else {
        Write-Host "Invalid input. Please enter a number." -f Red
        return
    }

    $selection = $selectedCredential.TargetName
	
    # Remove the selected credential
    Remove-StoredCredential -Target $selection
	
	Write-Host "$selection deleted." -f Red
}

# Create Test Credential
FUNCTION test-cred {
    [CmdletBinding()]
    param ()

    # Generate a random 8-digit number
    $randomNumber = -join ((0..9) | Get-Random -Count 8)

    # Set the target name and username using the random number
    $targetName = "tgt$randomNumber"
    $userName = "test$randomNumber"

    # Set the persistence to "Session"
    $persistence = "Session"

    # Generate a random 12-character password
    # Import System.Web assembly
	Add-Type -AssemblyName System.Web
	# Generate random password
	# ALT method: $password = [System.Web.Security.Membership]::GeneratePassword(20,2) #first number is length, second is special characters
	$length = 20
    $upper = 65..90  # ASCII A-Z
    $lower = 97..122 # ASCII a-z
    $numbers = 48..57 # ASCII 0-9
    $special = 33..47 + 58..64 + 91..96 + 123..126 # ASCII special characters
	$upper = 65..90  # ASCII A-Z
    $lower = 97..122 # ASCII a-z
    $numbers = 48..57 # ASCII 0-9
    $special = [char[]]'!@#$%^&*()' # Specified special characters
    $charSet = @()
    $charSet += $upper
    $charSet += $lower
    $charSet += $numbers
    $charSet += $special
    $passwordChars = @()
    $passwordChars += [char]($upper | Get-Random)
    $passwordChars += [char]($lower | Get-Random)
    $passwordChars += [char]($numbers | Get-Random)
    $passwordChars += ($special | Get-Random)
    for ($i = $passwordChars.Count; $i -lt $length; $i++) {
        $passwordChars += [char]($charSet | Get-Random)
    }
    # Shuffle the characters to ensure randomness
    $password = -join ($passwordChars | Sort-Object {Get-Random})
    # Store the credential
    New-StoredCredential -Target $targetName -Persist $persistence -UserName $userName -Password $password
    # Verify if the credential was successfully stored
    if ((Get-StoredCredential -Target $targetName | Where-Object { $_.UserName -eq $userName })) {
        Write-Host "New credential securely stored."
    } else {
        Write-Host "New credential not found."
    }
}

# Show current password for Windows Credential Manager object.
FUNCTION show-pass {

    [CmdletBinding()]
    param ()

    $searchString = Read-Host "Enter a part of the target name to search for, or press Enter to view all credentials"

    $credentials = Get-StoredCredential -AsCredentialObject

    if ($null -eq $credentials -or $credentials.Count -eq 0) {
        Write-Host "No credentials found." -f Red
        return
    }

    # Sort credentials alphabetically by TargetName
    $credentials = $credentials | Sort-Object TargetName

    # Filter credentials based on search string
    if (-not [string]::IsNullOrEmpty($searchString)) {
        $credentials = $credentials | Where-Object { $_.TargetName -like "*$searchString*" }
    }

    # Display filtered and sorted credentials with numbering
    $credentials | ForEach-Object -Begin { $i = 1 } -Process {
        $displayTargetName = $_.TargetName -replace "^.*=", ""
        Write-Host "$i. $displayTargetName" -f Cyan
        $i++
    }

    if ($credentials.Count -eq 0) {
        Write-Host "No matching credentials found." -f Red
        return
    }

    $selection = Read-Host "Select the number of the credential to delete (or press Enter to exit)"

    if ([string]::IsNullOrEmpty($selection)) {
        Write-Host "Exiting..."
        return
    }

    if ($selection -match '^\d+$') {
        $selection = [int]$selection

        if ($selection -gt 0 -and $selection -le $credentials.Count) {
            $selectedCredential = $credentials[$selection - 1]
        } else {
            Write-Host "Selection is out of range. Please select a valid number." -f Red
            return
        }
    } else {
        Write-Host "Invalid input. Please enter a number." -f Red
        return
    }

$securepassword = $selectedCredential.Password

if ($securepassword -is [string] ) {

# Display the password in a secure window
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show($securepassword, "Secure Password Display", 'OK', 'None') #OK, OKCancel, YesNoCancel, YesNo""
}

else {
Write-Host "$selectedCredential credential not found."
}
}

# Generate Strong Password
FUNCTION gen-pass {
    $length = 16
    $upper = 65..90  # ASCII A-Z
    $lower = 97..122 # ASCII a-z
    $numbers = 48..57 # ASCII 0-9
    $special = 33..47 + 58..64 + 91..96 + 123..126 # ASCII special characters

$upper = 65..90  # ASCII A-Z
    $lower = 97..122 # ASCII a-z
    $numbers = 48..57 # ASCII 0-9
    $special = [char[]]'!@#$%^&*()' # Specified special characters

    $charSet = @()
    $charSet += $upper
    $charSet += $lower
    $charSet += $numbers
    $charSet += $special

    $passwordChars = @()
    $passwordChars += [char]($upper | Get-Random)
    $passwordChars += [char]($lower | Get-Random)
    $passwordChars += [char]($numbers | Get-Random)
    $passwordChars += ($special | Get-Random)

    for ($i = $passwordChars.Count; $i -lt $length; $i++) {
        $passwordChars += [char]($charSet | Get-Random)
    }

    # Shuffle the characters to ensure randomness
    $password = -join ($passwordChars | Sort-Object {Get-Random})

    return $password
}
# Gen-pass

credman

# Example Usage
# Run .\Credman.ps1
