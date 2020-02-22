#import "PGPhotoEditorItem.h"

@class PGPhotoFilterDefinition;
@class PGPhotoProcessPass;

@interface PGPhotoFilter : NSObject <PGPhotoEditorItem, NSCopying>
{
    PGPhotoProcessPass *_pass;
}

@property (nonatomic, readonly) PGPhotoFilterDefinition *definition;
@property (nonatomic, retain) PGPhotoProcessPass *pass;
@property (nonatomic, readonly) PGPhotoProcessPass *optimizedPass;

- (void)invalidate;

+ (PGPhotoFilter *)filterWithDefinition:(PGPhotoFilterDefinition *)definition;

@end
