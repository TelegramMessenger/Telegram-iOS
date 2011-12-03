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

@interface CNSHockeyManager ()

- (BOOL)shouldUseLiveIdenfitier;

- (void)configureJMC;
- (void)configureHockeyManager;
- (void)configureQuincyManager;

@end

@implementation CNSHockeyManager

#pragma mark - Public Class Methods

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

+ (BOOL)isJMCActive {
  id jmcClass = NSClassFromString(@"JMC");
  id jmcInstance = [jmcClass performSelector:@selector(instance)];
  
  return (jmcInstance) && ([jmcInstance performSelector:@selector(url)]);
}

+ (BOOL)isJMCPresent {
  id jmcClass = NSClassFromString(@"JMC");
  return (jmcClass) && ([jmcClass respondsToSelector:@selector(instance)]);
}

#pragma mark - Private Class Methods

+ (void)disableJMCCrashReporter {
  id jmcClass = NSClassFromString(@"JMC");
  id jmcInstance = [jmcClass performSelector:@selector(instance)];
  id jmcOptions = [jmcInstance performSelector:@selector(options)];
  SEL crashReporterSelector = @selector(setCrashReportingEnabled:);

  BOOL value = NO;

  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[jmcOptions methodSignatureForSelector:crashReporterSelector]];
  invocation.target = jmcOptions;
  invocation.selector = crashReporterSelector;
  [invocation setArgument:&value atIndex:2];
  [invocation invoke];
}

+ (BOOL)checkJMCConfiguration:(NSDictionary *)configuration {
  return (([[configuration valueForKey:@"enabled"] boolValue]) &&
          ([[configuration valueForKey:@"url"] length] > 0) &&
          ([[configuration valueForKey:@"key"] length] > 0) &&
          ([[configuration valueForKey:@"project"] length] > 0));
}

+ (void)applyJMCConfiguration:(NSDictionary *)configuration {
  id jmcClass = NSClassFromString(@"JMC");
  id jmcInstance = [jmcClass performSelector:@selector(instance)];
  SEL configureSelector = @selector(configureJiraConnect:projectKey:apiKey:);
  
  NSString *url = [configuration valueForKey:@"url"];
  NSString *project = [configuration valueForKey:@"project"];
  NSString *key = [configuration valueForKey:@"key"];
  
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[jmcInstance methodSignatureForSelector:configureSelector]];
  invocation.target = jmcInstance;
  invocation.selector = configureSelector;
  [invocation setArgument:&url atIndex:2];
  [invocation setArgument:&project atIndex:3];
  [invocation setArgument:&key atIndex:4];
  [invocation invoke];
}

#pragma mark - Public Instance Methods

- (void)configureWithIdentifier:(NSString *)newAppIdentifier delegate:(id)delegate {
  [appIdentifier release];
  appIdentifier = [newAppIdentifier copy];
  
  [self configureQuincyManager];
  [self configureHockeyManager];
}

- (void)configureWithBetaIdentifier:(NSString *)betaIdentifier liveIdentifier:(NSString *)liveIdentifier delegate:(id)delegate {
  [appIdentifier release];

  if ([self shouldUseLiveIdenfitier]) {
    appIdentifier = [liveIdentifier copy];
    
    [self configureQuincyManager];
  }
  else {
    appIdentifier = [betaIdentifier copy];
    
    [self configureQuincyManager];
    [self configureHockeyManager];
  }
}

#pragma mark - Private Instance Methods

- (BOOL)shouldUseLiveIdenfitier {
  BOOL delegateResult = NO;
  if ([delegate respondsToSelector:@selector(shouldUseLiveIdenfitier)]) {
    delegateResult = [(NSObject <CNSHockeyManagerDelegate>*)delegate shouldUseLiveIdenfitier];
  }

  return (delegateResult) || ([[BWHockeyManager sharedHockeyManager] isAppStoreEnvironment]);
}

- (void)configureQuincyManager {
  [[BWQuincyManager sharedQuincyManager] setAppIdentifier:appIdentifier];
}

- (void)configureHockeyManager {
  [[BWHockeyManager sharedHockeyManager] setAppIdentifier:appIdentifier];
  [[BWHockeyManager sharedHockeyManager] setCheckForTracker:YES];
  
  // Only if JMC is part of the project
  if ([[self class] isJMCPresent]) {
    [[BWHockeyManager sharedHockeyManager] addObserver:self forKeyPath:@"trackerConfig" options:0 context:nil];
    [[self class] disableJMCCrashReporter];
    [self performSelector:@selector(configureJMC) withObject:nil afterDelay:0];
  }
}

- (void)configureJMC {
  // Return if JMC is already configured
  if ([[self class] isJMCActive]) {
    return;
  }
  
  // Return if app id is nil
  if (!appIdentifier) {
    return;
  }
  
  // Configure JMC from user defaults
  NSDictionary *configurations = [[NSUserDefaults standardUserDefaults] valueForKey:@"CNSTrackerConfigurations"];
  NSDictionary *configuration = [configurations valueForKey:appIdentifier];
  if ([[self class] checkJMCConfiguration:configuration]) {
    [[self class] applyJMCConfiguration:configuration];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if ([object trackerConfig]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *trackerConfig = [[defaults valueForKey:@"CNSTrackerConfigurations"] mutableCopy];
    if (!trackerConfig) {
      trackerConfig = [[NSMutableDictionary dictionaryWithCapacity:1] retain];
    }

    [trackerConfig setValue:[object trackerConfig] forKey:appIdentifier];
    [defaults setValue:trackerConfig forKey:@"CNSTrackerConfigurations"];
    [trackerConfig release];
    
    [defaults synchronize];
    [self configureJMC];
  }
}

- (void)dealloc {
  [appIdentifier release], appIdentifier = nil;
  delegate = nil;
  
  [super dealloc];
}

@end
