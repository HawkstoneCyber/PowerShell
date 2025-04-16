FUNCTION cvesearch {
<#
.SYNOPSIS

    MITRE CVE query.

.DESCRIPTION

    Searches cve.mitre.org for CVEs related to keywords in a file. Returns results in txt file with keyword names and related CVE URLs.

.COMPONENT

	•     Keyword file in text format.

.NOTES

    Author: Shane Liptak
    Company: Hawkstone Cyber
    Date: 20240422
    Contact: info@hawkstonecyber.com
    Last Modified: 20241104
    Version: 1.0

.LINK

    https://github.com/HawkstoneCyber/PowerShell

#>

    # Prompt for the path to the keyword file
    $keywordFilePath = (Read-Host "Enter the full path/name to the file containing the keywords").Replace('"', '')

    # Get current date and time in the specified format
    $dateTime = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"

    # Prompt for the path to the results file save location
    $resultFilePath = (Read-Host "Enter the full path to the results file save location").Replace('"', '')

    # Define the path to the result file including the date-time stamp
    $completeResultFilePath = "$resultFilePath\CVE-Search-Results-$dateTime.txt"

    # Read CVE keywords from the file
    $cveKeywords = Get-Content -Path $keywordFilePath

    # Prepare to capture the results
    $results = @()

    foreach ($keyword in $cveKeywords) {
        # Split keyword by tab, replace spaces in each keyword with %20, then join them with %20
        $formattedKeyword = ($keyword -split "`t" -replace ' ', '%20') -join '%20'

        # Enclose the formatted keyword in quotes for the URL
        $formattedKeyword = '"' + $formattedKeyword + '"'

        # Build the URL for querying the CVE database
        $url = "https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=$formattedKeyword"

        # Use Invoke-WebRequest to fetch the webpage
        try {
            $response = Invoke-WebRequest -Uri $url -ErrorAction Stop

            # Parse the response content to extract hyperlinks
            $links = $response.Links | Where-Object { $_.href -match 'CVE-\d{4}-\d+' } | ForEach-Object {
                # Construct plain text link
                "$($_.href)"
            }

            # Add the extracted hyperlinks to the results array, prepending each with the keyword and a tab
            if ($links) {
                foreach ($link in $links) {
                    $results += "$keyword`t$link"
                }
            } else {
                $results += "$keyword`tNo results found"
            }
        } catch {
            $results += "$keyword`tFailed to retrieve data. Error: $_"
        }
    }

    # Write results to the output file
    $results | Out-File -FilePath $completeResultFilePath
}
cvesearch

# Example Usage
# Run PS-CVESearch.ps1

