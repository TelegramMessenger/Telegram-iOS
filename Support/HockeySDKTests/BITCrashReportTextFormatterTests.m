//
//  BITCrashReportTextFormatterTests.m
//  HockeySDK
//
//  Created by Andreas Linde on 27.11.14.
//
//

#import <XCTest/XCTest.h>
#import "BITCrashReportTextFormatter.h"

@interface BITCrashReportTextFormatterTests : XCTestCase

@end

@implementation BITCrashReportTextFormatterTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Wimplicit"
  __gcov_flush();
# pragma clang diagnostic pop
  
  [super tearDown];
}

- (void)testOSXImages {
  NSString *processPath = nil;
  NSString *appBundlePath = nil;
  
  appBundlePath = @"/Applications/MyTestApp.App";

  // Test with default OS X app path
  processPath = [appBundlePath stringByAppendingString:@"/Contents/MacOS/MyApp"];
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self testAppBinaryWithImagePath:processPath processPath:processPath];
  
  // Test with OS X LoginItems app helper path
  processPath = [appBundlePath stringByAppendingString:@"/Contents/Library/LoginItems/net.hockeyapp.helper.app/Contents/MacOS/Helper"];
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self testAppBinaryWithImagePath:processPath processPath:processPath];
  
  // Test with OS X app in Resources folder
  processPath = @"/Applications/MyTestApp.App/Contents/Resources/Helper";
  [self testOSXNonAppSpecificImagesForProcessPath:processPath];
  [self testAppBinaryWithImagePath:processPath processPath:processPath];
}

- (void)testiOSImages {
  NSString *processPath = nil;
  NSString *appBundlePath = nil;
    
  appBundlePath = @"/private/var/mobile/Containers/Bundle/Application/9107B4E2-CD8C-486E-A3B2-82A5B818F2A0/MyApp.app";
  
  // Test with iOS App
  processPath = [appBundlePath stringByAppendingString:@"/MyApp"];
  [self testiOSNonAppSpecificImagesForProcessPath:processPath];
  [self testAppBinaryWithImagePath:processPath processPath:processPath];
  [self testiOSAppFrameworkAtProcessPath:processPath appBundlePath:appBundlePath];

  // Test with iOS App Extension
  processPath = [appBundlePath stringByAppendingString:@"/Plugins/MyAppExtension.appex/MyAppExtension"];
  [self testiOSNonAppSpecificImagesForProcessPath:processPath];
  [self testAppBinaryWithImagePath:processPath processPath:processPath];
  [self testiOSAppFrameworkAtProcessPath:processPath appBundlePath:appBundlePath];
}


#pragma mark - Test Helper

- (void)testAppBinaryWithImagePath:(NSString *)imagePath processPath:(NSString *)processPath {
  BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:imagePath
                                                                            processPath:processPath];
  XCTAssert((imageType == BITBinaryImageTypeAppBinary), @"Test app %@ with process %@", imagePath, processPath);
}


#pragma mark - OS X Test Helper

- (void)testOSXAppFrameworkAtProcessPath:(NSString *)processPath appBundlePath:(NSString *)appBundlePath {
  NSString *frameworkPath = [appBundlePath stringByAppendingString:@"/Contents/Frameworks/MyFrameworkLib.framework/Versions/A/MyFrameworkLib"];
  BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:frameworkPath
                                                                            processPath:processPath];
  XCTAssert((imageType == BITBinaryImageTypeAppFramework), @"Test framework %@ with process %@", frameworkPath, processPath);

  frameworkPath = [appBundlePath stringByAppendingString:@"/Contents/Frameworks/libSwiftMyLib.framework/Versions/A/libSwiftMyLib"];
  imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:frameworkPath
                                                         processPath:processPath];
  XCTAssert((imageType == BITBinaryImageTypeAppFramework), @"Test framework %@ with process %@", frameworkPath, processPath);

  NSMutableArray *swiftFrameworkPaths = [NSMutableArray new];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftCore.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftDarwin.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftDispatch.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftFoundation.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftObjectiveC.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftSecurity.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Contents/Frameworks/libswiftCoreGraphics.dylib"]];
  
  for (NSString *imagePath in swiftFrameworkPaths) {
    BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:imagePath
                                                                              processPath:processPath];
    XCTAssert((imageType == BITBinaryImageTypeOther), @"Test swift image %@ with process %@", imagePath, processPath);
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
    BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:imagePath
                                                                              processPath:processPath];
    XCTAssert((imageType == BITBinaryImageTypeOther), @"Test other image %@ with process %@", imagePath, processPath);
  }
}


#pragma mark - iOS Test Helper

- (void)testiOSAppFrameworkAtProcessPath:(NSString *)processPath appBundlePath:(NSString *)appBundlePath {
  NSString *frameworkPath = [appBundlePath stringByAppendingString:@"/Frameworks/MyFrameworkLib.framework/MyFrameworkLib"];
  BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:frameworkPath
                                                                            processPath:processPath];
  XCTAssert((imageType == BITBinaryImageTypeAppFramework), @"Test framework %@ with process %@", frameworkPath, processPath);
  
  frameworkPath = [appBundlePath stringByAppendingString:@"/Frameworks/libSwiftMyLib.framework/libSwiftMyLib"];
  imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:frameworkPath
                                                         processPath:processPath];
  XCTAssert((imageType == BITBinaryImageTypeAppFramework), @"Test framework %@ with process %@", frameworkPath, processPath);

  NSMutableArray *swiftFrameworkPaths = [NSMutableArray new];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftCore.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftDarwin.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftDispatch.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftFoundation.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftObjectiveC.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftSecurity.dylib"]];
  [swiftFrameworkPaths addObject:[appBundlePath stringByAppendingString:@"/Frameworks/libswiftCoreGraphics.dylib"]];
  
  for (NSString *imagePath in swiftFrameworkPaths) {
    BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:imagePath
                                                                              processPath:processPath];
    XCTAssert((imageType == BITBinaryImageTypeOther), @"Test swift image %@ with process %@", imagePath, processPath);
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
    BITBinaryImageType imageType = [BITCrashReportTextFormatter bit_imageTypeForImagePath:imagePath
                                                                              processPath:processPath];
    XCTAssert((imageType == BITBinaryImageTypeOther), @"Test other image %@ with process %@", imagePath, processPath);
  }
}


@end
