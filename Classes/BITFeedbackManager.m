/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_FEEDBACK

#import <AssetsLibrary/AssetsLibrary.h>

#import "HockeySDKPrivate.h"

#import "BITFeedbackManager.h"
#import "BITFeedbackMessageAttachment.h"
#import "BITFeedbackManagerPrivate.h"
#import "BITHockeyBaseManagerPrivate.h"

#import "BITHockeyHelper.h"
#import "BITHockeyAppClient.h"

#define kBITFeedbackUserDataAsked   @"HockeyFeedbackUserDataAsked"
#define kBITFeedbackDateOfLastCheck	@"HockeyFeedbackDateOfLastCheck"
#define kBITFeedbackMessages        @"HockeyFeedbackMessages"
#define kBITFeedbackToken           @"HockeyFeedbackToken"
#define kBITFeedbackUserID          @"HockeyFeedbackuserID"
#define kBITFeedbackName            @"HockeyFeedbackName"
#define kBITFeedbackEmail           @"HockeyFeedbackEmail"
#define kBITFeedbackLastMessageID   @"HockeyFeedbackLastMessageID"
#define kBITFeedbackAppID           @"HockeyFeedbackAppID"

NSString *const kBITFeedbackUpdateAttachmentThumbnail = @"BITFeedbackUpdateAttachmentThumbnail";

@interface BITFeedbackManager()<UIGestureRecognizerDelegate>

@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic) BOOL screenshotNotificationEnabled;

@end

@implementation BITFeedbackManager {
  NSFileManager  *_fileManager;
  NSString       *_settingsFile;
  
  id _appDidBecomeActiveObserver;
  id _appDidEnterBackgroundObserver;
  id _networkDidBecomeReachableObserver;
  
  BOOL _incomingMessagesAlertShowing;
  BOOL _didEnterBackgroundState;
  BOOL _networkRequestInProgress;
  
  BITFeedbackObservationMode _observationMode;
}

#pragma mark - Initialization

- (instancetype)init {
  if ((self = [super init])) {
    _currentFeedbackListViewController = nil;
    _currentFeedbackComposeViewController = nil;
    _didAskUserData = NO;
    
    _requireUserName = BITFeedbackUserDataElementOptional;
    _requireUserEmail = BITFeedbackUserDataElementOptional;
    _showAlertOnIncomingMessages = YES;
    _showFirstRequiredPresentationModal = YES;
    
    _disableFeedbackManager = NO;
    _networkRequestInProgress = NO;
    _incomingMessagesAlertShowing = NO;
    _lastCheck = nil;
    _token = nil;
    _lastMessageID = nil;
    
    _feedbackList = [NSMutableArray array];
    
    _fileManager = [[NSFileManager alloc] init];
    
    _settingsFile = [bit_settingsDir() stringByAppendingPathComponent:BITHOCKEY_FEEDBACK_SETTINGS];
    
    _userID = nil;
    _userName = nil;
    _userEmail = nil;
  }
  return self;
}

- (void)dealloc {
  [self unregisterObservers];
}


- (void)didBecomeActiveActions {
  if ([self isFeedbackManagerDisabled]) return;
  if (!_didEnterBackgroundState) return;
  
  _didEnterBackgroundState = NO;
  
  if ([_feedbackList count] == 0) {
    [self loadMessages];
  } else {
    [self updateAppDefinedUserData];
  }
  [self updateMessagesList];
}

- (void)didEnterBackgroundActions {
  _didEnterBackgroundState = NO;
  
  if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
    _didEnterBackgroundState = YES;
  }
}

#pragma mark - Observers
- (void) registerObservers {
  __weak typeof(self) weakSelf = self;
  if(nil == _appDidEnterBackgroundObserver) {
    _appDidEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                                                       object:nil
                                                                                        queue:NSOperationQueue.mainQueue
                                                                                   usingBlock:^(NSNotification *note) {
                                                                                     typeof(self) strongSelf = weakSelf;
                                                                                     [strongSelf didEnterBackgroundActions];
                                                                                   }];
  }
  if(nil == _appDidBecomeActiveObserver) {
    _appDidBecomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                                                    object:nil
                                                                                     queue:NSOperationQueue.mainQueue
                                                                                usingBlock:^(NSNotification *note) {
                                                                                  typeof(self) strongSelf = weakSelf;
                                                                                  [strongSelf didBecomeActiveActions];
                                                                                }];
  }
  if(nil == _networkDidBecomeReachableObserver) {
    _networkDidBecomeReachableObserver = [[NSNotificationCenter defaultCenter] addObserverForName:BITHockeyNetworkDidBecomeReachableNotification
                                                                                           object:nil
                                                                                            queue:NSOperationQueue.mainQueue
                                                                                       usingBlock:^(NSNotification *note) {
                                                                                         typeof(self) strongSelf = weakSelf;
                                                                                         [strongSelf didBecomeActiveActions];
                                                                                       }];
  }
}

- (void) unregisterObservers {
  if(_appDidEnterBackgroundObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_appDidEnterBackgroundObserver];
    _appDidEnterBackgroundObserver = nil;
  }
  if(_appDidBecomeActiveObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_appDidBecomeActiveObserver];
    _appDidBecomeActiveObserver = nil;
  }
  if(_networkDidBecomeReachableObserver) {
    [[NSNotificationCenter defaultCenter] removeObserver:_networkDidBecomeReachableObserver];
    _networkDidBecomeReachableObserver = nil;
  }
}

#pragma mark - Private methods

- (NSString *)uuidString {
  CFUUIDRef theToken = CFUUIDCreate(NULL);
  NSString *stringUUID = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, theToken);
  CFRelease(theToken);
  
  return stringUUID;
}

- (NSString *)uuidAsLowerCaseAndShortened {
  return [[[self uuidString] lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
}

#pragma mark - Feedback Modal UI

- (UIImage *)screenshot {
  return bit_screenshot();
}

- (BITFeedbackListViewController *)feedbackListViewController:(BOOL)modal {
  if ([self isPreiOS7Environment]) {
    return [[BITFeedbackListViewController alloc] initWithModalStyle:modal];
  } else {
    return [[BITFeedbackListViewController alloc] initWithStyle:UITableViewStyleGrouped modal:modal];
  }
}

- (void)showFeedbackListView {
  if (_currentFeedbackListViewController) {
    BITHockeyLog(@"INFO: update view already visible, aborting");
    return;
  }
  
  [self showView:[self feedbackListViewController:YES]];
}


- (BITFeedbackComposeViewController *)feedbackComposeViewController {
  BITFeedbackComposeViewController *composeViewController = [[BITFeedbackComposeViewController alloc] init];
  [composeViewController prepareWithItems:self.feedbackComposerPreparedItems];
    
  // by default set the delegate to be identical to the one of BITFeedbackManager
  [composeViewController setDelegate:self.delegate];
  return composeViewController;
}

- (void)showFeedbackComposeView {
  [self showFeedbackComposeViewWithPreparedItems:nil];
}

- (void)showFeedbackComposeViewWithPreparedItems:(NSArray *)items{
  if (_currentFeedbackComposeViewController) {
    BITHockeyLog(@"INFO: update view already visible, aborting");
    return;
  }
  BITFeedbackComposeViewController *composeView = [self feedbackComposeViewController];
  [composeView prepareWithItems:items];
  
  [self showView:composeView];
  
}

- (void)showFeedbackComposeViewWithGeneratedScreenshot {
  UIImage *screenshot = bit_screenshot();
  [self showFeedbackComposeViewWithPreparedItems:@[screenshot]];
}

#pragma mark - Manager Control

- (void)startManager {
  if ([self isFeedbackManagerDisabled]) return;
  
  [self registerObservers];
  
  // we are already delayed, so the notification already came in and this won't invoked twice
  switch ([[UIApplication sharedApplication] applicationState]) {
    case UIApplicationStateActive:
      // we did startup, so yes we are coming from background
      _didEnterBackgroundState = YES;
      
      [self didBecomeActiveActions];
      break;
    case UIApplicationStateBackground:
    case UIApplicationStateInactive:
      // do nothing, wait for active state
      break;
  }
}

- (void)updateMessagesList {
  if (_networkRequestInProgress) return;
  
  NSArray *pendingMessages = [self messagesWithStatus:BITFeedbackMessageStatusSendPending];
  if ([pendingMessages count] > 0) {
    [self submitPendingMessages];
  } else {
    [self fetchMessageUpdates];
  }
}

- (void)updateMessagesListIfRequired {
  double now = [[NSDate date] timeIntervalSince1970];
  if ((now - [_lastCheck timeIntervalSince1970] > 30)) {
    [self updateMessagesList];
  }
}

- (BOOL)updateUserIDUsingKeychainAndDelegate {
  BOOL availableViaDelegate = NO;
  
  NSString *userID = [self stringValueFromKeychainForKey:kBITHockeyMetaUserID];
  
  if ([BITHockeyManager sharedHockeyManager].delegate &&
      [[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(userIDForHockeyManager:componentManager:)]) {
    userID = [[BITHockeyManager sharedHockeyManager].delegate
              userIDForHockeyManager:[BITHockeyManager sharedHockeyManager]
              componentManager:self];
  }
  
  if (userID) {
    availableViaDelegate = YES;
    self.userID = userID;
  }
  
  return availableViaDelegate;
}

- (BOOL)updateUserNameUsingKeychainAndDelegate {
  BOOL availableViaDelegate = NO;
  
  NSString *userName = [self stringValueFromKeychainForKey:kBITHockeyMetaUserName];
  
  if ([BITHockeyManager sharedHockeyManager].delegate &&
      [[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(userNameForHockeyManager:componentManager:)]) {
    userName = [[BITHockeyManager sharedHockeyManager].delegate
                userNameForHockeyManager:[BITHockeyManager sharedHockeyManager]
                componentManager:self];
  }
  
  if (userName) {
    availableViaDelegate = YES;
    self.userName = userName;
    self.requireUserName = BITFeedbackUserDataElementDontShow;
  }
  
  return availableViaDelegate;
}

- (BOOL)updateUserEmailUsingKeychainAndDelegate {
  BOOL availableViaDelegate = NO;
  
  NSString *userEmail = [self stringValueFromKeychainForKey:kBITHockeyMetaUserEmail];
  
  if ([BITHockeyManager sharedHockeyManager].delegate &&
      [[BITHockeyManager sharedHockeyManager].delegate respondsToSelector:@selector(userEmailForHockeyManager:componentManager:)]) {
    userEmail = [[BITHockeyManager sharedHockeyManager].delegate
                 userEmailForHockeyManager:[BITHockeyManager sharedHockeyManager]
                 componentManager:self];
  }
  
  if (userEmail) {
    availableViaDelegate = YES;
    self.userEmail = userEmail;
    self.requireUserEmail = BITFeedbackUserDataElementDontShow;
  }
  
  return availableViaDelegate;
}

- (void)updateAppDefinedUserData {
  [self updateUserIDUsingKeychainAndDelegate];
  [self updateUserNameUsingKeychainAndDelegate];
  [self updateUserEmailUsingKeychainAndDelegate];
  
  // if both values are shown via the delegates, we never ever did ask and will never ever ask for user data
  if (self.requireUserName == BITFeedbackUserDataElementDontShow &&
      self.requireUserEmail == BITFeedbackUserDataElementDontShow) {
    self.didAskUserData = NO;
  }
}

#pragma mark - Local Storage

- (void)loadMessages {
  BOOL userIDViaDelegate = [self updateUserIDUsingKeychainAndDelegate];
  BOOL userNameViaDelegate = [self updateUserNameUsingKeychainAndDelegate];
  BOOL userEmailViaDelegate = [self updateUserEmailUsingKeychainAndDelegate];
  
  if (![_fileManager fileExistsAtPath:_settingsFile])
    return;
  
  NSData *codedData = [[NSData alloc] initWithContentsOfFile:_settingsFile];
  if (codedData == nil) return;
  
  NSKeyedUnarchiver *unarchiver = nil;
  
  @try {
    unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:codedData];
  }
  @catch (NSException *exception) {
    return;
  }
  
  if (!userIDViaDelegate) {
    if ([unarchiver containsValueForKey:kBITFeedbackUserID]) {
      self.userID = [unarchiver decodeObjectForKey:kBITFeedbackUserID];
      [self addStringValueToKeychain:self.userID forKey:kBITFeedbackUserID];
    }
    self.userID = [self stringValueFromKeychainForKey:kBITFeedbackUserID];
  }
  
  if (!userNameViaDelegate) {
    if ([unarchiver containsValueForKey:kBITFeedbackName]) {
      self.userName = [unarchiver decodeObjectForKey:kBITFeedbackName];
      [self addStringValueToKeychain:self.userName forKey:kBITFeedbackName];
    }
    self.userName = [self stringValueFromKeychainForKey:kBITFeedbackName];
  }
  
  if (!userEmailViaDelegate) {
    if ([unarchiver containsValueForKey:kBITFeedbackEmail]) {
      self.userEmail = [unarchiver decodeObjectForKey:kBITFeedbackEmail];
      [self addStringValueToKeychain:self.userEmail forKey:kBITFeedbackEmail];
    }
    self.userEmail = [self stringValueFromKeychainForKey:kBITFeedbackEmail];
  }
  
  if ([unarchiver containsValueForKey:kBITFeedbackUserDataAsked])
    _didAskUserData = YES;
  
  if ([unarchiver containsValueForKey:kBITFeedbackToken]) {
    self.token = [unarchiver decodeObjectForKey:kBITFeedbackToken];
    [self addStringValueToKeychain:self.token forKey:kBITFeedbackToken];
  }
  self.token = [self stringValueFromKeychainForKey:kBITFeedbackToken];
  
  if ([unarchiver containsValueForKey:kBITFeedbackAppID]) {
    NSString *appID = [unarchiver decodeObjectForKey:kBITFeedbackAppID];
    
    // the stored thread is from another application identifier, so clear the token
    // which will cause the new posts to create a new thread on the server for the
    // current app identifier
    if ([appID compare:self.appIdentifier] != NSOrderedSame) {
      self.token = nil;
    }
  }
  
  if ([unarchiver containsValueForKey:kBITFeedbackDateOfLastCheck])
    self.lastCheck = [unarchiver decodeObjectForKey:kBITFeedbackDateOfLastCheck];
  
  if ([unarchiver containsValueForKey:kBITFeedbackLastMessageID])
    self.lastMessageID = [unarchiver decodeObjectForKey:kBITFeedbackLastMessageID];
  
  if ([unarchiver containsValueForKey:kBITFeedbackMessages]) {
    [self.feedbackList setArray:[unarchiver decodeObjectForKey:kBITFeedbackMessages]];
    
    [self sortFeedbackList];
    
    // inform the UI to update its data in case the list is already showing
    [[NSNotificationCenter defaultCenter] postNotificationName:BITHockeyFeedbackMessagesLoadingFinished object:nil];
  }
  
  [unarchiver finishDecoding];
  
  if (!self.lastCheck) {
    self.lastCheck = [NSDate distantPast];
  }
}


- (void)saveMessages {
  [self sortFeedbackList];
  
  NSMutableData *data = [[NSMutableData alloc] init];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
  
  if (_didAskUserData)
    [archiver encodeObject:[NSNumber numberWithBool:YES] forKey:kBITFeedbackUserDataAsked];
  
  if (self.token)
    [self addStringValueToKeychain:self.token forKey:kBITFeedbackToken];
  
  if (self.appIdentifier)
    [archiver encodeObject:self.appIdentifier forKey:kBITFeedbackAppID];
  
  if (self.userID)
    [self addStringValueToKeychain:self.userID forKey:kBITFeedbackUserID];
  
  if (self.userName)
    [self addStringValueToKeychain:self.userName forKey:kBITFeedbackName];
  
  if (self.userEmail)
    [self addStringValueToKeychain:self.userEmail forKey:kBITFeedbackEmail];
  
  if (self.lastCheck)
    [archiver encodeObject:self.lastCheck forKey:kBITFeedbackDateOfLastCheck];
  
  if (self.lastMessageID)
    [archiver encodeObject:self.lastMessageID forKey:kBITFeedbackLastMessageID];
  
  [archiver encodeObject:self.feedbackList forKey:kBITFeedbackMessages];
  
  [archiver finishEncoding];
  [data writeToFile:_settingsFile atomically:YES];
}


- (void)updateDidAskUserData {
  if (!_didAskUserData) {
    _didAskUserData = YES;
    
    [self saveMessages];
  }
}

#pragma mark - Messages

- (void)sortFeedbackList {
  [_feedbackList sortUsingComparator:^(BITFeedbackMessage *obj1, BITFeedbackMessage *obj2) {
    NSDate *date1 = [obj1 date];
    NSDate *date2 = [obj2 date];
    
    // not send, in conflict and send in progress messages on top, sorted by date
    // read and unread on bottom, sorted by date
    // archived on the very bottom
    
    if ([obj1 status] >= BITFeedbackMessageStatusSendInProgress && [obj2 status] < BITFeedbackMessageStatusSendInProgress) {
      return NSOrderedDescending;
    } else if ([obj1 status] < BITFeedbackMessageStatusSendInProgress && [obj2 status] >= BITFeedbackMessageStatusSendInProgress) {
      return NSOrderedAscending;
    } else if ([obj1 status] == BITFeedbackMessageStatusArchived && [obj2 status] < BITFeedbackMessageStatusArchived) {
      return NSOrderedDescending;
    } else if ([obj1 status] < BITFeedbackMessageStatusArchived && [obj2 status] == BITFeedbackMessageStatusArchived) {
      return NSOrderedAscending;
    } else {
      return (NSInteger)[date2 compare:date1];
    }
  }];
}

- (NSUInteger)numberOfMessages {
  return [_feedbackList count];
}

- (BITFeedbackMessage *)messageAtIndex:(NSUInteger)index {
  if ([_feedbackList count] > index) {
    return [_feedbackList objectAtIndex:index];
  }
  
  return nil;
}

- (BITFeedbackMessage *)messageWithID:(NSNumber *)messageID {
  __block BITFeedbackMessage *message = nil;
  
  [_feedbackList enumerateObjectsUsingBlock:^(BITFeedbackMessage *objMessage, NSUInteger messagesIdx, BOOL *stop) {
    if ([[objMessage identifier] isEqualToNumber:messageID]) {
      message = objMessage;
      *stop = YES;
    }
  }];
  
  return message;
}

- (NSArray *)messagesWithStatus:(BITFeedbackMessageStatus)status {
  NSMutableArray *resultMessages = [[NSMutableArray alloc] initWithCapacity:[_feedbackList count]];
  
  [_feedbackList enumerateObjectsUsingBlock:^(BITFeedbackMessage *objMessage, NSUInteger messagesIdx, BOOL *stop) {
    if ([objMessage status] == status) {
      [resultMessages addObject: objMessage];
    }
  }];
  
  return [NSArray arrayWithArray:resultMessages];;
}

- (BITFeedbackMessage *)lastMessageHavingID {
  __block BITFeedbackMessage *message = nil;
  
  [_feedbackList enumerateObjectsUsingBlock:^(BITFeedbackMessage *objMessage, NSUInteger messagesIdx, BOOL *stop) {
    if ([[objMessage identifier] integerValue] != 0) {
      message = objMessage;
      *stop = YES;
    }
  }];
  
  return message;
}

- (void)markSendInProgressMessagesAsPending {
  // make sure message that may have not been send successfully, get back into the right state to be send again
  [_feedbackList enumerateObjectsUsingBlock:^(id objMessage, NSUInteger messagesIdx, BOOL *stop) {
    if ([(BITFeedbackMessage *)objMessage status] == BITFeedbackMessageStatusSendInProgress)
      [(BITFeedbackMessage *)objMessage setStatus:BITFeedbackMessageStatusSendPending];
  }];
}

- (void)markSendInProgressMessagesAsInConflict {
  // make sure message that may have not been send successfully, get back into the right state to be send again
  [_feedbackList enumerateObjectsUsingBlock:^(id objMessage, NSUInteger messagesIdx, BOOL *stop) {
    if ([(BITFeedbackMessage *)objMessage status] == BITFeedbackMessageStatusSendInProgress)
      [(BITFeedbackMessage *)objMessage setStatus:BITFeedbackMessageStatusInConflict];
  }];
}

- (void)updateLastMessageID {
  BITFeedbackMessage *lastMessageHavingID = [self lastMessageHavingID];
  if (lastMessageHavingID) {
    if (!self.lastMessageID || [self.lastMessageID compare:[lastMessageHavingID identifier]] != NSOrderedSame)
      self.lastMessageID = [lastMessageHavingID identifier];
  }
}

- (BOOL)deleteMessageAtIndex:(NSUInteger)index {
  if (_feedbackList && [_feedbackList count] > index && [_feedbackList objectAtIndex:index]) {
    BITFeedbackMessage *message = _feedbackList[index];
    [message deleteContents];
    [_feedbackList removeObjectAtIndex:index];
    
    [self saveMessages];
    return YES;
  }
  
  return NO;
}

- (void)deleteAllMessages {
  [_feedbackList removeAllObjects];
  
  [self saveMessages];
}


#pragma mark - User

- (BOOL)askManualUserDataAvailable {
  [self updateAppDefinedUserData];
  
  if (self.requireUserName == BITFeedbackUserDataElementDontShow &&
      self.requireUserEmail == BITFeedbackUserDataElementDontShow)
    return NO;
  
  return YES;
}

- (BOOL)requireManualUserDataMissing {
  [self updateAppDefinedUserData];
  
  if (self.requireUserName == BITFeedbackUserDataElementRequired && !self.userName)
    return YES;
  
  if (self.requireUserEmail == BITFeedbackUserDataElementRequired && !self.userEmail)
    return YES;
  
  return NO;
}

- (BOOL)isManualUserDataAvailable {
  [self updateAppDefinedUserData];
  
  if ((self.requireUserName != BITFeedbackUserDataElementDontShow && self.userName) ||
      (self.requireUserEmail != BITFeedbackUserDataElementDontShow && self.userEmail))
    return YES;
  
  return NO;
}


#pragma mark - Networking

- (void)updateMessageListFromResponse:(NSDictionary *)jsonDictionary {
  if (!jsonDictionary) {
    // nil is used when the server returns 404, so we need to mark all existing threads as archives and delete the discussion token
    
    NSArray *messagesSendInProgress = [self messagesWithStatus:BITFeedbackMessageStatusSendInProgress];
    NSInteger pendingMessagesCount = [messagesSendInProgress count] + [[self messagesWithStatus:BITFeedbackMessageStatusSendPending] count];
    
    [self markSendInProgressMessagesAsPending];
    
    [_feedbackList enumerateObjectsUsingBlock:^(id objMessage, NSUInteger messagesIdx, BOOL *stop) {
      if ([(BITFeedbackMessage *)objMessage status] != BITFeedbackMessageStatusSendPending)
        [(BITFeedbackMessage *)objMessage setStatus:BITFeedbackMessageStatusArchived];
    }];
    
    if ([self token]) {
      self.token = nil;
    }
    
    NSInteger pendingMessagesCountAfterProcessing = [[self messagesWithStatus:BITFeedbackMessageStatusSendPending] count];
    
    [self saveMessages];
    
    // check if this request was successful and we have more messages pending and continue if positive
    if (pendingMessagesCount > pendingMessagesCountAfterProcessing && pendingMessagesCountAfterProcessing > 0) {
      [self performSelector:@selector(submitPendingMessages) withObject:nil afterDelay:0.1];
    }
    
    return;
  }
  
  NSDictionary *feedback = [jsonDictionary objectForKey:@"feedback"];
  NSString *token = [jsonDictionary objectForKey:@"token"];
  NSDictionary *feedbackObject = [jsonDictionary objectForKey:@"feedback"];
  if (feedback && token && feedbackObject) {
    // update the thread token, which is not available until the 1st message was successfully sent
    self.token = token;
    
    self.lastCheck = [NSDate date];
    
    // add all new messages
    NSArray *feedMessages = [feedbackObject objectForKey:@"messages"];
    
    // get the message that was currently sent if available
    NSArray *messagesSendInProgress = [self messagesWithStatus:BITFeedbackMessageStatusSendInProgress];
    
    NSInteger pendingMessagesCount = [messagesSendInProgress count] + [[self messagesWithStatus:BITFeedbackMessageStatusSendPending] count];
    
    __block BOOL newMessage = NO;
    NSMutableSet *returnedMessageIDs = [[NSMutableSet alloc] init];
    
    [feedMessages enumerateObjectsUsingBlock:^(id objMessage, NSUInteger messagesIdx, BOOL *stop) {
      if ([(NSDictionary *)objMessage objectForKey:@"id"]) {
        NSNumber *messageID = [(NSDictionary *)objMessage objectForKey:@"id"];
        [returnedMessageIDs addObject:messageID];
        
        BITFeedbackMessage *thisMessage = [self messageWithID:messageID];
        if (!thisMessage) {
          // check if this is a message that was sent right now
          __block BITFeedbackMessage *matchingSendInProgressOrInConflictMessage = nil;
          
          // TODO: match messages in state conflict
          
          [messagesSendInProgress enumerateObjectsUsingBlock:^(id objSendInProgressMessage, NSUInteger messagesSendInProgressIdx, BOOL *stop2) {
            if ([[(NSDictionary *)objMessage objectForKey:@"token"] isEqualToString:[(BITFeedbackMessage *)objSendInProgressMessage token]]) {
              matchingSendInProgressOrInConflictMessage = objSendInProgressMessage;
              *stop2 = YES;
            }
          }];
          
          if (matchingSendInProgressOrInConflictMessage) {
            matchingSendInProgressOrInConflictMessage.date = [self parseRFC3339Date:[(NSDictionary *)objMessage objectForKey:@"created_at"]];
            matchingSendInProgressOrInConflictMessage.identifier = messageID;
            matchingSendInProgressOrInConflictMessage.status = BITFeedbackMessageStatusRead;
            NSArray *feedbackAttachments =[(NSDictionary *)objMessage objectForKey:@"attachments"];
            if (matchingSendInProgressOrInConflictMessage.attachments.count == feedbackAttachments.count) {
              int attachmentIndex = 0;
              for (BITFeedbackMessageAttachment* attachment in matchingSendInProgressOrInConflictMessage.attachments){
                attachment.identifier =feedbackAttachments[attachmentIndex][@"id"];
                attachmentIndex++;
              }
            }
          } else {
            if ([(NSDictionary *)objMessage objectForKey:@"clean_text"] || [(NSDictionary *)objMessage objectForKey:@"text"] || [(NSDictionary *)objMessage objectForKey:@"attachments"]) {
              BITFeedbackMessage *message = [[BITFeedbackMessage alloc] init];
              message.text = [(NSDictionary *)objMessage objectForKey:@"clean_text"] ?: [(NSDictionary *)objMessage objectForKey:@"text"] ?: @"";
              message.name = [(NSDictionary *)objMessage objectForKey:@"name"] ?: @"";
              message.email = [(NSDictionary *)objMessage objectForKey:@"email"] ?: @"";
              
              message.date = [self parseRFC3339Date:[(NSDictionary *)objMessage objectForKey:@"created_at"]] ?: [NSDate date];
              message.identifier = [(NSDictionary *)objMessage objectForKey:@"id"];
              message.status = BITFeedbackMessageStatusUnread;
              
              for (NSDictionary *attachmentData in objMessage[@"attachments"]) {
                BITFeedbackMessageAttachment *newAttachment = [BITFeedbackMessageAttachment new];
                newAttachment.originalFilename = attachmentData[@"file_name"];
                newAttachment.identifier = attachmentData[@"id"];
                newAttachment.sourceURL = attachmentData[@"url"];
                newAttachment.contentType = attachmentData[@"content_type"];
                [message addAttachmentsObject:newAttachment];
              }
              
              [_feedbackList addObject:message];
              
              newMessage = YES;
            }
          }
        } else {
          // we should never get any messages back that are already stored locally,
          // since we add the last_message_id to the request
        }
      }
    }];
    
    [self markSendInProgressMessagesAsPending];
    
    [self sortFeedbackList];
    [self updateLastMessageID];
    
    // we got a new incoming message, trigger user notification system
    if (newMessage) {
      // check if the latest message is from the users own email address, then don't show an alert since he answered using his own email
      BOOL latestMessageFromUser = NO;
      
      BITFeedbackMessage *latestMessage = [self lastMessageHavingID];
      if (self.userEmail && latestMessage.email && [self.userEmail compare:latestMessage.email] == NSOrderedSame)
        latestMessageFromUser = YES;
      
      if (!latestMessageFromUser) {
        if([self.delegate respondsToSelector:@selector(feedbackManagerDidReceiveNewFeedback:)]) {
          [self.delegate feedbackManagerDidReceiveNewFeedback:self];
        }
        
        if(self.showAlertOnIncomingMessages && !self.currentFeedbackListViewController && !self.currentFeedbackComposeViewController) {
          UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackNewMessageTitle")
                                                              message:BITHockeyLocalizedString(@"HockeyFeedbackNewMessageText")
                                                             delegate:self
                                                    cancelButtonTitle:BITHockeyLocalizedString(@"HockeyFeedbackIgnore")
                                                    otherButtonTitles:BITHockeyLocalizedString(@"HockeyFeedbackShow"), nil
                                    ];
          [alertView setTag:0];
          [alertView show];
          _incomingMessagesAlertShowing = YES;
        }
      }
    }
    
    NSInteger pendingMessagesCountAfterProcessing = [[self messagesWithStatus:BITFeedbackMessageStatusSendPending] count];
    
    // check if this request was successful and we have more messages pending and continue if positive
    if (pendingMessagesCount > pendingMessagesCountAfterProcessing && pendingMessagesCountAfterProcessing > 0) {
      [self performSelector:@selector(submitPendingMessages) withObject:nil afterDelay:0.1];
    }
    
  } else {
    [self markSendInProgressMessagesAsPending];
  }
  
  [self saveMessages];
  
  return;
}


- (void)sendNetworkRequestWithHTTPMethod:(NSString *)httpMethod withMessage:(BITFeedbackMessage *)message completionHandler:(void (^)(NSError *err))completionHandler {
  NSString *boundary = @"----FOO";
  
  _networkRequestInProgress = YES;
  // inform the UI to update its data in case the list is already showing
  [[NSNotificationCenter defaultCenter] postNotificationName:BITHockeyFeedbackMessagesLoadingStarted object:nil];
  
  NSString *tokenParameter = @"";
  if ([self token]) {
    tokenParameter = [NSString stringWithFormat:@"/%@", [self token]];
  }
  NSMutableString *parameter = [NSMutableString stringWithFormat:@"api/2/apps/%@/feedback%@", [self encodedAppIdentifier], tokenParameter];
  
  NSString *lastMessageID = @"";
  if (!self.lastMessageID) {
    [self updateLastMessageID];
  }
  if (self.lastMessageID) {
    lastMessageID = [NSString stringWithFormat:@"&last_message_id=%li", (long)[self.lastMessageID integerValue]];
  }
  
  [parameter appendFormat:@"?format=json&bundle_version=%@&sdk=%@&sdk_version=%@%@",
   bit_URLEncodedString([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]),
   BITHOCKEY_NAME,
   BITHOCKEY_VERSION,
   lastMessageID
   ];
  
  // build request & send
  NSString *url = [NSString stringWithFormat:@"%@%@", self.serverURL, parameter];
  BITHockeyLog(@"INFO: sending api request to %@", url);
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:1 timeoutInterval:10.0];
  [request setHTTPMethod:httpMethod];
  [request setValue:@"Hockey/iOS" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  
  if (message) {
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField:@"Content-type"];
    
    NSMutableData *postBody = [NSMutableData data];
    
    [postBody appendData:[BITHockeyAppClient dataWithPostValue:@"Apple" forKey:@"oem" boundary:boundary]];
    [postBody appendData:[BITHockeyAppClient dataWithPostValue:[[UIDevice currentDevice] systemVersion] forKey:@"os_version" boundary:boundary]];
    [postBody appendData:[BITHockeyAppClient dataWithPostValue:[self getDevicePlatform] forKey:@"model" boundary:boundary]];
    [postBody appendData:[BITHockeyAppClient dataWithPostValue:[[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0] forKey:@"lang" boundary:boundary]];
    [postBody appendData:[BITHockeyAppClient dataWithPostValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] forKey:@"bundle_version" boundary:boundary]];
    [postBody appendData:[BITHockeyAppClient dataWithPostValue:[message text] forKey:@"text" boundary:boundary]];
    [postBody appendData:[BITHockeyAppClient dataWithPostValue:[message token] forKey:@"message_token" boundary:boundary]];
    
    NSString *installString = bit_appAnonID();
    if (installString) {
      [postBody appendData:[BITHockeyAppClient dataWithPostValue:installString forKey:@"install_string" boundary:boundary]];
    }
    
    if (self.userID) {
      [postBody appendData:[BITHockeyAppClient dataWithPostValue:self.userID forKey:@"user_string" boundary:boundary]];
    }
    if (self.userName) {
      [postBody appendData:[BITHockeyAppClient dataWithPostValue:self.userName forKey:@"name" boundary:boundary]];
    }
    if (self.userEmail) {
      [postBody appendData:[BITHockeyAppClient dataWithPostValue:self.userEmail forKey:@"email" boundary:boundary]];
    }
    
    
    NSInteger photoIndex = 0;
    
    for (BITFeedbackMessageAttachment *attachment in message.attachments){
      NSString *key = [NSString stringWithFormat:@"attachment%ld", (long)photoIndex];
      
      NSString *filename = attachment.originalFilename;
      
      if (!filename) {
        filename = [NSString stringWithFormat:@"Attachment %ld", (long)photoIndex];
      }
      
      [postBody appendData:[BITHockeyAppClient dataWithPostValue:attachment.data forKey:key contentType:attachment.contentType boundary:boundary filename:filename]];
      
      photoIndex++;
    }
    
    [postBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    
    [request setHTTPBody:postBody];
  }
  
  [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *responseData, NSError *err) {
    _networkRequestInProgress = NO;
    
    if (err) {
      [self reportError:err];
      [self markSendInProgressMessagesAsPending];
      completionHandler(err);
    } else {
      NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
      if (statusCode == 404) {
        // thread has been deleted, we archive it
        [self updateMessageListFromResponse:nil];
      } else if (statusCode == 409) {
        // we submitted a message that is already on the server, mark it as being in conflict and resolve it with another fetch
        
        if (!self.token) {
          // set the token to the first message token, since this is identical
          __block NSString *token = nil;
          
          [_feedbackList enumerateObjectsUsingBlock:^(id objMessage, NSUInteger messagesIdx, BOOL *stop) {
            if ([(BITFeedbackMessage *)objMessage status] == BITFeedbackMessageStatusSendInProgress) {
              token = [(BITFeedbackMessage *)objMessage token];
              *stop = YES;
            }
          }];
          
          if (token) {
            self.token = token;
          }
        }
        
        [self markSendInProgressMessagesAsInConflict];
        [self saveMessages];
        [self performSelector:@selector(fetchMessageUpdates) withObject:nil afterDelay:0.2];
      } else if ([responseData length]) {
        NSString *responseString = [[NSString alloc] initWithBytes:[responseData bytes] length:[responseData length] encoding: NSUTF8StringEncoding];
        BITHockeyLog(@"INFO: Received API response: %@", responseString);
        
        if (responseString && [responseString dataUsingEncoding:NSUTF8StringEncoding]) {
          NSError *error = NULL;
          
          NSDictionary *feedDict = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
          
          // server returned empty response?
          if (error) {
            [self reportError:error];
          } else if (![feedDict count]) {
            [self reportError:[NSError errorWithDomain:kBITFeedbackErrorDomain
                                                  code:BITFeedbackAPIServerReturnedEmptyResponse
                                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Server returned empty response.", NSLocalizedDescriptionKey, nil]]];
          } else {
            BITHockeyLog(@"INFO: Received API response: %@", responseString);
            NSString *status = [feedDict objectForKey:@"status"];
            if ([status compare:@"success"] != NSOrderedSame) {
              [self reportError:[NSError errorWithDomain:kBITFeedbackErrorDomain
                                                    code:BITFeedbackAPIServerReturnedInvalidStatus
                                                userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Server returned invalid status.", NSLocalizedDescriptionKey, nil]]];
            } else {
              [self updateMessageListFromResponse:feedDict];
            }
          }
        }
      }
      
      [self markSendInProgressMessagesAsPending];
      completionHandler(err);
    }
  }];
}

- (void)fetchMessageUpdates {
  if ([_feedbackList count] == 0 && !self.token) {
    // inform the UI to update its data in case the list is already showing
    [[NSNotificationCenter defaultCenter] postNotificationName:BITHockeyFeedbackMessagesLoadingFinished object:nil];
    
    return;
  }
  
  [self sendNetworkRequestWithHTTPMethod:@"GET"
                             withMessage:nil
                       completionHandler:^(NSError *err){
                         // inform the UI to update its data in case the list is already showing
                         [[NSNotificationCenter defaultCenter] postNotificationName:BITHockeyFeedbackMessagesLoadingFinished object:nil];
                       }];
}

- (void)submitPendingMessages {
  if (_networkRequestInProgress) {
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(submitPendingMessages) object:nil];
    [self performSelector:@selector(submitPendingMessages) withObject:nil afterDelay:2.0f];
    return;
  }
  
  // app defined user data may have changed, update it
  [self updateAppDefinedUserData];
  [self saveMessages];
  
  NSArray *pendingMessages = [self messagesWithStatus:BITFeedbackMessageStatusSendPending];
  
  if ([pendingMessages count] > 0) {
    // we send one message at a time
    BITFeedbackMessage *messageToSend = [pendingMessages objectAtIndex:0];
    
    [messageToSend setStatus:BITFeedbackMessageStatusSendInProgress];
    if (self.userID)
      [messageToSend setUserID:self.userID];
    if (self.userName)
      [messageToSend setName:self.userName];
    if (self.userEmail)
      [messageToSend setEmail:self.userEmail];
    
    NSString *httpMethod = @"POST";
    if ([self token]) {
      httpMethod = @"PUT";
    }
    
    [self sendNetworkRequestWithHTTPMethod:httpMethod
                               withMessage:messageToSend
                         completionHandler:^(NSError *err){
                           if (err) {
                             [self markSendInProgressMessagesAsPending];
                             [self saveMessages];
                           }
                           
                           // inform the UI to update its data in case the list is already showing
                           [[NSNotificationCenter defaultCenter] postNotificationName:BITHockeyFeedbackMessagesLoadingFinished object:nil];
                         }];
  }
}

- (void)submitMessageWithText:(NSString *)text andAttachments:(NSArray *)attachments {
  BITFeedbackMessage *message = [[BITFeedbackMessage alloc] init];
  message.text = text;
  [message setStatus:BITFeedbackMessageStatusSendPending];
  [message setToken:[self uuidAsLowerCaseAndShortened]];
  [message setAttachments:attachments];
  [message setUserMessage:YES];
  
  [_feedbackList addObject:message];
  
  [self submitPendingMessages];
}


#pragma mark - UIAlertViewDelegate

// invoke the selected action from the action sheet for a location element
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
  
  _incomingMessagesAlertShowing = NO;
  if (buttonIndex == [alertView firstOtherButtonIndex]) {
    // Show button has been clicked
    [self showFeedbackListView];
  }
}

#pragma mark - Observation Handling

- (void)setFeedbackObservationMode:(BITFeedbackObservationMode)feedbackObservationMode {
  if (feedbackObservationMode != _feedbackObservationMode) {
    _feedbackObservationMode = feedbackObservationMode;
    
    if (feedbackObservationMode == BITFeedbackObservationModeOnScreenshot){
      if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenshotNotificationReceived:) name:UIApplicationUserDidTakeScreenshotNotification object:nil];
      } else {
        BITHockeyLog("WARNING: BITFeedbackObservationModeOnScreenshot requires iOS 7 or later.");
      }
      
      self.screenshotNotificationEnabled = YES;
      
      if (self.tapRecognizer){
        [[[UIApplication sharedApplication] keyWindow] removeGestureRecognizer:self.tapRecognizer];
        self.tapRecognizer = nil;
      }
    }
    
    if (feedbackObservationMode == BITFeedbackObservationModeThreeFingerTap){
      if (!self.tapRecognizer){
        self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(screenshotTripleTap:)];
        self.tapRecognizer.numberOfTouchesRequired = 3;
        self.tapRecognizer.delegate = self;
        
        dispatch_async(dispatch_get_main_queue(), ^{
          if (self.tapRecognizer) {
            [[UIApplication sharedApplication].keyWindow addGestureRecognizer:self.tapRecognizer];
          }
        });
      }
      
      if (self.screenshotNotificationEnabled){
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1){
          [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationUserDidTakeScreenshotNotification object:nil];
          self.screenshotNotificationEnabled = NO;
        }
      }
    }
  }
}

-(void)screenshotNotificationReceived:(NSNotification *)notification {
  double amountOfSeconds = 0.5;
  dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(amountOfSeconds * NSEC_PER_SEC));
  
  dispatch_after(delayTime, dispatch_get_main_queue(), ^{
    [self extractLastPictureFromLibraryAndLaunchFeedback];
  });
}

-(void)extractLastPictureFromLibraryAndLaunchFeedback {
  ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
  
  [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
    
    [group setAssetsFilter:[ALAssetsFilter allPhotos]];
    
    [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *alAsset, NSUInteger index, BOOL *innerStop) {
      
      if (alAsset) {
        ALAssetRepresentation *representation = [alAsset defaultRepresentation];
        UIImage *latestPhoto = [UIImage imageWithCGImage:[representation fullScreenImage]];
        
        *stop = YES;
        *innerStop = YES;
        
        [self showFeedbackComposeViewWithPreparedItems:@[latestPhoto]];
      }
    }];
  } failureBlock: nil];
}

- (void)screenshotTripleTap:(UITapGestureRecognizer *)tapRecognizer {
  if (tapRecognizer.state == UIGestureRecognizerStateRecognized){
    [self showFeedbackComposeViewWithGeneratedScreenshot];
  }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
  return YES;
}

@end



#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
