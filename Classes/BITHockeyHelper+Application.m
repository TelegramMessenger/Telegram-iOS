#import "BITHockeyHelper+Application.h"

/*
 * Workaround for exporting symbols from category object files.
 */
NSString *BITHockeyHelperApplicationCategory;

@implementation BITHockeyHelper (Application)

/**
 * @discussion
 * Workaround for exporting symbols from category object files.
 * See article https://medium.com/ios-os-x-development/categories-in-static-libraries-78e41f8ddb96#.aedfl1kl0
 */
__attribute__((used)) static void importCategories() {
  [NSString stringWithFormat:@"%@", BITHockeyHelperApplicationCategory];
}

+ (BITApplicationState)applicationState {
  
  // App extensions must not access sharedApplication.
  if (!bit_isRunningInAppExtension()) {
    
    __block BITApplicationState state;
    dispatch_block_t block = ^{
      state = (BITApplicationState)[[self class] sharedAppState];
    };
    
    if ([NSThread isMainThread]) {
      block();
    } else {
      dispatch_sync(dispatch_get_main_queue(), block);
    }
    
    return state;
  }
  return BITApplicationStateUnknown;
}

+ (UIApplication *)sharedApplication {
  
  // Compute selector at runtime for more discretion.
  SEL sharedAppSel = NSSelectorFromString(@"sharedApplication");
  return ((UIApplication * (*)(id, SEL))[[UIApplication class] methodForSelector:sharedAppSel])([UIApplication class],
                                                                                                sharedAppSel);
}

+ (UIApplicationState)sharedAppState {
  return [[[[self class] sharedApplication] valueForKey:@"applicationState"] longValue];
}

@end
