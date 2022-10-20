#import <Foundation/Foundation.h>

@class PSKeyValueCoder;

@protocol PSCoding <NSObject>

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder;
- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder;

@end
