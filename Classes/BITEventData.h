#import "BITDomain.h"

@interface BITEventData : BITDomain <NSCoding>

@property (nonatomic, copy, readonly) NSString *envelopeTypeName;
@property (nonatomic, copy, readonly) NSString *dataTypeName;

@end
