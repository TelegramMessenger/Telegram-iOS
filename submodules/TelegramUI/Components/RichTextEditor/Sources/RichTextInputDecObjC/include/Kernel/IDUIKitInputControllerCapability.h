#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

#import "IDUIKitBehaviorReport.h"
#import "IDUIKitCapabilityResolver.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const
    IDUIKitInputControllerCapabilityErrorDomain;

@interface IDUIKitInputControllerCapability :
    NSObject <UITextInput, UIKeyInput>

@property(nonatomic, strong, readonly) id privateController;
@property(nonatomic, strong, readonly) NSUndoManager *undoManager;
@property(nonatomic, copy)
    NSDictionary<NSAttributedStringKey, id> *typingAttributes;
@property(nonatomic, strong, readonly, nullable) id id_textInputTraits;
@property(nonatomic, strong, readonly)
    IDUIKitCapabilityReport *report;

- (nullable instancetype)initWithContract:
    (IDUIKitRuntimeCapabilityContract *)contract
                                resolver:(IDUIKitCapabilityResolver *)resolver
                        layoutController:(id)layoutController
                                delegate:(id)delegate
                                   error:(NSError **)error;
- (nullable instancetype)initAdoptingPrivateController:(id)controller
                                              contract:
    (IDUIKitRuntimeCapabilityContract *)contract
                                              resolver:
    (IDUIKitCapabilityResolver *)resolver
                                                 error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;

- (void)setValidatedOptionalCapabilities:
    (IDUIKitBehaviorCapabilities)capabilities;
- (void)setAllowedTypingAttributeNames:
    (NSSet<NSAttributedStringKey> *)attributeNames;
- (void)invalidateTypingAttributes;
- (void)performWhileSuppressingDelegateNotifications:
    (void (NS_NOESCAPE ^)(void))body;
- (void)preflightBackwardDeleteRanges;
- (NSRange)backwardDeleteRange;
- (BOOL)shouldHandlePasteAction:(SEL)action
                         sender:(nullable id)sender;
- (void)performCut:(nullable id)sender;
- (void)performCopy:(nullable id)sender;
- (void)performPaste:(nullable id)sender;
- (void)id_setContinuousSpellCheckingEnabled:(BOOL)enabled;
- (BOOL)id_isContinuousSpellCheckingEnabled;
- (BOOL)insertDictationResultIfSupported:
    (NSArray<UIDictationPhrase *> *)dictationResult;
- (void)detach;

@end

NS_ASSUME_NONNULL_END

#endif
