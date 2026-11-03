@import UIKit;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDTextInputScenarioFamily) {
    IDTextInputScenarioFamilyIME,
    IDTextInputScenarioFamilyAutocorrection,
    IDTextInputScenarioFamilyInlinePrediction,
    IDTextInputScenarioFamilyInlineFormatting,
};

typedef NS_ENUM(NSInteger, IDTextInputHostKind) {
    IDTextInputHostKindStock,
    IDTextInputHostKindReference,
    IDTextInputHostKindMinimal,
};

typedef NS_ENUM(NSInteger, IDTextInputExecutionOrder) {
    IDTextInputExecutionOrderStockReferenceMinimal,
    IDTextInputExecutionOrderMinimalReferenceStock,
};

typedef NS_ENUM(NSInteger, IDTextInputTransactionKind) {
    IDTextInputTransactionKindBecomeFirstResponder,
    IDTextInputTransactionKindResignFirstResponder,
    IDTextInputTransactionKindSetSelection,
    IDTextInputTransactionKindSetMarkedText,
    IDTextInputTransactionKindUnmarkText,
    IDTextInputTransactionKindInsertText,
    IDTextInputTransactionKindDeleteBackward,
    IDTextInputTransactionKindReplaceRange,
    IDTextInputTransactionKindBeginUndoGroup,
    IDTextInputTransactionKindEndUndoGroup,
    IDTextInputTransactionKindUndo,
    IDTextInputTransactionKindRedo,
    IDTextInputTransactionKindSetTraits,
    IDTextInputTransactionKindToggleInlineTrait,
    IDTextInputTransactionKindCheckpoint,
};

@interface IDTextInputTransaction : NSObject

@property(nonatomic, readonly) IDTextInputTransactionKind kind;
@property(nonatomic, copy, readonly, nullable) NSString *text;
@property(nonatomic, copy, readonly, nullable) NSValue *rangeValue;
@property(nonatomic, copy, readonly, nullable) NSValue *selectedRangeValue;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, id> *traits;
@property(nonatomic, copy, readonly, nullable) NSString *trait;
@property(nonatomic, copy, readonly, nullable) NSString *phase;

@end

@interface IDTextInputScenario : NSObject

@property(nonatomic, readonly) NSInteger schemaVersion;
@property(nonatomic, readonly) IDTextInputScenarioFamily family;
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *initialText;
@property(nonatomic, readonly) NSRange initialSelection;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, id> *initialTraits;
@property(nonatomic, copy, readonly)
    NSArray<IDTextInputTransaction *> *transactions;
@property(nonatomic, copy, readonly)
    NSArray<NSString *> *comparisonFields;
@property(nonatomic, readonly) CGFloat geometryTolerance;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, id> *provenance;

@end

FOUNDATION_EXPORT NSString *const IDTextInputScenarioErrorDomain;

FOUNDATION_EXPORT NSArray<IDTextInputScenario *> * _Nullable
IDLoadTextInputScenarios(NSURL *fixtureURL, NSError **error);

NS_ASSUME_NONNULL_END
