/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTTime.h>

#import <mach/mach_time.h>

MTAbsoluteTime MTAbsoluteSystemTime()
{
    static mach_timebase_info_data_t s_timebase_info;
    if (s_timebase_info.denom == 0)
        mach_timebase_info(&s_timebase_info);
    
    return ((MTAbsoluteTime)(mach_absolute_time() * s_timebase_info.numer)) / (s_timebase_info.denom * NSEC_PER_SEC);
}
