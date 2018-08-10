#import <Foundation/Foundation.h>

#import <LegacyComponents/PSCoding.h>
#import <LegacyComponents/TGBotInfo.h>

typedef enum {
    TGUserSexUnknown = 0,
    TGUserSexMale = 1,
    TGUserSexFemale = 2
} TGUserSex;

typedef enum {
    TGUserPresenceValueLately = -2,
    TGUserPresenceValueWithinAWeek = -3,
    TGUserPresenceValueWithinAMonth = -4,
    TGUserPresenceValueALongTimeAgo = -5
} TGUserPresenceValue;

typedef struct {
    bool online;
    int lastSeen;
    int temporaryLastSeen;
} TGUserPresence;

typedef enum {
    TGUserLinkKnown = 1,
    TGUserLinkForeignRequested = 2,
    TGUserLinkForeignMutual = 4,
    TGUserLinkMyRequested = 8,
    TGUserLinkMyContact = 16,
    TGUserLinkForeignHasPhone = 32
} TGUserLink;

typedef enum {
    TGUserFieldUid = 1,
    TGUserFieldPhoneNumber = 2,
    TGUserFieldPhoneNumberHash = 4,
    TGUserFieldFirstName = 8,
    TGUserFieldLastName = 16,
    TGUserFieldPhonebookFirstName = 32,
    TGUserFieldPhonebookLastName = 64,
    TGUserFieldSex = 128,
    TGUserFieldPhotoUrlSmall = 256,
    TGUserFieldPhotoUrlMedium = 512,
    TGUserFieldPhotoUrlBig = 1024,
    TGUserFieldPresenceLastSeen = 2048,
    TGUserFieldPresenceOnline = 4096,
    TGUserFieldUsername = 8192,
    TGUserFieldOther = 8192 * 2
} TGUserFields;

typedef enum {
    TGUserKindGeneric = 0,
    TGUserKindBot = 1,
    TGUserKindSmartBot = 2
} TGUserKind;

typedef enum {
    TGBotKindGeneric = 0,
    TGBotKindPrivate = 1
} TGBotKind;

@class TGNotificationPrivacyAccountSetting;

#define TGUserFieldsAllButPresenceMask (TGUserFieldUid | TGUserFieldPhoneNumber | TGUserFieldPhoneNumberHash | TGUserFieldFirstName| TGUserFieldLastName | TGUserFieldPhonebookFirstName | TGUserFieldPhonebookLastName | TGUserFieldSex | TGUserFieldPhotoUrlSmall | TGUserFieldPhotoUrlMedium | TGUserFieldPhotoUrlBig)

@interface TGUser : NSObject <PSCoding>

@property (nonatomic) int uid;
@property (nonatomic, strong) NSString *phoneNumber;
@property (nonatomic) int64_t phoneNumberHash;
@property (nonatomic, strong) NSString *firstName;
@property (nonatomic, strong) NSString *lastName;
@property (nonatomic, strong) NSString *userName;
@property (nonatomic, strong) NSString *phonebookFirstName;
@property (nonatomic, strong) NSString *phonebookLastName;
@property (nonatomic) TGUserSex sex;
@property (nonatomic) NSString *photoUrlSmall;
@property (nonatomic) NSString *photoUrlMedium;
@property (nonatomic) NSString *photoUrlBig;
@property (nonatomic) NSData *photoFileReferenceSmall;
@property (nonatomic) NSData *photoFileReferenceBig;

@property (nonatomic) NSString *photoFullUrlSmall;
@property (nonatomic) NSString *photoFullUrlBig;

@property (nonatomic) TGUserPresence presence;

@property (nonatomic) int contactId;

@property (nonatomic) int32_t kind;
@property (nonatomic) int32_t botKind;
@property (nonatomic) int32_t botInfoVersion;

@property (nonatomic) int32_t flags;

@property (nonatomic) bool isVerified;
@property (nonatomic) bool hasExplicitContent;
@property (nonatomic, strong) NSString *restrictionReason;
@property (nonatomic, strong) NSString *contextBotPlaceholder;
@property (nonatomic) bool isContextBot;

@property (nonatomic, strong) NSDictionary *customProperties;

@property (nonatomic) bool minimalRepresentation;

@property (nonatomic, strong) NSString *about;

@property (nonatomic) bool botInlineGeo;

@property (nonatomic, readonly) bool isBot;
@property (nonatomic, readonly) bool isDeleted;

- (id)copyWithZone:(NSZone *)zone;

- (bool)hasAnyName;

- (NSString *)realFirstName;
- (NSString *)realLastName;

- (NSString *)displayName;
- (NSString *)displayRealName;
- (NSString *)displayFirstName;
- (NSString *)compactName;

- (NSString *)formattedPhoneNumber;

- (bool)isEqualToUser:(TGUser *)anotherUser;
- (int)differenceFromUser:(TGUser *)anotherUser;

+ (TGUserPresence)approximatePresenceFromPresence:(TGUserPresence)presence currentTime:(NSTimeInterval)currentTime;

@end
