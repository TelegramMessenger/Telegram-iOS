// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
 * ServiceWorker script.
 *
 * Multi-threading in WASM is currently implemented by the means of
 * SharedArrayBuffer. Due to infamous vulnerabilities this feature is disabled
 * unless site is running in "cross-origin isolated" mode.
 * If there is not enough control over the server (e.g. when pages are hosted as
 * "github pages") ServiceWorker is used to upgrade responses with corresponding
 * headers.
 *
 * This script could be executed in 2 environments: HTML page or ServiceWorker.
 * The environment is detected by the type of "window" reference.
 *
 * When this script is executed from HTML page then ServiceWorker is registered.
 * Page reload might be necessary in some situations. By default it is done via
 * `window.location.reload()`. However this can be altered by setting a
 * configuration object `window.serviceWorkerConfig`. It's `doReload` property
 * should be a replacement callable.
 *
 * When this script is executed from ServiceWorker then standard lifecycle
 * event dispatchers are setup along with `fetch` interceptor.
 */

(() => {
  // Set COOP/COEP headers for document/script responses; use when this can not
  // be done on server side (e.g. GitHub Pages).
  const FORCE_COP = true;
  // Interpret 'content-type: application/octet-stream' as JXL; use when server
  // does not set appropriate content type (e.g. GitHub Pages).
  const FORCE_DECODING = true;
  // Embedded (baked-in) responses for faster turn-around.
  const EMBEDDED = {
    'client_worker.js': '$client_worker.js$',
    'jxl_decoder.js': '$jxl_decoder.js$',
    'jxl_decoder.worker.js': '$jxl_decoder.worker.js$',
  };

  // Enable SharedArrayBuffer.
  const setCopHeaders = (headers) => {
    headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
    headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  };

  // Inflight object: {clientId, uid, timestamp, controller}
  const inflight = [];

  // Generate (very likely) unique string.
  const makeUid = () => {
    return Math.random().toString(36).substring(2) +
        Math.random().toString(36).substring(2);
  };

  // Make list (non-recursively) of transferable entities.
  const gatherTransferrables = (...args) => {
    const result = [];
    for (let i = 0; i < args.length; ++i) {
      if (args[i] && args[i].buffer) {
        result.push(args[i].buffer);
      }
    }
    return result;
  };

  // Serve items that are embedded in this service worker.
  const maybeProcessEmbeddedResources = (event) => {
    const url = event.request.url;
    // Shortcut for baked-in scripts.
    for (const [key, value] of Object.entries(EMBEDDED)) {
      if (url.endsWith(key)) {
        const headers = new Headers();
        headers.set('Content-Type', 'application/javascript');
        setCopHeaders(headers);

        event.respondWith(new Response(value, {
          status: 200,
          statusText: 'OK',
          headers: headers,
        }));
        return true;
      }
    }
    return false;
  };

  // Decode JXL image response and serve it as a PNG image.
  const wrapImageResponse = async (clientId, originalResponse) => {
    // TODO: cache?
    const client = await clients.get(clientId);
    // Client is gone? Not our problem then.
    if (!client) {
      return originalResponse;
    }

    const inputStream = await originalResponse.body;
    // Can't use "BYOB" for regular responses.
    const reader = inputStream.getReader();

    const inflightEntry = {
      clientId: clientId,
      uid: makeUid(),
      timestamp: Date.now(),
      inputStreamReader: reader,
      outputStreamController: null
    };
    inflight.push(inflightEntry);

    const outputStream = new ReadableStream({
      start: (controller) => {
        inflightEntry.outputStreamController = controller;
      }
    });

    const onRead = (chunk) => {
      const msg = {
        op: 'decodeJxl',
        uid: inflightEntry.uid,
        url: originalResponse.url,
        data: chunk.value || null
      };
      client.postMessage(msg, gatherTransferrables(msg.data));
      if (!chunk.done) {
        reader.read().then(onRead);
      }
    };
    // const view = new SharedArrayBuffer(65536);
    const view = new Uint8Array(65536);
    reader.read(view).then(onRead);

    let modifiedResponseHeaders = new Headers(originalResponse.headers);
    modifiedResponseHeaders.delete('Content-Length');
    modifiedResponseHeaders.set('Content-Type', 'image/png');
    modifiedResponseHeaders.set('Server', 'ServiceWorker');
    return new Response(outputStream, {headers: modifiedResponseHeaders});
  };

  // Check if response needs decoding; if so - do it.
  const wrapImageRequest = async (clientId, request) => {
    let modifiedRequestHeaders = new Headers(request.headers);
    modifiedRequestHeaders.append('Accept', 'image/jxl');
    let modifiedRequest =
        new Request(request, {headers: modifiedRequestHeaders});
    let originalResponse = await fetch(modifiedRequest);
    let contentType = originalResponse.headers.get('Content-Type');

    let isJxlResponse = (contentType === 'image/jxl');
    if (FORCE_DECODING && contentType === 'application/octet-stream') {
      isJxlResponse = true;
    }
    if (isJxlResponse) {
      return wrapImageResponse(clientId, originalResponse);
    }

    return originalResponse;
  };

  const reportError = (err) => {
    // console.error(err);
  };

  const upgradeResponse = (response) => {
    if (response.status === 0) {
      return response;
    }

    const newHeaders = new Headers(response.headers);
    setCopHeaders(newHeaders);

    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: newHeaders,
    });
  };

  // Process fetch request; either bypass, or serve embedded resource,
  // or upgrade.
  const onFetch = async (event) => {
    const clientId = event.clientId;
    const request = event.request;

    // Pass direct cached resource requests.
    if (request.cache === 'only-if-cached' && request.mode !== 'same-origin') {
      return;
    }

    // Serve backed resources.
    if (maybeProcessEmbeddedResources(event)) {
      return;
    }

    // Notify server we are JXL-capable.
    if (request.destination === 'image') {
      let accept = request.headers.get('Accept');
      // Only if browser does not support JXL.
      if (accept.indexOf('image/jxl') === -1) {
        event.respondWith(wrapImageRequest(clientId, request));
      }
      return;
    }

    if (FORCE_COP) {
      event.respondWith(
          fetch(event.request).then(upgradeResponse).catch(reportError));
    }
  };

  // Serve decoded bytes.
  const onMessage = (event) => {
    const data = event.data;
    const uid = data.uid;
    let inflightEntry = null;
    for (let i = 0; i < inflight.length; ++i) {
      if (inflight[i].uid === uid) {
        inflightEntry = inflight[i];
        break;
      }
    }
    if (!inflightEntry) {
      console.log('Ooops, not found: ' + uid);
      return;
    }
    inflightEntry.outputStreamController.enqueue(data.data);
    inflightEntry.outputStreamController.close();
  };

  // This method is "main" for service worker.
  const serviceWorkerMain = () => {
    // https://v8.dev/blog/wasm-code-caching
    // > Every web site must perform at least one full compilation of a
    // > WebAssembly module — use workers to hide that from your users.
    // TODO(eustas): not 100% reliable, investigate why
    self['JxlDecoderLeak'] =
        WebAssembly.compileStreaming(fetch('jxl_decoder.wasm'));

    // ServiceWorker lifecycle.
    self.addEventListener('install', () => {
      return self.skipWaiting();
    });
    self.addEventListener(
        'activate', (event) => event.waitUntil(self.clients.claim()));
    self.addEventListener('message', onMessage);
    // Intercept some requests.
    self.addEventListener('fetch', onFetch);
  };

  // Service workers does not support multi-threading; that is why decoding is
  // relayed back to "client" (document / window).
  const prepareClient = () => {
    const clientWorker = new Worker('client_worker.js');
    clientWorker.onmessage = (event) => {
      const data = event.data;
      if (typeof addMessage !== 'undefined') {
        if (data.msg) {
          addMessage(data.msg, 'blue');
        }
      }
      navigator.serviceWorker.controller.postMessage(
          data, gatherTransferrables(data.data));
    };

    // Forward ServiceWorker requests to "Client" worker.
    navigator.serviceWorker.addEventListener('message', (event) => {
      clientWorker.postMessage(
          event.data, gatherTransferrables(event.data.data));
    });
  };

  // Executed in HTML page environment.
  const maybeRegisterServiceWorker = () => {
    const config = {
      log: console.log,
      error: console.error,
      requestReload: (msg) => window.location.reload(),
      ...window.serviceWorkerConfig  // add overrides
    }

    if (!window.isSecureContext) {
      config.log('Secure context is required for this ServiceWorker.');
      return;
    }

    const nav = navigator;  // Explicitly capture navigator object.
    const onServiceWorkerRegistrationSuccess = (registration) => {
      config.log('Service Worker registered', registration.scope);
      if (!registration.active || !nav.serviceWorker.controller) {
        config.requestReload(
            'Reload to allow Service Worker process all requests');
      }
    };

    const onServiceWorkerRegistrationFailure = (err) => {
      config.error('Service Worker failed to register:', err);
    };

    navigator.serviceWorker.register(window.document.currentScript.src)
        .then(
            onServiceWorkerRegistrationSuccess,
            onServiceWorkerRegistrationFailure);
  };

  const pageMain = () => {
    maybeRegisterServiceWorker();
    prepareClient();
  };

  // Detect environment and run corresponding "main" method.
  if (typeof window === 'undefined') {
    serviceWorkerMain();
  } else {
    pageMain();
  }
})();
