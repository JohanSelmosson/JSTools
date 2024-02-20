function Get-SecondTuesday {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]
        $Year = (Get-Date -Format "yyyy"),
        [Parameter()]
        [int]
        $Month = (Get-Date -Format "MM")
    )
    $firstdayofmonth = [datetime] ([string]$year  + "-" +  [string]$month + "-" + [string]'01')
    #Kolla av alla dagar i månaden, filtrerar ut tisdagarna och returnerar den andra tisdagen som kommer ut i slutet på pipen.
    (0..30 | ForEach-Object {$firstdayofmonth.adddays($_) } | Where-Object {$_.dayofweek -eq "Tuesday"})[1]
}
