#import "TGUser.h"

#import "LegacyComponentsInternal.h"

#import "TGStringUtils.h"
#import "TGPhoneUtils.h"

#import "NSObject+TGLock.h"

#import "PSKeyValueCoder.h"

#import "TGConversation.h"
#import "TGMediaOriginInfo.h"
#import "TGImageInfo.h"

typedef enum {
    TGUserFlagVerified = (1 << 0),
    TGUserFlagHasExplicitContent = (1 << 1),
    TGUserFlagIsContextBot = (1 << 2),
    TGUserFlagMinimalRepresentation = (1 << 3),
    TGUserFlagBotInlineGeo = (1 << 4)
} TGUserFlags;

@interface TGUser ()
{
    bool _contactIdInitialized;
    bool _formattedPhoneInitialized;
    
    TG_SYNCHRONIZED_DEFINE(_cachedValues);
}

@property (nonatomic, strong) NSString *cachedFormattedNumber;

@end

@implementation TGUser

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        TG_SYNCHRONIZED_INIT(_cachedValues);
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    self = [super init];
    if (self != nil)
    {
        TG_SYNCHRONIZED_INIT(_cachedValues);
        _kind = [coder decodeInt32ForCKey:"k"];
        if (_kind == TGUserKindBot || _kind == TGUserKindSmartBot)
        {
            _botInfoVersion = [coder decodeInt32ForCKey:"biv"];
            _botKind = [coder decodeInt32ForCKey:"bk"];
        }
        _flags = [coder decodeInt32ForCKey:"f"];
        _restrictionReason = [coder decodeStringForCKey:"rr"];
        if ([self isContextBot]) {
            _contextBotPlaceholder = [coder decodeStringForCKey:"cbp"];
        }
        _about = [coder decodeStringForCKey:"a"];
        _photoFileReferenceSmall = [coder decodeDataCorCKey:"frs"];
        _photoFileReferenceBig = [coder decodeDataCorCKey:"frb"];
    }
    return self;
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt32:_kind forCKey:"k"];
    if (_kind == TGUserKindBot || _kind == TGUserKindSmartBot)
    {
        [coder encodeInt32:_botInfoVersion forCKey:"biv"];
        [coder encodeInt32:_botKind forCKey:"bk"];
    }
    [coder encodeInt32:_flags forCKey:"f"];
    [coder encodeString:_restrictionReason forCKey:"rr"];
    if ([self isContextBot]) {
        [coder encodeString:_contextBotPlaceholder forCKey:"cbp"];
    }
    [coder encodeString:_about forCKey:"a"];
    [coder encodeData:_photoFileReferenceSmall forCKey:"frs"];
    [coder encodeData:_photoFileReferenceBig forCKey:"frb"];
}

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGUser *user = [[TGUser alloc] init];
    
    user.uid = _uid;
    user.phoneNumber = _phoneNumber;
    user.phoneNumberHash = _phoneNumberHash;
    user.firstName = _firstName;
    user.lastName = _lastName;
    user.userName = _userName;
    user.phonebookFirstName = _phonebookFirstName;
    user.phonebookLastName = _phonebookLastName;
    user.sex = _sex;
    user.photoUrlSmall = _photoUrlSmall;
    user.photoUrlMedium = _photoUrlMedium;
    user.photoUrlBig = _photoUrlBig;
    user.photoFileReferenceSmall = _photoFileReferenceSmall;
    user.photoFileReferenceBig = _photoFileReferenceBig;
    user.presence = _presence;
    user.customProperties = _customProperties;
    user.contactId = _contactId;
    user->_contactIdInitialized = _contactIdInitialized;
    user->_formattedPhoneInitialized = _formattedPhoneInitialized;
    user.cachedFormattedNumber = _cachedFormattedNumber;
    user->_kind = _kind;
    user->_botInfoVersion = _botInfoVersion;
    user->_botKind = _botKind;
    user->_flags = _flags;
    user->_restrictionReason = _restrictionReason;
    user->_contextBotPlaceholder = _contextBotPlaceholder;
    
    return user;
}

- (bool)hasAnyName
{
    return _firstName.length != 0 || _lastName.length != 0 || _phonebookFirstName.length != 0 || _phonebookLastName.length != 0;
}

- (bool)isBot {
    return _kind == TGUserKindBot || _kind == TGUserKindSmartBot;
}

- (bool)isDeleted {
    return (_phonebookFirstName.length != 0 || _phonebookLastName.length != 0) ? false : ((_firstName.length != 0 || _lastName.length != 0) ? false : (_phoneNumber.length == 0 ? true : false));
}

- (NSString *)firstName
{
    return (_phonebookFirstName.length != 0 || _phonebookLastName.length != 0) ? _phonebookFirstName : ((_firstName.length != 0 || _lastName.length != 0) ? _firstName : (_phoneNumber.length == 0 ? TGLocalized(@"User.DeletedAccount") : [self formattedPhoneNumber]));
}

- (NSString *)lastName
{
    return (_phonebookFirstName.length != 0 || _phonebookLastName.length != 0) ? _phonebookLastName : ((_firstName.length != 0 || _lastName.length != 0) ? _lastName : nil);
}

- (NSString *)realFirstName
{
    return _firstName;
}

- (NSString *)realLastName
{
    return _lastName;
}

- (NSString *)displayName
{
    NSString *firstName = self.firstName;
    NSString *lastName = self.lastName;
    
    if (firstName != nil && firstName.length != 0 && lastName != nil && lastName.length != 0)
    {
        if (TGIsKorean())
            return [[NSString alloc] initWithFormat:@"%@ %@", lastName, firstName];
        else
            return [[NSString alloc] initWithFormat:@"%@ %@", firstName, lastName];
    }
    else if (firstName != nil && firstName.length != 0)
        return firstName;
    else if (lastName != nil && lastName.length != 0)
        return lastName;
    
    return @"";
}

- (NSString *)displayRealName
{
    NSString *firstName = self.realFirstName;
    NSString *lastName = self.realLastName;
    
    if (firstName != nil && firstName.length != 0 && lastName != nil && lastName.length != 0)
        return [[NSString alloc] initWithFormat:@"%@ %@", firstName, lastName];
    else if (firstName != nil && firstName.length != 0)
        return firstName;
    else if (lastName != nil && lastName.length != 0)
        return lastName;
    
    return @"";
}

- (NSString *)displayFirstName
{
    NSString *firstName = self.firstName;
    if (firstName.length != 0)
        return firstName;
    
    return self.lastName;
}

- (NSString *)compactName
{
    NSString *firstName = self.firstName;
    NSString *lastName = self.lastName;
    
    if (firstName != nil && firstName.length != 0 && lastName != nil && lastName.length != 0)
        return [[NSString alloc] initWithFormat:@"%@.%@", [firstName substringToIndex:1], lastName];
    else if (firstName != nil && firstName.length != 0)
        return firstName;
    else if (lastName != nil && lastName.length != 0)
        return lastName;
    
    return @"";
}

- (void)setPhoneNumber:(NSString *)phoneNumber
{
    TG_SYNCHRONIZED_BEGIN(_cachedValues);
    _phoneNumber = phoneNumber;
    _contactIdInitialized = false;
    _formattedPhoneInitialized = false;
    TG_SYNCHRONIZED_END(_cachedValues);
}

- (int)contactId
{
    if (!_contactIdInitialized)
    {
        int contactId = 0;
        if (_phoneNumber != nil && _phoneNumber.length != 0)
            contactId = phoneMatchHash(_phoneNumber);
        
        TG_SYNCHRONIZED_BEGIN(_cachedValues);
        _contactId = contactId;
        _contactIdInitialized = true;
        TG_SYNCHRONIZED_END(_cachedValues);
    }
    
    return _contactId;
}

- (NSString *)formattedPhoneNumber
{
    if (_formattedPhoneInitialized)
        return _cachedFormattedNumber;
    else
    {
        NSString *cachedFormattedNumber = nil;
        if (_phoneNumber.length != 0)
            cachedFormattedNumber = [TGPhoneUtils formatPhone:_phoneNumber forceInternational:true];
        
        TG_SYNCHRONIZED_BEGIN(_cachedValues);
        _cachedFormattedNumber = cachedFormattedNumber;
        _formattedPhoneInitialized = true;
        TG_SYNCHRONIZED_END(_cachedValues);
        
        return cachedFormattedNumber;
    }
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGUser class]] && [self isEqualToUser:object];
}

- (bool)isEqualToUser:(TGUser *)anotherUser
{
    if (anotherUser.uid == _uid &&
        ((anotherUser.realFirstName == nil && _firstName == nil) || [anotherUser.realFirstName isEqualToString:_firstName]) &&
        ((anotherUser.realLastName == nil && _lastName == nil) || [anotherUser.realLastName isEqualToString:_lastName]) &&
        anotherUser.sex == _sex &&
        ((anotherUser.phonebookFirstName == nil && _phonebookFirstName == nil) || [anotherUser.phonebookFirstName isEqualToString:_phonebookFirstName]) &&
        ((anotherUser.phonebookLastName == nil && _phonebookLastName == nil) || [anotherUser.phonebookLastName isEqualToString:_phonebookLastName]) &&
        ((anotherUser.phoneNumber == nil && _phoneNumber == nil) || [anotherUser.phoneNumber isEqualToString:_phoneNumber]) &&
        anotherUser.phoneNumberHash == _phoneNumberHash &&
        ((anotherUser.photoUrlSmall == nil && _photoUrlSmall == nil) || [anotherUser.photoUrlSmall isEqualToString:_photoUrlSmall]) &&
        ((anotherUser.photoUrlMedium == nil && _photoUrlMedium == nil) || [anotherUser.photoUrlMedium isEqualToString:_photoUrlMedium]) &&
        ((anotherUser.photoUrlBig == nil && _photoUrlBig == nil) || [anotherUser.photoUrlBig isEqualToString:_photoUrlBig]) && TGObjectCompare(anotherUser.photoFileReferenceSmall, _photoFileReferenceSmall) && TGObjectCompare(anotherUser.photoFileReferenceBig, _photoFileReferenceBig) && anotherUser.presence.online == _presence.online && anotherUser.presence.lastSeen == _presence.lastSeen && TGStringCompare(_userName, anotherUser.userName) && anotherUser.kind == _kind && anotherUser.botKind == _botKind &&
        TGStringCompare(_restrictionReason, anotherUser.restrictionReason))
    {
        return true;
    }
    return false;
}

- (int)differenceFromUser:(TGUser *)anotherUser
{
    int difference = 0;
    
    if (_uid != anotherUser.uid)
        difference |= TGUserFieldUid;
    
    if ((_phoneNumber == nil) != (anotherUser.phoneNumber == nil) || (_phoneNumber != nil && ![_phoneNumber isEqualToString:anotherUser.phoneNumber]))
        difference |= TGUserFieldPhoneNumber;
    
    if (_phoneNumberHash != anotherUser.phoneNumberHash)
        difference |= TGUserFieldPhoneNumberHash;
    
    if ((_firstName == nil) != (anotherUser.realFirstName == nil) || (_firstName != nil && ![_firstName isEqualToString:anotherUser.realFirstName]))
        difference |= TGUserFieldFirstName;
    
    if ((_lastName == nil) != (anotherUser.realLastName == nil) || (_lastName != nil && ![_lastName isEqualToString:anotherUser.realLastName]))
        difference |= TGUserFieldLastName;
    
    if (!TGStringCompare(_userName, anotherUser.userName))
        difference |= TGUserFieldUsername;
    
    if ((_phonebookFirstName == nil) != (anotherUser.phonebookFirstName == nil) || (_phonebookFirstName != nil && ![_phonebookFirstName isEqualToString:anotherUser.phonebookFirstName]))
        difference |= TGUserFieldPhonebookFirstName;
    
    if ((_phonebookLastName == nil) != (anotherUser.phonebookLastName == nil) || (_phonebookLastName != nil && ![_phonebookLastName isEqualToString:anotherUser.phonebookLastName]))
        difference |= TGUserFieldPhonebookLastName;
    
    if (_sex != anotherUser.sex)
        difference |= TGUserFieldSex;
    
    if ((_photoUrlSmall == nil) != (anotherUser.photoUrlSmall == nil) || (_photoUrlSmall != nil && ![_photoUrlSmall isEqualToString:anotherUser.photoUrlSmall]))
        difference |= TGUserFieldPhotoUrlSmall;
    
    if ((_photoUrlMedium == nil) != (anotherUser.photoUrlMedium == nil) || (_photoUrlMedium != nil && ![_photoUrlMedium isEqualToString:anotherUser.photoUrlMedium]))
        difference |= TGUserFieldPhotoUrlMedium;
    
    if ((_photoUrlBig == nil) != (anotherUser.photoUrlBig == nil) || (_photoUrlBig != nil && ![_photoUrlBig isEqualToString:anotherUser.photoUrlBig]))
        difference |= TGUserFieldPhotoUrlBig;
    
    if (_presence.lastSeen != anotherUser.presence.lastSeen)
        difference |= TGUserFieldPresenceLastSeen;
    
    if (_presence.online != anotherUser.presence.online)
        difference |= TGUserFieldPresenceOnline;
    
    if (anotherUser.kind != _kind)
        difference |= TGUserFieldOther;
    
    if (anotherUser.botKind != _botKind)
        difference |= TGUserFieldOther;
    
    if (anotherUser.flags != _flags) {
        difference |= TGUserFieldOther;
    }
    
    if (!TGStringCompare(anotherUser.restrictionReason, _restrictionReason)) {
        difference |= TGUserFieldOther;
    }
    
    if (!TGStringCompare(anotherUser.contextBotPlaceholder, _contextBotPlaceholder)) {
        difference |= TGUserFieldOther;
    }
    
    return difference;
}

+ (TGUserPresence)approximatePresenceFromPresence:(TGUserPresence)presence currentTime:(NSTimeInterval)currentTime
{
    if (presence.lastSeen <= 0)
        return presence;
    
    if (presence.lastSeen >= (int)(currentTime - 60 * 60 * 24 * 4))
        return (TGUserPresence){.online = false, .lastSeen = TGUserPresenceValueLately, .temporaryLastSeen = 0};
    else if (presence.lastSeen >= (int)(currentTime - 60 * 60 * 24 * 4))
        return (TGUserPresence){.online = false, .lastSeen = TGUserPresenceValueWithinAWeek, .temporaryLastSeen = 0};
    else if (presence.lastSeen >= (int)(currentTime - 60 * 60 * 24 * 31))
        return (TGUserPresence){.online = false, .lastSeen = TGUserPresenceValueWithinAMonth, .temporaryLastSeen = 0};
    
    return (TGUserPresence){.online = false, .lastSeen = TGUserPresenceValueALongTimeAgo, .temporaryLastSeen = 0};
}

- (bool)isVerified {
    return _flags & TGUserFlagVerified;
}

- (void)setIsVerified:(bool)isVerified {
    if (isVerified) {
        _flags |= TGUserFlagVerified;
    } else {
        _flags &= ~TGUserFlagVerified;
    }
}

- (bool)isContextBot {
    return _flags & TGUserFlagIsContextBot;
}

- (void)setIsContextBot:(bool)isContextBot {
    if (isContextBot) {
        _flags |= TGUserFlagIsContextBot;
    } else {
        _flags &= ~TGUserFlagIsContextBot;
    }
}

- (bool)hasExplicitContent {
    return _flags & TGConversationFlagHasExplicitContent;
}

- (void)setHasExplicitContent:(bool)hasExplicitContent {
    if (hasExplicitContent) {
        _flags |= TGConversationFlagHasExplicitContent;
    } else {
        _flags &= ~TGConversationFlagHasExplicitContent;
    }
}

- (bool)minimalRepresentation {
    return _flags & TGUserFlagMinimalRepresentation;
}

- (void)setMinimalRepresentation:(bool)minimalRepresentation {
    if (minimalRepresentation) {
        _flags |= TGUserFlagMinimalRepresentation;
    } else {
        _flags &= ~TGUserFlagMinimalRepresentation;
    }
}

- (bool)botInlineGeo {
    return _flags & TGUserFlagBotInlineGeo;
}

- (void)setBotInlineGeo:(bool)botInlineGeo {
    if (botInlineGeo) {
        _flags |= TGUserFlagBotInlineGeo;
    } else {
        _flags &= ~TGUserFlagBotInlineGeo;
    }
}

- (NSString *)photoFullUrlSmall
{
    NSString *finalAvatarUrl = self.photoUrlSmall;
    if (finalAvatarUrl.length == 0)
        return finalAvatarUrl;
    
    int64_t volumeId = 0;
    int32_t localId = 0;
    if (extractFileUrlComponents(self.photoUrlSmall, NULL, &volumeId, &localId, NULL))
    {
        NSString *key = [NSString stringWithFormat:@"%lld_%d", volumeId, localId];
        NSDictionary *fileReferences = nil;
        if (self.photoFileReferenceSmall != nil) {
            fileReferences = @{ key: self.photoFileReferenceSmall };
        }
        TGMediaOriginInfo *originInfo = [TGMediaOriginInfo mediaOriginInfoWithFileReference:self.photoFileReferenceSmall fileReferences:fileReferences userId:_uid offset:0];
        finalAvatarUrl = [finalAvatarUrl stringByAppendingFormat:@"_o%@", [originInfo stringRepresentation]];
    }
    
    return finalAvatarUrl;
}

- (NSString *)photoFullUrlBig
{
    NSString *finalAvatarUrl = self.photoUrlBig;
    if (finalAvatarUrl.length == 0)
        return finalAvatarUrl;
    
    int64_t volumeId = 0;
    int32_t localId = 0;
    if (extractFileUrlComponents(self.photoUrlBig, NULL, &volumeId, &localId, NULL))
    {
        NSString *key = [NSString stringWithFormat:@"%lld_%d", volumeId, localId];
        NSDictionary *fileReferences = nil;
        if (self.photoFileReferenceBig != nil) {
            fileReferences = @{ key: self.photoFileReferenceBig };
        }
        TGMediaOriginInfo *originInfo = [TGMediaOriginInfo mediaOriginInfoWithFileReference:self.photoFileReferenceBig fileReferences:fileReferences userId:_uid offset:0];
        finalAvatarUrl = [finalAvatarUrl stringByAppendingFormat:@"_o%@", [originInfo stringRepresentation]];
    }
    
    return finalAvatarUrl;
}

@end
