#import <LegacyComponents/TGPhotoEditorToolView.h>

@protocol PGPhotoEditorItem <NSObject>

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *title;

@property (nonatomic, readonly) NSArray *parameters;

@property (nonatomic, readonly) CGFloat defaultValue;
@property (nonatomic, readonly) CGFloat minimumValue;
@property (nonatomic, readonly) CGFloat maximumValue;
@property (nonatomic, readonly) bool segmented;

@property (nonatomic, strong) id value;
@property (nonatomic, strong) id tempValue;
@property (nonatomic, readonly) id displayValue;
@property (nonatomic, readonly) NSString *stringValue;

@property (nonatomic, readonly) bool shouldBeSkipped;
@property (nonatomic, assign) bool beingEdited;
@property (nonatomic, assign) bool disabled;

@property (copy, nonatomic) void(^parametersChanged)(void);

- (UIView <TGPhotoEditorToolView> *)itemControlViewWithChangeBlock:(void (^)(id newValue, bool animated))changeBlock;
- (UIView <TGPhotoEditorToolView> *)itemAreaViewWithChangeBlock:(void (^)(id newValue))changeBlock;

- (Class)valueClass;

- (void)updateParameters;

@end
