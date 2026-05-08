function New-JSModule {
    <#
    .SYNOPSIS
        Creates the scaffolding for a new PowerShell module.
    .DESCRIPTION
        Creates folders, build scripts, manifest, GitVersion config, GitLab CI pipeline,
        CHANGELOG, and test files needed to build, test, and publish a module.
    .EXAMPLE
        New-JSModule -ModuleName js.windows.uptime
        Creates scaffolding in .\js.windows.uptime\

    .EXAMPLE
        New-JSModule -ModuleName js.windows.uptime -Path C:\PS\ -RunnerTag my-runner
        Creates scaffolding in C:\PS\js.windows.uptime\ using a custom GitLab runner tag.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter()]
        [string]$Path = "",

        # GitLab runner tag used in .gitlab-ci.yml
        [Parameter()]
        [string]$RunnerTag = "windows-build",

        [Parameter(Mandatory)]
        [string]$Description
    )

    if ($Path -eq "") {
        $Path = (Get-Item (Get-Location)).FullName
        Write-Verbose "Path is undefined, setting the parent path to: $Path"
    }

    if (Test-Path (Join-Path $Path $ModuleName) -PathType Container) {
        Write-Verbose "Folder $(Join-Path $Path $ModuleName) already exists"
        if ((Get-ChildItem (Join-Path $Path $ModuleName)).Count -eq 0) {
            Write-Verbose "Folder is empty, creating module here."
        }
        else {
            Write-Warning "There are already files in $(Join-Path $Path $ModuleName) — aborting"
            return
        }
    }

    $ModulePath = Join-Path $Path $ModuleName

    New-Item $ModulePath                    -ItemType Directory | Out-Null
    New-Item $ModulePath\.vscode            -ItemType Directory | Out-Null
    New-Item $ModulePath\tests              -ItemType Directory | Out-Null
    New-Item $ModulePath\source\public      -ItemType Directory | Out-Null
    New-Item $ModulePath\source\classes     -ItemType Directory | Out-Null
    New-Item $ModulePath\source\private     -ItemType Directory | Out-Null
    New-Item $ModulePath\source\files       -ItemType Directory | Out-Null

    New-Item $ModulePath\source\public\.gitkeep  -ItemType File | Out-Null
    New-Item $ModulePath\source\private\.gitkeep -ItemType File | Out-Null
    New-Item $ModulePath\source\classes\.gitkeep -ItemType File | Out-Null
    New-Item $ModulePath\source\files\.gitkeep   -ItemType File | Out-Null

    # .gitignore
    $gitIgnore = @"
Output/
testResults.xml
.DS_Store
"@
    Set-Content "$ModulePath\.gitignore" -Value $gitIgnore

    # source/build.psd1
    $buildPsd1 = @"
@{
    Path = "$ModuleName.psd1"
    VersionedOutputDirectory = `$true
    CopyDirectories = @(
        ".\Files"
    )
}
"@
    Set-Content "$ModulePath\source\build.psd1" -Encoding utf8BOM -Value $buildPsd1

    # Sample public function
    $sampleFunction = @"
function Write-About$ModuleName {
    Write-Host "This is a sample function in the $ModuleName module."
}
"@
    Set-Content "$ModulePath\source\public\Write-About$ModuleName.ps1" -Encoding utf8BOM -Value $sampleFunction

    # tests/PSScriptAnalyzerSettings.psd1
    $psaSettings = @"
@{
    #Severity = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
    )
}
"@
    Set-Content "$ModulePath\tests\PSScriptAnalyzerSettings.psd1" -Encoding utf8BOM -Value $psaSettings

    # tests/<ModuleName>.Generic.Tests.ps1
    $pesterTests = @"
describe 'Module-level tests' {

    BeforeAll {
        `$script:Version = (Test-ModuleManifest "`$PSScriptRoot\..\source\$ModuleName.psd1" -ErrorAction SilentlyContinue).Version
    }

    it 'the module imports successfully' {
        { Import-Module "`$PSScriptRoot\..\Output\$ModuleName\`$script:Version\$ModuleName.psm1" -ErrorAction Stop } |
            Should -Not -Throw
    }

    it 'the module has an associated manifest' {
        Test-Path "`$PSScriptRoot\..\Output\$ModuleName\`$script:Version\$ModuleName.psd1" |
            Should -Be `$true
    }

    it 'passes all default PSScriptAnalyzer rules' {
        `$params = @{
            Path     = "`$PSScriptRoot\..\Output\$ModuleName\`$script:Version\$ModuleName.psm1"
            Settings = "`$PSScriptRoot\..\tests\PSScriptAnalyzerSettings.psd1"
        }
        Invoke-ScriptAnalyzer @params | Should -BeNullOrEmpty
    }
}
"@
    Set-Content "$ModulePath\Tests\$ModuleName.Generic.Tests.ps1" -Encoding utf8BOM -Value $pesterTests

    # .vscode/settings.json
    $vscodeSettings = @"
{
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "editor.insertSpaces": true,
    "editor.tabSize": 4,
    "powershell.codeFormatting.preset": "OTBS"
}
"@
    Set-Content "$ModulePath\.vscode\settings.json" -Value $vscodeSettings

    # .vscode/tasks.json
    $vscodeTasks = @"
{
    "version": "2.0.0",
    "windows": {
        "options": {
            "shell": {
                "executable": "powershell.exe",
                "args": [ "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command" ]
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
    Set-Content "$ModulePath\.vscode\tasks.json" -Encoding utf8BOM -Value $vscodeTasks

    # GitVersion.yml
    $gitVersionYml = @"
workflow: GitHubFlow/v1
major-version-bump-message: '\s?(breaking|major|breaking\schange)'
minor-version-bump-message: '(adds?|features?|minor)\b'
patch-version-bump-message: '\s?(fix|patch)'
no-bump-message: '\+semver:\s?(none|skip)'
branches:
  main:
    regex: ^master$|^main$
    deployment-mode: ContinuousDeployment
    label: dev
    increment: Patch
  feature:
    regex: ^features?[/-]
    label: preview
    increment: Minor
  hotfix:
    regex: ^hotfix(es)?[/-]|^patch?[/-]
    label: preview
    increment: Patch
  support:
    regex: ^support[/-]
    label: preview
    increment: Patch
"@
    Set-Content "$ModulePath\GitVersion.yml" -Value $gitVersionYml

    # CHANGELOG.md
    $changelog = @"
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Initial release
"@
    Set-Content "$ModulePath\CHANGELOG.md" -Value $changelog

    # build.ps1
    $buildScript = @"
#Requires -Version 5

<#
.Synopsis
    Build script using ModuleBuilder.
.Description
    * Installs required modules
    * Builds the module (version set by GitVersion in CI via -SemVer)
    * Runs Pester tests
    * Runs PSScriptAnalyzer

    .\build.ps1                          # Build + Test + Import
    .\build.ps1 -Task Build,Import       # Build and import only
    .\build.ps1 -Task Analyze            # Lint only
    .\build.ps1 -Task Version            # Show next version (via GitVersion)
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet('Build', 'Test', 'Analyze', 'Publish', 'Import', 'Version')]
    [string[]]`$Task = @('Build', 'Test', 'Import'),

    # SemVer passed from GitVersion in CI; omit for local builds (uses manifest version)
    [string]`$SemVer = ''
)

Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction SilentlyContinue

if (`$IsWindows) {
    `$candidatePaths = @(
        `$(if ([System.Environment]::GetFolderPath('Personal')) {
            Join-Path ([System.Environment]::GetFolderPath('Personal')) 'PowerShell\Modules'
        }),
        (Join-Path `$PSScriptRoot 'PowerShell\Modules')
    ) | Where-Object { `$_ }
    foreach (`$p in `$candidatePaths) {
        if (`$env:PSModulePath -notlike "*`$p*") { `$env:PSModulePath = "`$p;`$env:PSModulePath" }
    }
}

if ((Get-Module Microsoft.Powershell.PSResourceGet -ListAvailable) -eq `$null) {
    Write-Host -NoNewLine '      Installing PSResourceGet module'
    `$null = Install-Module Microsoft.Powershell.PSResourceGet -Scope CurrentUser
    Write-Host -ForegroundColor Green '...Installed!'
}

if ((Get-Module PSScriptAnalyzer -ListAvailable) -eq `$null) {
    Write-Host -NoNewLine '      Installing PSScriptAnalyzer module'
    `$null = Install-PSResource PSScriptAnalyzer -Scope CurrentUser
    Write-Host -ForegroundColor Green '...Installed!'
}

if ((Get-Module ModuleBuilder -ListAvailable) -eq `$null) {
    Write-Host -NoNewLine '      Installing ModuleBuilder module'
    `$null = Install-PSResource ModuleBuilder -Scope CurrentUser
    Write-Host -ForegroundColor Green '...Installed!'
}
Import-Module ModuleBuilder

if (`$Task -contains 'Build') {
    try {
        `$buildParams = @{ SourcePath = "`$PSScriptRoot\source\" }

        if (`$SemVer) {
            `$buildParams.SemVer = `$SemVer
            Write-Host "Building with SemVer: `$SemVer" -ForegroundColor Cyan
        }

        # Patch ReleaseNotes from CHANGELOG.md when building a tagged release
        `$tag = `$env:CI_COMMIT_TAG
        if (`$tag) {
            `$changelog = Get-Content "`$PSScriptRoot\CHANGELOG.md" -Raw
            if (`$tag -match '-') {
                `$notes = [regex]::Match(`$changelog, '(?m)^## \[Unreleased\][^\n]*\r?\n([\s\S]*?)(?=\r?\n^## \[|\z)').Groups[1].Value.Trim()
            } else {
                `$version = `$tag -replace '^v', ''
                `$notes = [regex]::Match(`$changelog, "(?m)^## \[`$([regex]::Escape(`$version))\][^\n]*\r?\n([\s\S]*?)(?=\r?\n^## \[|\z)").Groups[1].Value.Trim()
            }
            `$manifest = "`$PSScriptRoot\source\$ModuleName.psd1"
            if (`$notes) {
                `$content = [System.IO.File]::ReadAllText(`$manifest)
                `$replacement = "ReleaseNotes = @'``r``n`$notes``r``n'@"
                `$content = [regex]::Replace(`$content, "ReleaseNotes\s*=\s*''", `$replacement)
                [System.IO.File]::WriteAllText(`$manifest, `$content, [System.Text.Encoding]::UTF8)
                Write-Host 'Release notes set from CHANGELOG.md' -ForegroundColor Cyan
            } else {
                Write-Warning "No matching release notes found in CHANGELOG.md for tag '`$tag'"
            }
        }

        Build-Module @buildParams
    }
    catch {
        Write-Host -ForegroundColor Red 'Build failed:'
        Write-Output `$_
        exit 1
    }
}

if ((Get-Module Pester -ListAvailable | Where-Object { `$_.Version -ge '5.0' }) -eq `$null) {
    Write-Host -NoNewLine '      Installing Pester module (v5+)'
    `$null = Install-PSResource Pester -Version '[5.0.0,]' -Scope CurrentUser
    Write-Host -ForegroundColor Green '...Installed!'
}

if (`$Task -contains 'Test') {
    Import-Module Pester -MinimumVersion 5.0 -Force
    `$config = [PesterConfiguration]::Default
    `$config.Run.Path = "`$PSScriptRoot\tests\"
    `$config.TestResult.Enabled = `$true
    `$config.TestResult.OutputPath = "`$PSScriptRoot\testResults.xml"
    `$config.TestResult.OutputFormat = 'JUnitXml'
    `$config.CodeCoverage.Enabled = `$false
    Invoke-Pester -Configuration `$config
}

if (`$Task -contains 'Analyze') {
    `$findings = @()
    `$findings += Invoke-ScriptAnalyzer -Path `$PSScriptRoot\source\private\* -Settings `$PSScriptRoot\tests\PSScriptAnalyzerSettings.psd1
    `$findings += Invoke-ScriptAnalyzer -Path `$PSScriptRoot\source\public\*  -Settings `$PSScriptRoot\tests\PSScriptAnalyzerSettings.psd1

    if (`$findings) {
        `$findings | Format-Table -AutoSize
        if (`$env:CI_COMMIT_TAG) {
            Write-Host "PSScriptAnalyzer: `$(`$findings.Count) finding(s) — failing build because CI_COMMIT_TAG is set." -ForegroundColor Red
            exit 1
        } else {
            Write-Warning "PSScriptAnalyzer: `$(`$findings.Count) finding(s) (warnings only on non-tag builds)"
        }
    } else {
        Write-Host 'PSScriptAnalyzer: no findings.' -ForegroundColor Green
    }
}

if (`$Task -contains 'Import') {
    if ((Get-Module).Name -contains '$ModuleName') {
        Remove-Module $ModuleName
    }
    Import-Module "`$PSScriptRoot\Output\$ModuleName"
}

if (`$Task -contains 'Publish') {
    `$apiKey    = `$env:NUGET_API_KEY
    `$serverUrl = `$env:NUGET_SERVER_URL

    if (-not `$apiKey -or -not `$serverUrl) {
        Write-Warning 'NUGET_API_KEY or NUGET_SERVER_URL is not set — skipping publish.'
    } else {
        if (`$serverUrl -notmatch '^https?://') { `$serverUrl = "https://`$serverUrl" }
        `$repoUri = "`$serverUrl/v3/index.json"
        if (-not (Get-PSResourceRepository -Name 'NuGet' -ErrorAction SilentlyContinue)) {
            Register-PSResourceRepository -Name 'NuGet' -Uri `$repoUri -Trusted
        }
        `$moduleName = (Get-ChildItem (Join-Path `$PSScriptRoot 'Output') -Directory | Select-Object -First 1).Name
        `$outputRoot = Join-Path `$PSScriptRoot "Output\`$moduleName"
        `$builtPath  = (Get-ChildItem `$outputRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
        if (-not `$builtPath) { throw "No built module found under `$outputRoot. Run Build first." }
        Write-Host "Publishing `$builtPath to `$serverUrl..." -ForegroundColor Cyan
        Publish-PSResource -Path `$builtPath -Repository 'NuGet' -ApiKey `$apiKey
        Write-Host 'Published successfully.' -ForegroundColor Green
    }
}

if (`$Task -contains 'Version') {
    `$dotnetTools = if (`$IsWindows) { "`$env:USERPROFILE\.dotnet\tools" } else { "`$HOME/.dotnet/tools" }
    `$env:PATH = "`$dotnetTools`$([IO.Path]::PathSeparator)`$env:PATH"
    if (-not (Get-Command dotnet-gitversion -ErrorAction SilentlyContinue)) {
        dotnet tool install --global GitVersion.Tool --ignore-failed-sources 2>`$null
    }
    `$semVer = (dotnet-gitversion /showvariable SemVer) | Select-Object -Last 1
    Write-Host "Next version: `$semVer" -ForegroundColor Cyan
}
"@
    Set-Content "$ModulePath\build.ps1" -Encoding utf8BOM -Value $buildScript

    # .gitlab-ci.yml
    $gitlabCi = @"
stages:
  - build
  - test
  - publish
  - release

default:
  tags:
    - $RunnerTag

variables:
  GIT_DEPTH: "0"   # GitVersion needs full history

build:
  stage: build
  script:
    - |
      dotnet tool install --global GitVersion.Tool --ignore-failed-sources 2>`$null
      `$env:PATH = "`$env:USERPROFILE\.dotnet\tools;`$env:PATH"
      `$semVer = (dotnet-gitversion /showvariable SemVer) | Select-Object -Last 1
      if (-not `$semVer) { throw "GitVersion failed to produce a SemVer" }
      Write-Host "GitVersion SemVer: `$semVer" -ForegroundColor Cyan
      & ./build.ps1 -Task Build -SemVer `$semVer
  artifacts:
    paths:
      - Output/
    expire_in: 1 hour

psscriptanalyzer:
  stage: test
  script:
    - pwsh -c '& ./build.ps1 -Task Analyze'

pester:
  stage: test
  needs:
    - job: build
      artifacts: true
  script:
    - pwsh -c '& ./build.ps1 -Task Test'
  artifacts:
    when: always
    paths:
      - testResults.xml
    reports:
      junit: testResults.xml

publish:
  stage: publish
  rules:
    - if: `$CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+`$/
      when: on_success
    - if: `$CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+-rc\.\d+`$/
      when: on_success
    - if: `$CI_COMMIT_BRANCH == `$CI_DEFAULT_BRANCH
      when: manual
      allow_failure: true
  needs:
    - job: build
      artifacts: true
  script:
    - |
      & ./build.ps1 -Task Publish
      `$src = (Get-ChildItem ./Output/$ModuleName -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
      `$ver = Split-Path `$src -Leaf
      Compress-Archive -Path "`$src\*" -DestinationPath "$ModuleName-`$ver.zip"
  artifacts:
    paths:
      - "$ModuleName-*.zip"
    expire_in: 90 days

release:
  stage: release
  needs:
    - publish
  rules:
    - if: `$CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+`$/
      when: on_success
  script:
    - |
      `$ErrorActionPreference = 'Stop'
      `$version = `$env:CI_COMMIT_TAG -replace '^v', ''
      `$changelog = Get-Content CHANGELOG.md -Raw
      `$notes = [regex]::Match(`$changelog, "(?m)^## \[`$([regex]::Escape(`$version))\][^\n]*\r?\n([\s\S]*?)(?=\r?\n^## \[|\z)").Groups[1].Value.Trim()
      if (-not `$notes) { `$notes = "Release `$env:CI_COMMIT_TAG" }
      `$zipName = (Get-ChildItem "$ModuleName-*.zip" | Select-Object -First 1).Name
      `$assetUrl = "`$env:CI_PROJECT_URL/-/jobs/artifacts/`$env:CI_COMMIT_TAG/raw/`$zipName?job=publish"
      `$body = @{
        name        = `$env:CI_COMMIT_TAG
        tag_name    = `$env:CI_COMMIT_TAG
        description = `$notes
        assets      = @{ links = @(@{ name = `$zipName; url = `$assetUrl }) }
      } | ConvertTo-Json -Depth 5
      Invoke-RestMethod -Uri "`$env:CI_API_V4_URL/projects/`$env:CI_PROJECT_ID/releases" ``
        -Method Post ``
        -Headers @{ "JOB-TOKEN" = `$env:CI_JOB_TOKEN } ``
        -Body `$body ``
        -ContentType "application/json"

release-prerelease:
  stage: release
  needs:
    - publish
  rules:
    - if: `$CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+-rc\.\d+`$/
      when: on_success
  script:
    - |
      `$ErrorActionPreference = 'Stop'
      `$changelog = Get-Content CHANGELOG.md -Raw
      `$notes = [regex]::Match(`$changelog, '(?m)^## \[Unreleased\][^\n]*\r?\n([\s\S]*?)(?=\r?\n^## \[|\z)').Groups[1].Value.Trim()
      if (-not `$notes) { `$notes = "Pre-release `$env:CI_COMMIT_TAG" }
      `$zipName = (Get-ChildItem "$ModuleName-*.zip" | Select-Object -First 1).Name
      `$assetUrl = "`$env:CI_PROJECT_URL/-/jobs/artifacts/`$env:CI_COMMIT_TAG/raw/`$zipName?job=publish"
      `$body = @{
        name        = "`$env:CI_COMMIT_TAG (pre-release)"
        tag_name    = `$env:CI_COMMIT_TAG
        description = `$notes
        assets      = @{ links = @(@{ name = `$zipName; url = `$assetUrl }) }
      } | ConvertTo-Json -Depth 5
      Invoke-RestMethod -Uri "`$env:CI_API_V4_URL/projects/`$env:CI_PROJECT_ID/releases" ``
        -Method Post ``
        -Headers @{ "JOB-TOKEN" = `$env:CI_JOB_TOKEN } ``
        -Body `$body ``
        -ContentType "application/json"
"@
    Set-Content "$ModulePath\.gitlab-ci.yml" -Value $gitlabCi

    # CLAUDE.md
    $claudeMd = @"
# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Build, Test, and Lint

Uses **ModuleBuilder** + **Pester** + **PSScriptAnalyzer** via ``build.ps1``.
The build script auto-installs missing prerequisites (PSResourceGet, PSScriptAnalyzer, ModuleBuilder, Pester).

``````powershell
# Build module → output to Output/$ModuleName/VERSION/
.\build.ps1 -Task Build

# Build + import into current session (most common during development)
.\build.ps1 -Task Build,Import

# Run Pester tests (tests/ directory)
.\build.ps1 -Task Test

# Run PSScriptAnalyzer on source/private/ and source/public/
.\build.ps1 -Task Analyze

# All tasks
.\build.ps1 -Task Build,Test,Analyze
``````

Default when run without arguments: ``Build, Test, Import``.

The ``-SemVer`` parameter overrides the version passed to ``Build-Module``.
In CI this is set by GitVersion. Locally it can be omitted (uses ``0.0.1`` from the manifest).

## Versioning and publishing

Versioning is handled by **GitVersion 6** (``GitVersion.yml``). Version is computed automatically from git history.

- Every commit to ``main`` produces a prerelease build (e.g. ``1.0.0-dev.3``)
- Commit messages control version increments:
  - ``breaking`` / ``major`` → major bump
  - ``adds`` / ``feature`` / ``minor`` → minor bump
  - ``fix`` / ``patch`` → patch bump (default)
  - ``+semver: none`` or ``+semver: skip`` → no bump
- Push a tag (e.g. ``v1.0.0``) to produce a stable release
- Push an rc tag (e.g. ``v1.0.0-rc.1``) to produce a named prerelease

Release notes are pulled from ``CHANGELOG.md`` — stable tags read ``## [X.Y.Z]``, rc tags read ``## [Unreleased]``.

**PSScriptAnalyzer:** warnings are non-fatal on dev/main builds; any finding fails the build when ``CI_COMMIT_TAG`` is set.

**Publishing** requires ``NUGET_API_KEY`` and ``NUGET_SERVER_URL`` environment variables.
The publish job runs automatically on release/rc tags, and is available as a manual trigger on ``main``.

## Architecture

### Module loading

``$ModuleName.psm1`` dot-sources all files from ``source/private/*.ps1`` and ``source/public/*.ps1`` at import time.

### Bundling static files

Place any static assets (scripts, binaries, data files) under ``source/files/``.
ModuleBuilder copies the entire ``files/`` directory into the built module output as configured in ``source/build.psd1`` (``CopyDirectories = @('.\Files')``).

Reference bundled files at runtime using ``\`$PSScriptRoot``:

``````powershell
\$assetPath = Join-Path \$PSScriptRoot "files\myasset.json"
``````

### Critical ``\`$PSScriptRoot`` rule

ModuleBuilder copies every ``.ps1`` file to the **root** of the versioned output directory — there is no ``private/`` subdirectory after building. Use ``\`$PSScriptRoot`` directly for sibling file references, not ``Split-Path \`$PSScriptRoot -Parent``.

## PowerShell 5.1 compatibility

The module targets PS 5.1+. Avoid cmdlets that require PS 6.1+:

``````powershell
# ✅ PS 5.1 compatible
\$result = \$array -join "\`n"

# ❌ PS Core 6.1+ only
\$result = \$array | Join-String -Separator "\`n"
``````
"@
    Set-Content "$ModulePath\CLAUDE.md" -Value $claudeMd

    # Module manifest — version 0.0.1 placeholder; real version set by GitVersion at build time
    $manifestParams = @{
        Path        = "$ModulePath\source\$ModuleName.psd1"
        RootModule  = "$ModuleName.psm1"
        ModuleVersion = '0.0.1'
        Author      = 'Johan Selmosson'
        CompanyName = 'Nordlo'
        Description = $Description
    }
    New-ModuleManifest @manifestParams

    # Add Prerelease and ReleaseNotes to PSData — required for ModuleBuilder -SemVer to work
    $manifestPath = "$ModulePath\source\$ModuleName.psd1"
    $manifestContent = [System.IO.File]::ReadAllText($manifestPath)
    $manifestContent = $manifestContent -replace 'PSData = @\{', "PSData = @{`r`n`r`n        Prerelease = ''`r`n`r`n        ReleaseNotes = ''"
    [System.IO.File]::WriteAllText($manifestPath, $manifestContent, [System.Text.Encoding]::UTF8)

    Write-Host "Module scaffolding created at $ModulePath" -ForegroundColor Green
}
