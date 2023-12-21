#!/bin/bash

set -euo pipefail
./update-dependencies.sh
cd LyraCoreWebService
carthage update --no-build

carthage build Auth0.swift --platform iOS --cache-builds --use-xcframeworks
