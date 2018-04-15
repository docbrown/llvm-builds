param (
    [String] $SourceDirectory = $PWD,
    [String] $BuildDirectory = "$SourceDirectory\_build",
    [String] $InstallDirectory = "$SourceDirectory\_install",
    [String[]] $Targets = @("all"),
    [Boolean] $BuildTools = $true,
    [Boolean] $EnableExceptions = $false,
    [Boolean] $EnableRTTI = $false,
    [Boolean] $EnableFFI = $false,
    [Boolean] $EnableZLIB = $true,
    [Boolean] $Shared = $false,
    [Microsoft.VisualStudio.Setup.Instance] $VSSetupInstance,

    [Parameter(Mandatory=$true)]
    [ValidateSet('X86', 'AMD64', 'ARM')]
    [String]
    $Architecture,

    [Parameter(Mandatory=$true)]
    [ValidateSet('Debug', 'Release', 'MinSizeRel', 'RelWithDebInfo')]
    [String]
    $Configuration
)

switch ($Architecture) {
    X86 {
        $Generator = 'Visual Studio 2017'
        $VSTargetArch = 'x86'
    }
    AMD64 {
        $Generator = 'Visual Studio 2017 Win64'
        $VSTargetArch = 'x64'
    }
    ARM {
        $Generator = 'Visual Studio 2017 ARM'
        $VSTargetArch = 'arm'
    }
    default { throw "Unhandled architecture '$Architecture'." }
}

if (-not $VSSetupInstance) {
    $VSSetupInstance = Get-VSSetupInstance -All | Select-VSSetupInstance `
        -Latest -Require "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
    if (-not $VSSetupInstance) {
        throw "No suitable Visual Studio installation found."
    }
}

$VSInstanceDir = $VSSetupInstance.InstallationPath

cmd /c "`"$VSInstanceDir\Common7\Tools\vsdevcmd.bat`" -arch=$VSTargetArch -host_arch=x64 && set" | ForEach-Object {
    if($_ -match "^(.*?)=(.*)$") {
        Set-Content "env:\$($matches[1])" $matches[2]
    }
}

New-Item $BuildDirectory -ItemType Directory
New-Item $InstallDirectory -ItemType Directory
Set-Location $BuildDirectory

$CMakeArgs = @(
    '-G', "`"$Generator`"",
    "-DCMAKE_INSTALL_PREFIX:STRING=$InstallDirectory",
    "-DCMAKE_BUILD_TYPE:STRING=$Configuration",
    "-DLLVM_TARGETS_TO_BUILD:STRING=$($Targets -Join ';')",
    "-DLLVM_BUILD_TOOLS:BOOL=$BuildTools",
    "-DLLVM_INCLUDE_TOOLS:BOOL=$BuildTools",
    "-DLLVM_INCLUDE_EXAMPLES:BOOL=FALSE",
    "-DLLVM_INCLUDE_TESTS:BOOL=FALSE",
    "-DLLVM_ENABLE_EH:BOOL=$EnableExceptions",
    "-DLLVM_ENABLE_RTTI:BOOL=$EnableRTTI",
    "-DLLVM_ENABLE_FFI:BOOL=$EnableFFI",
    "-DLLVM_ENABLE_ZLIB:BOOL=$EnableZLIB",
    "-DLLVM_BUILD_LLVM_DYLIB:BOOL=$Shared",
    "-DLLVM_OPTIMIZED_TABLEGEN:BOOL=TRUE",
    "$SourceDirectory"
)

cmake $CMakeArgs
cmake --build . --target install
