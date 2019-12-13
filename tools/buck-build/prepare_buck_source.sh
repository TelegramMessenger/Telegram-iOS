#!/bin/bash

set -x
set -e

target_directory="$1"

if [ -z "$target_directory" ]; then
	echo "Usage: sh prepare_buck_source.sh path/to/target/directory"
	exit 1
fi

mkdir -p "$target_directory"

jdk_archive_name="jdk.tar.gz"
jdk_archive_path="$target_directory/$jdk_archive_name"
jdk_unpacked_path="$target_directory/jdk8u232-b09"
jdk_url="https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u232-b09/OpenJDK8U-jdk_x64_mac_hotspot_8u232b09.tar.gz"

if [ ! -f "$jdk_archive_path" ]; then
	echo "Fetching JDK 8"
	curl "$jdk_url" -L -o "$target_directory/jdk.tar.gz"
fi

if [ ! -d "$jdk_unpacked_path" ]; then
	echo "Unpacking JDK 8"
	pushd "$target_directory"
	tar -xf "$jdk_archive_name"
	popd
fi

patch_file="$(ls *.patch | head -1)"
patch_path="$(pwd)/$patch_file"

if [ -z "$patch_file" ]; then
	echo "There should be a patch-COMMIT_SHA.patch in the current directory"
	exit 1
fi

commit_sha="$(echo "$patch_file" | sed -e 's/buck-//g' | sed -e 's/\.patch//g')"

echo "Fetching commit $commit_sha"

dir="$(pwd)"
cd "$target_directory"

if [ ! -d "buck" ]; then
	git clone "https://github.com/facebook/buck.git"
fi

cd "buck"

git reset --hard
git reset --hard "$commit_sha"

git apply --check "$patch_path"
git apply "$patch_path"

PATH="$PATH:$jdk_unpacked_path/Contents/Home/bin" ant
PATH="$PATH:$jdk_unpacked_path/Contents/Home/bin" ./bin/buck build --show-output buck

cd "$dir"
