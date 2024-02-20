function Get-WUHotfixTitle {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string[]]
        $KB
    )

    Begin {

    }

    Process{
        foreach ($KBItem in $KB) {
            $WUCatalogSearch = Get-MSCatalogUpdate -Search $KBItem
            $Matches = Select-String -Pattern "\(([^)]+)\)$" -InputObject $WUCatalogSearch[0].Title
            $Matches.Matches.Groups[1].Value

        }
    }

    End {

    }
}
