#import "TGContactModel.h"

#import <PhoneNumberFormat/PhoneNumberFormat.h>

@implementation TGPhoneNumberModel

- (instancetype)initWithPhoneNumber:(NSString *)phoneNumber label:(NSString *)label
{
    self = [super init];
    if (self != nil)
    {
        _phoneNumber = [FormatPhoneNumber cleanInternationalPhone:phoneNumber forceInternational:false];
        _displayPhoneNumber = [FormatPhoneNumber formatPhoneNumber:_phoneNumber];
        _label = label;
    }
    return self;
}

@end

@implementation TGContactModel

- (instancetype)initWithFirstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumbers:(NSArray *)phoneNumbers
{
    self = [super init];
    if (self != nil)
    {
        _firstName = firstName;
        _lastName = lastName;
        _phoneNumbers = phoneNumbers;
    }
    return self;
}

@end
