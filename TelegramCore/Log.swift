import Foundation
import TelegramCorePrivateModule

private let queue = DispatchQueue(label: "org.telegram.Telegram.trace", qos: .background)

public func trace(_ what: @autoclosure() -> String) {
    let string = what()
    var rawTime = time_t()
    time(&rawTime)
    var timeinfo = tm()
    localtime_r(&rawTime, &timeinfo)
    
    var curTime = timeval()
    gettimeofday(&curTime, nil)
    let milliseconds = curTime.tv_usec / 1000
    
    queue.async {
        let result = String(format: "%d-%d-%d %02d:%02d:%03d %@", arguments: [Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_yday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(milliseconds), string])
        print(result)
    }
}

public func trace(_ domain: String, what: @autoclosure() -> String) {
    let string = what()
    var rawTime = time_t()
    time(&rawTime)
    var timeinfo = tm()
    localtime_r(&rawTime, &timeinfo)
    
    var curTime = timeval()
    gettimeofday(&curTime, nil)
    let milliseconds = curTime.tv_usec / 1000
    
    queue.async {
        let result = String(format: "[%@] %d-%d-%d %02d:%02d:%03d %@", arguments: [domain, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_yday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(milliseconds), string])
        
        #if (arch(i386) || arch(x86_64))
        print(result)
        #endif
    }
}

public func registerLoggingFunctions() {
    setBridgingTraceFunction({ domain, what in
        if let what = what {
            if let domain = domain {
                trace(domain as String, what: what as String)
            } else {
                trace(what as String)
            }
        }
    })
}
