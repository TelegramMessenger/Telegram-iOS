#!/bin/bash

set -x
set -e

target_directory="$1"

if [ -z "$target_directory" ]; then
	echo "Usage: sh prepare_buck_source.sh path/to/target/directory"
	exit 1
fi

mkdir -p "$target_directory"

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

ant

./bin/buck build --show-output buck

#result_path="$(pwd)/buck-out/gen/programs/buck.pex"

cd "$dir"
