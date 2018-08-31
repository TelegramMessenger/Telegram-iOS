#import "TGSecretTimerPickerItemView.h"

#import "LegacyComponentsInternal.h"

#import "TGSecretTimerValueControllerItemView.h"

#import "TGMenuSheetController.h"

@interface TGSecretTimerPickerView : UIPickerView

@property (nonatomic, strong) UIColor *selectorColor;

@end


@interface TGSecretTimerPickerItemView () <UIPickerViewDataSource, UIPickerViewDelegate>
{
    bool _dark;
    NSArray *_timerValues;
    
    TGSecretTimerPickerView *_pickerView;
}
@end

@implementation TGSecretTimerPickerItemView

- (instancetype)initWithValues:(NSArray *)values value:(NSNumber *)value
{
    self = [super initWithType:TGMenuSheetItemTypeDefault];
    if (self != nil)
    {
        NSNumber *selectedValue = value;
        NSInteger selectedRow = 7;
        
        _timerValues = values;
        
        if (selectedValue != nil)
        {
            NSInteger index = [_timerValues indexOfObject:selectedValue];
            if (index != NSNotFound)
                selectedRow = index;
        }

        _pickerView = [[TGSecretTimerPickerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.frame.size.width, 216.0)];
        _pickerView.dataSource = self;
        _pickerView.delegate = self;
        [self addSubview:_pickerView];
        
        [_pickerView selectRow:selectedRow inComponent:0 animated:false];
    }
    return self;
}

- (void)setPallete:(TGMenuSheetPallete *)pallete
{
    [super setPallete:pallete];
    
    if (pallete.isDark)
        _dark = true;
}

- (NSNumber *)value
{
    NSInteger row = [_pickerView selectedRowInComponent:0];
    if (row == 0)
        return nil;
    
    return _timerValues[row];
}

- (void)setDark
{
    _dark = true;
    _pickerView.selectorColor = UIColorRGBA(0xffffff, 0.18f);
}

- (CGFloat)preferredHeightForWidth:(CGFloat)__unused width screenHeight:(CGFloat)__unused screenHeight
{
    if ((int)screenHeight == 320)
        return 168.0f;
    
    return 216.0f;
}

- (bool)requiresDivider
{
    return true;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)__unused pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)__unused pickerView numberOfRowsInComponent:(NSInteger)__unused component
{
    return _timerValues.count;
}

- (UIView *)pickerView:(UIPickerView *)__unused pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)__unused component reusingView:(TGSecretTimerValueControllerItemView *)view
{
    if (view != nil)
    {
        view.seconds = [_timerValues[row] intValue];
        return view;
    }
    
    TGSecretTimerValueControllerItemView *newView = [[TGSecretTimerValueControllerItemView alloc] initWithFrame:CGRectZero dark:_dark];
    newView.seconds = [_timerValues[row] intValue];
    return newView;
}

- (void)layoutSubviews
{
    _pickerView.frame = self.bounds;
}

@end


@implementation TGSecretTimerPickerView

- (void)didAddSubview:(UIView *)subview
{
    [super didAddSubview:subview];
    if (self.selectorColor == nil)
        return;
    
    if (subview.bounds.size.height <= 1.0)
        subview.backgroundColor = self.selectorColor;
}


- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.selectorColor == nil)
        return;
    
    for (UIView *subview in self.subviews)
    {
        if (subview.bounds.size.height <= 1.0)
            subview.backgroundColor = self.selectorColor;
    }
}

@end
