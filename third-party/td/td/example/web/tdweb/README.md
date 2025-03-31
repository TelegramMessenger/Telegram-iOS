## tdweb - TDLib in a browser

[TDLib](https://github.com/tdlib/td) is a library for building Telegram clients. tdweb is a convenient wrapper for TDLib in a browser which controls TDLib instance creation,
handles interaction with TDLib and manages a filesystem for persistent TDLib data.

For interaction with TDLib, you need to create an instance of the class `TdClient`, providing a handler for incoming updates and other options if needed.
Once this is done, you can send queries to the TDLib instance using the method `TdClient.send` which returns a Promise object representing the result of the query.

See [Getting Started](https://core.telegram.org/tdlib/getting-started) for a description of basic TDLib concepts and a short introduction to TDLib usage.

See the [td_api.tl](https://github.com/tdlib/td/blob/master/td/generate/scheme/td_api.tl) scheme or
the automatically generated [HTML documentation](https://core.telegram.org/tdlib/docs/td__api_8h.html) for a list of all available
TDLib [methods](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1_function.html) and [classes](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1_object.html).
The JSON representation of TDLib API objects is straightforward: all API objects are represented as JSON objects with the same keys as the API object field names in the
[td_api.tl](https://github.com/tdlib/td/blob/master/td/generate/scheme/td_api.tl) scheme. Note that in the automatically generated C++ documentation all fields have an additional terminating underscore
which shouldn't be used in the JSON interface. The object type name is stored in the special field '@type' which is optional in places where type is uniquely determined by the context.
Fields of Bool type are stored as Boolean, fields of int32, int53, and double types are stored as Number, fields of int64 and string types are stored as String,
fields of bytes type are base64 encoded and then stored as String, fields of array type are stored as Array.
You can also add the field '@extra' to any query to TDLib and the response will contain the field '@extra' with exactly the same value.

## Installation
As usual, add npm tdweb package into your project:
```
npm install tdweb
```

All files will be installed into `node_modules/tdweb/dist/` folder. For now, it is your responsibility to make
those files loadable from your server. For example, [telegram-react](https://github.com/evgeny-nadymov/telegram-react)
manually copies these files into the `public` folder. If you know how to avoid this problem, please tell us.
