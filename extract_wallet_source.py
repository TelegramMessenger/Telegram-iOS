import sys
import os
import json
import re
import shutil

def get_file_list(dir):
    result_files = []
    result_dirs = []
    for root, dirs, files in os.walk(dir, topdown=False):
        for name in files:
            result_files.append(os.path.relpath(os.path.join(root, name), dir))
        for name in dirs:
            result_dirs.append(os.path.relpath(os.path.join(root, name), dir))
    return set(result_dirs), set(result_files)

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

initial_dirs, initial_files = get_file_list(destination)
for file in initial_files:
    if re.match('^\\.git/.*$', file):
        continue
    os.remove(destination + '/' + file)
for dir in initial_dirs:
    if dir == '.git' or re.match('^\\.git/.*$', dir):
        continue
    shutil.rmtree(destination + '/' + dir, ignore_errors=True)

deps_data = os.popen('make -f Wallet.makefile --silent wallet_deps').read()

deps = json.loads(deps_data)

paths = []
for dep in deps:
    dep_type = deps[dep]['buck.type']
    if dep_type == 'genrule':
        continue
    match = re.search('//(.+?):', dep)
    if match:
        dep_path = match.group(1)
        if dep_path not in paths:
            paths.append(dep_path)

for dep_path in paths:
    shutil.copytree(dep_path, destination + '/' + dep_path)
    dep_dirs, dep_files = get_file_list(destination + '/' + dep_path)
    clean_dep_files(destination + '/' + dep_path, dep_dirs, dep_files)    

result_dirs, result_files = get_file_list(destination)
clean_files(destination, result_dirs, result_files)

with open(destination + '/BUCK', 'w+b') as file:
    pass

shutil.copytree('Config', destination + '/' + 'Config')
shutil.copytree('tools/buck-build', destination + '/' + 'tools/buck-build')

shutil.copy('Wallet/README.md', destination + '/' + 'README.md')
os.remove(destination + '/Wallet/' + 'README.md')

copy_files = [
    '.buckconfig',
    '.gitignore',
    'Utils.makefile',
    'Wallet.makefile',
    'check_env.sh',
    'package_app.sh',
]

for file in copy_files:
    shutil.copy(file, destination + '/' + file)
