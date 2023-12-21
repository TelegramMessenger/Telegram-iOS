#!/bin/bash

set -euo pipefail

cd LyraCoreWebService

arch -x86_64 pod repo update
arch -x86_64 pod install
