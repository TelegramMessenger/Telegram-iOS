#import <Foundation/Foundation.h>

@interface TGPhoneNumberModel : NSObject

@property (nonatomic, strong, readonly) NSString *phoneNumber;
@property (nonatomic, strong, readonly) NSString *displayPhoneNumber;

@property (nonatomic, strong, readonly) NSString *label;

- (instancetype)initWithPhoneNumber:(NSString *)string label:(NSString *)label;

@end


@interface TGContactModel : NSObject

@property (nonatomic, strong, readonly) NSString *firstName;
@property (nonatomic, strong, readonly) NSString *lastName;

@property (nonatomic, strong, readonly) NSArray *phoneNumbers;

- (instancetype)initWithFirstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumbers:(NSArray *)phoneNumbers;

@end
