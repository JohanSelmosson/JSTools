function New-ADDGuidMap {
    <#
    .SYNOPSIS
        Creates a guid map for the delegation part
    .DESCRIPTION
        Creates a guid map for the delegation part
    .EXAMPLE
        PS C:\> New-ADDGuidMap
    .OUTPUTS
        Hashtable
    .NOTESy
        Author: Constantin Hager
        Date: 06.08.2019
    #>

    $rootdse = Get-ADRootDSE
    $guidmap = @{ }

    $GuidMapParams = @{
        SearchBase = ($rootdse.SchemaNamingContext)
        LDAPFilter = "(schemaidguid=*)"
        Properties = ("lDAPDisplayName", "schemaIDGUID")
    }

    Get-ADObject @GuidMapParams | ForEach-Object { $guidmap[$_.lDAPDisplayName] = [System.GUID]$_.schemaIDGUID }

    return $guidmap
}
