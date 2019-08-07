#import "TGBridgeUser.h"
//#import "TGWatchCommon.h"
#import "TGBridgeBotInfo.h"

//#import "../Extension/TGStringUtils.h"

NSString *const TGBridgeUserIdentifierKey = @"identifier";
NSString *const TGBridgeUserFirstNameKey = @"firstName";
NSString *const TGBridgeUserLastNameKey = @"lastName";
NSString *const TGBridgeUserUserNameKey = @"userName";
NSString *const TGBridgeUserPhoneNumberKey = @"phoneNumber";
NSString *const TGBridgeUserPrettyPhoneNumberKey = @"prettyPhoneNumber";
NSString *const TGBridgeUserOnlineKey = @"online";
NSString *const TGBridgeUserLastSeenKey = @"lastSeen";
NSString *const TGBridgeUserPhotoSmallKey = @"photoSmall";
NSString *const TGBridgeUserPhotoBigKey = @"photoBig";
NSString *const TGBridgeUserKindKey = @"kind";
NSString *const TGBridgeUserBotKindKey = @"botKind";
NSString *const TGBridgeUserBotVersionKey = @"botVersion";
NSString *const TGBridgeUserVerifiedKey = @"verified";
NSString *const TGBridgeUserAboutKey = @"about";
NSString *const TGBridgeUserVersionKey = @"version";

NSString *const TGBridgeUsersDictionaryKey = @"users";

@implementation TGBridgeUser

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _identifier = [aDecoder decodeInt64ForKey:TGBridgeUserIdentifierKey];
        _firstName = [aDecoder decodeObjectForKey:TGBridgeUserFirstNameKey];
        _lastName = [aDecoder decodeObjectForKey:TGBridgeUserLastNameKey];
        _userName = [aDecoder decodeObjectForKey:TGBridgeUserUserNameKey];
        _phoneNumber = [aDecoder decodeObjectForKey:TGBridgeUserPhoneNumberKey];
        _prettyPhoneNumber = [aDecoder decodeObjectForKey:TGBridgeUserPrettyPhoneNumberKey];
        _online = [aDecoder decodeBoolForKey:TGBridgeUserOnlineKey];
        _lastSeen = [aDecoder decodeDoubleForKey:TGBridgeUserLastSeenKey];
        _photoSmall = [aDecoder decodeObjectForKey:TGBridgeUserPhotoSmallKey];
        _photoBig = [aDecoder decodeObjectForKey:TGBridgeUserPhotoBigKey];
        _kind = [aDecoder decodeInt32ForKey:TGBridgeUserKindKey];
        _botKind = [aDecoder decodeInt32ForKey:TGBridgeUserBotKindKey];
        _botVersion = [aDecoder decodeInt32ForKey:TGBridgeUserBotVersionKey];
        _verified = [aDecoder decodeBoolForKey:TGBridgeUserVerifiedKey];
        _about = [aDecoder decodeObjectForKey:TGBridgeUserAboutKey];
        _userVersion = [aDecoder decodeInt32ForKey:TGBridgeUserVersionKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.identifier forKey:TGBridgeUserIdentifierKey];
    [aCoder encodeObject:self.firstName forKey:TGBridgeUserFirstNameKey];
    [aCoder encodeObject:self.lastName forKey:TGBridgeUserLastNameKey];
    [aCoder encodeObject:self.userName forKey:TGBridgeUserUserNameKey];
    [aCoder encodeObject:self.phoneNumber forKey:TGBridgeUserPhoneNumberKey];
    [aCoder encodeObject:self.prettyPhoneNumber forKey:TGBridgeUserPrettyPhoneNumberKey];
    [aCoder encodeBool:self.online forKey:TGBridgeUserOnlineKey];
    [aCoder encodeDouble:self.lastSeen forKey:TGBridgeUserLastSeenKey];
    [aCoder encodeObject:self.photoSmall forKey:TGBridgeUserPhotoSmallKey];
    [aCoder encodeObject:self.photoBig forKey:TGBridgeUserPhotoBigKey];
    [aCoder encodeInt32:self.kind forKey:TGBridgeUserKindKey];
    [aCoder encodeInt32:self.botKind forKey:TGBridgeUserBotKindKey];
    [aCoder encodeInt32:self.botVersion forKey:TGBridgeUserBotVersionKey];
    [aCoder encodeBool:self.verified forKey:TGBridgeUserVerifiedKey];
    [aCoder encodeObject:self.about forKey:TGBridgeUserAboutKey];
    [aCoder encodeInt32:self.userVersion forKey:TGBridgeUserVersionKey];
}

- (instancetype)copyWithZone:(NSZone *)__unused zone
{
    TGBridgeUser *user = [[TGBridgeUser alloc] init];
    user->_identifier = self.identifier;
    user->_firstName = self.firstName;
    user->_lastName = self.lastName;
    user->_userName = self.userName;
    user->_phoneNumber = self.phoneNumber;
    user->_prettyPhoneNumber = self.prettyPhoneNumber;
    user->_online = self.online;
    user->_lastSeen = self.lastSeen;
    user->_photoSmall = self.photoSmall;
    user->_photoBig = self.photoBig;
    user->_kind = self.kind;
    user->_botKind = self.botKind;
    user->_botVersion = self.botVersion;
    user->_verified = self.verified;
    user->_about = self.about;
    user->_userVersion = self.userVersion;
    
    return user;
}

- (NSString *)displayName
{
    NSString *firstName = self.firstName;
    NSString *lastName = self.lastName;
    
    if (firstName != nil && firstName.length != 0 && lastName != nil && lastName.length != 0)
    {
        return [[NSString alloc] initWithFormat:@"%@ %@", firstName, lastName];
    }
    else if (firstName != nil && firstName.length != 0)
        return firstName;
    else if (lastName != nil && lastName.length != 0)
        return lastName;
    
    return @"";
}

- (bool)isBot
{
    return (self.kind == TGBridgeUserKindBot || self.kind ==TGBridgeUserKindSmartBot);
}

- (TGBridgeUserChange *)changeFromUser:(TGBridgeUser *)user
{
    NSMutableDictionary *fields = [[NSMutableDictionary alloc] init];
    
    [self _compareString:self.firstName oldString:user.firstName dict:fields key:TGBridgeUserFirstNameKey];
    [self _compareString:self.lastName oldString:user.lastName dict:fields key:TGBridgeUserLastNameKey];
    [self _compareString:self.userName oldString:user.userName dict:fields key:TGBridgeUserUserNameKey];
    [self _compareString:self.phoneNumber oldString:user.phoneNumber dict:fields key:TGBridgeUserPhoneNumberKey];
    [self _compareString:self.prettyPhoneNumber oldString:user.prettyPhoneNumber dict:fields key:TGBridgeUserPrettyPhoneNumberKey];
    
    if (self.online != user.online)
        fields[TGBridgeUserOnlineKey] = @(self.online);
    
    if (fabs(self.lastSeen - user.lastSeen) > DBL_EPSILON)
        fields[TGBridgeUserLastSeenKey] = @(self.lastSeen);
    
    [self _compareString:self.photoSmall oldString:user.photoSmall dict:fields key:TGBridgeUserPhotoSmallKey];
    [self _compareString:self.photoBig oldString:user.photoBig dict:fields key:TGBridgeUserPhotoBigKey];
    
    if (self.kind != user.kind)
        fields[TGBridgeUserKindKey] = @(self.kind);
    
    if (self.botKind != user.botKind)
        fields[TGBridgeUserBotKindKey] = @(self.botKind);
    
    if (self.botVersion != user.botVersion)
        fields[TGBridgeUserBotVersionKey] = @(self.botVersion);
    
    if (self.verified != user.verified)
        fields[TGBridgeUserVerifiedKey] = @(self.verified);
    
    if (fields.count == 0)
        return nil;
    
    return [[TGBridgeUserChange alloc] initWithUserIdentifier:user.identifier fields:fields];
}

- (void)_compareString:(NSString *)newString oldString:(NSString *)oldString dict:(NSMutableDictionary *)dict key:(NSString *)key
{
    if (newString == nil && oldString == nil)
        return;
    
    if (![newString isEqualToString:oldString])
    {
        if (newString == nil)
            dict[key] = [NSNull null];
        else
            dict[key] = newString;
    }
}

- (TGBridgeUser *)userByApplyingChange:(TGBridgeUserChange *)change
{
    if (change.userIdentifier != self.identifier)
        return nil;
    
    TGBridgeUser *user = [self copy];
    
    NSString *firstNameChange = change.fields[TGBridgeUserFirstNameKey];
    if (firstNameChange != nil)
        user->_firstName = [self _stringForFieldChange:firstNameChange];

    NSString *lastNameChange = change.fields[TGBridgeUserLastNameKey];
    if (lastNameChange != nil)
        user->_lastName = [self _stringForFieldChange:lastNameChange];
    
    NSString *userNameChange = change.fields[TGBridgeUserUserNameKey];
    if (userNameChange != nil)
        user->_userName = [self _stringForFieldChange:userNameChange];
    
    NSString *phoneNumberChange = change.fields[TGBridgeUserPhoneNumberKey];
    if (phoneNumberChange != nil)
        user->_phoneNumber = [self _stringForFieldChange:phoneNumberChange];
    
    NSString *prettyPhoneNumberChange = change.fields[TGBridgeUserPrettyPhoneNumberKey];
    if (prettyPhoneNumberChange != nil)
        user->_prettyPhoneNumber = [self _stringForFieldChange:prettyPhoneNumberChange];
    
    NSNumber *onlineChange = change.fields[TGBridgeUserOnlineKey];
    if (onlineChange != nil)
        user->_online = [onlineChange boolValue];
    
    NSNumber *lastSeenChange = change.fields[TGBridgeUserLastSeenKey];
    if (lastSeenChange != nil)
        user->_lastSeen = [lastSeenChange doubleValue];
    
    NSString *photoSmallChange = change.fields[TGBridgeUserPhotoSmallKey];
    if (photoSmallChange != nil)
        user->_photoSmall = [self _stringForFieldChange:photoSmallChange];
    
    NSString *photoBigChange = change.fields[TGBridgeUserPhotoBigKey];
    if (photoBigChange != nil)
        user->_photoBig = [self _stringForFieldChange:photoBigChange];
    
    NSNumber *kindChange = change.fields[TGBridgeUserKindKey];
    if (kindChange != nil)
        user->_kind = (int32_t)[kindChange intValue];
    
    NSNumber *botKindChange = change.fields[TGBridgeUserBotKindKey];
    if (botKindChange != nil)
        user->_botKind = (int32_t)[botKindChange intValue];
    
    NSNumber *botVersionChange = change.fields[TGBridgeUserBotVersionKey];
    if (botVersionChange != nil)
        user->_botVersion = (int32_t)[botVersionChange intValue];
    
    NSNumber *verifiedChange = change.fields[TGBridgeUserVerifiedKey];
    if (verifiedChange != nil)
        user->_verified = [verifiedChange boolValue];
    
    return user;
}
                            
- (NSString *)_stringForFieldChange:(NSString *)fieldChange
{
    if ([fieldChange isKindOfClass:[NSNull class]])
        return nil;
    
    return fieldChange;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    return self.identifier == ((TGBridgeUser *)object).identifier;
}

@end


NSString *const TGBridgeUserChangeIdentifierKey = @"userIdentifier";
NSString *const TGBridgeUserChangeFieldsKey = @"fields";

@implementation TGBridgeUserChange

- (instancetype)initWithUserIdentifier:(int64_t)userIdentifier fields:(NSDictionary *)fields
{
    self = [super init];
    if (self != nil)
    {
        _userIdentifier = userIdentifier;
        _fields = fields;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _userIdentifier = [aDecoder decodeInt64ForKey:TGBridgeUserChangeIdentifierKey];
        _fields = [aDecoder decodeObjectForKey:TGBridgeUserChangeFieldsKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.userIdentifier forKey:TGBridgeUserChangeIdentifierKey];
    [aCoder encodeObject:self.fields forKey:TGBridgeUserChangeFieldsKey];
}

@end
