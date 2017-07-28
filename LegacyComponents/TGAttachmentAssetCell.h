#import "TGAttachmentMenuCell.h"
#import <LegacyComponents/TGImageView.h>
#import <LegacyComponents/TGCheckButtonView.h>

@class TGMediaAsset;
@class TGMediaSelectionContext;
@class TGMediaEditingContext;

@interface TGAttachmentAssetCell : TGAttachmentMenuCell
{
    TGCheckButtonView *_checkButton;
    
    UIImageView *_iconView;
    UIImageView *_gradientView;
}

@property (nonatomic, readonly) TGImageView *imageView;
- (void)setHidden:(bool)hidden animated:(bool)animated;

@property (nonatomic, readonly) TGMediaAsset *asset;
- (void)setAsset:(TGMediaAsset *)asset signal:(SSignal *)signal;
- (void)setSignal:(SSignal *)signal;

@property (nonatomic, assign) bool isZoomed;

@property (nonatomic, strong) TGMediaSelectionContext *selectionContext;
@property (nonatomic, strong) TGMediaEditingContext *editingContext;

@end
