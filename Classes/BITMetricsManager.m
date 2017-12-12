#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "BITMetricsManager.h"
#import "BITTelemetryContext.h"
#import "BITMetricsManagerPrivate.h"
#import "BITHockeyHelper.h"
#import "BITHockeyHelper+Application.h"
#import "HockeySDKPrivate.h"
#import "BITChannelPrivate.h"
#import "BITEventData.h"
#import "BITSession.h"
#import "BITSessionState.h"
#import "BITSessionStateData.h"
#import "BITPersistencePrivate.h"
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
  self.sender = [[BITSender alloc] initWithPersistence:self.persistence serverURL:(NSURL *)[NSURL URLWithString:self.serverURL]];
  [self.sender sendSavedDataAsync];
  [self startNewSessionWithId:bit_UUID()];
  [self registerObservers];
}

#pragma mark - Configuration

- (void)setDisabled:(BOOL)disabled {
  if (_disabled == disabled) { return; }
    _disabled = disabled;
  if (disabled) {
    [self unregisterObservers];
  } else {
    [self startManager];
  }
}

#pragma mark - Sessions

- (void)registerObservers {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  __weak typeof(self) weakSelf = self;

  if (nil == self.appDidEnterBackgroundObserver) {
    self.appDidEnterBackgroundObserver =
        [center addObserverForName:UIApplicationDidEnterBackgroundNotification
                            object:nil
                             queue:NSOperationQueue.mainQueue
                        usingBlock:^(NSNotification __unused *note) {
                          typeof(self) strongSelf = weakSelf;
                          [strongSelf updateDidEnterBackgroundTime];
                        }];
  }
  if (nil == self.appWillEnterForegroundObserver) {
    self.appWillEnterForegroundObserver =
        [center addObserverForName:UIApplicationWillEnterForegroundNotification
                            object:nil
                             queue:NSOperationQueue.mainQueue
                        usingBlock:^(NSNotification __unused *note) {
                          typeof(self) strongSelf = weakSelf;
                          [strongSelf startNewSessionIfNeeded];
                        }];
  }
}

- (void)unregisterObservers {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  id appDidEnterBackgroundObserver = self.appDidEnterBackgroundObserver;
  if(appDidEnterBackgroundObserver) {
    [center removeObserver:appDidEnterBackgroundObserver];
    self.appDidEnterBackgroundObserver = nil;
  }
  id appWillEnterForegroundObserver = self.appWillEnterForegroundObserver;
  if(appWillEnterForegroundObserver) {
    [center removeObserver:appWillEnterForegroundObserver];
    self.appWillEnterForegroundObserver = nil;
  }
}

- (void)updateDidEnterBackgroundTime {
  [self.userDefaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:kBITApplicationDidEnterBackgroundTime];
}

- (void)startNewSessionIfNeeded {
  double appDidEnterBackgroundTime = [self.userDefaults doubleForKey:kBITApplicationDidEnterBackgroundTime];
  // Add safeguard in case this returns a negative value
  if(appDidEnterBackgroundTime < 0) {
    appDidEnterBackgroundTime = 0;
    [self.userDefaults setDouble:0 forKey:kBITApplicationDidEnterBackgroundTime];
  }
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
  } else {
    session.isFirst = @"false";
  }
  return session;
}

#pragma mark - Track telemetry

#pragma mark Sessions

- (void)trackSessionWithState:(BITSessionState)state {
  if (self.disabled) {
    BITHockeyLogDebug(@"INFO: BITMetricsManager is disabled, therefore this tracking call was ignored.");
    return;
  }
  BITSessionStateData *sessionStateData = [BITSessionStateData new];
  sessionStateData.state = state;
  [self.channel enqueueTelemetryItem:sessionStateData];
}

#pragma mark Events

- (void)trackEventWithName:(nonnull NSString *)eventName {
  if (!eventName) {
    return;
  }
  if (self.disabled) {
    BITHockeyLogDebug(@"INFO: BITMetricsManager is disabled, therefore this tracking call was ignored.");
    return;
  }
  
  __weak typeof(self) weakSelf = self;
  dispatch_group_t group = dispatch_group_create();
  dispatch_group_async(group, self.metricsEventQueue, ^{
    typeof(self) strongSelf = weakSelf;
    BITEventData *eventData = [BITEventData new];
    [eventData setName:eventName];
    [strongSelf trackDataItem:eventData];
  });
  
  // If the app is running in the background.
  UIApplication *application = [UIApplication sharedApplication];
  BOOL applicationIsInBackground = ([BITHockeyHelper applicationState] == BITApplicationStateBackground);
  if (applicationIsInBackground) {
    [self.channel createBackgroundTaskWhileDataIsSending:application withWaitingGroup:group];
  }
}

- (void)trackEventWithName:(nonnull NSString *)eventName
                properties:(nullable NSDictionary<NSString *, NSString *> *)properties
              measurements:(nullable NSDictionary<NSString *, NSNumber *> *)measurements {
  if (!eventName) {
    return;
  }
  if (self.disabled) {
    BITHockeyLogDebug(@"INFO: BITMetricsManager is disabled, therefore this tracking call was ignored.");
    return;
  }

  __weak typeof(self) weakSelf = self;
  dispatch_group_t group = dispatch_group_create();
  dispatch_group_async(group, self.metricsEventQueue, ^{
    typeof(self) strongSelf = weakSelf;
    BITEventData *eventData = [BITEventData new];
    [eventData setName:eventName];
    [eventData setProperties:(NSDictionary *)properties];
    [eventData setMeasurements:measurements];
    [strongSelf trackDataItem:eventData];
  });
  
  // If the app is running in the background.
  UIApplication *application = [UIApplication sharedApplication];
  BOOL applicationIsInBackground = ([BITHockeyHelper applicationState] == BITApplicationStateBackground);
  if (applicationIsInBackground) {
    [self.channel createBackgroundTaskWhileDataIsSending:application withWaitingGroup:group];
  }
}

#pragma mark Track DataItem

- (void)trackDataItem:(BITTelemetryData *)dataItem {
  if (self.disabled) {
    BITHockeyLogDebug(@"INFO: BITMetricsManager is disabled, therefore this tracking call was ignored.");
    return;
  }
  
  BITHockeyLogDebug(@"INFO: Enqueue telemetry item: %@", dataItem.name);
  [self.channel enqueueTelemetryItem:dataItem];
}

#pragma mark - Custom getter

- (BITChannel *)channel {
  @synchronized(self) {
    if (!_channel) {
      _channel = [[BITChannel alloc] initWithTelemetryContext:self.telemetryContext persistence:self.persistence];
    }
    return _channel;
  }
}

- (BITTelemetryContext *)telemetryContext {
  @synchronized(self) {
    if (!_telemetryContext) {
      _telemetryContext = [[BITTelemetryContext alloc] initWithAppIdentifier:self.appIdentifier persistence:self.persistence];
    }
    return _telemetryContext;
  }
}

- (BITPersistence *)persistence {
  @synchronized(self) {
    if (!_persistence) {
      _persistence = [BITPersistence new];
    }
    return _persistence;
  }
}

- (NSUserDefaults *)userDefaults {
  @synchronized(self) {
    if (!_userDefaults) {
      _userDefaults = [NSUserDefaults standardUserDefaults];
    }
    return _userDefaults;
  }
}

@end

#endif /* HOCKEYSDK_FEATURE_METRICS */
