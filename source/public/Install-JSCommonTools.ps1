function Install-JSCommonToolsWIP {
    [CmdletBinding()]
    param (

    )

    begin {
        $commands = @{
            "rg" = "install BurntSushi.ripgrep.MSVC"
            "fzf" = "install fzf"
            "code"  = "install Microsoft.VisualStudioCode"
            "git"  = "install Git.Git"
        }

        $wingetexepath = (get-command winget).source

    }

    process {

        foreach ($command in $commands.keys) {
            try {
                get-command $command -erroraction stop
                Write-Information "Command $command is available"
            }
            catch {
                write-verbose "Excuting: $($commands[$command])"
                #& $($commands[$command])
                & $wingetexepath $commands[$command]
            }
        }



    }

    end {

    }
}
Install-JSCommonToolsWIP -verbose
