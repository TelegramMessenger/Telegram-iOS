// PORTED VERBATIM from
// /Users/isaac/Documents/InputDec/Tests/IDRichTextLayoutControllerContractProbe.m
// @ fdad9ca519f5f27a07362e00dc6cefdcb73ca369. See the header for why the upstream name is kept.

#import "IDRichTextLayoutControllerContractProbe.h"

@interface IDRichTextLayoutControllerContractProbe ()
@property(nonatomic, strong, readwrite) id target;
@property(nonatomic, strong) NSMutableArray<NSString *> *mutableRecordedSelectors;
@end

@implementation IDRichTextLayoutControllerContractProbe

- (instancetype)initWithTarget:(id)target {
    self.target = target;
    self.mutableRecordedSelectors = [NSMutableArray array];
    return self;
}

- (NSArray<NSString *> *)recordedSelectors {
    return self.mutableRecordedSelectors.copy;
}

- (BOOL)recordedSelector:(SEL)selector {
    return [self.mutableRecordedSelectors containsObject:NSStringFromSelector(selector)];
}

- (Class)class {
    return IDRichTextLayoutControllerContractProbe.class;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [self.target methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [self.mutableRecordedSelectors addObject:NSStringFromSelector(invocation.selector)];
    [invocation invokeWithTarget:self.target];
}

@end
