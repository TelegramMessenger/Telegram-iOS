# TDLib Universal Windows Platform example

This is an example of building TDLib SDK for Universal Windows Platform and an example of its usage from C#.

## Building SDK

* Download and install Microsoft Visual Studio 2017+ with Windows 10 SDK. We recommend to use the latest available versions of Microsoft Visual Studio and Windows 10 SDK.
* Download and install [CMake](https://cmake.org/download/). CMake 3.13 or newer is required.
* Install `zlib` and `openssl` for all UWP architectures and `gperf` for x86 using [vcpkg](https://github.com/Microsoft/vcpkg#quick-start):
```
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
git checkout 07b30b49e5136a36100a2ce644476e60d7f3ddc1
.\bootstrap-vcpkg.bat
.\vcpkg.exe install gperf:x86-windows openssl:arm-uwp openssl:arm64-uwp openssl:x64-uwp openssl:x86-uwp zlib:arm-uwp zlib:arm64-uwp zlib:x64-uwp zlib:x86-uwp
```
* (Optional. For XML documentation generation.) Download [PHP](https://windows.php.net/download). Add the path to php.exe to the PATH environment variable.
* Download and install [7-Zip](http://www.7-zip.org/download.html) archiver, which is used by the `build.ps1` script to create a Telegram.Td.UWP Visual Studio Extension. Add the path to 7z.exe to the PATH environment variable.
  Alternatively `build.ps1` supports compressing using [WinRAR](https://en.wikipedia.org/wiki/WinRAR) with option `-compress winrar` and compressing using [zip](http://gnuwin32.sourceforge.net/packages/zip.htm) with `-compress zip`.
* Build `TDLib` using provided `build.ps1` script (TDLib should be built 6 times for multiple platforms in Debug and Release configurations, so it make take few hours). Pass path to vcpkg.exe as `-vcpkg-root` argument, for example:
```
powershell -ExecutionPolicy ByPass .\build.ps1 -vcpkg_root C:\vcpkg
```
If you need to restart the build from scratch, call `.\build.ps1 -vcpkg_root C:\vcpkg -mode clean` first.
* Install Visual Studio Extension "TDLib for Universal Windows Platform" located at `build-uwp\vsix\tdlib.vsix`, which was created on the previous step by `build.ps1` script.

After this `TDLib` can be used from any UWP project, built in Visual Studio.

Alternatively, you can build `TDLib` as a NuGet package, adding the option `-nupkg` to the `.\build.ps1` script invocation. The resulting package will be placed in the directory `build-uwp\nupkg`.

## Example of usage

The `app/` directory contains a simple example of a C# application for Universal Windows Platform. Just open it with Visual Studio 2015 or later and run.
