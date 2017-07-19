#import <Foundation/Foundation.h>

typedef enum {
    TGTextCheckingResultTypeMention,
    TGTextCheckingResultTypeHashtag,
    TGTextCheckingResultTypeCommand,
    TGTextCheckingResultTypeBold,
    TGTextCheckingResultTypeUltraBold,
    TGTextCheckingResultTypeItalic,
    TGTextCheckingResultTypeCode,
    TGTextCheckingResultTypeLink,
    TGTextCheckingResultTypeColor
} TGTextCheckingResultType;

@interface TGTextCheckingResult : NSObject

@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly) TGTextCheckingResultType type;
@property (nonatomic, strong, readonly) NSString *contents;
@property (nonatomic, strong, readonly) id value;
@property (nonatomic, readonly) bool highlightAsLink;

- (instancetype)initWithRange:(NSRange)range type:(TGTextCheckingResultType)type contents:(NSString *)contents;
- (instancetype)initWithRange:(NSRange)range type:(TGTextCheckingResultType)type contents:(NSString *)contents value:(id)value highlightAsLink:(bool)highlightAsLink;

@end
