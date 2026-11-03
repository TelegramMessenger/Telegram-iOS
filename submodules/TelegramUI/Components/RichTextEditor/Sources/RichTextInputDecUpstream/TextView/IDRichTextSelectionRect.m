#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDRichTextSelectionRect.h"
#import "IDRichTextLayoutControllerInternal.h"

@interface IDRichTextSelectionRect ()
@property(nonatomic) CGRect storedRect;
@property(nonatomic) CGFloat storedBaselineOffset;
@property(nonatomic) BOOL storedContainsStart;
@property(nonatomic) BOOL storedContainsEnd;
@property(nonatomic) BOOL storedVertical;
@property(nonatomic) NSWritingDirection storedWritingDirection;
@end

@implementation IDRichTextSelectionRect

+ (void)initialize {
    if (self == IDRichTextSelectionRect.class) {
        IDRichTextSelectionRectInstallPrivateCallbacks(self);
    }
}

- (instancetype)initWithRect:(CGRect)rect
                containsStart:(BOOL)containsStart
                  containsEnd:(BOOL)containsEnd
                   isVertical:(BOOL)isVertical
             writingDirection:(NSWritingDirection)writingDirection {
    return [self initWithRect:rect
               baselineOffset:0.0
                containsStart:containsStart
                  containsEnd:containsEnd
                   isVertical:isVertical
             writingDirection:writingDirection];
}

- (instancetype)initWithRect:(CGRect)rect
               baselineOffset:(CGFloat)baselineOffset
                containsStart:(BOOL)containsStart
                  containsEnd:(BOOL)containsEnd
                   isVertical:(BOOL)isVertical
             writingDirection:(NSWritingDirection)writingDirection {
    self = [super init];
    if (self != nil) {
        _storedRect = rect;
        _storedBaselineOffset = isfinite(baselineOffset) ? baselineOffset : 0.0;
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

- (CGFloat)baselineOffset {
    return self.storedBaselineOffset;
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
