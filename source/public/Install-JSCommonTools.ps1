function Install-JSCommonToolsWIP {
    [CmdletBinding()]
    param (

    )

    begin {
        $commands = @{
            "rg" = "BurntSushi.ripgrep.MSVC"
            "fzf" = "fzf"
            "pwsh" = "Microsoft.PowerShell"
            "code"  = "Microsoft.VisualStudioCode"
            "git"  = "Git.Git"
        }

        $WingetExePath = (get-command winget).source

        $Modules = @(
            'Pester',
            'PSScriptAnalyzer'
        )

        $ModulesAvailable = Get-Module -ListAvailable

        if ($ModulesAvailable.Name -notcontains 'Microsoft.Powershell.PSResourceGet') {
            Install-Module - 'Microsoft.Powershell.PSResourceGet'
        }

    }

    process {

        foreach ($command in $commands.keys) {
            try {
                $null = get-command $command -erroraction stop
                Write-Information "Command $command is available"
            }
            catch {
                write-verbose "Excuting: $($commands[$command])"
                #& $($commands[$command])
                try {
                    #Start-Process -FilePath $wingetexepath -Wait -ArgumentList $commands[$command]
                    #Write-Host "Path to Winget: $WingetExePath"
                    #Write-Host "$WingetExePath $($Commands[$command])"
                    winget install $($Commands[$command])
                }
                catch {
                    Write-Warning $PSItem
                }
            }
        }



    }

    end {

    }
}
Install-JSCommonToolsWIP
