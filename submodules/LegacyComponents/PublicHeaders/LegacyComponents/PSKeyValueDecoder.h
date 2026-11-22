#import <LegacyComponents/PSKeyValueCoder.h>

@interface PSKeyValueDecoder : PSKeyValueCoder

- (instancetype)init;
- (instancetype)initWithData:(NSData *)data;

- (void)resetData:(NSData *)data;
- (void)resetBytes:(uint8_t const *)bytes length:(NSUInteger)length;
- (void)rewind;

@end
