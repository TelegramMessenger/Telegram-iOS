#import "NotificationService.h"

#import <UIKit/UIKit.h>
#import <BuildConfig/BuildConfig.h>

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

@interface NotificationService () {
    NSString * _Nullable _rootPath;
    NSString * _Nullable _baseAppBundleId;
    void (^_contentHandler)(UNNotificationContent *);
    UNMutableNotificationContent * _Nullable _bestAttemptContent;
    void (^_cancelFetch)(void);
}

@end

@implementation NotificationService

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        NSString *appBundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
        NSRange lastDotRange = [appBundleIdentifier rangeOfString:@"." options:NSBackwardsSearch];
        if (lastDotRange.location != NSNotFound) {
            _baseAppBundleId = [appBundleIdentifier substringToIndex:lastDotRange.location];
            NSString *appGroupName = [@"group." stringByAppendingString:_baseAppBundleId];
            NSURL *appGroupUrl = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:appGroupName];
            
            if (appGroupUrl != nil) {
                NSString *rootPath = [[appGroupUrl path] stringByAppendingPathComponent:@"telegram-data"];
                _rootPath = rootPath;
            } else {
                NSAssert(false, @"appGroupUrl == nil");
            }
        } else {
            NSAssert(false, @"Invalid bundle id");
        }
    }
    return self;
}

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    if (_rootPath == nil) {
        contentHandler(request.content);
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
        
        NSString *silentString = decryptedPayload[@"silent"];
        if ([silentString isKindOfClass:[NSString class]]) {
            silent = [silentString intValue] != 0;
        }
        
        NSString *attachmentDataString = decryptedPayload[@"attachb64"];
        NSData *attachmentData = nil;
        id parsedAttachment = nil;
        if ([attachmentDataString isKindOfClass:[NSString class]]) {
            attachmentData = parseBase64(attachmentDataString);
            if (attachmentData != nil) {
                parsedAttachment = parseAttachment(attachmentData);
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
        
        NSString *fetchResourceId = nil;
        bool isPng = false;
        bool isExpandableMedia = false;
        
        if (parsedAttachment != nil) {
            if ([parsedAttachment isKindOfClass:[Api1_Photo_photo class]]) {
                Api1_Photo_photo *photo = parsedAttachment;
                isExpandableMedia = true;
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
                _bestAttemptContent.subtitle = subtitle;
                _bestAttemptContent.body = body;
            } else if ([alert isKindOfClass:[NSString class]]) {
                _bestAttemptContent.title = @"";
                _bestAttemptContent.subtitle = @"";
                _bestAttemptContent.body = alert;
            }
            
            NSString *threadIdString = aps[@"thread-id"];
            if ([threadIdString isKindOfClass:[NSString class]]) {
                _bestAttemptContent.threadIdentifier = threadIdString;
            }
            NSString *soundString = aps[@"sound"];
            if ([soundString isKindOfClass:[NSString class]]) {
                _bestAttemptContent.sound = [UNNotificationSound soundNamed:soundString];
            }
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
                if (_contentHandler && _bestAttemptContent != nil) {
                    _contentHandler(_bestAttemptContent);
                }
            } else {
                BuildConfig *buildConfig = [[BuildConfig alloc] initWithBaseAppBundleId:_baseAppBundleId];
                
                __weak NotificationService *weakSelf = self;
                _cancelFetch = fetchImage(buildConfig, accountInfos.proxy, account, inputFileLocation, fileDatacenterId, ^(NSData * _Nullable data) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        __strong NotificationService *strongSelf = weakSelf;
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
                            
                            if (strongSelf->_contentHandler && strongSelf->_bestAttemptContent != nil) {
                                strongSelf->_contentHandler(strongSelf->_bestAttemptContent);
                            }
                        }
                    });
                });
            }
        } else {
            if (_contentHandler && _bestAttemptContent != nil) {
                _contentHandler(_bestAttemptContent);
            }
        }
    } else {
        if (_contentHandler && _bestAttemptContent != nil) {
            _contentHandler(_bestAttemptContent);
        }
    }
}

- (void)serviceExtensionTimeWillExpire {
    if (_cancelFetch) {
        _cancelFetch();
        _cancelFetch = nil;
    }
    
    if (_contentHandler) {
        if(_bestAttemptContent) {
            _contentHandler(_bestAttemptContent);
            _bestAttemptContent = nil;
        }
        _contentHandler = nil;
    }
}

@end
