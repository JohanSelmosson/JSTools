function Get-WUMonthlyUpdates {
    [CmdletBinding()]
    param (
        [switch]
        $full,
        [string]
        $SearchQuery
    )

    if (-not $SearchQuery){
        if ((Get-SecondTuesday) -lt (get-date))  {
            $SearchQuery = get-date -Format yyyy-MM
        } else {
            $SearchQuery = get-date -Date (get-date).AddDays(-15) -Format yyyy-MM
        }
        Write-Verbose "Searching MS Catalog for ""$SearchQuery"""
    }

    $result = Get-MSCatalogUpdate -Search $SearchQuery -AllPages

    $KBList = foreach ($item in $result) {

        # Format of title (one of them)
        # 2023-12 Cumulative Update for Microsoft server operating system, version 22H2 for x64-based Systems (KB5033118)

        try {
            $KBArticle = (select-string -InputObject  $item.title -Pattern "\(([^)]+)\)$").Matches.groups[1]
        }
        catch {
            $KBArticle = ""
        }

        if ($Full) {
            $title = $Item.Title
        } else {
            #Remove ' for x64' and everything after
            $title = $item.Title -replace ' for x64.*$', ''
            #Remove ' for arm64' and everthing after
            $title = $Title -replace ' for arm64.*$', ''
            #Remove ' for x86' and everything after
            $title = $Title -replace ' for x86.*$', ''
            #Remove (KB12345) and everything after, we already captured the KB-number into $KBArticle
            $Title = $Title -replace "\(KB\d+\)", ''
        }

        $output = [PSCustomObject]@{
            KB = $KBArticle
            Title = $title
            Classification = $item.Classification
        }

        if ($Full) {
            $output  | add-member -MemberType NoteProperty -Name Guid -Value $item.guid
            $output  | add-member -MemberType NoteProperty -Name Products -Value $item.Products
        }
        $output
    }

    if ($Full) {
        $KBList
    } else {
        #The KB-number can be used on several updates if they are for the same OS-family or for
        #one of several cpu architectures (x86/arm64/x64)
        #Here we group them together and just pick one of them.
        #It´s good enough to know if it is a Cumulative update for 2023-11
        $KBList | Group-Object -Property "KB" | ForEach-Object {$_.Group[0]}
    }

}
