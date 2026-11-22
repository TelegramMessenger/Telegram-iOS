

#import <Foundation/Foundation.h>

@interface TGMediaAttachment : NSObject

@property (nonatomic) int type;
@property (nonatomic) bool isMeta;

- (void)serialize:(NSMutableData *)data;

@end

@protocol TGMediaAttachmentParser <NSObject>

@required

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is;

@end
