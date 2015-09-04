#import "BITReachability.h"
#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import <netinet/in.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <sys/socket.h>

NSString * const kBITReachabilityTypeChangedNotification = @"BITReachabilityTypeChangedNotification";
NSString* const kBITReachabilityUserInfoName = @"kName";
NSString* const kBITReachabilityUserInfoType = @"kType";

static char *const BITReachabilitySingletonQueue = "com.microsoft.ApplicationInsights.singletonQueue";
static char *const BITReacabilityNetworkQueue = "com.microsoft.ApplicationInsights.networkQueue";

static void BITReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info){
  if(info != NULL && [(__bridge NSObject*) info isKindOfClass: [BITReachability class]]){
    [(__bridge BITReachability *)info notify];
  }
}

@implementation BITReachability{
  SCNetworkReachabilityRef _reachability;
  BITReachabilityType _reachabilityType;
  BOOL _running;
}

#pragma mark - Initialize & configure shared instance

+ (instancetype)sharedInstance {
  static BITReachability *sharedInstance = nil;
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    sharedInstance = [BITReachability new];
    sharedInstance.singletonQueue = dispatch_queue_create(BITReachabilitySingletonQueue, DISPATCH_QUEUE_SERIAL);
    sharedInstance.networkQueue = dispatch_queue_create(BITReacabilityNetworkQueue, DISPATCH_QUEUE_SERIAL);
    
    if ([CTTelephonyNetworkInfo class]) {
      sharedInstance.radioInfo = [CTTelephonyNetworkInfo new];
    }
    [sharedInstance configureReachability];
  });
  return sharedInstance;
}

- (void)registerRadioObserver{
  __weak typeof(self) weakSelf = self;
  [NSNotificationCenter.defaultCenter addObserverForName:CTRadioAccessTechnologyDidChangeNotification
                                                  object:nil
                                                   queue:nil
                                              usingBlock:^(NSNotification *note)
   {
     typeof(self) strongSelf = weakSelf;
     [strongSelf notify];
   }];
}

- (void)unregisterRadioObserver{
  [NSNotificationCenter.defaultCenter removeObserver:self name:CTRadioAccessTechnologyDidChangeNotification object:nil];
}

- (void)configureReachability{
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.singletonQueue, ^{
    typeof(self) strongSelf = weakSelf;
    
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    SCNetworkReachabilityRef networkReachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    if (networkReachability != NULL){
      strongSelf->_reachability = networkReachability;
    }
  });
}

#pragma mark - Register for network changes

- (void)startNetworkStatusTracking{
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.singletonQueue, ^{
    typeof(self) strongSelf = weakSelf;
    
    if(_running){
      return;
    }
    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    context.info = (__bridge void *)self;
    if(SCNetworkReachabilitySetCallback(strongSelf->_reachability, BITReachabilityCallback, &context)){
      if(SCNetworkReachabilitySetDispatchQueue(strongSelf->_reachability, strongSelf.networkQueue)){
        if ([CTTelephonyNetworkInfo class]) {
          [strongSelf registerRadioObserver];
        }
        strongSelf->_running = YES;
      }else{
        SCNetworkReachabilitySetCallback(strongSelf->_reachability, NULL, NULL);
      }
    }
  });
}

- (void)stopNetworkStatusTracking{
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.singletonQueue, ^{
    typeof(self) strongSelf = weakSelf;
    
    if ([CTTelephonyNetworkInfo class]) {
      [strongSelf unregisterRadioObserver];
    }
    
    if (strongSelf->_reachability != NULL){
      SCNetworkReachabilitySetCallback(strongSelf->_reachability, NULL, NULL);
      SCNetworkReachabilitySetDispatchQueue(strongSelf->_reachability, NULL);
      _running = NO;
    }
  });
}

#pragma mark - Broadcast network changes

- (void)notify{
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.singletonQueue, ^{
    typeof(self) strongSelf = weakSelf;
    
    _reachabilityType = [strongSelf activeReachabilityType];
    NSDictionary *notificationDict = @{kBITReachabilityUserInfoName:[strongSelf descriptionForReachabilityType:strongSelf->_reachabilityType],
                                       kBITReachabilityUserInfoType:@(strongSelf->_reachabilityType)};
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter] postNotificationName:kBITReachabilityTypeChangedNotification object:nil userInfo:notificationDict];
    });
  });
}

#pragma mark - Get network status

- (BITReachabilityType)activeReachabilityType{
  
  BITReachabilityType reachabilityType = BITReachabilityTypeNone;
  SCNetworkReachabilityFlags flags;
  
  if(SCNetworkReachabilityGetFlags(_reachability, &flags)){
    
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0){
      return BITReachabilityTypeNone;
    }
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0){
      reachabilityType = BITReachabilityTypeWIFI;
    }
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)){
      if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0){
        reachabilityType = BITReachabilityTypeWIFI;
      }
    }
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN){
      reachabilityType = BITReachabilityTypeWWAN;
      
      // TODO: Radio info is nil after app returns to foreground, so set reachability type to wwan for now
      if ([CTTelephonyNetworkInfo class] && self.radioInfo && self.radioInfo.currentRadioAccessTechnology) {
        reachabilityType = [self wwanTypeForRadioAccessTechnology:self.radioInfo.currentRadioAccessTechnology];
      }
    }
  }
  
  return reachabilityType;
}

- (NSString *)descriptionForActiveReachabilityType{
  BITReachabilityType currentType = [self activeReachabilityType];
  
  return [self descriptionForReachabilityType:currentType];
}

#pragma mark - Helper

- (BITReachabilityType)wwanTypeForRadioAccessTechnology:(NSString *)technology{
  BITReachabilityType radioType = BITReachabilityTypeNone;
  
  // TODO: Check mapping
  if([technology isEqualToString:CTRadioAccessTechnologyGPRS]||
     [technology isEqualToString:CTRadioAccessTechnologyCDMA1x]){
    radioType = BITReachabilityTypeGPRS;
  }else if([technology isEqualToString:CTRadioAccessTechnologyEdge]){
    radioType = BITReachabilityTypeEDGE;
  }else if([technology isEqualToString:CTRadioAccessTechnologyWCDMA]||
           [technology isEqualToString:CTRadioAccessTechnologyHSDPA]||
           [technology isEqualToString:CTRadioAccessTechnologyHSUPA]||
           [technology isEqualToString:CTRadioAccessTechnologyCDMAEVDORev0]||
           [technology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevA]||
           [technology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevB]||
           [technology isEqualToString:CTRadioAccessTechnologyeHRPD]){
    radioType = BITReachabilityType3G;
  }else if([technology isEqualToString:CTRadioAccessTechnologyLTE]){
    radioType = BITReachabilityTypeLTE;
  }
  return radioType;
}

- (NSString *)descriptionForReachabilityType:(BITReachabilityType)reachabilityType{
  switch(reachabilityType){
    case BITReachabilityTypeWIFI:
      return @"WIFI";
    case BITReachabilityTypeWWAN:
      return @"WWAN";
    case BITReachabilityTypeGPRS:
      return @"GPRS";
    case BITReachabilityTypeEDGE:
      return @"EDGE";
    case BITReachabilityType3G:
      return @"3G";
    case BITReachabilityTypeLTE:
      return @"LTE";
    default:
      return @"None";
  }
}

@end
