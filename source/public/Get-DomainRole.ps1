function Get-DomainRole {

# https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-computersystem
# Standalone Workstation (0)
# Member Workstation (1)
# Standalone Server (2)
# Member Server (3)
# Backup Domain Controller (4)
# Primary Domain Controller (5)

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