#!/bin/bash
# Docs by jazzy
# https://github.com/realm/jazzy
# ------------------------------
if which jazzy >/dev/null; then
    jazzy \
        --clean \
        --author 'Serhii Londar' \
        --author_url 'https://github.com/serhii-londar' \
        --github_url 'https://github.com/serhii-londar' \
        --module 'CrowdinSDK' \
        --source-directory 'CrowdinSDK/Classes/' \
        --readme 'README.md' \
        --documentation 'Documentation/*.md' \
        --podspec 'CrowdinSDK.podspec' \
        --min-acl 'public'\
        --output 'docs/'
exit
else
echo "
    Error: jazzy not installed! <https://github.com/realm/jazzy>
    Install: gem install jazzy
    "
exit 1
fi
