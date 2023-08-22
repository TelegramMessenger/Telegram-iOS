## WebAssembly demonstration

This folder contains an example how to decode JPEG XL files on a web page using
WASM engine.

### One line demo

The simplest way to get support of JXL images on the client side is simply to
link one extra script (`<script src="service_worker.js">`) to the page.
This script installs a `ServiceWorker` that:

 - checks if the browser supports the JXL image format already
 - if it is not, then advertise `image/jxl` as media format in image requests
 - then, if the server responds with `image/jxl` content it gets decoded and
   re-encoded to PNG on the fly

Generally the message / data flow looks the following way:

 - `Fetch API` receives a resource request from client page (e.g. when the HTML
   engine discovers an `img` tag) and asks the `ServiceWorker` how to proceed
 - the `ServiceWorker` alters the request and uses the `Fetch API`
   to obtain data
 - when data arrives, the `ServiceWorker` forwards it to the "client"
   (the page) that initiated the resource request
 - the client forwards the data to a worker (see `client_worker.js`) to avoid
   processing in the "main loop" thread
 - a worker does the actual decoding; to make it faster several additional
   workers are spawned (to enable multi-threading in WASM module);
   the decoded image is wrapped in non-compressed PNG format and sent back
   to client
 - the client relays image data to `ServiceWorker`
 - the `ServiceWorker` passes data to `Fetch API` as a response to initial
   resource request

Despite the additional "hop" (client) in the flow, data is not copied every
time but rather "transferred" between the participants.

Demo page: `one_line_demo.html`. Extended demo, that also shows how long it
took do decode images: `one_line_demo_with_console.html`.

Page that shows "manual" decoding (and has benchmarking capabilities):
`manual_decode_demo.html`.

### Hosting

To enable multi-threading some files should be served in a secure context (i.e.
transferred over HTTPS) and executed in a "site-isolation" mode (controlled by
COOP and COEP response headers).

Unfortunately [GitHub Pages](https://pages.github.com/) does not allow setting
response headers.

[Netlify](https://www.netlify.com/) provides free, easy to setup and deploy
platform for serving such demonstration sites. However, any other
service provider / software that allows changing response headers could be
employed as well.

`netlify.toml` and `netlify/precompressed.ts` specify the serving rules.
Namely, some requests get "upgraded" responses:

 - if a request specifies that `brotli` compression is supported,
   then precompressed entries are sent
 - if a request specifies that `image/jxl` format is allowed,
   then entries transcoded to JXL format are sent

### How to build the demo

`build_site.py` script takes care of JavaScript minification, template
substitution and resource compression. Its arguments are:

 - source path: site template directory (that contains this README file)
 - binary path: build directory, that contains compiled WASM module
 - output path

To complete the site few more files are to be added to output directory:

 - `image00.jpg`, `image01.png` demo images; will be shown if `ServiceWorker`
   is not yet operable (fallback); to see those one could initiate
   "hard page reload" (press Shift-(Ctrl|Cmd)-R)
 - `image00.jpg.jxl`, `image01.png.jxl` demo images in JXL format
 - `imageNN.jxl` images for "manual" decoding demo; NN is a number starting
   form `00`
 - `favicon.ico` is an optional site icon
 - `index.html` is an optional site "home" page

In the source code (`service_worker.js`) there are two compile-time constants
that modify the behaviour of Service Worker:

 - `FORCE_COP` flag allows rewriting responses to add COOP / COEP headers;
   this is useful when it is difficult / impossible to setup response headers
   otherwise (e.g. GitHub Pages)
 - `FORCE_DECODING` flag activate JXL decoding when image response type has
   `Content-Encoding` header set to `application/octet-stream`; this happens
   when server does not know the JXL MIME-type

One dependency that `build_site.py` requires is [uglifyjs](https://github.com/mishoo/UglifyJS), which can be installed with
```
npm install uglify-js -g
```
If you followed the [wasm build instructions](../../docs/building_wasm.md),
assuming you are in the root level of the cloned libjxl repo a typical call to
build the site would be
```bash
python3 ./tools/wasm_demo/build_site.py ./tools/wasm_demo/ ./build-wasm32/tools/wasm_demo/ /path/to/demo-site
```
Then you need to put your image files in the correct same place and are should be good to go.


To summarize, using the wasm decoder together with a service workder amounts to adding
```html
<script src="service_worker.js"></script>
```
to your html and then putting the `service_worker.js` and `jxl_decoder.wasm` binary in directory where they can be read.


It is not guaranteed, but somewhat fresh demo is hosted on
`https://jxl-demo.netlify.app/`, e.g.:

 - [one line demo](https://jxl-demo.netlify.app/one_line_demo_with_console.html)
 - [one line demo with console](https://jxl-demo.netlify.app/one_line_demo.html)
 - [manual decode demo](https://jxl-demo.netlify.app/manual_decode_demo.html?img=1&colorSpace=rec2100-pq&runBenchmark=30&wantSdr=false&displayNits=1500);
   URL contains query parameters that control rendering and benchmarking options;
   please note, that HDR canvas is often not enabled by default, it could be
   enabled in some browsers via `about://flags/#enable-experimental-web-platform-features`
 - [`service_worker.js`](https://jxl-demo.netlify.app/service_worker.js)
 - [`jxl_decoder.wasm`](https://jxl-demo.netlify.app/jxl_decoder.wasm)
