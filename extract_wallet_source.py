import sys
import os
import re
import shutil

ignore_patterns_when_copying = [
    "^\\.git$",
    "^.*/\\.git$",
]

def mkdir_p(path):
    if not os.path.isdir(path):
        os.makedirs(path)

def clean_copy_files(dir, destination_dir):
    for root, dirs, files in os.walk(dir, topdown=False):
        for name in files:
            skip_file = False
            for pattern in ignore_patterns_when_copying:
                if re.match(pattern, name):
                    skip_file = True
                    break
            if skip_file:
                continue
            file_path = os.path.relpath(os.path.join(root, name), dir)
            dir_path = os.path.dirname(file_path)
            mkdir_p(destination_dir + "/" + dir_path)
            shutil.copy(dir + "/" + file_path, destination_dir + "/" + file_path)
        for name in dirs:
            skip_file = False
            for pattern in ignore_patterns_when_copying:
                if re.match(pattern, name):
                    skip_file = True
                    break
            if skip_file:
                continue
            dir_path = os.path.relpath(os.path.join(root, name), dir)
            if os.path.islink(dir + "/" + dir_path):
                continue
            mkdir_p(destination_dir + "/" + dir_path)

def clean_files(base_dir, dirs, files):
    for file in files:
        if file == '.DS_Store':
            os.remove(base_dir + '/' + file)
    for dir in dirs:
        if re.match('.*\\.xcodeproj', dir) or re.match('.*\\.xcworkspace', dir):
            shutil.rmtree(base_dir + '/' + dir, ignore_errors=True)

def clean_dep_files(base_dir, dirs, files):
    for file in files:
        if re.match('^\\.git$', file) or re.match('^.*/\\.git$', file):
            os.remove(base_dir + '/' + file)
    for dir in dirs:
        if re.match('^\\.git$', dir) or re.match('^.*/\\.git$', dir):
            shutil.rmtree(base_dir + '/' + dir, ignore_errors=True)

if len(sys.argv) != 2:
    print('Usage: extract_wallet_source.py destination')
    sys.exit(1)

destination = sys.argv[1]

deps_data = os.popen("""bazel query 'kind("source file", deps(//Wallet:Wallet))'""").read().splitlines()
buildfile_deps_data = os.popen("""bazel query 'buildfiles(deps(//Wallet:Wallet))'""").read().splitlines()

directories = set()

for line in deps_data + buildfile_deps_data:
    if len(line) == 0:
        continue
    if line[:1] == "@":
        continue
    if line[:2] != "//":
        continue
    file_path = line[2:].replace(":", "/")
    if file_path.startswith("build-input"):
        continue
    if file_path.startswith("external"):
        continue
    file_name = os.path.basename(file_path)
    file_dir = os.path.dirname(file_path)

    mkdir_p(destination + "/" + file_dir)
    shutil.copy(file_path, destination + '/' + file_path)

additional_paths = [
    ".gitignore",
    "WORKSPACE",
    "build-system/xcode_version",
    "build-system/bazel_version",
    "build-system/bazel-rules",
    "build-system/tulsi",
    "build-system/prepare-build.sh",
    "build-system/generate-xcode-project.sh",
    "build-system/copy-provisioning-profiles-Wallet.sh",
    "build-system/prepare-build-variables-Wallet.sh",
    ".bazelrc",
    "Utils.makefile",
    "Wallet.makefile",
]

for file_path in additional_paths:
    if os.path.isdir(file_path):
        clean_copy_files(file_path, destination + '/' + file_path)
    else:
        shutil.copy(file_path, destination + '/' + file_path)
