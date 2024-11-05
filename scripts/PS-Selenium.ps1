FUNCTION Invoke-Update {

<#
.SYNOPSIS

    Proof of concept automated login and content posting to the ClearanceJobs.com website utlizing PowerShell 7 and the Selenium WebDriver for Microsoft Edge.

.DESCRIPTION

    Provides automated login to the ClearanceJobs.com website and content updates (status posts) for a given user profile utilizing PowerShell 7 in concert with the Selenium WebDriver for Microsoft Edge. Dependent on the PowerShell TUN.CredentialManager module for credential management.

.COMPONENT

	•     Selenium WedDriver for the Microsoft Edge browser

	•     TUN.CredentialManager to access credentials stored in Windows Credential Manager

	•     Text file with content prepended by a dash `- `

.NOTES

    Author: Shane Liptak
    Company: Hawkstone Cyber LLC
    Date: 20240322
    Contact: info@hawkstonecyber.com
	Last Modified: 20241104
    Version: 1.0

.LINK

    https://github.com/HawkstoneCyber/PowerShell

#>

# Function to post an update

    param (
        [string] $textFilePath,
        [OpenQA.Selenium.IWebDriver] $driver
    )

    # Open the status update form
    $statusUpdateButton = $driver.FindElementByCssSelector("button.btn.cjicon-wrapper.status-update")
    $statusUpdateButton.Click()

    Write-Output "Status update form opened."

    # Wait for the content-editable area to become visible
    $wait = New-Object OpenQA.Selenium.Support.UI.WebDriverWait $driver, ([TimeSpan]::FromSeconds(10))
    $contentEditable = $wait.Until([OpenQA.Selenium.Support.UI.ExpectedConditions]::ElementIsVisible([OpenQA.Selenium.By]::CssSelector("div.tiptap.ProseMirror")))

    # Focus and clear existing content
    $contentEditable.Click()
    $driver.ExecuteScript("arguments[0].innerHTML = '';", $contentEditable)

    # Load and set new content from text file. Change the $prefix as desired.
    $statusUpdates = @()
    Get-Content $textFilePath | ForEach-Object {
        if ($_ -match '^\s*-\s') {
            $line = $_ -replace '^\s*-\s', ''
            $prefix = "Wouldn't you like to hire a candidate with-> "
            $statusUpdates += $prefix + $line
        }
    }

    $statusUpdateText = Get-Random -InputObject $statusUpdates
    $driver.ExecuteScript("arguments[0].textContent = arguments[1];", $contentEditable, $statusUpdateText)

    Start-Sleep -Seconds 2

    # Click the 'Post Update' button
    $postUpdateButton = $driver.FindElementByCssSelector("button.btn.btn-info.uppercase[data-v-60e8db57]:not([disabled])")
    $postUpdateButton.Click()

    Write-Output "Status update posted."
}

FUNCTION Invoke-PostingLoop {
    param (
        [string] $username,
        [string] $textFilePath
    )
	Write-Output = "Testing"
    $securePassword = Get-StoredCredential -Target "MicrosoftPowerShell:user=$username"
    $password = $securePassword.GetNetworkCredential().Password

    $driver = Start-SeEdge
    $driver.Url = "https://www.clearancejobs.com/login"

    $usernameField = $driver.FindElementByCssSelector("input[placeholder=Username]")
    $passwordField = $driver.FindElementByCssSelector("input[placeholder=Password]")
    $loginButton = $driver.FindElementByCssSelector("#login-btn")

    $usernameField.SendKeys($username)
    $passwordField.SendKeys($password)
    $loginButton.Click()

    Start-Sleep -Seconds 5
    $driver.Url = "https://www.clearancejobs.com/profile/timeline"
    Start-Sleep -Seconds 5

    $continueLoop = $true  # Control variable to manage the loop continuation without re-prompting

    do {
        Invoke-Update -textFilePath $textFilePath -driver $driver

        if ($continueLoop) {
            $quitprompt = Read-Host -Prompt "Do you want to quit? Y or N."
            if ($quitprompt -match "Y") {
                $driver.Quit()
                break
            } elseif ($quitprompt -match "N") {
                $continueLoop = $false  # User chose not to quit, disable further prompts
            }
        }

        $randomDelay = Get-Random -Minimum 600 -Maximum 1800
        Write-Output "Waiting $randomDelay seconds before posting the next update..."
        $startTime = Get-Date

        # Implementing the progress bar
        while ((Get-Date) -lt $startTime.AddSeconds($randomDelay)) {
            $elapsed = (New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds
            $percentComplete = ($elapsed / $randomDelay) * 100
            Write-Progress -Activity "Waiting to post next update" -Status "$([math]::Round($percentComplete, 2))% Complete" -PercentComplete $percentComplete
            Start-Sleep -Seconds 1
        }
    } while ($true)
}

FUNCTION Invoke-CJPost {
$username = Read-Host "Input user name."
$textFilePath = Read-Host "Input file path and name."
Invoke-PostingLoop $username $textFilePath
}
Invoke-CJPost

#Example
#Run PS-Selenium.ps1 file to use.
