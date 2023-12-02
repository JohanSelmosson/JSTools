function Get-LastBootUpTime {
    <#
    .SYNOPSIS
        Gets the last boot time and how many days and hours since that time.
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        Test-MyTestFunction -Verbose
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
    [Alias("Get-UpTime")]
    Param (
        # Param1 help description
        [Parameter(
            ValueFromPipelineByPropertyName,
            ValueFromPipeline,
            Position = 0)]
        [Alias("DNSHostName")]
        [string]$ComputerName
    )

    Begin {
        if ($null -eq $ComputerName) {
            $ComputerName = "" 
        }

        function GetLastBootUpTime {
            [CmdletBinding()]
            param(
                [string]
                $ComputerName
            )
            try {
                if ($ComputerName -and $env:COMPUTERNAME -notlike "*$ComputerName*") {
                    $LastBootUpTime = (Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop).LastBootUpTime
                }
                else {
                    $ComputerName = $env:COMPUTERNAME
                    $LastBootUpTime = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
                }
            }
            catch {
                Write-Warning "$PSitem"
                return [PSCustomObject]@{
                    ComputerName   = $ComputerName
                    LastBootUpTime = "" 
                    Uptime         = ""
                    UptimeVerbose  = "Unknown, query failed." 
                }
            }

            $TimeSpan = New-TimeSpan -Start $LastBootUpTime -end (get-date)
            $VerboseTimeSpan = switch ($timespan) {
                { $_.TotalMinutes -le '60' } { "$([math]::Round($_.TotalMinutes,0)) minutes since last boot"; continue }
                { $_.TotalHours -eq '1' } { "$([math]::Round($_.TotalHours,0)) hour $($_.Minutes) minutes since last boot"; continue }
                { $_.TotalHours -le '24' } { "$([math]::Round($_.TotalHours,0)) hours $($_.Minutes) minutes since last boot"; continue }
                { $_.TotalDays -eq '1' } { "$($_.Days) day $($_.Hours) hours since last boot"; continue }
                { $_.TotalDays -le '30' } { "$($_.Days) days $($_.Hours) hours since last boot"; continue }
                Default { "$([math]::Round($_.TotalDays,0)) days since last boot" }
            }

            [PSCustomObject]@{
                ComputerName   = $ComputerName
                LastBootUpTime = $LastBootUpTime
                Uptime         = $TimeSpan
                UptimeVerbose  = $VerboseTimeSpan 
            }

        }
    }
    Process {
        if (! $computername) {
            return GetLastBootUpTime
        }
        foreach ($item in $computername) {
            GetLastBootUpTime -ComputerName $ComputerName
        }
    }
    End {
    }
}