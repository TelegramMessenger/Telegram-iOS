#import <LegacyComponents/TGImageView.h>
#import <LegacyComponents/TGCheckButtonView.h>

@class TGMediaSelectionContext;
@class TGMediaEditingContext;

@interface TGMediaPickerCell : UICollectionViewCell

@property (nonatomic, readonly) TGImageView *imageView;
@property (nonatomic, readonly) TGCheckButtonView *checkButton;
- (void)setHidden:(bool)hidden animated:(bool)animated;

@property (nonatomic, strong) TGMediaSelectionContext *selectionContext;
@property (nonatomic, strong) TGMediaEditingContext *editingContext;

@property (nonatomic, readonly) NSObject *item;
- (void)setItem:(NSObject *)item signal:(SSignal *)signal;

@end
