#import <Foundation/Foundation.h>

typedef enum {
    TGNetworkTypeUnknown,
    TGNetworkTypeNone,
    TGNetworkTypeGPRS,
    TGNetworkTypeEdge,
    TGNetworkType3G,
    TGNetworkTypeLTE,
    TGNetworkTypeWiFi,
} TGNetworkType;

typedef enum {
    TGAutoDownloadModeNone = 0,
    
    TGAutoDownloadModeCellularContacts = 1 << 0,
    TGAutoDownloadModeWifiContacts = 1 << 1,
    
    TGAutoDownloadModeCellularPrivateChats = 1 << 2,
    TGAutoDownloadModeWifiPrivateChats = 1 << 3,
    
    TGAutoDownloadModeCellularGroups = 1 << 4,
    TGAutoDownloadModeWifiGroups = 1 << 5,
    
    TGAutoDownloadModeCellularChannels = 1 << 6,
    TGAutoDownloadModeWifiChannels = 1 << 7,
    
    TGAutoDownloadModeAutosavePhotosAll = TGAutoDownloadModeCellularContacts | TGAutoDownloadModeCellularPrivateChats | TGAutoDownloadModeCellularGroups | TGAutoDownloadModeCellularChannels,
    
    TGAutoDownloadModeAllPrivateChats = TGAutoDownloadModeCellularContacts | TGAutoDownloadModeWifiContacts | TGAutoDownloadModeCellularPrivateChats | TGAutoDownloadModeWifiPrivateChats,
    TGAutoDownloadModeAllGroups = TGAutoDownloadModeCellularGroups | TGAutoDownloadModeWifiGroups | TGAutoDownloadModeCellularChannels | TGAutoDownloadModeWifiChannels,
    TGAutoDownloadModeAll = TGAutoDownloadModeCellularContacts | TGAutoDownloadModeWifiContacts | TGAutoDownloadModeCellularPrivateChats | TGAutoDownloadModeWifiPrivateChats | TGAutoDownloadModeCellularGroups | TGAutoDownloadModeWifiGroups | TGAutoDownloadModeCellularChannels | TGAutoDownloadModeWifiChannels
} TGAutoDownloadMode;

typedef enum {
    TGAutoDownloadChatContact,
    TGAutoDownloadChatOtherPrivateChat,
    TGAutoDownloadChatGroup,
    TGAutoDownloadChatChannel
} TGAutoDownloadChat;

@interface TGAutoDownloadPreferences : NSObject <NSCoding>

@property (nonatomic, readonly) bool disabled;

@property (nonatomic, readonly) TGAutoDownloadMode photos;
@property (nonatomic, readonly) TGAutoDownloadMode videos;
@property (nonatomic, readonly) int32_t maximumVideoSize;
@property (nonatomic, readonly) TGAutoDownloadMode documents;
@property (nonatomic, readonly) int32_t maximumDocumentSize;
@property (nonatomic, readonly) TGAutoDownloadMode gifs;
@property (nonatomic, readonly) TGAutoDownloadMode voiceMessages;
@property (nonatomic, readonly) TGAutoDownloadMode videoMessages;

- (instancetype)updateDisabled:(bool)disabled;
- (instancetype)updatePhotosMode:(TGAutoDownloadMode)mode;
- (instancetype)updateVideosMode:(TGAutoDownloadMode)mode maximumSize:(int32_t)maximumSize;
- (instancetype)updateDocumentsMode:(TGAutoDownloadMode)mode maximumSize:(int32_t)maximumSize;
- (instancetype)updateGifsMode:(TGAutoDownloadMode)mode;
- (instancetype)updateVoiceMessagesMode:(TGAutoDownloadMode)mode;
- (instancetype)updateVideoMessagesMode:(TGAutoDownloadMode)mode;

+ (bool)shouldDownload:(TGAutoDownloadMode)mode inChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType;
- (bool)shouldDownloadPhotoInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType;
- (bool)shouldDownloadVideoInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType;
- (bool)shouldDownloadDocumentInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType;
- (bool)shouldDownloadGifInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType;
- (bool)shouldDownloadVoiceMessageInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType;
- (bool)shouldDownloadVideoMessageInChat:(TGAutoDownloadChat)chat networkType:(TGNetworkType)networkType;

- (bool)isDefaultPreferences;

+ (instancetype)defaultPreferences;
+ (instancetype)preferencesWithLegacyDownloadPrivatePhotos:(bool)privatePhotos groupPhotos:(bool)groupPhotos privateVoiceMessages:(bool)privateVoiceMessages groupVoiceMessages:(bool)groupVoiceMessages privateVideoMessages:(bool)privateVideoMessages groupVideoMessages:(bool)groupVideoMessages;

@end
