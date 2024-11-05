FUNCTION Get-OutlookEmailHeaderBrief {

<#
.SYNOPSIS

    Outlook email headers extraction.

.DESCRIPTION

    Returns Outlook email headers (brief format) including Date, Subject, HELO server, and any URLs. I created this script to provide a fast way to conduct bulk data extraction for analyzing malicious or tracking URLs.

.COMPONENT

	Requires Outlook installed on the client machine.

.NOTES

    Author: Shane Liptak
    Company: Hawkstone Cyber
    Date: 20240608
    Contact: info@hawkstonecyber.com
    Last Modified: 20241104
    Version: 1.0

.LINK

    https://github.com/HawkstoneCyber/PowerShell

#>

    $mailboxName = Read-Host "Please enter the mailbox name (email address)"
    $folderName = Read-Host "Please enter the Outlook mailbox folder name (e.g. Junk Email) where the emails are stored"

    # Function to process emails in the specified folder
    function ProcessEmailsInFolder($folder) {
        $folder.Items | ForEach-Object {
            $item = $_
            if ($item -is [System.__ComObject] -and $item.MessageClass -eq "IPM.Note") {
                try {
                    # Extract subject, transport date, and HELO data
                    $subject = $item.Subject
                    $transportDate = $item.ReceivedTime.ToString("g")
                    $internetHeaders = $item.PropertyAccessor.GetProperty("http://schemas.microsoft.com/mapi/proptag/0x007D001E")
                    $heloData = if ($internetHeaders -match "helo=([^;]+);") { $matches[1].Trim() } else { "N/A" }
                    
                    # Construct a detailed data string for each email
                    $data = "Date Sent: $transportDate`r`nSubject: $subject`r`nHELO Data: $heloData`r`n"
                    Add-Content -Path $global:fileName -Value $data
                    
                    # Parse the plain text email content for URLs, prepend with hex variable
                    $plainTextBody = $item.Body
                    $matches = [regex]::Matches($plainTextBody, '(http|https)://[a-zA-Z0-9./?=_-]+')
                    foreach ($match in $matches) {
                        $url = $match.Value
                        
                        # Skip the specified URL pattern
                        if ($url -eq "https://na01.safelinks.protection.outlook.com/?url=https") {
                            continue
                        }

                        # Generate a random 64-character hexadecimal string
                        $bytes = New-Object byte[] 32
                        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
                        $hexvariable = ($bytes | ForEach-Object ToString x2) -join ''
                        
                        # Add URL with descriptor to file
                        Add-Content -Path $global:fileName -Value "URL ID $hexvariable`: $url`r`n"
                    }
                    
                } catch {
                    Write-Warning "Failed to process item. It may not be a mail item or might be missing expected properties."
                }
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($item) | Out-Null
            }
        }
    }

    # Setup Outlook COM objects
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNameSpace("MAPI")

    # Locate the target mailbox and specified folder
    $targetMailbox = $namespace.Folders | Where-Object { $_.Name -eq $mailboxName }
    if (-not $targetMailbox) {
        Write-Error "Mailbox with the name '$mailboxName' was not found."
        return
    }

    $specificFolder = $targetMailbox.Folders | Where-Object { $_.Name -eq $folderName }
    if (-not $specificFolder) {
        Write-Error "The folder '$folderName' was not found in '$mailboxName'."
        return
    }

    # Prepare the output file name with mailbox name, folder name, and the current date and time
    $date = Get-Date -Format "yyyy-MM-dd HH_mm_ss"
    $mailboxNameForFile = $mailboxName -replace '[\\/:*?"<>|]', '-' # Basic sanitization
    $folderNameForFile = $folderName -replace '[\\/:*?"<>|]', '-'
    $global:fileName = "${mailboxNameForFile}_${folderNameForFile}_header-brief-$date.txt"

    # Process the emails
    ProcessEmailsInFolder $specificFolder

    Write-Output "Header and URL extraction complete. File saved as $global:fileName."

    # Cleanup to free resources
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($specificFolder) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($targetMailbox) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($namespace) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($outlook) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}
Get-OutlookEmailHeaderBrief

# Example of how to call the function:
# Run the Get-OutlookEmailHeader.ps1 file.

