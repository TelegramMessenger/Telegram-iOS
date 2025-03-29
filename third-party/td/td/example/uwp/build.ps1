param (
  [string]$vcpkg_root = $(throw "-vcpkg_root=<path to vcpkg> is required"),
  [ValidateSet('x86', 'x64', 'ARM', 'ARM64', IgnoreCase = $false)]
  [string[]]$arch = @( "x86", "x64", "ARM", "ARM64" ),
  [string]$mode = "all",
  [string]$compress = "7z",
  [switch]$release_only = $false,
  [switch]$nupkg = $false
)
$ErrorActionPreference = "Stop"

$vcpkg_root = Resolve-Path $vcpkg_root

$vcpkg_cmake="${vcpkg_root}\scripts\buildsystems\vcpkg.cmake"
$arch_list = $arch
$config_list = @( "Debug", "Release" )
if ($release_only -or $nupkg) {
  $config_list = @(, "RelWithDebInfo")
}
$targets = @{ Debug = "Debug"; Release = "Retail"; RelWithDebInfo = "CommonConfiguration"}

$td_root = Resolve-Path "../.."

function CheckLastExitCode {
  if ($LastExitCode -ne 0) {
    $msg = @"
EXE RETURNED EXIT CODE $LastExitCode
CALLSTACK:$(Get-PSCallStack | Out-String)
"@
    throw $msg
  }
}

function clean {
  Remove-Item build-* -Force -Recurse -ErrorAction SilentlyContinue
}

function prepare {
  New-Item -ItemType Directory -Force -Path build-native

  cd build-native

  cmake -A Win32 -DTD_GENERATE_SOURCE_FILES=ON -DTD_ENABLE_DOTNET=ON "$td_root"
  CheckLastExitCode
  cmake --build .
  CheckLastExitCode

  cd ..
}

function config {
  New-Item -ItemType Directory -Force -Path build-uwp
  cd build-uwp

  ForEach ($arch in $arch_list) {
    echo "Config Arch = [$arch]"
    New-Item -ItemType Directory -Force -Path $arch
    cd $arch
    echo "${td_root}"
    $fixed_arch = $arch
    if ($arch -eq "x86") {
      $fixed_arch = "win32"
    }
    cmake -A $fixed_arch -DCMAKE_SYSTEM_VERSION="10.0" -DCMAKE_SYSTEM_NAME="WindowsStore" -DCMAKE_TOOLCHAIN_FILE="$vcpkg_cmake" -DTD_ENABLE_DOTNET=ON "$td_root"
    CheckLastExitCode
    cd ..
  }
  echo "done"
  cd ..
}

function build {
  cd build-uwp
  ForEach ($arch in $arch_list) {
    echo "Build Arch = [$arch]"
    cd $arch
    ForEach ($config in $config_list) {
      cmake --build . --config $config --target tddotnet
      CheckLastExitCode
    }
    cd ..
  }
  cd ..
}

function export-vsix {
  cd build-uwp
  Remove-Item vsix -Force -Recurse -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path vsix
  cp ../SDKManifest.xml vsix
  cp ../extension.vsixmanifest vsix
  cp '../`[Content_Types`].xml' vsix
  cp ../LICENSE_1_0.txt vsix

  ForEach ($arch in $arch_list) {
    New-Item -ItemType Directory -Force -Path vsix/References/CommonConfiguration/${arch}
    ForEach ($config in $config_list) {
      $target = $targets[$config]

      New-Item -ItemType Directory -Force -Path vsix/DesignTime/${target}/${arch}
      cp ${arch}/${config}/Telegram.Td.lib vsix/DesignTime/${target}/${arch}/

      New-Item -ItemType Directory -Force -Path vsix/Redist/${target}/${arch}
      cp ${arch}/${config}/* -include "SSLEAY*","LIBEAY*","libcrypto*","libssl*","zlib*","Telegram.Td.pdb","Telegram.Td.dll" vsix/Redist/${target}/${arch}/

      cp ${arch}/${config}/* -include "Telegram.Td.pri","Telegram.Td.winmd","Telegram.Td.xml" vsix/References/CommonConfiguration/${arch}/
    }
  }

  cd vsix

  if ($compress -eq "zip") {
    zip -r tdlib.vsix *
  } elseif ($compress -eq "winrar") {
    WinRAR.exe a -afzip -r -ep1 tdlib.vsix *
  } else {
    7z.exe a -tzip -r tdlib.vsix *
  }
  cd ..
}

function export-nupkg {
  cd build-uwp
  Remove-Item nupkg -Force -Recurse -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path nupkg/build/native
  cp ../LICENSE_1_0.txt nupkg
  cp ../Telegram.Td.UWP.nuspec nupkg
  cp ../Telegram.Td.UWP.targets nupkg/build/native

  ForEach ($arch in $arch_list) {
    $fixed_arch = $arch.ToLower();
    New-Item -ItemType Directory -Force -Path nupkg/runtimes/win10-${fixed_arch}/native
    New-Item -ItemType Directory -Force -Path nupkg/lib/uap10.0

    ForEach ($config in $config_list) {
      cp ${arch}/${config}/* -include "SSLEAY*","LIBEAY*","libcrypto*","libssl*","zlib*","Telegram.Td.pdb","Telegram.Td.pri","Telegram.Td.dll" nupkg/runtimes/win10-${fixed_arch}/native
      cp ${arch}/${config}/* -include "Telegram.Td.winmd","Telegram.Td.xml" nupkg/lib/uap10.0
    }
  }

  cd nupkg
  nuget pack Telegram.Td.UWP.nuspec
  cd ..
}

function run {
  Push-Location
  Try {
    if ($mode -eq "clean") {
      clean
    }
    if (($mode -eq "prepare") -or ($mode -eq "all")) {
      prepare
    }
    if (($mode -eq "config") -or ( $mode -eq "all")) {
      config
    }
    if (($mode -eq "build") -or ($mode -eq "all")) {
      build
    }
    if (($mode -eq "export") -or ($mode -eq "all")) {
      if ($nupkg) {
        export-nupkg
      } else {
        export-vsix
      }
    }
  } Finally {
    Pop-Location
  }
}

run
