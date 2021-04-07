#import "TGPhotoPaintEntityView.h"
#import "TGPhotoPaintTextEntity.h"

@class TGPaintSwatch;

@interface TGPhotoTextSelectionView : TGPhotoPaintEntitySelectionView

@end


@interface TGPhotoTextEntityView : TGPhotoPaintEntityView

@property (nonatomic, readonly) TGPhotoPaintTextEntity *entity;
@property (nonatomic, readonly) UIImage *image;

@property (nonatomic, readonly) bool isEmpty;

@property (nonatomic, copy) void (^beganEditing)(TGPhotoTextEntityView *);
@property (nonatomic, copy) void (^finishedEditing)(TGPhotoTextEntityView *);

- (instancetype)initWithEntity:(TGPhotoPaintTextEntity *)entity;
- (void)setFont:(TGPhotoPaintFont *)font;
- (void)setSwatch:(TGPaintSwatch *)swatch;
- (void)setStyle:(TGPhotoPaintTextEntityStyle)style;

@property (nonatomic, readonly) bool isEditing;
- (void)beginEditing;
- (void)endEditing;

@end


@interface TGPhotoTextView : UITextView

@property (nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, assign) CGFloat strokeWidth;
@property (nonatomic, assign) CGPoint strokeOffset;
@property (nonatomic, strong) UIColor *frameColor;
@property (nonatomic, assign) CGFloat frameWidthInset;

@end
