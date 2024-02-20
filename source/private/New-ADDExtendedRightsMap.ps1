function New-ADDExtendedRightsMap {
    <#
    .SYNOPSIS
        Creates a extended rights map for the delegation part
    .DESCRIPTION
        Creates a extended rights map for the delegation part
    .EXAMPLE
        PS C:\> New-ADDExtendedRightsMap
    .NOTES
        Author: Constantin Hager
        Date: 06.08.2019
    #>

    $rootdse = Get-ADRootDSE

    $ExtendedMapParams = @{
        SearchBase = ($rootdse.ConfigurationNamingContext)
        LDAPFilter = "(&amp;(objectclass=controlAccessRight)(rightsguid=*))"
        Properties = ("displayName", "rightsGuid")
    }

    $ExtendedRightsMap = @{ }

    Get-ADObject @ExtendedMapParams | ForEach-Object { $extendedrightsmap[$_.displayName] = [System.GUID]$_.rightsGuid }

    return $ExtendedRightsMap
}
