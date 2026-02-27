// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

function assertTrue(ok, msg) {
  if (!ok) {
    console.log('FAIL: ' + msg);
    process.exit(1);
  }
}

function runTest(testFn) {
  console.log('Running ' + testFn.name);
  testFn();
  console.log('PASS');
}

let jxlModule;

const isAddress = (v) => {
  return (v >= 4) && ((v & (1 << 31)) === 0);
};

let splinesJxl = new Uint8Array([
  0xff, 0x0a, 0xf8, 0x19, 0x10, 0x09, 0xd8, 0x63, 0x10, 0x00, 0xbc, 0x00,
  0xa6, 0x19, 0x4a, 0xa3, 0x56, 0x8c, 0x94, 0x62, 0x24, 0x7d, 0x12, 0x72,
  0x87, 0x00, 0x00, 0xda, 0xd4, 0xc9, 0xc1, 0xe2, 0x9e, 0x02, 0xb9, 0x37,
  0x00, 0xfe, 0x07, 0x9a, 0x91, 0x08, 0xcd, 0xbf, 0xa1, 0xdc, 0x71, 0x36,
  0x62, 0xc8, 0x97, 0x31, 0xc4, 0x3e, 0x58, 0x02, 0xc1, 0x01, 0x00
]);

let crossJxl = new Uint8Array([
  0xff, 0x0a, 0x98, 0x10, 0x10, 0x50, 0x5c, 0x08, 0x08, 0x02, 0x01,
  0x00, 0x98, 0x00, 0x4b, 0x18, 0x8b, 0x15, 0x00, 0xd4, 0x92, 0x62,
  0xcc, 0x98, 0x91, 0x17, 0x08, 0x01, 0xe0, 0x92, 0xbc, 0x7e, 0xdf,
  0xbf, 0xff, 0x50, 0xc0, 0x64, 0x35, 0xb0, 0x40, 0x1e, 0x24, 0xa9,
  0xac, 0x38, 0xd9, 0x13, 0x1e, 0x85, 0x4a, 0x0d
]);

function testSdr() {
  let decoder = jxlModule._jxlCreateInstance(
      /* wantSdr */ true, /* displayNits */ 100);
  assertTrue(isAddress(decoder), 'create decoder instance');
  let encoded = splinesJxl;
  let buffer = jxlModule._malloc(encoded.length);
  jxlModule.HEAP8.set(encoded, buffer);

  let result = jxlModule._jxlProcessInput(decoder, buffer, encoded.length);
  assertTrue(result === 0, 'process input');

  let w = jxlModule.HEAP32[decoder >> 2];
  let h = jxlModule.HEAP32[(decoder + 4) >> 2];
  let pixelData = jxlModule.HEAP32[(decoder + 8) >> 2];

  assertTrue(pixelData, 'output allocated');
  assertTrue(h === 320, 'output height');
  assertTrue(w === 320, 'output width ');

  jxlModule._jxlDestroyInstance(decoder);
  jxlModule._free(buffer);
}

function testRegular() {
  let decoder = jxlModule._jxlCreateInstance(
      /* wantSdr */ false, /* displayNits */ 100);
  assertTrue(isAddress(decoder), 'create decoder instance');
  let encoded = splinesJxl;
  let buffer = jxlModule._malloc(encoded.length);
  jxlModule.HEAP8.set(encoded, buffer);

  let result = jxlModule._jxlProcessInput(decoder, buffer, encoded.length);
  assertTrue(result === 0, 'process input');

  let w = jxlModule.HEAP32[decoder >> 2];
  let h = jxlModule.HEAP32[(decoder + 4) >> 2];
  let pixelData = jxlModule.HEAP32[(decoder + 8) >> 2];

  assertTrue(pixelData, 'output allocated');
  assertTrue(h === 320, 'output height');
  assertTrue(w === 320, 'output width ');

  jxlModule._jxlDestroyInstance(decoder);
  jxlModule._free(buffer);
}

function testChunks() {
  let decoder = jxlModule._jxlCreateInstance(
      /* wantSdr */ false, /* displayNits */ 100);
  assertTrue(isAddress(decoder), 'create decoder instance');
  let encoded = splinesJxl;
  let buffer = jxlModule._malloc(encoded.length);
  jxlModule.HEAP8.set(encoded, buffer);

  let part1_length = encoded.length >> 1;
  let part2_length = encoded.length - part1_length;

  let result = jxlModule._jxlProcessInput(decoder, buffer, part1_length);
  assertTrue(result === 2, 'process first part');

  result =
      jxlModule._jxlProcessInput(decoder, buffer + part1_length, part2_length);
  assertTrue(result === 0, 'process second part');

  let w = jxlModule.HEAP32[decoder >> 2];
  let h = jxlModule.HEAP32[(decoder + 4) >> 2];
  let pixelData = jxlModule.HEAP32[(decoder + 8) >> 2];

  assertTrue(pixelData, 'output allocated');
  assertTrue(h === 320, 'output height');
  assertTrue(w === 320, 'output width ');

  jxlModule._jxlDestroyInstance(decoder);
  jxlModule._free(buffer);
}

function testDecompress() {
  let encoded = crossJxl;
  let buffer = jxlModule._malloc(encoded.length);
  jxlModule.HEAP8.set(encoded, buffer);

  let output = jxlModule._jxlDecompress(buffer, encoded.length);
  assertTrue(isAddress(output), 'decompress');

  jxlModule._free(buffer);

  let pngSize = jxlModule.HEAP32[output >> 2];
  let px = 20 * 20;
  assertTrue(pngSize >= 6 * px, 'png size');
  assertTrue(pngSize <= 6 * px + 800, 'png size');

  jxlModule._jxlCleanup(output);
}

require('jxl_decoder_for_test.js')().then(module => {
  jxlModule = module;
  let tests = [testSdr, testRegular, testChunks, testDecompress];
  tests.forEach(runTest);
  process.exit(0);
});
