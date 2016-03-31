#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "BITMetricsManager.h"
#import "BITTelemetryContext.h"
#import "BITMetricsManagerPrivate.h"
#import "BITHockeyHelper.h"
#import "HockeySDKPrivate.h"
#import "BITChannel.h"
#import "BITEventData.h"
#import "BITSession.h"
#import "BITSessionState.h"
#import "BITSessionStateData.h"
#import "BITPersistence.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITSender.h"

NSString *const kBITApplicationWasLaunched = @"BITApplicationWasLaunched";

static char *const kBITMetricsEventQueue = "net.hockeyapp.telemetryEventQueue";

static NSString *const kBITSessionFileType = @"plist";
static NSString *const kBITApplicationDidEnterBackgroundTime = @"BITApplicationDidEnterBackgroundTime";

static NSString *const BITMetricsBaseURLString = @"https://gate.hockeyapp.net/";
static NSString *const BITMetricsURLPathString = @"v2/track";

@interface BITMetricsManager ()

@property (nonatomic, strong) id<NSObject> appWillEnterForegroundObserver;
@property (nonatomic, strong) id<NSObject> appDidEnterBackgroundObserver;

@end

@implementation BITMetricsManager

@synthesize channel = _channel;
@synthesize telemetryContext = _telemetryContext;
@synthesize persistence = _persistence;
@synthesize serverURL = _serverURL;
@synthesize userDefaults = _userDefaults;

#pragma mark - Create & start instance

- (instancetype)init {
  if ((self = [super init])) {
    _disabled = NO;
    _metricsEventQueue = dispatch_queue_create(kBITMetricsEventQueue, DISPATCH_QUEUE_CONCURRENT);
    _appBackgroundTimeBeforeSessionExpires = 20;
    _serverURL = [NSString stringWithFormat:@"%@%@", BITMetricsBaseURLString, BITMetricsURLPathString];
  }
  return self;
}

- (instancetype)initWithChannel:(BITChannel *)channel telemetryContext:(BITTelemetryContext *)telemetryContext persistence:(BITPersistence *)persistence userDefaults:(NSUserDefaults *)userDefaults {
  if ((self = [self init])) {
    _channel = channel;
    _telemetryContext = telemetryContext;
    _persistence = persistence;
    _userDefaults = userDefaults;
  }
  return self;
}

- (void)startManager {
  self.sender = [[BITSender alloc] initWithPersistence:self.persistence serverURL:[NSURL URLWithString:self.serverURL]];
  [self.sender sendSavedDataAsync];
  [self startNewSessionWithId:bit_UUID()];
  [self registerObservers];
}

#pragma mark - Configuration

- (void)setDisabled:(BOOL)disabled {
  if (_disabled == disabled) { return; }
  
  if (disabled) {
    [self unregisterObservers];
  } else {
    [self registerObservers];
  }
  _disabled = disabled;
}

#pragma mark - Sessions

- (void)registerObservers {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  __weak typeof(self) weakSelf = self;

  if (nil == self.appDidEnterBackgroundObserver) {
    self.appDidEnterBackgroundObserver = [nc addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                     object:nil
                                                      queue:NSOperationQueue.mainQueue
                                                 usingBlock:^(NSNotification *note) {
                                                   typeof(self) strongSelf = weakSelf;
                                                   [strongSelf updateDidEnterBackgroundTime];
                                                 }];
  }
  if (nil == self.appWillEnterForegroundObserver) {
    self.appWillEnterForegroundObserver = [nc addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(NSNotification *note) {
                                                    typeof(self) strongSelf = weakSelf;
                                                    [strongSelf startNewSessionIfNeeded];
                                                  }];
  }
}

- (void)unregisterObservers {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.appDidEnterBackgroundObserver = nil;
  self.appWillEnterForegroundObserver = nil;
}

- (void)updateDidEnterBackgroundTime {
  [self.userDefaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:kBITApplicationDidEnterBackgroundTime];
  [self.userDefaults synchronize];
}

- (void)startNewSessionIfNeeded {
  if (self.appBackgroundTimeBeforeSessionExpires == 0) {
    __weak typeof(self) weakSelf = self;
    dispatch_async(_metricsEventQueue, ^{
      typeof(self) strongSelf = weakSelf;
      [strongSelf startNewSessionWithId:bit_UUID()];
    });
  }

  double appDidEnterBackgroundTime = [self.userDefaults doubleForKey:kBITApplicationDidEnterBackgroundTime];
  double timeSinceLastBackground = [[NSDate date] timeIntervalSince1970] - appDidEnterBackgroundTime;
  if (timeSinceLastBackground > self.appBackgroundTimeBeforeSessionExpires) {
    [self startNewSessionWithId:bit_UUID()];
  }
}

- (void)startNewSessionWithId:(NSString *)sessionId {
  BITSession *newSession = [self createNewSessionWithId:sessionId];
  [self.telemetryContext setSessionId:newSession.sessionId];
  [self.telemetryContext setIsFirstSession:newSession.isFirst];
  [self.telemetryContext setIsNewSession:newSession.isNew];
  [self trackSessionWithState:BITSessionState_start];
}

- (BITSession *)createNewSessionWithId:(NSString *)sessionId {
  BITSession *session = [BITSession new];
  session.sessionId = sessionId;
  session.isNew = @"true";

  if (![self.userDefaults boolForKey:kBITApplicationWasLaunched]) {
    session.isFirst = @"true";
    [self.userDefaults setBool:YES forKey:kBITApplicationWasLaunched];
    [self.userDefaults synchronize];
  } else {
    session.isFirst = @"false";
  }
  return session;
}

#pragma mark - Track telemetry

#pragma mark Sessions

- (void)trackSessionWithState:(BITSessionState)state {
  if (self.disabled) { return; }
  BITSessionStateData *sessionStateData = [BITSessionStateData new];
  sessionStateData.state = state;
  [self.channel enqueueTelemetryItem:sessionStateData];
}

#pragma mark Events

- (void)trackEventWithName:(NSString *)eventName {
  if (!eventName) { return; }
  
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.metricsEventQueue, ^{
    typeof(self) strongSelf = weakSelf;
    BITEventData *eventData = [BITEventData new];
    [eventData setName:eventName];
    [strongSelf trackDataItem:eventData];
  });
}

#pragma mark Track DataItem

- (void)trackDataItem:(BITTelemetryData *)dataItem {
  [self.channel enqueueTelemetryItem:dataItem];
}

#pragma mark - Custom getter

- (BITChannel *)channel {
  if (!_channel) {
    _channel = [[BITChannel alloc] initWithTelemetryContext:self.telemetryContext persistence:self.persistence];
  }
  return _channel;
}

- (BITTelemetryContext *)telemetryContext {
  if (!_telemetryContext) {
    _telemetryContext = [[BITTelemetryContext alloc] initWithAppIdentifier:self.appIdentifier persistence:self.persistence];
  }
  return _telemetryContext;
}

- (BITPersistence *)persistence {
  if (!_persistence) {
    _persistence = [BITPersistence new];
  }
  return _persistence;
}

- (NSUserDefaults *)userDefaults {
  if (!_userDefaults) {
    _userDefaults = [NSUserDefaults standardUserDefaults];
  }
  return _userDefaults;
}

@end

#endif /* HOCKEYSDK_FEATURE_METRICS */
