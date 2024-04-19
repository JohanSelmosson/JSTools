function Get-DomainRole {

# https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-computersystem
$DomainRole = (get-ciminstance -ClassName Win32_ComputerSystem).domainrole

    $RoleDescription = switch ($DomainRole) {
        0 { "Standalone Workstation" }
        1 { "Member Workstation" }
        2 { "Standalone Server" }
        3 { "Member Server" }
        4 { "Backup Domain Controller" }
        5 { "Primary Domain Controller" }
        Default {}
    }

    [PSCustomObject]@{
        DomainRole = $DomainRole
        DomainRoleDescription = $RoleDescription
    }

}