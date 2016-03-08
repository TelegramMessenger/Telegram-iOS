## Introduction

Mac and iOS crash reports show the stack traces for all running threads of your app of the time a crash occured. But the stack traces only contain memory addresses and don't show class names, methods, file names and line numbers that are needed to understand them.

To get these memory addresses translated you need to upload a dSYM package to the server, which contains all information required to make this happen. The symbolication process will then check the binary images section of the crash report and grab the UUID of the binary that caused the crash. Next it will get the UUID of the dSYM package to make sure they are identical and process the data if so.

**WARNING:** Every time you are doing a build, the app binary and the dSYM will get a new unique UUID, no matter if you changed the code or not. So make sure to archive all your binaries and dSYMs that you are using for beta or app store builds!
This will also apply when using Bitcode. Then, Apple will use your uploaded build and re-compile it on their end. Whenever this happens, this also changes the UUID and requires you to download the newly generated dSYM from Apple and upload it to HockeyApp.

## HowTo

Once you have your app ready for beta testing or even to submit it to the App Store, you need to upload the `.dSYM` bundle to HockeyApp to enable symbolication. If you have built your app with Xcode, menu `Product` > `Archive`, you can find the `.dSYM` as follows:

1. Chose `Window` > `Organizer` in Xcode.
2. Select the tab Archives.
3. Select your app in the left sidebar.
4. Right-click on the latest archive and select `Show in Finder`.
5. Right-click the `.xcarchive` in Finder and select `Show Package Contents`.
6. You should see a folder named dSYMs which contains your dSYM bundle. If you use Safari, just drag this file from Finder and drop it on to the corresponding drop zone in HockeyApp. If you use another browser, copy the file to a different location, then right-click it and choose Compress `YourApp.dSYM`. The file will be compressed as a .zip file. Drag & drop this file to HockeyApp. 

## Mac Desktop Uploader

As an alternative, you can use our [HockeyApp for Mac](http://hockeyapp.net/releases/mac/) app to upload the complete archive in one step.

Also check out the guide on [how to upload to HockeyApp from Mac OS X](http://support.hockeyapp.net/kb/client-integration-ios-mac-os-x/how-to-upload-to-hockeyapp-from-mac-os-x).