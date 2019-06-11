#import "TGSecretTimerValueController.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"

#import "TGSecretTimerValueControllerItemView.h"

@interface TGSecretTimerValueController () <UIPickerViewDelegate, UIPickerViewDataSource>
{
    UIView *_backgroundView;
    UIPickerView *_pickerView;
    
    NSArray *_timerValues;
}

@end

@implementation TGSecretTimerValueController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.title = TGLocalized(@"MessageTimer.Title");
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)]];
        [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(donePressed)]];
        
        NSMutableArray *timerValues = [[NSMutableArray alloc] init];
        for (int i = 1; i < 60; i++)
        {
            [timerValues addObject:@(i)];
        }
        for (int i = 1; i < 60; i++)
        {
            [timerValues addObject:@(i * 60)];
        }
        for (int i = 1; i < 24; i++)
        {
            [timerValues addObject:@(i * 60 * 60)];
        }
        for (int i = 1; i < 7; i++)
        {
            [timerValues addObject:@(i * 60 * 60 * 24)];
        }
        for (int i = 1; i < 10; i++)
        {
            [timerValues addObject:@(i * 60 * 60 * 24 * 7)];
        }
        _timerValues = timerValues;
    }
    return self;
}

- (void)cancelPressed
{
    [[self presentingViewController] dismissViewControllerAnimated:true completion:nil];
}

- (void)donePressed
{
    if (_timerValueSelected)
        _timerValueSelected([_timerValues[[_pickerView selectedRowInComponent:0]] intValue]);
    
    [[self presentingViewController] dismissViewControllerAnimated:true completion:nil];
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = UIColorRGB(0xf0f1f2);
    
    _backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, 264.0f)];
    _backgroundView.backgroundColor = [UIColor whiteColor];
    _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    CGFloat separatorHeight = ([UIScreen mainScreen].scale >= 2.0f - FLT_EPSILON) ? 0.5f : 1.0f;
    UIView *separatorView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, _backgroundView.frame.size.height - separatorHeight, _backgroundView.frame.size.width, separatorHeight)];
    separatorView.backgroundColor = TGSeparatorColor();
    separatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_backgroundView addSubview:separatorView];
    
    [self.view addSubview:_backgroundView];
    
    _pickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, 216.0)];
    _pickerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _pickerView.dataSource = self;
    _pickerView.delegate = self;
    [self.view addSubview:_pickerView];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];
    
    _backgroundView.frame = (CGRect){{0.0f, self.controllerInset.top}, {_backgroundView.frame.size.width, _backgroundView.frame.size.height}};
    _pickerView.frame = (CGRect){{0.0f, _backgroundView.frame.origin.y + CGFloor((_backgroundView.frame.size.height - _pickerView.frame.size.height) / 2.0f)}, {_pickerView.frame.size.width, _pickerView.frame.size.height}};
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
    
    TGSecretTimerValueControllerItemView *newView = [[TGSecretTimerValueControllerItemView alloc] init];
    newView.seconds = [_timerValues[row] intValue];
    return newView;
}

@end
