#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_TELEMETRY

#import "BITTelemetryManager.h"
#import "BITTelemetryContext.h"
#import "BITTelemetryManagerPrivate.h"
#import "BITHockeyHelper.h"
#import "HockeySDKPrivate.h"
#import "BITChannel.h"
#import "BITSession.h"
#import "BITSessionState.h"
#import "BITSessionStateData.h"
#import "BITPersistence.h"
#import "BITHockeyBaseManagerPrivate.h"

static char *const kBITTelemetryEventQueue =
"com.microsoft.ApplicationInsights.telemetryEventQueue";

NSString *const kBITSessionFileType = @"plist";
NSString *const kBITApplicationDidEnterBackgroundTime = @"BITApplicationDidEnterBackgroundTime";
NSString *const kBITApplicationWasLaunched = @"BITApplicationWasLaunched";

@implementation BITTelemetryManager {
  id _appWillEnterForegroundObserver;
  id _appDidEnterBackgroundObserver;
}

@synthesize channel = _channel;
@synthesize telemetryContext = _telemetryContext;
@synthesize persistence = _persistence;
#pragma mark - Create & start instance

- (instancetype)init {
  if((self = [super init])) {
    _telemetryEventQueue = dispatch_queue_create(kBITTelemetryEventQueue, DISPATCH_QUEUE_CONCURRENT);
    _appBackgroundTimeBeforeSessionExpires = 20;
  }
  return self;
}

- (instancetype)initWithChannel:(BITChannel *)channel telemetryContext:(BITTelemetryContext *)telemetryContext persistence:(BITPersistence *)persistence {
  if((self = [self init])) {
    _channel = channel;
    _telemetryContext = telemetryContext;
    _persistence = persistence;
  }
  return self;
}

- (void)startManager {
  [self startNewSession];
  [self registerObservers];
}

#pragma mark - Sessions

- (void)registerObservers {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  
  __weak typeof(self) weakSelf = self;
  
  if(nil == _appDidEnterBackgroundObserver) {
    _appDidEnterBackgroundObserver = [nc addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                     object:nil
                                                      queue:NSOperationQueue.mainQueue
                                                 usingBlock:^(NSNotification *note) {
                                                   typeof(self) strongSelf = weakSelf;
                                                   [strongSelf updateDidEnterBackgroundTime];
                                                 }];
  }
  if(nil == _appWillEnterForegroundObserver) {
    _appWillEnterForegroundObserver = [nc addObserverForName:UIApplicationWillEnterForegroundNotification
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
  _appDidEnterBackgroundObserver = nil;
  _appWillEnterForegroundObserver = nil;
}

- (void)updateDidEnterBackgroundTime {
  [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:kBITApplicationDidEnterBackgroundTime];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)startNewSessionIfNeeded {
  if(self.appBackgroundTimeBeforeSessionExpires == 0) {
    [self startNewSession];
    return;
  }
  
  double appDidEnterBackgroundTime = [[NSUserDefaults standardUserDefaults] doubleForKey:kBITApplicationDidEnterBackgroundTime];
  double timeSinceLastBackground = [[NSDate date] timeIntervalSince1970] - appDidEnterBackgroundTime;
  if(timeSinceLastBackground > self.appBackgroundTimeBeforeSessionExpires) {
    [self startNewSession];
  }
}

- (void)startNewSession {
  NSString *newSessionId = bit_UUID();
  BITSession *newSession = [self createNewSessionWithId:newSessionId];
  //TODO: Update context
  
  [self trackSessionWithState:BITSessionState_start];
}

- (BITSession *)createNewSessionWithId:(NSString *)sessionId {
  BITSession *session = [BITSession new];
  session.sessionId = sessionId;
  session.isNew = @"true";
  
  if(![[NSUserDefaults standardUserDefaults] boolForKey:kBITApplicationWasLaunched]) {
    session.isFirst = @"true";
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBITApplicationWasLaunched];
    [[NSUserDefaults standardUserDefaults] synchronize];
  } else {
    session.isFirst = @"false";
  }
  return session;
}

#pragma mark - Track telemetry

- (void)trackSessionWithState:(BITSessionState) state {
  __weak typeof(self) weakSelf = self;
  dispatch_async(_telemetryEventQueue, ^{
    typeof(self) strongSelf = weakSelf;
    BITSessionStateData *sessionStateData = [BITSessionStateData new];
    sessionStateData.state = state;
    [[strongSelf channel] enqueueTelemetryItem:sessionStateData];
  });
}

#pragma mark - Custom getter

- (BITChannel *)channel {
  if(!_channel){
    _channel = [[BITChannel alloc]initWithTelemetryContext:self.telemetryContext persistence:self.persistence];
  }
  return _channel;
}

- (BITTelemetryContext *)telemetryContext {
  if(!_telemetryContext){
    _telemetryContext = [[BITTelemetryContext alloc] initWithInstrumentationKey:self.appIdentifier persistence:self.persistence];
  }
  return _telemetryContext;
}

- (BITPersistence *)persistence {
  if(!_persistence){
    _persistence = [BITPersistence new];
  }
  return _persistence;
}

@end

#endif /* HOCKEYSDK_FEATURE_TELEMETRY */
