#import "TGNeoViewModel.h"

@interface TGNeoViewModel ()
{
    NSMutableArray *_submodels;
}
@end

@implementation TGNeoViewModel

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _submodels = [[NSMutableArray alloc] init];
    }
    return self;
}

- (CGRect)bounds
{
    return CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
}

- (NSArray *)submodels
{
    return _submodels;
}

- (void)addSubmodel:(TGNeoViewModel *)viewModel
{
    [_submodels addObject:viewModel];
}

- (void)removeSubmodel:(TGNeoViewModel *)viewModel
{
    [_submodels removeObject:viewModel];
}

- (void)drawInContext:(CGContextRef)context
{
    [self drawSubmodelsInContext:context];
}

- (void)drawSubmodelsInContext:(CGContextRef)context
{
    for (TGNeoViewModel *submodel in self.submodels)
    {
        CGContextTranslateCTM(context, submodel.frame.origin.x, submodel.frame.origin.y);
        [submodel drawInContext:context];
        CGContextTranslateCTM(context, -submodel.frame.origin.x, -submodel.frame.origin.y);
    }
}

- (CGSize)contentSizeWithContainerSize:(CGSize)containerSize
{
    return CGSizeZero;
}

@end
