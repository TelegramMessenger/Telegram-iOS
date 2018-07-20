#import "TGStickerItemPreviewView.h"

#import "TGMenuSheetController.h"
#import "LegacyComponentsInternal.h"
#import "LegacyComponentsGlobals.h"

#import "TGStickerPack.h"
#import "TGStickerAssociation.h"

#import "TGImageView.h"

static const CGFloat TGStickersTopMargin = 140.0f;

@interface TGStickerItemPreviewView ()
{
    TGDocumentMediaAttachment *_sticker;
    
    TGImageView *_imageView;
    UIView *_altWrapperView;
    
    UIImpactFeedbackGenerator *_feedbackGenerator;
}
@end

@implementation TGStickerItemPreviewView

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context frame:(CGRect)frame
{
    self = [super initWithContext:context frame:frame];
    if (self != nil)
    {
        self.eccentric = true;
        self.dontBlurOnPresentation = true;
    
        [self insertSubview:self.dimView belowSubview:self.wrapperView];
        
        bool isDark = false;
        if ([[LegacyComponentsGlobals provider] respondsToSelector:@selector(menuSheetPallete)])
            isDark = [[LegacyComponentsGlobals provider] menuSheetPallete].isDark;
        
        self.dimView.backgroundColor = [UIColor colorWithWhite:isDark ? 0.0f : 1.0f alpha:0.7f];
        
        _altWrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 40.0f)];
        [self.wrapperView addSubview:_altWrapperView];
        
        _imageView = [[TGImageView alloc] init];
        _imageView.expectExtendedEdges = true;
        [self.wrapperView addSubview:_imageView];
        
        if (iosMajorVersion() >= 11)
        {
            _altWrapperView.accessibilityIgnoresInvertColors = true;
            _imageView.accessibilityIgnoresInvertColors = true;
        }
        
        if (iosMajorVersion() >= 10)
            _feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }
    return self;
}

- (void)_didAppear
{
    [self addSubview:_containerView];
    
    _altWrapperView.frame = [self.wrapperView convertRect:_altWrapperView.frame fromView:self];
    [self addSubview:_altWrapperView];
}

- (void)_willDisappear
{
    if (_altWrapperView.superview != self.wrapperView)
    {
        _altWrapperView.frame = [self convertRect:_altWrapperView.frame toView:self.wrapperView];
        [self.wrapperView addSubview:_altWrapperView];
    }
}

- (void)presentActions
{
    [self presentActions:^
    {
        CGPoint wrapperCenter = [self _wrapperViewContainerCenter];
        self.wrapperView.center = wrapperCenter;
        
        if (self.frame.size.width > self.frame.size.height)
            _altWrapperView.alpha = 0.0f;
    }];
}

- (CGPoint)_wrapperViewContainerCenter
{
    CGRect bounds = self.bounds;
    
    CGFloat y = 0.0f;
    if (bounds.size.height > bounds.size.width && self.eccentric)
        y = bounds.size.height / 3.0f;
    else if (!TGIsPad() && bounds.size.height < bounds.size.width && self.actionsPresented)
        y = bounds.size.height / 4.0f;
    else
        y = bounds.size.height / 2.0f;
    
    return CGPointMake(bounds.size.width / 2.0f, y);
}

- (id)item
{
    return _sticker;
}

- (void)setSticker:(TGDocumentMediaAttachment *)sticker stickerPack:(TGStickerPack *)stickerPack recent:(bool)recent
{
    _stickerPack = stickerPack;
    _recent = recent;
    [self setSticker:sticker associations:stickerPack.stickerAssociations];
}

- (void)setSticker:(TGDocumentMediaAttachment *)sticker associations:(NSArray *)associations
{
    if (sticker.documentId != _sticker.documentId || sticker.localDocumentId != _sticker.localDocumentId)
    {
        [_feedbackGenerator impactOccurred];
        [_feedbackGenerator prepare];
        _lastFeedbackTime = CFAbsoluteTimeGetCurrent();
        
        bool animated = false;
        if (iosMajorVersion() >= 7 && _sticker != sticker)
            animated = true;
        
        _sticker = sticker;
        
        CGSize imageSize = CGSizeZero;
        bool isSticker = false;
        for (id attribute in sticker.attributes)
        {
            if ([attribute isKindOfClass:[TGDocumentAttributeImageSize class]])
                imageSize = ((TGDocumentAttributeImageSize *)attribute).size;
            else if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
                isSticker = true;
        }
        
        CGSize displaySize = [self displaySizeForSize:imageSize];
        
        NSMutableString *imageUri = [[NSMutableString alloc] init];
        [imageUri appendString:@"sticker://?"];
        if (_sticker.documentId != 0)
        {
            [imageUri appendFormat:@"&documentId=%" PRId64, _sticker.documentId];
            
            TGMediaOriginInfo *originInfo = _sticker.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:_sticker];
            if (originInfo != nil)
                [imageUri appendFormat:@"&origin_info=%@", [originInfo stringRepresentation]];
        }
        else
        {
            [imageUri appendFormat:@"&localDocumentId=%" PRId64, _sticker.localDocumentId];
        }
        [imageUri appendFormat:@"&accessHash=%" PRId64, _sticker.accessHash];
        [imageUri appendFormat:@"&datacenterId=%d", (int)_sticker.datacenterId];
        [imageUri appendFormat:@"&fileName=%@", [TGStringUtils stringByEscapingForURL:_sticker.fileName]];
        [imageUri appendFormat:@"&size=%d", (int)_sticker.size];
        [imageUri appendFormat:@"&width=%d&height=%d", (int)displaySize.width, (int)displaySize.height];
        [imageUri appendFormat:@"&mime-type=%@", [TGStringUtils stringByEscapingForURL:_sticker.mimeType]];
        
        _imageView.frame = CGRectMake(CGFloor((self.frame.size.width - displaySize.width) / 2.0f), CGFloor((self.frame.size.height - displaySize.height) / 2.0f), displaySize.width, displaySize.height);
        
        [_imageView loadUri:imageUri withOptions:@{}];
        
        NSMutableArray *alts = [[NSMutableArray alloc] init];
        for (TGStickerAssociation *association in associations)
        {
            for (NSNumber *nDocumentId in association.documentIds)
            {
                if ((int64_t)[nDocumentId longLongValue] == sticker.documentId && [association.key containsSingleEmoji])
                {
                    if ([association.key characterAtIndex:0] == 0x2639)
                        [alts addObject:@"\u2639\ufe0f"];
                    else
                        [alts addObject:association.key];
                }
            }
            
            if (alts.count == 5)
                break;
        }
        
        [self updateAltViews:alts animated:animated];
        if (_altWrapperView.superview == self.wrapperView)
        {
            _altWrapperView.frame = CGRectMake(CGFloor(self.frame.size.width - _altWrapperView.frame.size.width) / 2.0f, CGRectGetMidY(self.bounds) - TGStickersTopMargin, _altWrapperView.frame.size.width, _altWrapperView.frame.size.height);
        }
        
        if (animated)
        {
            self.wrapperView.transform = CGAffineTransformMakeScale(0.7f, 0.7f);
            [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.72f initialSpringVelocity:0.0f options:0 animations:^
            {
                self.wrapperView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }
}

- (void)updateAltViews:(NSArray *)alts animated:(bool)animated
{
    for (UIView *view in _altWrapperView.subviews)
        [view removeFromSuperview];
    
    NSInteger i = 0;
    UIView *lastAltView = nil;
    for (NSString *alt in alts)
    {
        UILabel *altView = [[UILabel alloc] initWithFrame:CGRectZero];
        altView.backgroundColor = [UIColor clearColor];
        altView.font = TGSystemFontOfSize(32);
        altView.text = alt;
        [altView sizeToFit];
        [_altWrapperView addSubview:altView];
        
        altView.frame = CGRectMake(i * 42.0f, 0, altView.frame.size.width, altView.frame.size.height);
        i++;
        
        if (animated)
        {
            altView.transform = CGAffineTransformMakeScale(0.7f, 0.7f);
            [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.72f initialSpringVelocity:0.0f options:0 animations:^
            {
                altView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
        
        lastAltView = altView;
    }
    
    CGRect frame = _altWrapperView.frame;
    frame.size.width = CGRectGetMaxX(lastAltView.frame);
    _altWrapperView.frame = frame;
}

- (CGSize)displaySizeForSize:(CGSize)size
{
    CGSize maxSize = CGSizeMake(160, 170);
    return TGFitSize(CGSizeMake(size.width / 2.0f, size.height / 2.0f), maxSize);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGPoint wrapperCenter = [self _wrapperViewContainerCenter];
    
    if (_altWrapperView.superview == self)
    {
        _altWrapperView.frame = CGRectMake(wrapperCenter.x - _altWrapperView.frame.size.width / 2.0f, wrapperCenter.y - TGStickersTopMargin, _altWrapperView.frame.size.width, _altWrapperView.frame.size.height);
    }
}

@end
