#!/bin/sh
cd $(dirname $0)
./src.sh | grep -v CxCli.h | grep -v DotNet | grep -v tl/tl_dotnet_object.h | grep -v /tl-parser/ | xargs -n 1 clang-format -verbose -style=file -i
