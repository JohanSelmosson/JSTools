function Add-ADObjectAce {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        $DN,

        [parameter()]
        [ValidateSet(
            "AccessSystemSecurity",
            "CreateChild",
            "Delete",
            "DeleteChild",
            "DeleteTree",
            #"ExtendedRight",
            "GenericAll",
            "GenericExecute",
            "GenericRead",
            "GenericWrite",
            "ListChildren",
            "ListObject",
            "ReadControl",
            "ReadProperty",
            "Self",
            "Synchronize",
            "WriteDacl",
            "WriteOwner",
            "WriteProperty"
        )]
        [string[]]
        $ActiveDirectoryRights,

        [parameter()]
        [ValidateSet("Allow", "Deny")]
        [string]
        $AccessControlType = "Allow",

        [parameter()]
        [validateset(
            "All",
            "Children",
            "Descendents",
            "None",
            "SelfAndChildren"
        )]
        [string[]]
        $ActiveDirectorySecurityInheritance="Descendents",

        [parameter()]
        [string]
        $inheritedObjectType,

        $Identity
    )

    if ($inheritedObjectType) {
        $inheritedObjectGuid = (New-ADDGuidMap)[$inheritedObjectType]

        if (-not $inheritedObjectGuid) {
            Write-Warning "could not find the Guid for $inheritedObjectType, aborting"
            break
        }
    }

    try {
        $sid = new-object System.Security.Principal.SecurityIdentifier (get-adgroup -Identity $Identity).sid
    }
    catch {
        Write-Warning "Could Not find $identity in AD, aborting"
        break
    }

    try {
        $ACL = Get-Acl -Path "AD:\$dn" -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not get ACL for $DN"
        break
    }


    if ($inheritedObjectType) {

        #funkar
        $Ace = [System.DirectoryServices.ActiveDirectoryAccessRule]::New(
            $SID, #Identity
            $ActiveDirectoryRights, #https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.activedirectoryrights?view=dotnet-plat-ext-8.0
            $AccessControlType, #Allow / Deny
            $ActiveDirectorySecurityInheritance,
            $inheritedObjectGuid #Group GUID
        )

        #otestad
        $Ace = [System.DirectoryServices.ActiveDirectoryAccessRule]::new(
            [System.Security.Principal.SecurityIdentifier]$Sid,
            [System.DirectoryServices.ActiveDirectoryRights]$ActiveDirectoryRights,
            [System.Security.AccessControl.AccessControlType]$AccessControlType,
            [System.Security.ActiveDirectorySecurityInheritance]$ActiveDirectorySecurityInheritance,
            [guid]::$inheritedObjectGuid
        )
    }

    $ACL.AddAccessRule($Ace)

    $ACE

    if ($PSCmdlet.ShouldProcess($DN, "Add ACE")) {
        try {
            Set-Acl -Path "AD:\$dn" -AclObject $acl
        }
        catch {
            Write-Warning "Could not update the acl on $DN"
            break
        }
    }

}
