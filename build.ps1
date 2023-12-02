#Requires -Version 5
<#
.Synopsis
	Build script using Invoke-Build (https://github.com/nightroman/Invoke-Build)
.Description
    The overarching build steps are:
    * Installing required modules
    * Building the module
    * Running pester tests
    * Running psscriptanalyzer

   To run the basic build:
        .\build.ps1

#>

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet("Build","Test","Analyze","Publish")]
    [string[]]
    $Task = @('Build', 'Test')
)

if ((get-module Microsoft.Powershell.PSResourceGet -ListAvailable) -eq $null) {
    Write-Host -NoNewLine "      Installing PSResourceGet module"
    $null = Install-Module Microsoft.Powershell.PSResourceGet
    Write-Host -ForegroundColor Green '...Installed!'
}

if ((get-module Microsoft.Powershell.PSResourceGet -ListAvailable) -eq $null) {
    Write-Host -NoNewLine "      Importing PSResourceGet module"
    $null = Import-Module Microsoft.Powershell.PSResourceGet
    Write-Host -ForegroundColor Green '...Imported!'
}

if ((get-module PSScriptAnalyzer -ListAvailable) -eq $null) {
    Write-Host -NoNewLine "      Installing PScriptAnalyzer module"
    $null = Install-PSResource PSScriptAnalyzer
    Write-Host -ForegroundColor Green '...Installed!'
}

if ((get-PSResource ModuleBuilder) -eq $null) {
    Write-Host -NoNewLine "      Installing ModuleBuilder module"
    $null = Install-PSResource ModuleBuilder
    Write-Host -ForegroundColor Green '...Installed!'
}

if (get-PSResource ModuleBuilder ) {
    Write-Host -NoNewLine "      Importing ModuleBuilder module"
    Import-Module ModuleBuilder -Force -WarningAction SilentlyContinue
    Write-Host -ForegroundColor Green '...Imported!'
}
else {
    throw 'How did you even get here?'
}

if ($task -contains "Build") {
    # Kick off the standard build
    try {
        Build-Module $PSScriptRoot\source\
    }
    catch {
        # If it fails then show the error and try to clean up the environment
        Write-Host -ForegroundColor Red 'Build Failed with the following error:'
        Write-Output $_
    }
    finally {
        Write-Host ''
        #Write-Host 'Attempting to clean up the session (loaded modules and such)...'
        #Invoke-Build BuildSessionCleanup
        #Remove-Module
    }
}

if ($Task -contains "Test") {
    invoke-pester $psscriptroot\tests\
}

if ($Task -contains "Analyze") {
    Invoke-ScriptAnalyzer -Path $psscriptroot\source\private\* -Settings $PSScriptRoot\tests\PSScriptAnalyzerSettings.psd1
    Invoke-ScriptAnalyzer -Path $psscriptroot\source\public\*  -Settings $PSScriptRoot\tests\PSScriptAnalyzerSettings.psd1
}

if ($Task -contains "Publish") {
    Write-Warning "Publish has not been implemented yet"
}
