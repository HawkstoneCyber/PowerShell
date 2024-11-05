<#
.SYNOPSIS

    Queries Windows logs for a term.

.DESCRIPTION

    Queries select or every available Windows event log for a user provided term. When you just want to find something possibly logged without really knowing where to look.

.COMPONENT

	 N/A

.NOTES

    Author: Shane Liptak
    Company: Hawkstone Cyber
    Date: 202405xx
    Contact: info@hawkstonecyber.com
    Last Modified: 20241105
    Version: 1.0

.LINK

    https://github.com/HawkstoneCyber/PowerShell

#>

# Query Windows Event Logs
function Get-Log {
    Write-Host " " -ForegroundColor Black

    # Prompt user for estimated log name and construct the wildcard pattern
    $estimatedloginput = Read-Host "Input estimated log name"
    $estimatedlog = "*$estimatedloginput*"

    # Display available logs matching the estimated log name
    $matchingLogs = Get-WinEvent -ListProvider $estimatedlog | Select-Object Name, LogLinks
    $logLinksList = @()
    $uniqueLogNames = @{}
    $index = 1

    if ($matchingLogs) {
        Write-Host "Matching logs:" -ForegroundColor Green
        foreach ($log in $matchingLogs) {
            foreach ($logLink in $log.LogLinks) {
                if (-not $uniqueLogNames.ContainsKey($logLink.LogName)) {
                    Write-Host "$index. $($logLink.LogName)"
                    $logLinksList += $logLink.LogName
                    $uniqueLogNames[$logLink.LogName] = $true
                    $index++
                }
            }
        }
        Write-Host "$index. Search all matching logs"
    } else {
        Write-Host "No logs found matching '$estimatedlog'" -ForegroundColor Red
        return
    }

    Write-Host " " -ForegroundColor Black

    # Prompt user to select the log by number
    $logIndex = [int](Read-Host "Input the number corresponding to the log name")
    if ($logIndex -eq $index) {
        $logsToSearch = $logLinksList
    } elseif ($logIndex -gt 0 -and $logIndex -lt $index) {
        $logsToSearch = @($logLinksList[$logIndex - 1])
    } else {
        Write-Host "Invalid selection. Exiting." -ForegroundColor Red
        return
    }

    # Prompt user for object name to find in the log
    $nameinput = Read-Host "Input object name to find in log"
    $name = [regex]::Escape($nameinput)

    # Fetch and display log events matching the criteria, fully suppressing errors
    foreach ($log in $logsToSearch) {
        try {
            # Execute Get-WinEvent and pipe output to Out-Null if there are no matches
            $logEvents = Get-WinEvent -Oldest -LogName $log 2>$null | Where-Object { $_.Message -match $name }
            if ($logEvents) {
                Write-Host "Log entries found in '$log':" -ForegroundColor Green
                $logEvents | Select-Object LogName, TimeCreated, Id, LevelDisplayName, Message | Format-Table -AutoSize
            }
        } catch {
            # Suppress all errors silently
            continue
        }
    }
}
