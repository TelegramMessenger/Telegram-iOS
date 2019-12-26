/**
 Makes the writable properties all package-private, effectively
 */

#import "NodeList.h"

@interface NodeList()

@property(nonatomic,strong) NSMutableArray* internalArray;

@end
