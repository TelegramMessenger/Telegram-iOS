#import <LegacyComponents/POPSpringAnimation.h>

@interface TGPhotoEditorAnimation : NSObject

+ (POPSpringAnimation *)prepareTransitionAnimationForPropertyNamed:(NSString *)propertyName;
+ (void)performBlock:(void (^)(bool allFinished))block whenCompletedAllAnimations:(NSArray *)animations;

@end
