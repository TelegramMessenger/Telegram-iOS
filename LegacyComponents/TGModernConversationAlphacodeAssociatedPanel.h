#import "TGModernConversationAssociatedInputPanel.h"

#import <SSignalKit/SSignalKit.h>

@class TGAlphacodeEntry;

@interface TGModernConversationAlphacodeAssociatedPanel : TGModernConversationAssociatedInputPanel

@property (nonatomic, copy) void (^alphacodeSelected)(TGAlphacodeEntry *);

- (void)setAlphacodeListSignal:(SSignal *)alphacodeListSignal;

@end
