#import "TGBridgeContactMediaAttachment.h"

//#import "../Extension/TGStringUtils.h"

const NSInteger TGBridgeContactMediaAttachmentType = 0xB90A5663;

NSString *const TGBridgeContactMediaUidKey = @"uid";
NSString *const TGBridgeContactMediaFirstNameKey = @"firstName";
NSString *const TGBridgeContactMediaLastNameKey = @"lastName";
NSString *const TGBridgeContactMediaPhoneNumberKey = @"phoneNumber";
NSString *const TGBridgeContactMediaPrettyPhoneNumberKey = @"prettyPhoneNumber";

@implementation TGBridgeContactMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _uid = [aDecoder decodeInt32ForKey:TGBridgeContactMediaUidKey];
        _firstName = [aDecoder decodeObjectForKey:TGBridgeContactMediaFirstNameKey];
        _lastName = [aDecoder decodeObjectForKey:TGBridgeContactMediaLastNameKey];
        _phoneNumber = [aDecoder decodeObjectForKey:TGBridgeContactMediaPhoneNumberKey];
        _prettyPhoneNumber = [aDecoder decodeObjectForKey:TGBridgeContactMediaPrettyPhoneNumberKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:self.uid forKey:TGBridgeContactMediaUidKey];
    [aCoder encodeObject:self.firstName forKey:TGBridgeContactMediaFirstNameKey];
    [aCoder encodeObject:self.lastName forKey:TGBridgeContactMediaLastNameKey];
    [aCoder encodeObject:self.phoneNumber forKey:TGBridgeContactMediaPhoneNumberKey];
    [aCoder encodeObject:self.prettyPhoneNumber forKey:TGBridgeContactMediaPrettyPhoneNumberKey];
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

+ (NSInteger)mediaType
{
    return TGBridgeContactMediaAttachmentType;
}

@end
