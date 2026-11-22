@import XCTest;

NS_ASSUME_NONNULL_BEGIN

@interface IDHIDTouchWaypoint : NSObject
@property(nonatomic, readonly) CGPoint screenPoint;
@property(nonatomic, readonly) NSTimeInterval offset;
@property(nonatomic, readonly, getter=isLift) BOOL lift;
+ (instancetype)moveTo:(CGPoint)screenPoint offset:(NSTimeInterval)offset;
+ (instancetype)liftAtOffset:(NSTimeInterval)offset;
@end

@interface IDHIDTouchPath : NSObject
@property(nonatomic, readonly) CGPoint startScreenPoint;
@property(nonatomic, readonly) NSTimeInterval startOffset;
@property(nonatomic, copy, readonly) NSArray<IDHIDTouchWaypoint *> *waypoints;
- (instancetype)initWithStartScreenPoint:(CGPoint)point
                              startOffset:(NSTimeInterval)offset
                                waypoints:(NSArray<IDHIDTouchWaypoint *> *)waypoints;
@end

@interface IDHIDFloatingLifecycleSchedule : NSObject
@property(nonatomic) NSTimeInterval keyboardActivation;
@property(nonatomic) NSTimeInterval heldCapture;
@property(nonatomic) NSTimeInterval actionDown;
@property(nonatomic) NSTimeInterval actionUp;
@property(nonatomic) NSTimeInterval immediateCapture;
@property(nonatomic) NSTimeInterval settledCapture;
@property(nonatomic) NSTimeInterval keyboardLift;
@property(nonatomic) NSTimeInterval postLiftCapture;
@end

FOUNDATION_EXPORT BOOL IDHIDBuildFloatingLifecycleTouchPaths(
    CGPoint keyboardPoint,
    CGPoint actionPoint,
    IDHIDFloatingLifecycleSchedule *schedule,
    NSArray<IDHIDTouchPath *> * _Nullable * _Nullable paths,
    NSError * _Nullable * _Nullable error);

FOUNDATION_EXPORT BOOL IDHIDAssertRuntimeCompatible(XCTestCase *testCase);
FOUNDATION_EXPORT id _Nullable IDHIDBuildEventRecord(
    XCTestCase *testCase,
    NSArray<IDHIDTouchPath *> *paths,
    Class pathClass,
    Class recordClass);
FOUNDATION_EXPORT BOOL IDHIDSynthesizeTouchPaths(
    XCTestCase *testCase,
    XCUIApplication *application,
    NSArray<IDHIDTouchPath *> *paths,
    NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT BOOL IDHIDTapSoftwareKeyboardKey(
    XCTestCase *testCase, XCUIApplication *application, NSString *key);
FOUNDATION_EXPORT BOOL IDHIDTypeSoftwareKeyboardText(
    XCTestCase *testCase, XCUIApplication *application, NSString *text);
FOUNDATION_EXPORT BOOL IDHIDTryTypeSoftwareKeyboardText(
    XCUIApplication *application, NSString *text);

NS_ASSUME_NONNULL_END
