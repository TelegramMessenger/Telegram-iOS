/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTDropResponseContext.h"

@implementation MTDropResponseContext

- (instancetype)initWithDropMessageId:(int64_t)dropMessageId
{
    self = [super init];
    if (self != nil)
    {
        _dropMessageId = dropMessageId;
    }
    return self;
}

@end
