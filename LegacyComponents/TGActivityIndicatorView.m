#import "TGActivityIndicatorView.h"

@implementation TGActivityIndicatorView

+ (NSArray *)animationFrames
{
    static NSArray *array = nil;
    if (array == nil)
    {
        NSMutableArray *mutableArray = [[NSMutableArray alloc] init];
        for (int i = 1; i <= 24; i++)
        {
            UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"grayProgress%d.png", i]];
            if (image != nil)
                [mutableArray addObject:image];
        }
        array = [[NSArray alloc] initWithArray:mutableArray];
    }
    return array;
}

+ (NSArray *)largeAnimationFrames
{
    static NSArray *array = nil;
    if (array == nil)
    {
        NSMutableArray *mutableArray = [[NSMutableArray alloc] init];
        for (int i = 0; i <= 24; i++)
        {
            UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"navbar_big_progress_%d.png", i]];
            if (image != nil)
                [mutableArray addObject:image];
        }
        array = [[NSArray alloc] initWithArray:mutableArray];
    }
    return array;
}

+ (NSArray *)smallWhiteAnimationFrames
{
    static NSArray *array = nil;
    if (array == nil)
    {
        NSMutableArray *mutableArray = [[NSMutableArray alloc] init];
        
        for (int i = 1; i <= 24; i++)
        {
            UIImage *image = [UIImage imageNamed:[[NSString alloc] initWithFormat:@"RProgress%d.png", i]];
            if (image != nil)
                [mutableArray addObject:image];
        }
        array = [[NSArray alloc] initWithArray:mutableArray];
    }
    return array;
}

- (id)initWithStyle:(TGActivityIndicatorViewStyle)style
{
    NSArray *frames = style == TGActivityIndicatorViewStyleSmall ? [TGActivityIndicatorView animationFrames] : (style == TGActivityIndicatorViewStyleLarge ?[TGActivityIndicatorView largeAnimationFrames] : [TGActivityIndicatorView smallWhiteAnimationFrames]);
    self = [super initWithImage:[frames objectAtIndex:0]];
    if (self)
    {
        [self setAnimationImages:frames];
    }
    return self;
}

- (id)init
{
    NSArray *frames = [TGActivityIndicatorView animationFrames];
    self = [super initWithImage:[frames objectAtIndex:0]];
    if (self)
    {
        [self setAnimationImages:frames];
    }
    return self;
}

- (id)initWithFrame:(CGRect)__unused frame
{
    NSArray *frames = [TGActivityIndicatorView animationFrames];
    self = [super initWithImage:[frames objectAtIndex:0]];
    if (self)
    {
        [self setAnimationImages:frames];
    }
    return self;
}

@end
