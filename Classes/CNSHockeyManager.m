//  Copyright 2011 Codenauts UG (haftungsbeschränkt). All rights reserved.
//  See LICENSE.txt for author information.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "CNSHockeyManager.h"
#import "BWQuincyManager.h"
#import "BWHockeyManager.h"

#ifdef JMC_PRESENT
#import "JMC.h"
#endif

@interface CNSHockeyManager ()

#ifdef JMC_PRESENT
- (void)configureJMC;
#endif

@end

@implementation CNSHockeyManager

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 40000
+ (CNSHockeyManager *)sharedHockeyManager {   
  static CNSHockeyManager *sharedInstance = nil;
  static dispatch_once_t pred;
  
  if (sharedInstance) {
    return sharedInstance;
  }
  
  dispatch_once(&pred, ^{
    sharedInstance = [CNSHockeyManager alloc];
    sharedInstance = [sharedInstance init];
  });
  
  return sharedInstance;
}
#else
+ (CNSHockeyManager *)sharedHockeyManager {
	static CNSHockeyManager *hockeyManager = nil;
  
	if (hockeyManager == nil) {
		hockeyManager = [[CNSHockeyManager alloc] init];
	}
  
	return hockeyManager;
}
#endif

- (void)configureWithIdentifier:(NSString *)appIdentifier delegate:(id)delegate {
  // Crash Reporting
  [[BWQuincyManager sharedQuincyManager] setAppIdentifier:appIdentifier];
  
  // Distribution
  [[BWHockeyManager sharedHockeyManager] setAppIdentifier:appIdentifier];
  [[BWHockeyManager sharedHockeyManager] setUpdateURL:@"http://192.168.178.53:3000"];
  [[BWHockeyManager sharedHockeyManager] setCheckForTracker:YES];
  
#ifdef JMC_PRESENT
  // JMC
  [[[JMC instance] options] setCrashReportingEnabled:NO];
  [[BWHockeyManager sharedHockeyManager] addObserver:self forKeyPath:@"trackerConfig" options:0 context:nil];
  [self performSelector:@selector(configureJMC) withObject:nil afterDelay:0];
#endif
}

#ifdef JMC_PRESENT
- (void)configureJMC {
  // Return if JMC is already configured
  if ([[JMC instance] url]) {
    return;
  }
  
  // Configure JMC from user defaults
  NSDictionary *config = [[NSUserDefaults standardUserDefaults] valueForKey:@"CNSTrackerConfig"];
  if (([[config valueForKey:@"enabled"] boolValue]) &&
      ([[config valueForKey:@"url"] length] > 0) &&
      ([[config valueForKey:@"key"] length] > 0) &&
      ([[config valueForKey:@"project"] length] > 0)) {
    [[JMC instance] configureJiraConnect:[config valueForKey:@"url"] projectKey:[config valueForKey:@"project"] apiKey:[config valueForKey:@"key"]];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if ([object trackerConfig]) {
    [[NSUserDefaults standardUserDefaults] setValue:[object trackerConfig] forKey:@"CNSTrackerConfig"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self configureJMC];
  }
}
#endif 

@end
