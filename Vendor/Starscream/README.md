![starscream](https://raw.githubusercontent.com/daltoniam/starscream/assets/starscream.jpg)

Starscream is a conforming WebSocket ([RFC 6455](http://tools.ietf.org/html/rfc6455)) library in Swift.

## Features

- Conforms to all of the base [Autobahn test suite](https://crossbar.io/autobahn/).
- Nonblocking. Everything happens in the background, thanks to GCD.
- TLS/WSS support.
- Compression Extensions support ([RFC 7692](https://tools.ietf.org/html/rfc7692))

### Import the framework

First thing is to import the framework. See the Installation instructions on how to add the framework to your project.

```swift
import Starscream
```

### Connect to the WebSocket Server

Once imported, you can open a connection to your WebSocket server. Note that `socket` is probably best as a property, so it doesn't get deallocated right after being setup.

```swift
var request = URLRequest(url: URL(string: "http://localhost:8080")!)
request.timeoutInterval = 5
socket = WebSocket(request: request)
socket.delegate = self
socket.connect()
```

After you are connected, there is either a delegate or closure you can use for process WebSocket events.

### Receiving data from a WebSocket

`didReceive` receives all the WebSocket events in a single easy to handle enum.

```swift
func didReceive(event: WebSocketEvent, client: WebSocket) {
	switch event {
	case .connected(let headers):
		isConnected = true
		print("websocket is connected: \(headers)")
	case .disconnected(let reason, let code):
		isConnected = false
		print("websocket is disconnected: \(reason) with code: \(code)")
	case .text(let string):
		print("Received text: \(string)")
	case .binary(let data):
		print("Received data: \(data.count)")
	case .ping(_):
		break
	case .pong(_):
		break
	case .viabilityChanged(_):
		break
	case .reconnectSuggested(_):
		break
	case .cancelled:
		isConnected = false
	case .error(let error):
		isConnected = false
		handleError(error)
	}
}
```

The closure of this would be:

```swift
socket.onEvent = { event in
	switch event {
		// handle events just like above...
	}
}
```

### Writing to a WebSocket

### write a binary frame

The writeData method gives you a simple way to send `Data` (binary) data to the server.

```swift
socket.write(data: data) //write some Data over the socket!
```

### write a string frame

The writeString method is the same as writeData, but sends text/string.

```swift
socket.write(string: "Hi Server!") //example on how to write text over the socket!
```

### write a ping frame

The writePing method is the same as write, but sends a ping control frame.

```swift
socket.write(ping: Data()) //example on how to write a ping control frame over the socket!
```

### write a pong frame


the writePong method is the same as writePing, but sends a pong control frame.

```swift
socket.write(pong: Data()) //example on how to write a pong control frame over the socket!
```

Starscream will automatically respond to incoming `ping` control frames so you do not need to manually send `pong`s.

However if for some reason you need to control this process you can turn off the automatic `ping` response by disabling `respondToPingWithPong`.

```swift
socket.respondToPingWithPong = false //Do not automaticaly respond to incoming pings with pongs.
```

In most cases you will not need to do this.

### disconnect

The disconnect method does what you would expect and closes the socket.

```swift
socket.disconnect()
```

The disconnect method can also send a custom close code if desired.

```swift
socket.disconnect(closeCode: CloseCode.normal.rawValue)
```

### Custom Headers, Protocols and Timeout

You can override the default websocket headers, add your own custom ones and set a timeout:

```swift
var request = URLRequest(url: URL(string: "ws://localhost:8080/")!)
request.timeoutInterval = 5 // Sets the timeout for the connection
request.setValue("someother protocols", forHTTPHeaderField: "Sec-WebSocket-Protocol")
request.setValue("14", forHTTPHeaderField: "Sec-WebSocket-Version")
request.setValue("chat,superchat", forHTTPHeaderField: "Sec-WebSocket-Protocol")
request.setValue("Everything is Awesome!", forHTTPHeaderField: "My-Awesome-Header")
let socket = WebSocket(request: request)
```

### SSL Pinning

SSL Pinning is also supported in Starscream.


Allow Self-signed certificates:

```swift
var request = URLRequest(url: URL(string: "ws://localhost:8080/")!)
let pinner = FoundationSecurity(allowSelfSigned: true) // don't validate SSL certificates
let socket = WebSocket(request: request, certPinner: pinner)
```

TODO: Update docs on how to load certificates and public keys into an app bundle, use the builtin pinner and TrustKit.

### Compression Extensions

Compression Extensions ([RFC 7692](https://tools.ietf.org/html/rfc7692)) is supported in Starscream.  Compression is enabled by default, however compression will only be used if it is supported by the server as well.  You may enable or disable compression via the `.enableCompression` property:

```swift
var request = URLRequest(url: URL(string: "ws://localhost:8080/")!)
let compression = WSCompression()
let socket = WebSocket(request: request, compressionHandler: compression)
```

Compression should be disabled if your application is transmitting already-compressed, random, or other uncompressable data.

### Custom Queue

A custom queue can be specified when delegate methods are called. By default `DispatchQueue.main` is used, thus making all delegate methods calls run on the main thread. It is important to note that all WebSocket processing is done on a background thread, only the delegate method calls are changed when modifying the queue. The actual processing is always on a background thread and will not pause your app.

```swift
socket = WebSocket(url: URL(string: "ws://localhost:8080/")!, protocols: ["chat","superchat"])
//create a custom queue
socket.callbackQueue = DispatchQueue(label: "com.vluxe.starscream.myapp")
```

## Example Project

Check out the SimpleTest project in the examples directory to see how to setup a simple connection to a WebSocket server.

## Requirements

Starscream works with iOS 8/10.10 or above for CocoaPods/framework support. To use Starscream with a project targeting iOS 7, you must include all Swift files directly in your project.

## Installation

### CocoaPods

Check out [Get Started](http://cocoapods.org/) tab on [cocoapods.org](http://cocoapods.org/).

To use Starscream in your project add the following 'Podfile' to your project

	source 'https://github.com/CocoaPods/Specs.git'
	platform :ios, '9.0'
	use_frameworks!

	pod 'Starscream', '~> 4.0.0'

Then run:

    pod install

### Carthage

Check out the [Carthage](https://github.com/Carthage/Carthage) docs on how to add a install. The `Starscream` framework is already setup with shared schemes.

[Carthage Install](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application)

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate Starscream into your Xcode project using Carthage, specify it in your `Cartfile`:

```
github "daltoniam/Starscream" >= 4.0.0
```

### Accio

Check out the [Accio](https://github.com/JamitLabs/Accio) docs on how to add a install. 

Add the following to your Package.swift:

```swift
.package(url: "https://github.com/daltoniam/Starscream.git", .upToNextMajor(from: "4.0.0")),
```

Next, add `Starscream` to your App targets dependencies like so:

```swift
.target(
    name: "App",
    dependencies: [
        "Starscream",
    ]
),
```

Then run `accio update`.

### Rogue

First see the [installation docs](https://github.com/acmacalister/Rogue) for how to install Rogue.

To install Starscream run the command below in the directory you created the rogue file.

```
rogue add https://github.com/daltoniam/Starscream
```

Next open the `libs` folder and add the `Starscream.xcodeproj` to your Xcode project. Once that is complete, in your "Build Phases" add the `Starscream.framework` to your "Link Binary with Libraries" phase. Make sure to add the `libs` folder to your `.gitignore` file.

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.

Once you have your Swift package set up, adding Starscream as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .Package(url: "https://github.com/daltoniam/Starscream.git", majorVersion: 4)
]
```

### Other

Simply grab the framework (either via git submodule or another package manager).

Add the `Starscream.xcodeproj` to your Xcode project. Once that is complete, in your "Build Phases" add the `Starscream.framework` to your "Link Binary with Libraries" phase.

### Add Copy Frameworks Phase

If you are running this in an OSX app or on a physical iOS device you will need to make sure you add the `Starscream.framework` to be included in your app bundle. To do this, in Xcode, navigate to the target configuration window by clicking on the blue project icon, and selecting the application target under the "Targets" heading in the sidebar. In the tab bar at the top of that window, open the "Build Phases" panel. Expand the "Link Binary with Libraries" group, and add `Starscream.framework`. Click on the + button at the top left of the panel and select "New Copy Files Phase". Rename this new phase to "Copy Frameworks", set the "Destination" to "Frameworks", and add `Starscream.framework` respectively.

## TODOs

- [ ] Proxy support

## License

Starscream is licensed under the Apache v2 License.

## Contact

### Dalton Cherry
* https://github.com/daltoniam
* http://twitter.com/daltoniam
* http://daltoniam.com

### Austin Cherry ###
* https://github.com/acmacalister
* http://twitter.com/acmacalister
* http://austincherry.me
