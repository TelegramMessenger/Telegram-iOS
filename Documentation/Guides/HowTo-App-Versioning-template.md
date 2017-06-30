## Introduction

We suggest to handle beta and release versions in two separate *apps* on HockeyApp with their own bundle identifier (e.g. by adding "beta" to the bundle identifier), so

* both apps can run on the same device or computer at the same time without interfering,
* release versions do not appear on the beta download pages, and
* easier analysis of crash reports and user feedback.

We propose the following method to set version numbers in your beta versions:

* Use both `Bundle Version` and `Bundle Version String, short` in your Info.plist.
* "Bundle Version" should contain a sequential build number, e.g. 1, 2, 3.
* "Bundle Version String, short" should contain the target official version number, e.g. 1.0.

## HowTo

The recommended way to do versioning of your app versions is as follows:

- Each version gets an ongoing `build` number which increases by `1` for every version as `CFBundleVersion` in `Info.plist`
- Additionally `CFBundleShortVersionString` in `Info.plist` will contain you target public version number as a string like `1.0.0`

This ensures that each app version is uniquely identifiable, and that live and beta version numbers never ever collide.

This is how to set it up with Xcode 4:

1. Pick `File | New`, choose `Other` and `Configuration Settings File`, this gets you a new .xcconfig file.
2. Name it `buildnumber.xcconfig`
3. Add one line with this content: `BUILD_NUMBER = 1`
4. Then click on the project on the upper left in the file browser (the same place where you get to build settings), click on the project again in the second-to-left panel, and click on the Info tab at the top of the inner panel.
5.  There, you can choose `Based on Configuration File` for each of your targets for each of your configurations (debug, release, etc.)
6. Select your target
7. Select the `Summary` tab
8. For `Build` enter the value: `${BUILD_NUMBER}`
9. Select the `Build Phases` tab
10. Select `Add Build Phase`
11. Choose `Add Run Script`
12. Add the following content:

        if [ "$CONFIGURATION" == "AdHoc_Distribution" ]
             then /usr/bin/perl -pe 's/(BUILD_NUMBER = )(\d+)/$1.($2+1)/eg' -i buildnumber.xcconfig
        fi
13. Change `AdHoc_Distribution` to the actual name of the Xcode configuration(s) you wnat the build number to be increased.

    *Note:* Configuration names should not contain spaces!
14. If you want to increase the build number before the build actuallry starts, just drag it up