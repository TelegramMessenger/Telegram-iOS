#import "PGPhotoProcessPass.h"

@class PGPhotoTool;

@interface PGPhotoToolComposer : PGPhotoProcessPass

@property (nonatomic, readonly) NSArray *tools;
@property (nonatomic, readonly) NSArray *advancedTools;
@property (nonatomic, readonly) bool shouldBeSkipped;
@property (nonatomic, assign) CGSize imageSize;

- (void)addPhotoTool:(PGPhotoTool *)tool;
- (void)addPhotoTools:(NSArray *)tools;
- (void)compose;

@end
