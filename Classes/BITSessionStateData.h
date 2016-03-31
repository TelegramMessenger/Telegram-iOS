#import "BITDomain.h"
#import "BITSessionState.h"

@interface BITSessionStateData : BITDomain <NSCoding>

@property (nonatomic, copy, readonly) NSString *envelopeTypeName;
@property (nonatomic, copy, readonly) NSString *dataTypeName;
@property (nonatomic, assign) BITSessionState state;

@end
