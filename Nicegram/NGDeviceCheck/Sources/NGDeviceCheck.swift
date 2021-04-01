import NGLogging
import DeviceCheck

fileprivate let LOGTAG = extractNameFromPath(#file)


public func getDeviceToken(completion: @escaping (String?) -> ()) {
    if #available(iOS 11.0, *) {
        let currentDevice = DCDevice.current
        if currentDevice.isSupported
        {
            currentDevice.generateToken(completionHandler: { (data, error) in
                if let tokenData = data {
                    let tokenString = tokenData.base64EncodedString()
                    #if DEBUG
                    ngLog("Received token \(tokenString)", LOGTAG)
                    #endif
                    ngLog("Received token \(tokenString.count)", LOGTAG)
                    completion(tokenString)
                } else{
                    ngLog("Error generating token: \(error!.localizedDescription)", LOGTAG)
                }
            })
        } else {
            ngLog("Device is not supported", LOGTAG)
        }
    } else {
        ngLog("Device is lower than iOS 11", LOGTAG)
    }
}

