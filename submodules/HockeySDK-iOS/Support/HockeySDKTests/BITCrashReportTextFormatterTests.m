//
//  BITCrashReportTextFormatterTests.m
//  HockeySDK
//
//  Created by Andreas Linde on 27.11.14.
//
//

#import <XCTest/XCTest.h>

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

#import <CrashReporter/CrashReporter.h>
#import "BITCrashReportTextFormatter.h"

#import "BITTestHelper.h"
#import "BITCrashReportTextFormatterPrivate.h"

@interface BITCrashReportTextFormatterTests : XCTestCase

@end

@implementation BITCrashReportTextFormatterTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {  
  [super tearDown];
}

- (void)testOSXImages {
  NSString *processPath = nil;
  NSString *appBundlePath = nil;
  
  appBundlePath = @"/Applications/MyTestApp.App";

  // Test with default OS X app path
  processPath = [appBundlePath stringByAppendingString:@"/Contents/MacOS/MyApp"];
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
  
  // Test with OS X LoginItems app helper path
  processPath = [appBundlePath stringByAppendingString:@"/Contents/Library/LoginItems/net.hockeyapp.helper.app/Contents/MacOS/Helper"];
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
  
  // Test with OS X app in Resources folder
  processPath = @"/Applications/MyTestApp.App/Contents/Resources/Helper";
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
}

- (void)testiOSImages {
  NSString *processPath = nil;
  NSString *appBundlePath = nil;
    
  appBundlePath = @"/private/var/mobile/Containers/Bundle/Application/9107B4E2-CD8C-486E-A3B2-82A5B818F2A0/MyApp.app";
  
  // Test with iOS App
  processPath = [appBundlePath stringByAppendingString:@"/MyApp"];
  [self testiOSNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
  [self testiOSAppFrameworkAtProcessPath:processPath appBundlePath:appBundlePath];
  

  // Test with iOS App Extension
  processPath = [appBundlePath stringByAppendingString:@"/Plugins/MyAppExtension.appex/MyAppExtension"];
  [self testiOSNonAppSpecificImagesForProcessPath:processPath];
  [self assertIsOtherWithImagePath:processPath processPath:nil];
  [self assertIsOtherWithImagePath:nil processPath:processPath];
  [self assertIsAppBinaryWithImagePath:processPath processPath:processPath];
  [self testiOSAppFrameworkAtProcessPath:processPath appBundlePath:appBundlePath];
}


#pragma mark - Test Helper

- (void)assertIsAppFrameworkWithFrameworkPath:(NSString *)frameworkPath processPath:(NSString *)processPath {
  BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:frameworkPath
                                                                            processPath:processPath];
  XCTAssertEqual(imageType, BITBinaryImageTypeAppFramework, @"Test framework %@ with process %@", frameworkPath, processPath);
}

- (void)assertIsAppBinaryWithImagePath:(NSString *)imagePath processPath:(NSString *)processPath {
  BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:imagePath
                                                                            processPath:processPath];
  XCTAssertEqual(imageType, BITBinaryImageTypeAppBinary, @"Test app %@ with process %@", imagePath, processPath);
}

- (void)assertIsSwiftFrameworkWithFrameworkPath:(NSString *)swiftFrameworkPath processPath:(NSString *)processPath {
  BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:swiftFrameworkPath
                                                                            processPath:processPath];
  XCTAssertEqual(imageType, BITBinaryImageTypeOther, @"Test swift image %@ with process %@", swiftFrameworkPath, processPath);
}

- (void)assertIsOtherWithImagePath:(NSString *)imagePath processPath:(NSString *)processPath {
  BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:imagePath
                                                                            processPath:processPath];
  XCTAssertEqual(imageType, BITBinaryImageTypeOther, @"Test other image %@ with process %@", imagePath, processPath);
}

#pragma mark - OS X Test Helper

- (void)testOSXAppFrameworkAtProcessPath:(NSString *)processPath appBundlePath:(NSString *)appBundlePath {
  NSString *frameworkPath = [appBundlePath stringByAppendingString:@"/Contents/Frameworks/MyFrameworkLib.framework/Versions/A/MyFrameworkLib"];
  [self assertIsAppFrameworkWithFrameworkPath:frameworkPath processPath:processPath];

  frameworkPath = [appBundlePath stringByAppendingString:@"/Contents/Frameworks/libSwiftMyLib.framework/Versions/A/libSwiftMyLib"];
  [self assertIsAppFrameworkWithFrameworkPath:frameworkPath processPath:processPath];

  NSMutableArray *swiftFrameworkPaths = [NSMutableArray new];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftCore.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftDarwin.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftDispatch.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftFoundation.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftObjectiveC.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftSecurity.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftCoreGraphics.dylib"]];
  
  for (NSString *swiftFrameworkPath in swiftFrameworkPaths) {
    [self assertIsSwiftFrameworkWithFrameworkPath:swiftFrameworkPath processPath:processPath];
  }
}

- (void)testOSXNonAppSpecificImagesForProcessPath:(NSString *)processPath {
  // system test paths
  NSMutableArray *nonAppSpecificImagePaths = [NSMutableArray new];

  // OS X frameworks
  [nonAppSpecificImagePaths addObject:@"cl_kernels"];
  [nonAppSpecificImagePaths addObject:@""];
  [nonAppSpecificImagePaths addObject:@"???"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/Frameworks/CFNetwork.framework/Versions/A/CFNetwork"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libsystem_platform.dylib"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/Versions/A/vecLib"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/Sharing.framework/Versions/A/Sharing"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libbsm.0.dylib"];
  
  for (NSString *imagePath in nonAppSpecificImagePaths) {
    [self assertIsOtherWithImagePath:imagePath processPath:processPath];
  }
}


#pragma mark - iOS Test Helper

- (void)testiOSAppFrameworkAtProcessPath:(NSString *)processPath appBundlePath:(NSString *)appBundlePath {
  NSString *frameworkPath = [appBundlePath stringByAppendingString:@"/Frameworks/MyFrameworkLib.framework/MyFrameworkLib"];
  [self assertIsAppFrameworkWithFrameworkPath:frameworkPath processPath:processPath];

  
  frameworkPath = [appBundlePath stringByAppendingString:@"/Frameworks/libSwiftMyLib.framework/libSwiftMyLib"];
  [self assertIsAppFrameworkWithFrameworkPath:frameworkPath processPath:processPath];

  NSMutableArray *swiftFrameworkPaths = [NSMutableArray new];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftCore.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftDarwin.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftDispatch.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftFoundation.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftObjectiveC.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftSecurity.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftCoreGraphics.dylib"]];
  
  for (NSString *swiftFrameworkPath in swiftFrameworkPaths) {
    [self assertIsSwiftFrameworkWithFrameworkPath:swiftFrameworkPath processPath:processPath];
  }
}

- (void)testiOSNonAppSpecificImagesForProcessPath:(NSString *)processPath {
  // system test paths
  NSMutableArray *nonAppSpecificImagePaths = [NSMutableArray new];
  
  // iOS frameworks
  [nonAppSpecificImagePaths addObject:@"/System/Library/AccessibilityBundles/AccessibilitySettingsLoader.bundle/AccessibilitySettingsLoader"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/Frameworks/AVFoundation.framework/AVFoundation"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/Frameworks/AVFoundation.framework/libAVFAudio.dylib"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/AOSNotification.framework/AOSNotification"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/Accessibility.framework/Frameworks/AccessibilityUI.framework/AccessibilityUI"];
  [nonAppSpecificImagePaths addObject:@"/System/Library/PrivateFrameworks/Accessibility.framework/Frameworks/AccessibilityUIUtilities.framework/AccessibilityUIUtilities"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libAXSafeCategoryBundle.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libAXSpeechManager.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/libAccessibility.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libcache.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libcommonCrypto.dylib"];
  [nonAppSpecificImagePaths addObject:@"/usr/lib/system/libcompiler_rt.dylib"];
  
  // iOS Jailbreak libraries
  [nonAppSpecificImagePaths addObject:@"/Library/MobileSubstrate/MobileSubstrate.dylib"];
  [nonAppSpecificImagePaths addObject:@"/Library/MobileSubstrate/DynamicLibraries/WeeLoader.dylib"];
  [nonAppSpecificImagePaths addObject:@"/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateLoader.dylib"];
  [nonAppSpecificImagePaths addObject:@"/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate"];
  [nonAppSpecificImagePaths addObject:@"/Library/MobileSubstrate/DynamicLibraries/WinterBoard.dylib"];
  
  for (NSString *imagePath in nonAppSpecificImagePaths) {
    [self assertIsOtherWithImagePath:imagePath processPath:processPath];
  }
}

- (void)testSignalReport {
  NSData *crashData = [BITTestHelper dataOfFixtureCrashReportWithFileName:@"live_report_signal"];
  assertThat(crashData, notNilValue());
  
  NSError *error = nil;
  BITPLCrashReport *report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
  
  NSString *crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:@""];

  assertThat(crashLogString, notNilValue());

  crashData = [BITTestHelper dataOfFixtureCrashReportWithFileName:@"live_report_signal_marketing"];
  assertThat(crashData, notNilValue());
  
  report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
  
  crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:@""];
  
  assertThat(crashLogString, notNilValue());
}

- (void)testExceptionReport {
  NSData *crashData = [BITTestHelper dataOfFixtureCrashReportWithFileName:@"live_report_exception"];
  assertThat(crashData, notNilValue());
  
  NSError *error = nil;
  BITPLCrashReport *report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
  
  NSString *crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:@""];
  
  assertThat(crashLogString, notNilValue());

  crashData = [BITTestHelper dataOfFixtureCrashReportWithFileName:@"live_report_exception_marketing"];
  assertThat(crashData, notNilValue());
  
  report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
  
  crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:@""];
  
  assertThat(crashLogString, notNilValue());
}

- (void)testXamarinReport {
  NSData *crashData = [BITTestHelper dataOfFixtureCrashReportWithFileName:@"live_report_xamarin"];
  assertThat(crashData, notNilValue());
  
  NSError *error = nil;
  BITPLCrashReport *report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
  
  NSString *filePath = [[NSBundle bundleForClass:self.class] pathForResource:@"log_report_xamarin" ofType:@""];
  NSString *expected = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
  
  NSString *actual = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:@""];
  
  assertThat(expected, equalTo(actual));
}

- (void)testAnonymizedPathFromPath {
  NSString *testPath = @"/var/containers/Bundle/Application/2A0B0E6F-0BF2-419D-A699-FCDF8ADECD8C/Puppet.app/Puppet";
  NSString *expected = testPath;
  NSString *actual = [BITCrashReportTextFormatter anonymizedPathFromPath:testPath];
  assertThat(actual, equalTo(expected));
  
  testPath = @"/Users/sampleuser/Library/Developer/CoreSimulator/Devices/B8321AD0-C30B-41BD-BA54-5A7759CEC4CD/data/Containers/Bundle/Application/8CC7B5B5-7841-45C4-BAC2-6AA1B944A5E1/Puppet.app/Puppet";
  expected = @"/Users/USER/Library/Developer/CoreSimulator/Devices/B8321AD0-C30B-41BD-BA54-5A7759CEC4CD/data/Containers/Bundle/Application/8CC7B5B5-7841-45C4-BAC2-6AA1B944A5E1/Puppet.app/Puppet";
  actual = [BITCrashReportTextFormatter anonymizedPathFromPath:testPath];
  assertThat(actual, equalTo(expected));
  XCTAssertFalse([actual containsString:@"sampleuser"]);
  XCTAssertTrue([actual hasPrefix:@"/Users/USER/"]);

}

@end
