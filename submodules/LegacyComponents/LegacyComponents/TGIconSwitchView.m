#import "TGIconSwitchView.h"

#import <LegacyComponents/LegacyComponents.h>

#import "LegacyComponentsInternal.h"

#import "TGAnimationUtils.h"

#import <objc/runtime.h>

static const void *positionChangedKey = &positionChangedKey;

@interface TGBaseIconSwitch : CALayer

@end

@implementation TGBaseIconSwitch

- (void)setPosition:(CGPoint)center {
    [super setPosition:center];
    
    void (^block)(CGPoint) = objc_getAssociatedObject(self, positionChangedKey);
    if (block) {
        block(center);
    }
}

@end

@interface TGIconSwitchView () {
    UIImageView *_offIconView;
    UIImageView *_onIconView;
    
    bool _stateIsOn;
}

@end

@implementation TGIconSwitchView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        if (iosMajorVersion() >= 8) {
            _offIconView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"PermissionSwitchOff.png")];
            _onIconView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"PermissionSwitchOn.png")];
            self.layer.cornerRadius = 17.0f;
            self.backgroundColor = [UIColor redColor];
            self.tintColor = [UIColor redColor];
            UIView *handleView = self.subviews[0].subviews.lastObject;
            if (iosMajorVersion() >= 13) {
                handleView = self.subviews[0].subviews[1].subviews.lastObject;
            } else {
                handleView = self.subviews[0].subviews.lastObject;
            }
            
            static Class subclass;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                subclass = freedomMakeClass([handleView.layer class], [TGBaseIconSwitch class]);
                object_setClass(handleView.layer, subclass);
            });
            
            CGPoint offset = CGPointZero;
            if (iosMajorVersion() >= 12) {
                offset = CGPointMake(-7.0, -3.0);
            }
            
            _offIconView.frame = CGRectOffset(_offIconView.bounds, TGScreenPixelFloor(21.5f) + offset.x, TGScreenPixelFloor(14.5f) + offset.y);
            _onIconView.frame = CGRectOffset(_onIconView.bounds, 20.0f + offset.x, 15.0f + offset.y);
            [handleView addSubview:_onIconView];
            [handleView addSubview:_offIconView];
            
            _onIconView.alpha = 0.0f;
            
            [self addTarget:self action:@selector(currentValueChanged) forControlEvents:UIControlEventValueChanged];
            
            __weak TGIconSwitchView *weakSelf = self;
            void (^block)(CGPoint) = ^(CGPoint point) {
                __strong TGIconSwitchView *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf updateState:point.x > 30.0 animated:true force:false];
                }
            };
            objc_setAssociatedObject(handleView.layer, positionChangedKey, [block copy], OBJC_ASSOCIATION_RETAIN);
        }
    }
    return self;
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    [super setOn:on animated:animated];
    
    [self updateState:on animated:animated force:true];
}

- (void)updateState:(bool)on animated:(bool)animated force:(bool)force {
    if (_stateIsOn != on || force) {
        _stateIsOn = on;
    
        if (on) {
            _onIconView.alpha = 1.0f;
            _offIconView.alpha = 0.0f;
        } else {
            _onIconView.alpha = 0.0f;
            _offIconView.alpha = 1.0f;
        }
        
        if (animated) {
            if (on) {
                [_offIconView.layer animateAlphaFrom:1.0f to:0.0f duration:0.25 timingFunction:kCAMediaTimingFunctionEaseInEaseOut removeOnCompletion:true completion:nil];
                [_offIconView.layer animateScaleFrom:1.0f to:0.2f duration:0.251 timingFunction:kCAMediaTimingFunctionEaseInEaseOut removeOnCompletion:true completion:nil];
                [_onIconView.layer animateAlphaFrom:0.0f to:1.0f duration:0.25 timingFunction:kCAMediaTimingFunctionEaseInEaseOut removeOnCompletion:true completion:nil];
                [_onIconView.layer animateSpringScaleFrom:0.2f to:1.0f duration:0.5 removeOnCompletion:true completion:nil];
            } else {
                [_onIconView.layer animateAlphaFrom:1.0f to:0.0f duration:0.25 timingFunction:kCAMediaTimingFunctionEaseInEaseOut removeOnCompletion:true completion:nil];
                [_onIconView.layer animateScaleFrom:1.0f to:0.2f duration:0.251 timingFunction:kCAMediaTimingFunctionEaseInEaseOut removeOnCompletion:true completion:nil];
                [_offIconView.layer animateAlphaFrom:0.0f to:1.0f duration:0.25 timingFunction:kCAMediaTimingFunctionEaseInEaseOut removeOnCompletion:true completion:nil];
                [_offIconView.layer animateSpringScaleFrom:0.2f to:1.0f duration:0.5 removeOnCompletion:true completion:nil];
            }
        }
    }
}

- (void)setPositiveContentColor:(UIColor *)color {
    _onIconView.image = TGTintedImage(TGComponentsImageNamed(@"PermissionSwitchOn.png"), color);
}

- (void)setNegativeContentColor:(UIColor *)color {
    _offIconView.image = TGTintedImage(TGComponentsImageNamed(@"PermissionSwitchOff.png"), color);
}

- (void)currentValueChanged {
    [self updateState:self.isOn animated:true force:false];
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

@end
