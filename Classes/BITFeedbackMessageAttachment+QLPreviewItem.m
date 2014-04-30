//
//  BITFeedbackMessageAttachment+QLPreviewItem.m
//  HockeySDK
//
//  Created by Moritz Haarmann on 30.04.14.
//
//

#import "BITFeedbackMessageAttachment+QLPreviewItem.h"

@implementation BITFeedbackMessageAttachment (QLPreviewItem)

- (NSString *)previewItemTitle {
  return self.originalFilename;
}

- (NSURL *)previewItemURL {
  return self.localURL;
}

@end
