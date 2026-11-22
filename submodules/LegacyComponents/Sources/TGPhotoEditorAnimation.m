#import <LegacyComponents/TGPhotoEditorAnimation.h>

@implementation TGPhotoEditorAnimation

+ (POPSpringAnimation *)prepareTransitionAnimationForPropertyNamed:(NSString *)propertyName
{
    POPSpringAnimation *animation = [POPSpringAnimation animationWithPropertyNamed:propertyName];
    animation.springBounciness = 1;
    animation.springSpeed = 12;
    
    return animation;
}

+ (void)performBlock:(void (^)(bool))block whenCompletedAllAnimations:(NSArray *)animations
{
    if (block == nil)
        return;
    
    NSMutableSet *animationsSet = [NSMutableSet setWithArray:animations];
    __block bool allFinished = true;
    void (^onAnimationCompletion)(POPAnimation *, BOOL) = ^(POPAnimation *animation, BOOL finished)
    {
        if (!finished)
            allFinished = false;
            
        [animationsSet removeObject:animation];
        
        if (animationsSet.count == 0 && block != nil)
            block(allFinished);
    };
    
    for (POPAnimation *animation in animations)
        animation.completionBlock = onAnimationCompletion;
}

@end
