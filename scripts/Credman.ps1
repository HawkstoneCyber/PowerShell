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
    Date: 20250416
    Contact: shane@hawkstonecyber.com
    Last Modified: 20250416
    Version: 1.0

.LINK

    https://github.com/HawkstoneCyber/PowerShell

#>

FUNCTION credman {
# Main loop
while ($true) {
	cls
	Write-Host "Credential Manager" -f cyan
	Write-Host "----------------------------------------------------------------------" -f white
	Write-Host "1 Add Credential" -f cyan
	Write-Host "2 Copy Credential" -f cyan
	Write-Host "3 Create Temp Test Credential" -f cyan
	Write-Host "4 Delete Credential" -f cyan
	Write-Host "5 Show Credential Password" -f cyan
	Write-Host "6 Create Strong Password" -f cyan
	Write-Host "7 Backup / Restore Credential dB" -f cyan
	Write-Host " " -f black
    $choice = Read-Host "Please enter your choice (1-7) or enter to exit"

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
		
		1 { add-cred }
    2 { copy-cred }
    3 { test-cred }
    4 { del-cred }
    5 { show-pass }
		6 { gen-pass }
		7 { credwiz }
		
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

# Copy Credential
FUNCTION copy-cred {
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

    $selection = Read-Host "Select the number of the credential to copy the username (or press Enter to exit)"

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

    $username = $selectedCredential.UserName

    if ($username -is [string]) {
        $username | Set-Clipboard
        $Seconds = 10
        for ($i = $Seconds; $i -ge 0; $i--) {
            Write-Progress -Activity "Clipboard username copy (countdown to self destruct)..." -Status "Time remaining: $i seconds" -PercentComplete (($Seconds - $i) / $Seconds * 100)
            Start-Sleep -Seconds 1
        }
		[Windows.ApplicationModel.DataTransfer.Clipboard, Windows, ContentType = WindowsRuntime]::ClearHistory() > $null
        $securepassword = $selectedCredential.Password
        $securepassword | Set-Clipboard
        $Seconds = 10
        for ($i = $Seconds; $i -ge 0; $i--) {
            Write-Progress -Activity "Clipboard password copy (countdown to self destruct)..." -Status "Time remaining: $i seconds" -PercentComplete (($Seconds - $i) / $Seconds * 100)
            Start-Sleep -Seconds 1
        }
		[Windows.ApplicationModel.DataTransfer.Clipboard, Windows, ContentType = WindowsRuntime]::ClearHistory() > $null
        Write-Host "" -f Black
        Write-Host "" -f Black
        Write-Host "" -f Black
        Write-Host "Clipboard " -f Yellow -NoNewline
        Write-Host "erased! " -f Green
        Write-Host "" -f Black
        Write-Host "" -f Black
    } else {
        Write-Host "Failed to retrieve the username from the selected credential." -f Red
    }
}

#Delete Specific Credentials
FUNCTION del-cred {
    # Get stored credentials
    $creds = Get-StoredCredential -AsCredentialObject -ErrorAction SilentlyContinue

    # Check if there are any stored credentials
    if ($creds -eq $null) {
        Write-Host "No stored credentials found."
        return
    }

    # Display the stored credentials as a numbered list
    $i = 1
    foreach ($cred in $creds) {
        Write-Host "$i. $($cred.TargetName)"
        $i++
    }

    # Prompt the user to select the number of the credential to delete
    Write-Host "" -f Black
	$selection = Read-Host "Enter the number of the credential to delete"

    # Validate the user's input
    if ([string]::IsNullOrWhiteSpace($selection) -or -not $selection -match '^\d+$' -or [int]$selection -lt 1 -or [int]$selection -gt $creds.Count) {
        Write-Host "Invalid selection. Cancelling the function."
        return
    }

    # Convert the selection to an integer
    $selection = [int]$selection

    # Get the selected credential
    $credToDelete = $creds[$selection - 1]
    $targetNameString = $credToDelete.TargetName.ToString()

    # Remove the selected credential
    Remove-StoredCredential -Target $targetNameString

    # Display remaining credentials
	Write-Host "" -f Black
    $remainingCreds = Get-StoredCredential -AsCredentialObject -ErrorAction SilentlyContinue
    if ($remainingCreds -eq $null) {
        Write-Host "No remaining stored credentials."
    } else {
        Write-Host "Remaining stored credentials" -f cyan
		Write-Host "" -f Black
		$remainingCreds | ForEach-Object {
                    if ($targetValue -match "target=(.+)") {
                        Write-Host $matches[1]
                    } else {
                        Write-Host $_.TargetName
                    }
                }
    }
}

#Create Test Credntial
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

#Show current password for Windows Credential Manager object (Requires TUN.CredentialManager Module).
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

# Example Usage
# Run .\Credman.ps1
