#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"

#import "TGPrivateMethodAliases.h"

#import "IDNativeSelectionPresentationBackend.h"

#import "IDBlockStackCanvasView.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"

@interface IDNativeSelectionPresentationBackend ()
@property(nonatomic, weak) IDBlockTextView *hostView;
@property(nonatomic, strong, nullable, readwrite) UIView *existingSelectionContainerView;
@property(nonatomic, readwrite) NSUInteger presentationUpdateCount;
@property(nonatomic, readwrite) NSUInteger selectionContainerCreationCount;
- (CGRect)containerFrame;
@end

@implementation IDNativeSelectionPresentationBackend

// Renamed members keep their previous selectors at run time (`TGPrivateMethodAliases.h`): the names are
// UIKit's private ones, which must not be compiled into the binary, and this object may be reached by
// them, as the layout controller's connection is.
+ (void)initialize {
    if (self != IDNativeSelectionPresentationBackend.class) {
        return;
    }
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_selectionContainerView, @selector(id_selectionContainerView) },
    };
    TGPrivateInstallMethodAliases(self, aliases, sizeof(aliases) / sizeof(aliases[0]));
}


- (instancetype)initWithHostView:(IDBlockTextView *)hostView {
    if (hostView == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Native selection presentation requires a host view"];
    }
    self = [super init];
    if (self != nil) {
        _hostView = hostView;
    }
    return self;
}

- (UIView *)id_selectionContainerView {
    if (self.existingSelectionContainerView == nil) {
        IDBlockTextView *hostView = self.hostView;
        if (hostView == nil) {
            [NSException raise:NSInternalInconsistencyException
                        format:@"Selection presentation host was released"];
        }
        UIView *container = [[UIView alloc] initWithFrame:[self containerFrame]];
        container.userInteractionEnabled = NO;
        container.backgroundColor = UIColor.clearColor;
        self.existingSelectionContainerView = container;
        [hostView addSubview:container];
        self.selectionContainerCreationCount += 1;
    }
    return self.existingSelectionContainerView;
}

/// Where the container goes: at the block stack's origin, NOT at the host's `bounds`.
///
/// UIKit hangs its selection views — the autocorrection underline among them — inside this
/// container, and it moves geometry across the two spaces in both directions: it converts a
/// selection rect INTO the container (from `-textInputView`, which is the block stack) and later
/// reads those same numbers back relative to `-textInputView` again, without a second conversion.
/// The two spaces must therefore be ONE. A stock text view satisfies that by construction — its
/// container reports (0, 0) as its origin in its own `-textInputView` at every scroll offset — and
/// this view satisfies it by starting where the stack starts. Anchoring the container to `bounds`
/// instead put the spaces one content offset apart, and the prompt offering the original spelling of
/// a corrected word came up that far BELOW the word (device, 2026-09-11: the word at window y 269.3
/// against a prompt at 337.3, the editor's 68pt top inset).
///
/// The SIZE stays the host's viewport: it takes no part in the mapping (the container does not clip)
/// and a container covering what is on screen is what the selection views expect.
- (CGRect)containerFrame {
    IDBlockTextView *hostView = self.hostView;
    if (hostView == nil) {
        return CGRectZero;
    }
    IDBlockStackCanvasView *stack = hostView.id_blockStackCanvasView;
    CGPoint origin = stack == nil ? CGPointZero : stack.frame.origin;
    return (CGRect){origin, hostView.bounds.size};
}

- (void)placeSelectionContainerView {
    UIView *container = [self id_selectionContainerView];
    IDBlockTextView *hostView = self.hostView;
    if (container != nil && hostView != nil) {
        container.frame = [self containerFrame];
        [hostView bringSubviewToFront:container];
    }
}

- (void)updateWithSnapshot:(IDSelectionPresentationSnapshot *)snapshot {
    if (snapshot == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Selection presentation snapshot is nil"];
    }
    self.presentationUpdateCount += 1;
    [self placeSelectionContainerView];
}

- (void)tearDown {
    [self.existingSelectionContainerView removeFromSuperview];
    self.existingSelectionContainerView = nil;
}

@end

#endif
