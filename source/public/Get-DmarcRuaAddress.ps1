function Get-DmarcRuaAddress {
    [CmdletBinding()]
    param (
        [Parameter(
            ValueFromPipeline,
            Position = 0)]
        [string[]]
        $DmarcPolicy
    )

    Begin {
        $rua_regex = "rua=([^;]+)"
        $email_regex = "mailto:([^,;]+)"
    }

    Process {
        foreach ($DmarPolicyItem in $DmarcPolicy) {
            <# $DmarPolicyItem is tDmarc$DmarcPolicy item #>
            $rua_match = $string | Select-String -Pattern $rua_regex
            if ($rua_match) {
                $rua_addresses = $rua_match.Matches.Groups[1].Value
                $email_matches = [regex]::Matches($rua_addresses, $email_regex)

                foreach ($email in $email_matches) {
                    $email.Groups[1].Value
                }
            } else {
                Write-Verbose "No rua-addresses found in the string."
            }
        }
    }
}
