#import "TGTextCheckingResult.h"

@implementation TGTextCheckingResult

- (instancetype)initWithRange:(NSRange)range type:(TGTextCheckingResultType)type contents:(NSString *)contents {
    return [self initWithRange:range type:type contents:contents value:nil highlightAsLink:false];
}

- (instancetype)initWithRange:(NSRange)range type:(TGTextCheckingResultType)type contents:(NSString *)contents value:(id)value highlightAsLink:(bool)highlightAsLink
{
    if (self != nil)
    {
        _range = range;
        _type = type;
        _contents = contents;
        _value = value;
        _highlightAsLink = highlightAsLink;
    }
    return self;
}

@end
