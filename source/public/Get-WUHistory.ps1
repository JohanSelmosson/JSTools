function Get-WUHistory {

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [Alias("Name", "DNSHostName")]
        [string[]]
        $ComputerName
    )

    Begin {
        $UpdateHT = @{
            "KB5034129" = "2024-01 Cumulative Update for Microsoft server operating system, version 22H2 for x64-based Systems"
            "KB5029928" = "2023-09 Cumulative Update for .NET Framework 3.5 and 4.8 for Microsoft server operating system"
        }


    }
    Process {
        foreach ($ComputerNameItem in $ComputerName) {
            $result = $null

            try {
                $HotfixHistory = Get-CimInstance -Class win32_quickfixengineering -ComputerName $ComputerName
            }
            catch {
                Write-Warning $_
            }

            foreach ($Item in $HotfixHistory) {

                if ($UpdateHT[$item.HotfixID]) {
                    $HotfixInfo = $UpdateHT[$Item.HotfixID]
                }
                else {
                    $HotfixInfo = "Unknown"
                }

                [PSCustomObject]@{
                    ComputerName = $ComputerNameItem
                    HotfixID     = $Item.HotfixID
                    Info         = $HotfixInfo
                    Source       = $Item.Source
                    Description  = $Item.Description
                    Installedby  = $item.InstalledBy
                    InstalledOn  = $item.InstalledOn
                }
            }
        }

    }
    End {

    }

}
