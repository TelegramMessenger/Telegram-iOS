#import <XCTest/XCTest.h>

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

@interface BITTestsDependencyInjection : XCTestCase

- (void)setMockNotificationCenter:(id)mockNotificationCenter;
- (id)mockNotificationCenter;

@end
