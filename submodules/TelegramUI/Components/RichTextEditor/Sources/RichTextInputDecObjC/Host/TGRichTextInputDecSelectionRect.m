#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGRichTextInputDecSelectionRect.h"

@interface TGRichTextInputDecSelectionRect ()
@property(nonatomic) CGRect storedRect;
@property(nonatomic) BOOL storedContainsStart;
@property(nonatomic) BOOL storedContainsEnd;
@property(nonatomic) BOOL storedVertical;
@property(nonatomic) NSWritingDirection storedWritingDirection;
@end

@implementation TGRichTextInputDecSelectionRect

- (instancetype)initWithRect:(CGRect)rect
                containsStart:(BOOL)containsStart
                  containsEnd:(BOOL)containsEnd
                   isVertical:(BOOL)isVertical
             writingDirection:(NSWritingDirection)writingDirection {
    self = [super init];
    if (self != nil) {
        _storedRect = rect;
        _storedContainsStart = containsStart;
        _storedContainsEnd = containsEnd;
        _storedVertical = isVertical;
        _storedWritingDirection = writingDirection;
    }
    return self;
}

- (CGRect)rect {
    return self.storedRect;
}

- (BOOL)containsStart {
    return self.storedContainsStart;
}

- (BOOL)containsEnd {
    return self.storedContainsEnd;
}

- (BOOL)isVertical {
    return self.storedVertical;
}

- (NSWritingDirection)writingDirection {
    return self.storedWritingDirection;
}

@end

#endif
