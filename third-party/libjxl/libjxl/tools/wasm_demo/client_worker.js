// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

let decoder = null;

// Serialize work; plus postpone processing until decoder is ready.
let jobs = [];

const processJobs = () => {
  // Decoder not yet loaded.
  if (!decoder) {
    return;
  }

  while (true) {
    let job = null;
    // Currently we do not do progressive; process only "inputComplete" jobs.
    for (let i = 0; i < jobs.length; ++i) {
      if (!jobs[i].inputComplete) {
        continue;
      }
      job = jobs[i];
      jobs[i] = jobs[jobs.length - 1];
      jobs.pop();
      break;
    }
    if (!job) {
      return;
    }
    console.log('CW job: ' + job.uid);
    const input = job.input;
    let totalInputLength = 0;
    for (let i = 0; i < input.length; i++) {
      totalInputLength += input[i].length;
    }

    // TODO: persist to reduce fragmentation?
    const buffer = decoder._malloc(totalInputLength);
    // TODO: check OOM
    let offset = 0;
    for (let i = 0; i < input.length; ++i) {
      decoder.HEAP8.set(input[i], buffer + offset);
      offset += input[i].length;
    }
    let t0 = Date.now();
    // TODO: check result
    const result = decoder._jxlDecompress(buffer, totalInputLength);
    let t1 = Date.now();
    const msg = 'Decoded ' + job.url + ' in ' + (t1 - t0) + 'ms';
    // console.log(msg);
    decoder._free(buffer);
    const outputLength = decoder.HEAP32[result >> 2];
    const outputAddr = decoder.HEAP32[(result + 4) >> 2];
    const output = new Uint8Array(outputLength);
    const outputSrc = new Uint8Array(decoder.HEAP8.buffer);
    output.set(outputSrc.slice(outputAddr, outputAddr + outputLength));
    decoder._jxlCleanup(result);
    const response = {uid: job.uid, data: output, msg: msg};
    postMessage(response, [output.buffer]);
  }
};

onmessage = function(event) {
  const data = event.data;
  console.log('CW received: ' + data.op);
  if (data.op === 'decodeJxl') {
    let job = null;
    for (let i = 0; i < jobs.length; ++i) {
      if (jobs[i].uid === data.uid) {
        job = jobs[i];
        break;
      }
    }
    if (!job) {
      job = {uid: data.uid, input: [], inputComplete: false, url: data.url};
      jobs.push(job);
    }
    if (data.data) {
      job.input.push(data.data);
    } else {
      job.inputComplete = true;
    }
    processJobs();
  }
};

const onLoadJxlModule = (instance) => {
  decoder = instance;
  processJobs();
};

importScripts('jxl_decoder.js');
const config = {
  mainScriptUrlOrBlob: 'https://jxl-demo.netlify.app/jxl_decoder.js',
  INITIAL_MEMORY: 16 * 1024 * 1024,
};
JxlDecoderModule(config).then(onLoadJxlModule);
