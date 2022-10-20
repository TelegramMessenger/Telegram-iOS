#import "TGNeoViewModel.h"
#import <SSignalKit/SSignalKit.h>

@interface TGNeoRenderableViewModel : TGNeoViewModel

@property (nonatomic, assign) CGSize contentSize;
@property (nonatomic, strong) UIImage *cachedImage;

- (CGSize)layoutWithContainerSize:(CGSize)containerSize;
+ (SSignal *)renderSignalForViewModel:(TGNeoRenderableViewModel *)viewModel;

@end
