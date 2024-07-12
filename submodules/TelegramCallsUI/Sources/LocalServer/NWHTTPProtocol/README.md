#  NWHTTPProtocol

![Swift5](https://img.shields.io/badge/swift-5-blue.svg?style=flat)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![iOS](https://img.shields.io/badge/os-iOS-green.svg?style=flat)

An HTTP protocol parser (aka 
[NWProtocolFramer](https://developer.apple.com/documentation/network/nwprotocolframer))
for the Apple 
[Network](https://developer.apple.com/documentation/network).framework.

Network.framework requires iOS 13+ / macOS 10.15+.

This is intentionally kept very simple and basic. E.g. it does not define
Swift types for HTTP requests and the like, but puts the status/request/URI in plain
`NWProtocolFramer.Message` metadata fields.

The protocol is just wrapping the (embedded) 
[http_parser.c/h](https://github.com/nodejs/http-parser/)
developed as part of the Node.js project.

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
