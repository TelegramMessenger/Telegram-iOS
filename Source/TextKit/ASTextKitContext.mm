//
//  ASTextKitContext.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTextKitContext.h>

#if AS_ENABLE_TEXTNODE

#import <AsyncDisplayKit/ASLayoutManager.h>
#import <AsyncDisplayKit/ASThread.h>

#include <memory>

@implementation ASTextKitContext
{
  // All TextKit operations (even non-mutative ones) must be executed serially.
  std::shared_ptr<ASDN::Mutex> __instanceLock__;

  NSLayoutManager *_layoutManager;
  NSTextStorage *_textStorage;
  NSTextContainer *_textContainer;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
                           lineBreakMode:(NSLineBreakMode)lineBreakMode
                    maximumNumberOfLines:(NSUInteger)maximumNumberOfLines
                          exclusionPaths:(NSArray *)exclusionPaths
                         constrainedSize:(CGSize)constrainedSize

{
  if (self = [super init]) {
    static dispatch_once_t onceToken;
    static ASDN::Mutex *mutex;
    dispatch_once(&onceToken, ^{
      mutex = new ASDN::Mutex();
    });
    
    // Concurrently initialising TextKit components crashes (rdar://18448377) so we use a global lock.
    ASDN::MutexLocker l(*mutex);
    
    __instanceLock__ = std::make_shared<ASDN::Mutex>();
    
    // Create the TextKit component stack with our default configuration.
    
    _textStorage = [[NSTextStorage alloc] init];
    _layoutManager = [[ASLayoutManager alloc] init];
    _layoutManager.usesFontLeading = NO;
    [_textStorage addLayoutManager:_layoutManager];
    
    // Instead of calling [NSTextStorage initWithAttributedString:], setting attributedString just after calling addlayoutManager can fix CJK language layout issues.
    // See https://github.com/facebook/AsyncDisplayKit/issues/2894
    if (attributedString) {
      [_textStorage setAttributedString:attributedString];
    }
    
    _textContainer = [[NSTextContainer alloc] initWithSize:constrainedSize];
    // We want the text laid out up to the very edges of the container.
    _textContainer.lineFragmentPadding = 0;
    _textContainer.lineBreakMode = lineBreakMode;
    _textContainer.maximumNumberOfLines = maximumNumberOfLines;
    _textContainer.exclusionPaths = exclusionPaths;
    [_layoutManager addTextContainer:_textContainer];
  }
  return self;
}

- (void)performBlockWithLockedTextKitComponents:(NS_NOESCAPE void (^)(NSLayoutManager *,
                                                                      NSTextStorage *,
                                                                      NSTextContainer *))block
{
  ASDN::MutexLocker l(*__instanceLock__);
  if (block) {
    block(_layoutManager, _textStorage, _textContainer);
  }
}

@end

#endif
