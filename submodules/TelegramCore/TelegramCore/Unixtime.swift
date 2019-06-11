import Foundation

public struct DateTime {
    public let seconds: Int32 // 0 ... 59
    public let minutes: Int32 // 0 ... 59
    public let hours: Int32 // 0 ... 23
    public let dayOfMonth: Int32 // 1 ... 31
    public let month: Int32 // 0 ... 11
    public let year: Int32 // since 1900
    public let dayOfWeek: Int32 // 0 ... 6
    public let dayOfYear: Int32  // 0 ... 365
}

private let daysSinceJan1st: [[UInt32]] =
[
    [0,31,59,90,120,151,181,212,243,273,304,334,365], // 365 days, non-leap
    [0,31,60,91,121,152,182,213,244,274,305,335,366]  // 366 days, leap
]

public func secondsSinceEpochToDateTime(_ secondsSinceEpoch: Int64) -> DateTime {
    var sec: UInt64
    let quadricentennials: UInt32
    var centennials: UInt32
    var quadrennials: UInt32
    var annuals: UInt32
    let year: UInt32
    let leap: UInt32
    let yday: UInt32
    let hour: UInt32
    let min: UInt32
    var month: UInt32
    var mday: UInt32
    let wday: UInt32
    
    /*
     400 years:
     
     1st hundred, starting immediately after a leap year that's a multiple of 400:
     n n n l  \
     n n n l   } 24 times
     ...      /
     n n n l /
     n n n n
     
     2nd hundred:
     n n n l  \
     n n n l   } 24 times
     ...      /
     n n n l /
     n n n n
     
     3rd hundred:
     n n n l  \
     n n n l   } 24 times
     ...      /
     n n n l /
     n n n n
     
     4th hundred:
     n n n l  \
     n n n l   } 24 times
     ...      /
     n n n l /
     n n n L <- 97'th leap year every 400 years
     */
    
    // Re-bias from 1970 to 1601:
    // 1970 - 1601 = 369 = 3*100 + 17*4 + 1 years (incl. 89 leap days) =
    // (3*100*(365+24/100) + 17*4*(365+1/4) + 1*365)*24*3600 seconds
    sec = UInt64(secondsSinceEpoch) + (11644473600 as UInt64)
    
    wday = (uint)((sec / 86400 + 1) % 7); // day of week
    
    // Remove multiples of 400 years (incl. 97 leap days)
    quadricentennials = UInt32((UInt64(sec) / (12622780800 as UInt64))) // 400*365.2425*24*3600
    sec %= 12622780800 as UInt64
    
    // Remove multiples of 100 years (incl. 24 leap days), can't be more than 3
    // (because multiples of 4*100=400 years (incl. leap days) have been removed)
    centennials = UInt32(UInt64(sec) / (3155673600 as UInt64)) // 100*(365+24/100)*24*3600
    if centennials > 3 {
        centennials = 3
    }
    sec -= UInt64(centennials) * (3155673600 as UInt64)
    
    // Remove multiples of 4 years (incl. 1 leap day), can't be more than 24
    // (because multiples of 25*4=100 years (incl. leap days) have been removed)
    quadrennials = UInt32((UInt64(sec) / (126230400 as UInt64))) // 4*(365+1/4)*24*3600
    if quadrennials > 24 {
        quadrennials = 24
    }
    sec -= UInt64(quadrennials) * (126230400 as UInt64)
    
    // Remove multiples of years (incl. 0 leap days), can't be more than 3
    // (because multiples of 4 years (incl. leap days) have been removed)
    annuals = UInt32(sec / (31536000 as UInt64)) // 365*24*3600
    if annuals > 3 {
        annuals = 3
    }
    sec -= UInt64(annuals) * (31536000 as UInt64)
    
    // Calculate the year and find out if it's leap
    year = 1601 + quadricentennials * 400 + centennials * 100 + quadrennials * 4 + annuals;
    leap = (!(year % UInt32(4) != 0) && ((year % UInt32(100) != 0) || !(year % UInt32(400) != 0))) ? 1 : 0
    
    // Calculate the day of the year and the time
    yday = UInt32(sec / (86400 as UInt64))
    sec %= 86400;
    hour = UInt32(sec / 3600);
    sec %= 3600;
    min = UInt32(sec / 60);
    sec %= 60;
    
    mday = 1
    month = 1
    while month < 13 {
        if (yday < daysSinceJan1st[Int(leap)][Int(month)]) {
            mday += yday - daysSinceJan1st[Int(leap)][Int(month - 1)]
            break
        }
        
        month += 1
    }
    
    return DateTime(seconds: Int32(sec), minutes: Int32(min), hours: Int32(hour), dayOfMonth: Int32(mday), month: Int32(month - 1), year: Int32(year - 1900), dayOfWeek: Int32(wday), dayOfYear: Int32(yday))
}
