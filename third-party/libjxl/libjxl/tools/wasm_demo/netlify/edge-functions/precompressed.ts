// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import type {Context} from 'netlify:edge';

// This lambda is executed whenever request URL matches.
export default async (request: Request, context: Context) => {
  // Measure time for debugging purpose.
  let t0 = Date.now();
  // Get resource path (i.e. ignore query parameters).
  let url = request.url.split('?')[0];
  // Pick request headers; fallback to empty string if header is not set.
  let acceptEncodingHeader = request.headers.get('Accept-Encoding') || '';
  let acceptHeader = request.headers.get('Accept') || '';
  let etag = request.headers.get('If-None-Match') || '';
  // Roughly parse encodings list; this ignores "quality"; no modern browsers
  // use it -> don't care.
  let splitter = /[,;]/;
  let supportedEncodings =
      acceptEncodingHeader.split(splitter).map(v => v.trimStart());
  let supportsBr = supportedEncodings.includes('br');
  let supportedMedia = acceptHeader.split(splitter).map(v => v.trimStart());
  let supportsJxl = supportedMedia.includes('image/jxl');
  // Dump basic request info (we care about).
  context.log(
      'URL: ' + url + '; acceptEncodingHeader: ' + acceptEncodingHeader +
      '; supportsBr: ' + supportsBr + '; supportsJxl: ' + supportsJxl +
      '; etag: ' + etag);

  // If browser does not support Brotli/Jxl - just process request normally.

  if (!supportsBr && !supportsJxl) {
    return;
  }

  // Jxl processing is higher priority, because images are (usually) transferred
  // with 'identity' content encoding.
  let isJxlWorkflow = supportsJxl;
  let suffix = isJxlWorkflow ? '.jxl' : '.br';

  // Request pre-compressed resource (with a suffix).
  let response = await context.rewrite(url + suffix);
  context.log('Response status: ' + response.status);
  // First latency checkpoint (as we synchronously wait for resource fetch).
  let t1 = Date.now();
  // If pre-compressed resource does not exist - pass.
  if (response.status == 404) {
    return;
  }
  // Get resource ETag.
  let responseEtag = response.headers.get('ETag') || '';
  context.log('Response etag: ' + responseEtag);
  // We rely on platform to check ETag; add debugging info just in case.
  if (etag.length >= 4 && responseEtag === etag) {
    console.log('Match; status: ' + response.status);
  }
  // Status 200 is regular "OK" - fetch resource; in such a case we need to
  // craft response with the response contents.
  // Status 3xx likely means "use cache"; pass response as is.
  // Status 4xx is unlikely (404 has been already processed).
  // Status 5xx is server error - nothing we could do around it.
  if (response.status != 200) return response;
  // Second time consuming operation - wait for resource contents.
  let data = await response.arrayBuffer();
  let fixedHeaders = new Headers(response.headers);

  if (isJxlWorkflow) {
    fixedHeaders.set('Content-Type', 'image/jxl');
  } else {  // is Brotli workflow
    // Set "Content-Type" based on resource suffix;
    // otherwise browser will complain.
    let contentEncoding = 'text/html; charset=UTF-8';
    if (url.endsWith('.js')) {
      contentEncoding = 'application/javascript';
    } else if (url.endsWith('.wasm')) {
      contentEncoding = 'application/wasm';
    }
    fixedHeaders.set('Content-Type', contentEncoding);
    // Inform browser that data stream is compressed.
    fixedHeaders.set('Content-Encoding', 'br');
  }
  let t2 = Date.now();
  console.log('Timing: ' + (t1 - t0) + ' ' + (t2 - t1));
  return new Response(data, {headers: fixedHeaders});
};
