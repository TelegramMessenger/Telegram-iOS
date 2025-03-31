./src.ps1 | Select-String -NotMatch "CxCli.h" | Select-String -CaseSensitive -NotMatch "DotNet" | Select-String -NotMatch "tl/tl_dotnet_object.h" | Select-String -NotMatch "/tl-parser/" | ForEach-Object {
  clang-format -verbose -style=file -i $_
}
