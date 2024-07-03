function Get-ShodanIPInfo {

[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $APIKey,

    [Parameter()]
    [ipaddress[]]
    $IPAddress
)

begin {}

process {
    foreach($IPItem in $IPAddress){
        try {
            Invoke-RestMethod -uri "https://api.shodan.io/shodan/host/$($IPItem.IPAddressToString)?key=$APIKEY" -ErrorAction Stop
        }
        catch {
            Write-Warning "$($IPItem.IpaddresstoString) $_"
        }
    }
}

end {}

}