#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGInputTextTag : NSTextAttachment

@property (nonatomic, readonly) int64_t uniqueId;
@property (nonatomic, readonly) bool left;
@property (nonatomic, strong, readonly) id attachment;

- (instancetype)initWithUniqueId:(int64_t)uniqueId left:(bool)left attachment:(id)attachment;

@end

@interface TGInputTextTagAndRange : NSObject

@property (nonatomic, strong, readonly) TGInputTextTag *tag;
@property (nonatomic) NSRange range;

- (instancetype)initWithTag:(TGInputTextTag *)tag range:(NSRange)range;

@end
