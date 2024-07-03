function Get-ShodanSimpleIPInfo {

[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
    [ipaddress[]]
    $IPAddress
)

begin {}

process {
    foreach($IPItem in $IPAddress){
        try {
            (Invoke-WebRequest https://internetdb.shodan.io/$($IPItem.IPAddressToString) -ErrorAction Stop).content  | convertfrom-json
        }
        catch {
            Write-Warning "$($IPItem.IpaddresstoString) $_"
        }
    }
}

end {}

}