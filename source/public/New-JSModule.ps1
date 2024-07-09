function New-JSModule {
    <#
    .SYNOPSIS
        Creates the scaffolding for a new module.
    .DESCRIPTION
        This is a self contained function that creates the folders, buildscripts and manifest files
        that are needed to maintain a buildable module
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        New-JSModule -ModuleName js.windows.uptime
        Creates the folders and files needed for building a module namned js.windows.uptime in
        the folder .\js.windows.uptime.

        New-JSModule -ModuleName js.windows.schedulereboot -path c:\PS\
        Creates the folders and files needed for building a module named js.windows.schedulereboot
        in the folder c:\ps\js.windows.schedulereboot\
    #>


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
        $Path = (Get-Item (Get-Location)).FullName
        Write-Verbose "Path is undefined, setting the parent path to: $Path"
    }

    if (Test-Path (Join-Path $path $ModuleName) -PathType Container ) {
        Write-Verbose "folder $(Join-Path $path $ModuleName) already exists"

        if ((Get-ChildItem (Join-Path $path $ModuleName)).Count -eq 0) {
            Write-Verbose "Folder is empty, creating module here."
        }
        else {
            Write-Warning "There are already files in $(Join-Path $Path $ModuleName) aborting"
            break
        }
    }

    $ModulePath = Join-Path $Path $ModuleName

    new-item $ModulePath -ItemType Directory
    New-Item $ModulePath\.vscode -ItemType Directory
    New-Item $ModulePath\tests\ -ItemType Directory
    new-item $ModulePath\source\public -itemType Directory
    new-item $ModulePath\source\classes -itemType Directory
    new-item $ModulePath\source\private -itemType Directory
    new-item $ModulePath\source\files -itemType Directory

    new-item $ModulePath\source\public\.gitkeep -itemType File
    new-item $ModulePath\source\private\.gitkeep -itemType File
    new-item $ModulePath\source\classes\.gitkeep -itemType File
    new-item $ModulePath\source\files\.gitkeep -itemType File

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
        ".\Files"
        #Add a comma after files if you want to copy more than one folder.
        #".\AnotherfolderwithFiles"
    )
}
"@
    set-content -path $ModulePath\source\build.psd1 -Value $BuildPsdOneContent

    $samplefunctionfile = @"
function Write-About$ModuleName {
    Write-Information "This is a sample function in the $ModuleName module."
    Write-Host "This is a sample function in the $ModuleName module."
    `$unused = "not used"
}

"@

    set-content $ModulePath\source\public\Write-About$ModuleName.ps1 -Value $SampleFunctionFile

    #Install-Module -Name PSScriptAnalyzer -Scope CurrentUser

    $PesterBaseTests = @"
describe 'Module-level tests' {

    BeforeAll {
        `$Version = (Test-ModuleManifest `$PSScriptRoot\..\source\$ModuleName.psd1 -ErrorAction SilentlyContinue ).Version
    }

    it 'the module imports successfully' {
        { Import-Module "`$PSScriptRoot\..\Output\$ModuleName\`$Version\$moduleName.psm1" -ErrorAction Stop } |
            Should -not -Throw
    }

    it 'the module has an associated manifest' {
        Test-Path "`$PSScriptRoot\..\Output\$ModuleName\`$Version\$moduleName.psd1" |
            should -Be `$true
    }

    it 'passes all default PSScriptAnalyzer rules' {
        Invoke-ScriptAnalyzer -Path "`$PSScriptRoot\..\Output\$ModuleName\`$Version\$moduleName.psm1" -Settings `$PSScriptRoot\..\tests\PSScriptAnalyzerSettings.psd1 |
            should -BeNullOrEmpty
    }
}

"@
    set-content $ModulePath\Tests\$ModuleName.Generic.Tests.ps1 -Value $PesterBaseTests

$dotvscodeSettings = @"
{
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "editor.insertSpaces": true,
    "editor.tabSize": 4,
    "powershell.codeFormatting.preset": "OTBS"
}
"@
Set-Content -Path $ModulePath\.vscode\settings.json -Value $dotvscodeSettings


$pscodeanalyzer = @"
@{
    #Severity=@('Error','Warning')
    ExcludeRules=@('MadeupRule',
        'AnotherMadeupRule'
    )
}
"@
Set-Content -Path $ModulePath\tests\PSScriptAnalyzerSettings.psd1 -Value $pscodeanalyzer

$dotvsodeTasks = @"
{
    // See https://go.microsoft.com/fwlink/?LinkId=733558
    // for the documentation about the tasks.json format
    "version": "2.0.0",

    // Start PowerShell (pwsh on *nix)
    "windows": {
        "options": {
            "shell": {
                "executable": "powershell.exe",
                "args": [ "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command" ]
            }
        }
    },
    "linux": {
        "options": {
            "shell": {
                "executable": "/usr/bin/pwsh",
                "args": [ "-NoProfile", "-Command" ]
            }
        }
    },
    "osx": {
        "options": {
            "shell": {
                "executable": "/usr/local/bin/pwsh",
                "args": [ "-NoProfile", "-Command" ]
            }
        }
    },

    "tasks": [
        {
            "label": "Build",
            "type": "shell",
            "command": "`${cwd}/build.ps1 -Verbose",
            "group": {
                "kind": "build",
                "isDefault": true
            }
        }
    ]
}
"@
set-content $ModulePath\.vscode\tasks.json -Value $dotvsodeTasks

$GitLabCIyml = @"
#variables:
#  MODULE_PATH: (Get-ChildItem -Path .\Output\*.psm1 -Recurse).DirectoryName

#.def_rules:
#  rules:
#  - if: `$CI_PIPELINE_SOURCE == 'merge_request_event' && `$CI_MERGE_REQUEST_TARGET_BRANCH_NAME == 'dev'
#  - if: `$CI_COMMIT_BRANCH == "main"

default:
  image:
    name: mcr.microsoft.com/powershell:7.4-ubuntu-22.04
  tags:
    - docker

stages:
  - build
  - test
  - deploy

build:
  stage: build
#  rules:
#    - !reference [.def_rules, rules]
  script:
    - |
      pwsh -c '
          Set-PackageSource PSGallery -Trusted > `$null;
          Set-PSResourceRepository -Name PSGallery -Trusted;
          Install-PSResource -Name ModuleBuilder;
          Install-PSResource -Name PSScriptAnalyzer;
          ./build.ps1 -task Build;
        '
 #   - `$ModuleVersion = Get-ManifestValue .\source\nordlo.ombreport.psd1
  artifacts:
    paths:
     - Output/

psscriptanalyzer:
  stage: test
  #rules:
  #  - !reference [.def_rules, rules]
  script:
        #Invoke-ScriptAnalyzer  -Path (Get-ChildItem -Path ./Output/*/*/*.psm1) -EnableExit -ReportSummary;
    - pwsh -c '
        Write-Host "Running PSScriptAnalyzer...";
        Set-PSResourceRepository -Name PSGallery -Trusted;
        Install-PSResource -Name PSScriptAnalyzer;
        Invoke-ScriptAnalyzer -Path ./source/private/* -Settings ./tests/PSScriptAnalyzerSettings.psd1 -EnableExit -ReportSummary;
        Invoke-ScriptAnalyzer -Path ./source/public/*  -Settings ./tests/PSScriptAnalyzerSettings.psd1 -EnableExit -ReportSummary;
      '

pester:
  stage: test
# # rules:
# #   - !reference [.def_rules, rules]
  script:
    - pwsh -c '
        Write-Host "Running Pester...";
        Set-PSResourceRepository -Name PSGallery -Trusted;
        Install-PSResource -Name ModuleBuilder;
        Install-PSResource -Name PSScriptAnalyzer;
        Install-PSResource -Name Pester;
        Import-Module Pester;
        `$Config = [PesterConfiguration]::Default;
        `$Config.CodeCoverage.Enabled = `$False;
        `$Config.TestResult.Enabled = `$True;
        `$Config.TestResult.OutputFormat = "JunitXML";
        `$Config.Run.Container = `$Container;
        `$Result = Invoke-Pester -Configuration `$Config;
        `$Result | Export-JUnitReport -Path testResults.xml;
      '
        #Invoke-Pester -EnableExit;
  needs:
  - job: build
  artifacts:
    paths:
    - testResults.xml
    #- coverage.xml
    reports:
      junit: testResults.xml
    # Pester only has one output format called JaCoCo which is not supported by
    # Gitlabs. Disabling for now.
    # https://github.com/pester/Pester/issues/2203
    #  coverage_report:
    #    coverage_format: cobertura
    #    path: coverage.xml

publish:
  stage: deploy
  only:
    - main
  script:
    - pwsh -c '
        Register-PSResourceRepository -Name ngit -Uri "`$(`$env:CI_API_V4_URL)/projects/`$(`$env:CI_PROJECT_ID)/packages/nuget/index.json" -Trusted -ApiVersion v3 -Force;
        Publish-PSResource -Repository ngit -Path (Get-ChildItem -Path ./Output/*/*/*.psm1).DirectoryName -ApiKey `$env:CI_JOB_TOKEN -Verbose;
        Unregister-PSResourceRepository -Name ngit;
      '
  environment: production
  needs:
  - job: build
    artifacts: true
"@

Set-Content -Path  "$ModulePath\.gitlab-ci.yml" -Value $GitLabCIyml


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
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet("Build","Test","Analyze","Publish", "Import")]
    [string[]]
    `$Task = @('Build', 'Test', 'Import')
)

if ((get-module Microsoft.Powershell.PSResourceGet -ListAvailable) -eq `$null) {
    Write-Host -NoNewLine "      Installing PSResourceGet module"
    `$null = Install-Module Microsoft.Powershell.PSResourceGet
    Write-Host -ForegroundColor Green '...Installed!'
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

if (`$task -contains "Build") {
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
}

if (`$Task -contains "Test") {
    invoke-pester `$psscriptroot\tests\
}

if (`$Task -contains "Analyze") {
    Invoke-ScriptAnalyzer -Path `$psscriptroot\source\private\* -Settings `$PSScriptRoot\tests\PSScriptAnalyzerSettings.psd1
    Invoke-ScriptAnalyzer -Path `$psscriptroot\source\public\*  -Settings `$PSScriptRoot\tests\PSScriptAnalyzerSettings.psd1
}

if (`$Task -contains "Import") {
    if ((get-module).name -contains '$ModuleName') {
        Remove-Module $ModuleName
    }
    Import-Module `$psscriptroot\Output\$ModuleName
}

if (`$Task -contains "Publish") {
    Write-Warning "Publish has not been implemented yet"
}


"@
    set-content $ModulePath\build.ps1 -Value $buildscript

    New-ModuleManifest -Path "$ModulePath\source\$ModuleName.psd1" -RootModule "$ModuleName.psm1" -ModuleVersion '0.1.0'
}

#$testing = $True
if ($testing) {
    new-item c:\mb -ItemType Directory
    Set-Location c:\mb
    remove-item C:\mb\jsmoduletest -Recurse
    New-JSModule -ModuleName jsmoduletest

    Set-Location C:\mb\jsmoduletest\
    .\build.ps1
}



