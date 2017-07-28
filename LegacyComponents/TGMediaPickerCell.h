#import <LegacyComponents/TGImageView.h>
#import <LegacyComponents/TGCheckButtonView.h>

@class TGMediaSelectionContext;
@class TGMediaEditingContext;

@interface TGMediaPickerCell : UICollectionViewCell
{
    TGCheckButtonView *_checkButton;
}

@property (nonatomic, readonly) TGImageView *imageView;
- (void)setHidden:(bool)hidden animated:(bool)animated;

@property (nonatomic, strong) TGMediaSelectionContext *selectionContext;
@property (nonatomic, strong) TGMediaEditingContext *editingContext;

@property (nonatomic, readonly) NSObject *item;
- (void)setItem:(NSObject *)item signal:(SSignal *)signal;

@end
