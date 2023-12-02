describe 'Module-level tests' {

    BeforeAll {
        $Version = (Test-ModuleManifest $PSScriptRoot\..\source\jstools.psd1 -ErrorAction SilentlyContinue ).Version
    }

    it 'the module imports successfully' {
        { Import-Module "$PSScriptRoot\..\output\jstools\$Version\jstools.psm1" -ErrorAction Stop } | Should -not -Throw
    }

    it 'the module has an associated manifest' {
        Test-Path "$PSScriptRoot\..\output\jstools\$Version\jstools.psd1" | should -Be $true
    }

    it 'passes all default PSScriptAnalyzer rules' {
        $ModuleFile =  "$PSScriptRoot\..\output\jstools\$Version\jstools.psm1"
        $PSScriptAnalyzerSettings = "$PSScriptRoot\..\tests\PSScriptAnalyzerSettings.psd1"
        Invoke-ScriptAnalyzer -Path $ModuleFile -Settings $PSScriptAnalyzerSettings | should -BeNullOrEmpty
    }
}

