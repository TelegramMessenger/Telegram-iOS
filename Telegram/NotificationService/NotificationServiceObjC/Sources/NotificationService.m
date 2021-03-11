#import <NotificationServiceObjC/NotificationServiceObjC.h>

#import <mach/mach.h>

#import <UIKit/UIKit.h>
#import <BuildConfig/BuildConfig.h>

#ifdef __IPHONE_13_0
#import <BackgroundTasks/BackgroundTasks.h>
#endif

#import "StoredAccountInfos.h"
#import "Attachments.h"
#import "Api.h"
#import "FetchImage.h"

static NSData * _Nullable parseBase64(NSString *string) {
    string = [string stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    string = [string stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    while (string.length % 4 != 0) {
        string = [string stringByAppendingString:@"="];
    }
    return [[NSData alloc] initWithBase64EncodedString:string options:0];
}

typedef enum {
    PeerNamespaceCloudUser = 0,
    PeerNamespaceCloudGroup = 1,
    PeerNamespaceCloudChannel = 2,
    PeerNamespaceSecretChat = 3
} PeerNamespace;

static int64_t makePeerId(int32_t namespace, int32_t value) {
    return (((int64_t)(namespace)) << 32) | ((int64_t)((uint64_t)((uint32_t)value)));
}

#if DEBUG
static void reportMemory() {
    struct task_basic_info info;
    mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    if (kerr == KERN_SUCCESS) {
        NSLog(@"Memory in use (in bytes): %lu", info.resident_size);
        NSLog(@"Memory in use (in MiB): %f", ((CGFloat)info.resident_size / 1048576));
    } else {
        NSLog(@"Error with task_info(): %s", mach_error_string(kerr));
    }
}
#endif

@interface NotificationServiceImpl () {
    void (^_serialDispatch)(dispatch_block_t);
    void (^_countIncomingMessage)(NSString *, int64_t, DeviceSpecificEncryptionParameters *, int64_t, int32_t);
    
    NSString * _Nullable _rootPath;
    DeviceSpecificEncryptionParameters * _Nullable _deviceSpecificEncryptionParameters;
    bool _isLockedValue;
    NSString *_lockedMessageTextValue;
    NSString * _Nullable _baseAppBundleId;
    void (^_contentHandler)(UNNotificationContent *);
    UNMutableNotificationContent * _Nullable _bestAttemptContent;
    void (^_cancelFetch)(void);
    
    NSNumber * _Nullable _updatedUnreadCount;
    bool _contentReady;
}

@end

@implementation NotificationServiceImpl

- (instancetype)initWithSerialDispatch:(void (^)(dispatch_block_t))serialDispatch countIncomingMessage:(void (^)(NSString *, int64_t, DeviceSpecificEncryptionParameters *, int64_t, int32_t))countIncomingMessage isLocked:(nonnull bool (^)(NSString * _Nonnull))isLocked lockedMessageText:(NSString *(^)(NSString *))lockedMessageText {
    self = [super init];
    if (self != nil) {
        #if DEBUG
        reportMemory();
        #endif
        
        _serialDispatch = [serialDispatch copy];
        _countIncomingMessage = [countIncomingMessage copy];
        
        NSString *appBundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
        NSRange lastDotRange = [appBundleIdentifier rangeOfString:@"." options:NSBackwardsSearch];
        if (lastDotRange.location != NSNotFound) {
            _baseAppBundleId = [appBundleIdentifier substringToIndex:lastDotRange.location];
            NSString *appGroupName = [@"group." stringByAppendingString:_baseAppBundleId];
            NSURL *appGroupUrl = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:appGroupName];
            
            if (appGroupUrl != nil) {
                NSString *rootPath = [[appGroupUrl path] stringByAppendingPathComponent:@"telegram-data"];
                _rootPath = rootPath;
                if (rootPath != nil) {
                    _deviceSpecificEncryptionParameters = [BuildConfig deviceSpecificEncryptionParameters:rootPath baseAppBundleId:_baseAppBundleId];
                    
                    _isLockedValue = isLocked(rootPath);
                    if (_isLockedValue) {
                        _lockedMessageTextValue = lockedMessageText(rootPath);
                    }
                }
            } else {
                NSAssert(false, @"appGroupUrl == nil");
            }
        } else {
            NSAssert(false, @"Invalid bundle id");
        }
    }
    return self;
}

- (void)completeWithBestAttemptContent {
    _contentReady = true;
    _updatedUnreadCount = @(-1);
    if (_contentReady && _updatedUnreadCount) {
        [self _internalComplete];
    }
}

- (void)updateUnreadCount:(int32_t)unreadCount {
    _updatedUnreadCount = @(unreadCount);
    if (_contentReady && _updatedUnreadCount) {
        [self _internalComplete];
    }
}
 
- (void)_internalComplete {
    #if DEBUG
    reportMemory();
    #endif
    
    NSString *baseAppBundleId = _baseAppBundleId;
    void (^contentHandler)(UNNotificationContent *) = [_contentHandler copy];
    UNMutableNotificationContent *bestAttemptContent = _bestAttemptContent;
    NSNumber *updatedUnreadCount = updatedUnreadCount;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        #ifdef __IPHONE_13_0
        if (baseAppBundleId != nil && false) {
            BGAppRefreshTaskRequest *request = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:[baseAppBundleId stringByAppendingString:@".refresh"]];
            request.earliestBeginDate = nil;
            NSError *error = nil;
            [[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error];
            if (error != nil) {
                NSLog(@"Error: %@", error);
            }
        }
        #endif
        
        if (updatedUnreadCount != nil) {
            int32_t unreadCount = (int32_t)[updatedUnreadCount intValue];
            if (unreadCount > 0) {
                bestAttemptContent.badge = @(unreadCount);
            }
        }
        contentHandler(bestAttemptContent);
    });
}

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    if (_rootPath == nil) {
        _bestAttemptContent = (UNMutableNotificationContent *)[request.content mutableCopy];
        [self completeWithBestAttemptContent];
        return;
    }
    
    _contentHandler = [contentHandler copy];
    _bestAttemptContent = (UNMutableNotificationContent *)[request.content mutableCopy];
    
    NSString * _Nullable encryptedPayload = request.content.userInfo[@"p"];
    NSData * _Nullable encryptedData = nil;
    if (encryptedPayload != nil && [encryptedPayload isKindOfClass:[NSString class]]) {
        encryptedData = parseBase64(encryptedPayload);
    }
    
    StoredAccountInfos * _Nullable accountInfos = [StoredAccountInfos loadFromPath:[_rootPath stringByAppendingPathComponent:@"accounts-shared-data"]];
    
    int selectedAccountIndex = -1;
    NSDictionary *decryptedPayload = decryptedNotificationPayload(accountInfos.accounts, encryptedData, &selectedAccountIndex);
    
    if (decryptedPayload != nil && selectedAccountIndex != -1) {
        StoredAccountInfo *account = accountInfos.accounts[selectedAccountIndex];
        
        NSMutableDictionary *userInfo = nil;
        if (_bestAttemptContent.userInfo != nil) {
            userInfo = [[NSMutableDictionary alloc] initWithDictionary:_bestAttemptContent.userInfo];
        } else {
            userInfo = [[NSMutableDictionary alloc] init];
        }
        userInfo[@"accountId"] = @(account.accountId);
        
        int64_t peerId = 0;
        int32_t messageId = 0;
        bool silent = false;
        
        NSString *messageIdString = decryptedPayload[@"msg_id"];
        if ([messageIdString isKindOfClass:[NSString class]]) {
            userInfo[@"msg_id"] = messageIdString;
            messageId = [messageIdString intValue];
        }
        
        NSString *fromIdString = decryptedPayload[@"from_id"];
        if ([fromIdString isKindOfClass:[NSString class]]) {
            userInfo[@"from_id"] = fromIdString;
            peerId = makePeerId(PeerNamespaceCloudUser, [fromIdString intValue]);
        }
        
        NSString *chatIdString = decryptedPayload[@"chat_id"];
        if ([chatIdString isKindOfClass:[NSString class]]) {
            userInfo[@"chat_id"] = chatIdString;
            peerId = makePeerId(PeerNamespaceCloudGroup, [chatIdString intValue]);
        }
        
        NSString *channelIdString = decryptedPayload[@"channel_id"];
        if ([channelIdString isKindOfClass:[NSString class]]) {
            userInfo[@"channel_id"] = channelIdString;
            peerId = makePeerId(PeerNamespaceCloudChannel, [channelIdString intValue]);
        }
        
        /*if (_countIncomingMessage && _deviceSpecificEncryptionParameters) {
            _countIncomingMessage(_rootPath, account.accountId, _deviceSpecificEncryptionParameters, peerId, messageId);
        }*/
        
        NSString *silentString = decryptedPayload[@"silent"];
        if ([silentString isKindOfClass:[NSString class]]) {
            silent = [silentString intValue] != 0;
        }
        
        NSData *attachmentData = nil;
        id parsedAttachment = nil;
        
        if (!_isLockedValue) {
            NSString *attachmentDataString = decryptedPayload[@"attachb64"];
            if ([attachmentDataString isKindOfClass:[NSString class]]) {
                attachmentData = parseBase64(attachmentDataString);
                if (attachmentData != nil) {
                    parsedAttachment = parseAttachment(attachmentData);
                }
            }
        }
        
        NSString *imagesPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"aps-data"];
        [[NSFileManager defaultManager] createDirectoryAtPath:imagesPath withIntermediateDirectories:true attributes:nil error:nil];
        NSString *accountBasePath = [_rootPath stringByAppendingPathComponent:[NSString stringWithFormat:@"account-%llud", account.accountId]];
        
        NSString *mediaBoxPath = [accountBasePath stringByAppendingPathComponent:@"/postbox/media"];
        
        NSString *tempImagePath = nil;
        NSString *mediaBoxThumbnailImagePath = nil;
        
        int32_t fileDatacenterId = 0;
        Api1_InputFileLocation *inputFileLocation = nil;
        int32_t progressiveFileLimit = -1;
        
        NSString *fetchResourceId = nil;
        bool isPng = false;
        bool isExpandableMedia = false;
        
        if (parsedAttachment != nil) {
            if ([parsedAttachment isKindOfClass:[Api1_Photo_photo class]]) {
                Api1_Photo_photo *photo = parsedAttachment;
                isExpandableMedia = true;
                
                /*for (id size in photo.sizes) {
                    if ([size isKindOfClass:[Api1_PhotoSize_photoSizeProgressive class]]) {
                        Api1_PhotoSize_photoSizeProgressive *sizeValue = size;
                        inputFileLocation = [Api1_InputFileLocation inputPhotoFileLocationWithPid:photo.pid accessHash:photo.accessHash fileReference:photo.fileReference thumbSize:sizeValue.type];
                        fileDatacenterId = [photo.dcId intValue];
                        fetchResourceId = [NSString stringWithFormat:@"telegram-cloud-photo-size-%@-%@-%@", photo.dcId, photo.pid, sizeValue.type];
                        break;
                    }
                }*/
                
                if (inputFileLocation == nil) {
                    for (id size in photo.sizes) {
                        if ([size isKindOfClass:[Api1_PhotoSize_photoSize class]]) {
                            Api1_PhotoSize_photoSize *sizeValue = size;
                            if ([sizeValue.type isEqualToString:@"m"]) {
                                inputFileLocation = [Api1_InputFileLocation inputPhotoFileLocationWithPid:photo.pid accessHash:photo.accessHash fileReference:photo.fileReference thumbSize:sizeValue.type];
                                fileDatacenterId = [photo.dcId intValue];
                                fetchResourceId = [NSString stringWithFormat:@"telegram-cloud-photo-size-%@-%@-%@", photo.dcId, photo.pid, sizeValue.type];
                                break;
                            }
                        }
                    }
                }
            } else if ([parsedAttachment isKindOfClass:[Api1_Document_document class]]) {
                Api1_Document_document *document = parsedAttachment;
                
                bool isSticker = false;
                for (id attribute in document.attributes) {
                    if ([attribute isKindOfClass:[Api1_DocumentAttribute_documentAttributeSticker class]]) {
                        isSticker = true;
                    }
                }
                bool isAnimatedSticker = [document.mimeType isEqualToString:@"application/x-tgsticker"];
                if (isSticker || isAnimatedSticker) {
                    isExpandableMedia = true;
                }
                for (id size in document.thumbs) {
                    if ([size isKindOfClass:[Api1_PhotoSize_photoSize class]]) {
                        Api1_PhotoSize_photoSize *photoSize = size;
                        if ((isSticker && [photoSize.type isEqualToString:@"s"]) || [photoSize.type isEqualToString:@"m"]) {
                            if (isSticker) {
                                isPng = true;
                            }
                            inputFileLocation = [Api1_InputFileLocation inputDocumentFileLocationWithPid:document.pid accessHash:document.accessHash fileReference:document.fileReference thumbSize:photoSize.type];
                            fileDatacenterId = [document.dcId intValue];
                            fetchResourceId = [NSString stringWithFormat:@"telegram-cloud-document-size-%@-%@-%@", document.dcId, document.pid, photoSize.type];
                            break;
                        }
                    }
                }
            }
        }
        
        if (fetchResourceId != nil) {
            tempImagePath = [imagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", fetchResourceId, isPng ? @"png" : @"jpg"]];
            mediaBoxThumbnailImagePath = [mediaBoxPath stringByAppendingPathComponent:fetchResourceId];
        }
        
        NSDictionary *aps = decryptedPayload[@"aps"];
        if ([aps isKindOfClass:[NSDictionary class]]) {
            id alert = aps[@"alert"];
            if ([alert isKindOfClass:[NSDictionary class]]) {
                NSDictionary *alertDict = alert;
                NSString *title = alertDict[@"title"];
                NSString *subtitle = alertDict[@"subtitle"];
                NSString *body = alertDict[@"body"];
                if (![title isKindOfClass:[NSString class]]) {
                    title = @"";
                }
                if (![subtitle isKindOfClass:[NSString class]]) {
                    subtitle = @"";
                }
                if (![body isKindOfClass:[NSString class]]) {
                    body = nil;
                }
                if (title.length != 0 && silent) {
                    title = [title stringByAppendingString:@" 🔕"];
                }
                _bestAttemptContent.title = title;
                if (_isLockedValue) {
                    _bestAttemptContent.title = @"";
                    _bestAttemptContent.subtitle = @"";
                    if (_lockedMessageTextValue != nil) {
                        _bestAttemptContent.body = _lockedMessageTextValue;
                    } else {
                        _bestAttemptContent.body = @"^You have a new message";
                    }
                } else {
                    _bestAttemptContent.subtitle = subtitle;
                    _bestAttemptContent.body = body;
                }
            } else if ([alert isKindOfClass:[NSString class]]) {
                _bestAttemptContent.title = @"";
                _bestAttemptContent.subtitle = @"";
                if (_isLockedValue) {
                    if (_lockedMessageTextValue != nil) {
                        _bestAttemptContent.body = _lockedMessageTextValue;
                    } else {
                        _bestAttemptContent.body = @"^You have a new message";
                    }
                } else {
                    _bestAttemptContent.body = alert;
                }
            }
            
            if (_isLockedValue) {
                _bestAttemptContent.threadIdentifier = @"locked";
            } else {
                NSString *threadIdString = aps[@"thread-id"];
                if ([threadIdString isKindOfClass:[NSString class]]) {
                    _bestAttemptContent.threadIdentifier = threadIdString;
                }
            }
            NSString *soundString = aps[@"sound"];
            if ([soundString isKindOfClass:[NSString class]]) {
                _bestAttemptContent.sound = [UNNotificationSound soundNamed:soundString];
            }
            if (_isLockedValue) {
                _bestAttemptContent.categoryIdentifier = @"locked";
            } else {
                NSString *categoryString = aps[@"category"];
                if ([categoryString isKindOfClass:[NSString class]]) {
                    _bestAttemptContent.categoryIdentifier = categoryString;
                    if (peerId != 0 && messageId != 0 && parsedAttachment != nil && attachmentData != nil) {
                        userInfo[@"peerId"] = @(peerId);
                        userInfo[@"messageId.namespace"] = @(0);
                        userInfo[@"messageId.id"] = @(messageId);
                        
                        userInfo[@"media"] = [attachmentData base64EncodedStringWithOptions:0];
                        
                        if (isExpandableMedia) {
                            if ([categoryString isEqualToString:@"r"]) {
                                _bestAttemptContent.categoryIdentifier = @"withReplyMedia";
                            } else if ([categoryString isEqualToString:@"m"]) {
                                _bestAttemptContent.categoryIdentifier = @"withMuteMedia";
                            }
                        }
                    }
                }
                
                if (accountInfos.accounts.count > 1) {
                    if (_bestAttemptContent.title.length != 0 && account.peerName.length != 0) {
                        _bestAttemptContent.title = [NSString stringWithFormat:@"%@ → %@", _bestAttemptContent.title, account.peerName];
                    }
                }
            }
        }
        
        _bestAttemptContent.userInfo = userInfo;
        
        if (_cancelFetch) {
            _cancelFetch();
            _cancelFetch = nil;
        }
        
        if (mediaBoxThumbnailImagePath != nil && tempImagePath != nil && inputFileLocation != nil) {
            NSData *data = [NSData dataWithContentsOfFile:mediaBoxThumbnailImagePath];
            if (data != nil) {
                NSData *tempData = data;
                if (isPng) {
                    /*if let image = WebP.convert(fromWebP: data), let imageData = image.pngData() {
                        tempData = imageData
                    }*/
                }
                if ([tempData writeToFile:tempImagePath atomically:true]) {
                    UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:@"image" URL:[NSURL fileURLWithPath:tempImagePath] options:nil error:nil];
                    if (attachment != nil) {
                        _bestAttemptContent.attachments = @[attachment];
                    }
                }
                [self completeWithBestAttemptContent];
            } else {
                BuildConfig *buildConfig = [[BuildConfig alloc] initWithBaseAppBundleId:_baseAppBundleId];
                
                void (^serialDispatch)(dispatch_block_t) = _serialDispatch;
                
                __weak typeof(self) weakSelf = self;
                _cancelFetch = fetchImage(buildConfig, accountInfos.proxy, account, inputFileLocation, fileDatacenterId, ^(NSData * _Nullable data) {
                    serialDispatch(^{
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (strongSelf == nil) {
                            return;
                        }
                        if (strongSelf->_cancelFetch) {
                            strongSelf->_cancelFetch();
                            strongSelf->_cancelFetch = nil;
                            
                            if (data != nil) {
                                [data writeToFile:mediaBoxThumbnailImagePath atomically:true];
                                NSData *tempData = data;
                                if (isPng) {
                                    /*if let image = WebP.convert(fromWebP: data), let imageData = image.pngData() {
                                        tempData = imageData
                                    }*/
                                }
                                if ([tempData writeToFile:tempImagePath atomically:true]) {
                                    UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:@"image" URL:[NSURL fileURLWithPath:tempImagePath] options:nil error:nil];
                                    if (attachment != nil) {
                                        strongSelf->_bestAttemptContent.attachments = @[attachment];
                                    }
                                }
                            }
                            [strongSelf completeWithBestAttemptContent];
                        }
                    });
                });
            }
        } else {
            [self completeWithBestAttemptContent];
        }
    } else {
        [self completeWithBestAttemptContent];
    }
}

- (void)serviceExtensionTimeWillExpire {
    if (_cancelFetch) {
        _cancelFetch();
        _cancelFetch = nil;
    }
    
    if (_contentHandler) {
        if(_bestAttemptContent) {
            if (_updatedUnreadCount == nil) {
                _updatedUnreadCount = @(-1);
            }
            [self completeWithBestAttemptContent];
        }
        _contentHandler = nil;
    }
}

@end
