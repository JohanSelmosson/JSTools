function New-JSModule {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $ModuleName,
        # Path
        [Parameter()]
        [string]
        $Path  
    )

    if ($Path -eq "") {
        $Path = (get-item (Get-Location)).FullName
        Write-Verbose "Path is undefined, setting the parent path to: $Path"
    }    

    if (test-path (join-path $path $ModuleName) -PathType Container ) {
        Write-Verbose "folder $(Join-Path $path $ModuleName) already exists"
    
        if ((get-childitem (join-path $path $ModuleName)).Count -eq 0) {
            Write-Verbose "Folder is empty, creating module here."
        }
        else {
            Write-Warning "There are already files in $(Join-Path $Path $ModuleName) aborting"
            break
        }
    }

    $ModulePath = Join-Path $Path $ModuleName

    new-item $ModulePath -ItemType Directory
    New-Item $ModulePath\Tests\ -ItemType Directory
    new-item $ModulePath\source\public -itemType Directory
    new-item $ModulePath\source\private -itemType Directory
    
    new-item $ModulePath\source\public\.gitkeep -itemType File
    new-item $ModulePath\source\private\.gitkeep -itemType File
    
    $GitIgnore = @"
# ignore the build folder
Output/
"@

    set-content $path\$ModuleName\.gitignore -value $GitIgnore    
    
    $BuildPsdOneContent = @"
# -----------------------------------------------------------------------------
# ModuleBuilder configuration file. Use this file to override the default
# parameter values used by the `Build-Module` command when building the module.
#
# For a full list of supported arguments run `Get-Help Build-Module -Full`.
# -----------------------------------------------------------------------------

@{
    Path = "$ModuleName.psd1"
    VersionedOutputDirectory = `$true
    CopyDirectories = @(
        #Path relative to the source folder
        #".\Files",
        #".\AnotherfolderwithFiles"
    )
}
"@
    set-content -path $ModulePath\source\build.psd1 -Value $BuildPsdOneContent

    $samplefunctionfile = @"
function Write-About$ModuleName {
    Write-Information "This is a sample function in the $ModuleName module."
    Write-Host "This is a sample function in the $ModuleName module."
    $unused = "not used"
}

"@
    set-content $ModulePath\source\public\Write-About$ModuleName.ps1 -Value $SampleFunctionFile

    #Install-Module -Name PSScriptAnalyzer -Scope CurrentUser

    $PesterBaseTests = @"
describe 'Module-level tests' {

    BeforeAll {
        `$Version = (Test-ModuleManifest `$PSScriptRoot\..\source\$ModuleName.psd1 -ErrorAction SilentlyContinue ).Version
    }

    `$Version = (Test-ModuleManifest `$PSScriptRoot\..\source\$ModuleName.psd1 -ErrorAction SilentlyContinue ).Version

    it 'the module imports successfully' {
        { Import-Module "`$PSScriptRoot\..\output\$ModuleName\`$Version\$moduleName.psm1" -ErrorAction Stop } | Should -not -Throw
    }

    it 'the module has an associated manifest' {
        Test-Path "`$PSScriptRoot\..\output\$ModuleName\`$Version\$moduleName.psd1" | should -Be `$true
    }

    it 'passes all default PSScriptAnalyzer rules' {
        Invoke-ScriptAnalyzer -Path "`$PSScriptRoot\..\output\$ModuleName\`$Version\$moduleName.psm1" | should -BeNullOrEmpty
    }
}

"@
    set-content $ModulePath\Tests\$ModuleName.Generic.Tests.ps1 -Value $PesterBaseTests

    $buildscript = @"
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

if ((get-module Microsoft.Powershell.PSResourceGet -ListAvailable) -eq `$null) {
    Write-Host -NoNewLine "      Installing PSResourceGet module"
    `$null = Install-Module Microsoft.Powershell.PSResourceGet
    Write-Host -ForegroundColor Green '...Installed!'
}

if ((get-module Microsoft.Powershell.PSResourceGet -ListAvailable) -eq `$null) {
    Write-Host -NoNewLine "      Importing PSResourceGet module"
    `$null = Import-Module Microsoft.Powershell.PSResourceGet
    Write-Host -ForegroundColor Green '...Imported!'
}

if ((get-module PSScriptAnalyzer -ListAvailable) -eq `$null) {
    Write-Host -NoNewLine "      Installing PScriptAnalyzer module"
    `$null = Install-PSResource PSScriptAnalyzer 
    Write-Host -ForegroundColor Green '...Installed!'
}

if ((get-PSResource ModuleBuilder) -eq `$null) {
    Write-Host -NoNewLine "      Installing ModuleBuilder module"
    `$null = Install-PSResource ModuleBuilder
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

# Kick off the standard build
try {
    Build-Module `$PSScriptRoot\source\ 
}
catch {
    # If it fails then show the error and try to clean up the environment
    Write-Host -ForegroundColor Red 'Build Failed with the following error:'
    Write-Output `$_
}
finally {
    Write-Host ''
    #Write-Host 'Attempting to clean up the session (loaded modules and such)...'
    #Invoke-Build BuildSessionCleanup
    #Remove-Module 
}

invoke-pester `$psscriptroot\tests\

Invoke-ScriptAnalyzer -Path `$psscriptroot\source\private\*
Invoke-ScriptAnalyzer -Path `$psscriptroot\source\public\*

"@

    set-content $ModulePath\build.ps1 -Value $buildscript

    New-ModuleManifest -Path "$ModulePath\source\$ModuleName.psd1" -RootModule "$ModuleName.psm1" -ModuleVersion '0.1.0'
}

#$testing = $True
if ($testing) {

    Set-Location c:\mb
    remove-item C:\mb\jsmoduletest -Recurse
    New-JSModule -ModuleName jsmoduletest
    
    Set-Location C:\mb\jsmoduletest\
    .\build.ps1
}



