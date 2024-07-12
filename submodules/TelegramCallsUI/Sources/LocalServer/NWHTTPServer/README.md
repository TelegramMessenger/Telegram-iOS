#  NWHTTPServer

![Swift5](https://img.shields.io/badge/swift-5-blue.svg?style=flat)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![iOS](https://img.shields.io/badge/os-iOS-green.svg?style=flat)

A very simple HTTP server
for the Apple 
[Network](https://developer.apple.com/documentation/network).framework.
Based on the `NWHTTPProtocol`.

Example:
```swift
let server = HTTPServer { request, response in
    print("Received:", request)
    try response.send("Hello!\n")
}
server.run()
```

### Who

**NWHTTPProtocol** is brought to you by
the
[Always Right Institute](http://www.alwaysrightinstitute.com)
and
[ZeeZide](http://zeezide.de).
We like 
[feedback](https://twitter.com/ar_institute), 
GitHub stars, 
cool [contract work](http://zeezide.com/en/services/services.html),
presumably any form of praise you can think of.
