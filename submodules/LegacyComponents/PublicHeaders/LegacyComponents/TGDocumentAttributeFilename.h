#import <LegacyComponents/PSCoding.h>

@interface TGDocumentAttributeFilename : NSObject <PSCoding, NSCoding>

@property (nonatomic, strong, readonly) NSString *filename;

- (instancetype)initWithFilename:(NSString *)filename;

@end
