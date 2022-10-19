#!/bin/bash

git checkout .

git checkout master

pod trunk me

pod cache clean 'CrowdinSDK' --all

pod trunk push --allow-warnings --skip-tests