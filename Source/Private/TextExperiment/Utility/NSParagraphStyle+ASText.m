//
//  NSParagraphStyle+ASText.m
//  Modified from YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 14/10/7.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <AsyncDisplayKit/NSParagraphStyle+ASText.h>
#import <AsyncDisplayKit/ASTextAttribute.h>
#import <CoreText/CoreText.h>

// Dummy class for category
@interface NSParagraphStyle_ASText : NSObject @end
@implementation NSParagraphStyle_ASText @end


@implementation NSParagraphStyle (ASText)

+ (NSParagraphStyle *)as_styleWithCTStyle:(CTParagraphStyleRef)CTStyle {
  if (CTStyle == NULL) return nil;
  
  NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  
#if TARGET_OS_IOS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CGFloat lineSpacing;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierLineSpacing, sizeof(CGFloat), &lineSpacing)) {
    style.lineSpacing = lineSpacing;
  }
#pragma clang diagnostic pop
#endif
  
  CGFloat paragraphSpacing;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierParagraphSpacing, sizeof(CGFloat), &paragraphSpacing)) {
    style.paragraphSpacing = paragraphSpacing;
  }
  
  CTTextAlignment alignment;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierAlignment, sizeof(CTTextAlignment), &alignment)) {
    style.alignment = NSTextAlignmentFromCTTextAlignment(alignment);
  }
  
  CGFloat firstLineHeadIndent;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierFirstLineHeadIndent, sizeof(CGFloat), &firstLineHeadIndent)) {
    style.firstLineHeadIndent = firstLineHeadIndent;
  }
  
  CGFloat headIndent;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierHeadIndent, sizeof(CGFloat), &headIndent)) {
    style.headIndent = headIndent;
  }
  
  CGFloat tailIndent;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierTailIndent, sizeof(CGFloat), &tailIndent)) {
    style.tailIndent = tailIndent;
  }
  
  CTLineBreakMode lineBreakMode;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierLineBreakMode, sizeof(CTLineBreakMode), &lineBreakMode)) {
    style.lineBreakMode = (NSLineBreakMode)lineBreakMode;
  }
  
  CGFloat minimumLineHeight;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierMinimumLineHeight, sizeof(CGFloat), &minimumLineHeight)) {
    style.minimumLineHeight = minimumLineHeight;
  }
  
  CGFloat maximumLineHeight;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierMaximumLineHeight, sizeof(CGFloat), &maximumLineHeight)) {
    style.maximumLineHeight = maximumLineHeight;
  }
  
  CTWritingDirection baseWritingDirection;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierBaseWritingDirection, sizeof(CTWritingDirection), &baseWritingDirection)) {
    style.baseWritingDirection = (NSWritingDirection)baseWritingDirection;
  }
  
  CGFloat lineHeightMultiple;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierLineHeightMultiple, sizeof(CGFloat), &lineHeightMultiple)) {
    style.lineHeightMultiple = lineHeightMultiple;
  }
  
  CGFloat paragraphSpacingBefore;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierParagraphSpacingBefore, sizeof(CGFloat), &paragraphSpacingBefore)) {
    style.paragraphSpacingBefore = paragraphSpacingBefore;
  }
  
  CFArrayRef tabStops;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierTabStops, sizeof(CFArrayRef), &tabStops)) {
    NSMutableArray *tabs = [NSMutableArray new];
    [((__bridge NSArray *)(tabStops))enumerateObjectsUsingBlock : ^(id obj, NSUInteger idx, BOOL *stop) {
      CTTextTabRef ctTab = (__bridge CTTextTabRef)obj;
      
      NSTextTab *tab = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentFromCTTextAlignment(CTTextTabGetAlignment(ctTab)) location:CTTextTabGetLocation(ctTab) options:(__bridge id)CTTextTabGetOptions(ctTab)];
      [tabs addObject:tab];
    }];
    if (tabs.count) {
      style.tabStops = tabs;
    }
  }
  
  CGFloat defaultTabInterval;
  if (CTParagraphStyleGetValueForSpecifier(CTStyle, kCTParagraphStyleSpecifierDefaultTabInterval, sizeof(CGFloat), &defaultTabInterval)) {
    style.defaultTabInterval = defaultTabInterval;
  }
  
  return style;
}

- (CTParagraphStyleRef)as_CTStyle CF_RETURNS_RETAINED {
  CTParagraphStyleSetting set[kCTParagraphStyleSpecifierCount] = { };
  int count = 0;
  
#if TARGET_OS_IOS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CGFloat lineSpacing = self.lineSpacing;
  set[count].spec = kCTParagraphStyleSpecifierLineSpacing;
  set[count].valueSize = sizeof(CGFloat);
  set[count].value = &lineSpacing;
  count++;
#pragma clang diagnostic pop
#endif
  
  CGFloat paragraphSpacing = self.paragraphSpacing;
  set[count].spec = kCTParagraphStyleSpecifierParagraphSpacing;
  set[count].valueSize = sizeof(CGFloat);
  set[count].value = &paragraphSpacing;
  count++;
  
  CTTextAlignment alignment = NSTextAlignmentToCTTextAlignment(self.alignment);
  set[count].spec = kCTParagraphStyleSpecifierAlignment;
  set[count].valueSize = sizeof(CTTextAlignment);
  set[count].value = &alignment;
  count++;
  
  CGFloat firstLineHeadIndent = self.firstLineHeadIndent;
  set[count].spec = kCTParagraphStyleSpecifierFirstLineHeadIndent;
  set[count].valueSize = sizeof(CGFloat);
  set[count].value = &firstLineHeadIndent;
  count++;
  
  CGFloat headIndent = self.headIndent;
  set[count].spec = kCTParagraphStyleSpecifierHeadIndent;
  set[count].valueSize = sizeof(CGFloat);
  set[count].value = &headIndent;
  count++;
  
  CGFloat tailIndent = self.tailIndent;
  set[count].spec = kCTParagraphStyleSpecifierTailIndent;
  set[count].valueSize = sizeof(CGFloat);
  set[count].value = &tailIndent;
  count++;
  
  CTLineBreakMode paraLineBreak = (CTLineBreakMode)self.lineBreakMode;
  set[count].spec = kCTParagraphStyleSpecifierLineBreakMode;
  set[count].valueSize = sizeof(CTLineBreakMode);
  set[count].value = &paraLineBreak;
  count++;
  
  CGFloat minimumLineHeight = self.minimumLineHeight;
  set[count].spec = kCTParagraphStyleSpecifierMinimumLineHeight;
  set[count].valueSize = sizeof(CGFloat);
  set[count].value = &minimumLineHeight;
  count++;
  
  CGFloat maximumLineHeight = self.maximumLineHeight;
  set[count].spec = kCTParagraphStyleSpecifierMaximumLineHeight;
  set[count].valueSize = sizeof(CGFloat);
  set[count].value = &maximumLineHeight;
  count++;
  
  CTWritingDirection paraWritingDirection = (CTWritingDirection)self.baseWritingDirection;
  set[count].spec = kCTParagraphStyleSpecifierBaseWritingDirection;
  set[count].valueSize = sizeof(CTWritingDirection);
  set[count].value = &paraWritingDirection;
  count++;
  
  CGFloat lineHeightMultiple = self.lineHeightMultiple;
  set[count].spec = kCTParagraphStyleSpecifierLineHeightMultiple;
  set[count].valueSize = sizeof(CGFloat);
  set[count].value = &lineHeightMultiple;
  count++;
  
  CGFloat paragraphSpacingBefore = self.paragraphSpacingBefore;
  set[count].spec = kCTParagraphStyleSpecifierParagraphSpacingBefore;
  set[count].valueSize = sizeof(CGFloat);
  set[count].value = &paragraphSpacingBefore;
  count++;
  
  NSMutableArray *tabs = [NSMutableArray array];
  NSInteger numTabs = self.tabStops.count;
  if (numTabs) {
    [self.tabStops enumerateObjectsUsingBlock: ^(NSTextTab *tab, NSUInteger idx, BOOL *stop) {
      CTTextTabRef ctTab = CTTextTabCreate(NSTextAlignmentToCTTextAlignment(tab.alignment), tab.location, (__bridge CFDictionaryRef)tab.options);
      [tabs addObject:(__bridge id)ctTab];
      CFRelease(ctTab);
    }];
    
    CFArrayRef tabStops = (__bridge CFArrayRef)(tabs);
    set[count].spec = kCTParagraphStyleSpecifierTabStops;
    set[count].valueSize = sizeof(CFArrayRef);
    set[count].value = &tabStops;
    count++;
  }
  
  CGFloat defaultTabInterval = self.defaultTabInterval;
  set[count].spec = kCTParagraphStyleSpecifierDefaultTabInterval;
  set[count].valueSize = sizeof(CGFloat);
  set[count].value = &defaultTabInterval;
  count++;
  
  CTParagraphStyleRef style = CTParagraphStyleCreate(set, count);
  return style;
}

@end
