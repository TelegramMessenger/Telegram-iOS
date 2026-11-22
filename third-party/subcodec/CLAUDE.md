# subcodec

C++23 library that constructs H.264 Baseline/High Profile bitstreams for sprite multiplexing. Composites many small sprite animations into a single H.264 stream decoded by one hardware decoder, using selective macroblock updates (P_16x16, I_16x16, skip) in P-frames.

## Build

```bash
cmake -B build && cmake --build build
```

- This project lives inside `telegram-ios/third-party/subcodec/`
- CMake 3.16+, C++23 standard (for `std::expected`); OpenH264 compiled as C++11
- Dependencies: FFmpeg (libavcodec, libavformat, libavutil, libswscale) — required for sprite_extract video input; vendored h264bitstream; OpenH264 encoder + decoder (Telegram's patched copy at the sibling `../openh264/` directory, accessed via symlink `third_party/openh264_codec` — not vendored here)
- Produces: `libsubcodec.a`, 25 test executables, `sprite_extract` tool, `sprite_mux` tool

### SwiftPM

```bash
cmake --build build --target fixtures  # generate YUV fixtures before running Swift tests
swift build   # builds core library + OpenH264 + sprite_encode + ObjC++ wrapper
swift test    # runs Swift XCTest suite (12 tests including 160-frame e2e)
```

- Swift 5.9+, targets macOS 10.15+/iOS 13+/tvOS 13+
- SwiftPM targets: `h264bitstream`, `subcodec`, `oh264_common`, `oh264_processing`, `oh264_encoder`, `oh264_decoder`, `sprite_encode`, `SubcodecObjC`, `SubcodecTests`
- OpenH264 is referenced via the `third_party/openh264_codec` symlink pointing to Telegram's sibling `../openh264/` directory
- CMake remains the primary build system; SwiftPM builds alongside it

## Project Structure

- `src/types.h` — Core types: `MacroblockData`, `FrameParams`, `MbContext`, `MbsRow`, `MbsEncodedFrame` (merged rows only), `MbsFrame` (`merged_rows` span), `MbsSprite` (bulk data + row storage)
- `src/error.h` — `subcodec::Error` enum class
- `src/tables.h` — Compile-time lookup tables (CBP, block scan order)
- `src/frame_writer.cpp/.h` — `subcodec::frame_writer` namespace: `write_headers` (auto-selects Baseline/High Profile + level from frame size), `write_idr_frame_ex`, `write_p_frame_ex`
- `src/cavlc.cpp/.h` — `subcodec::cavlc` namespace: CAVLC entropy coding and decoding (spec tables, block read/write, nC context)
- `src/h264_parser.cpp/.h` — `subcodec::H264Parser` class: H.264 Baseline CAVLC slice parser with RAII buffers
- `src/mux_surface.cpp/.h` — `subcodec::MuxSurface` class: streaming mux surface with sprite loading/removal/looping, P-frame emission, dynamic resize. `Params` takes `sprite_width`/`sprite_height` in content pixels (padding added internally). `add_sprite` returns `SpriteRegion` (slot index + color/alpha content pixel rects in composite frame); also sets `needs_emit`/`dirty_` so the next `emit_frame_if_needed` emits the sprite's frame 0 introduction. `advance_sprite(slot)` schedules one sprite for emit+advance (sets `needs_emit` flag); `emit_frame_if_needed(sink)` emits a P-frame if any sprites are scheduled, then advances their frame indices (emit-then-advance semantics). `advance_frame(sink)` is a convenience wrapper that schedules all active sprites then calls `emit_frame_if_needed`. `resize` emits new SPS/PPS + all-I_PCM IDR to change grid dimensions mid-stream, compacting active sprites. `check_compaction_opportunity` returns `CompactionInfo` for caller-driven resize decisions
- `src/mbs_mux_common.cpp/.h` — `subcodec::mux` namespace: shared muxing primitives, `EbspWriter` (single-pass direct EBSP output with inline escape checking + zero-run metadata fast path + `flush_bytes` for NEON-accelerated bulk byte writing), `RbspWriter` (branchless RBSP staging writer, no escape checking), `MicroOp` (pre-resolved blob operation), `RowOp`/`CompositeRowPlan` (precomputed composite grid layout), `build_row_plans`, `build_micro_ops`, `write_p_frame_micro` (active P-frame path), `write_p_frame_rbsp` (legacy two-pass path), `write_idr_ipcm` (inline in header — all-I_PCM IDR for resize transitions, single-pass EbspWriter with precomputed black-MB fast path), `write_skip_safe` (splits long mb_skip_runs with dummy P_16x16 zero-residual MBs for VT compatibility), `scan_zero_runs`, `rbsp_to_ebsp_neon`, exp-golomb LUT, row-blob copy, RBSP↔EBSP conversion
- `src/mbs_encode.cpp/.h` — `subcodec::mbs` namespace: MBS binary format encoding with real nC context and zero-run scanning, returns `MbsEncodedFrame`
- `src/mbs_format.h` — MBS binary format constants (MBS6 format). Header: magic `MBS6` (4 bytes) + width_mbs(2) + height_mbs(2) + num_frames(2) + qp(1) + qp_delta_idr(1) + qp_delta_p(1) + flags(1) = 14 bytes
- `src/sprite_data.cpp` — `MbsSprite` file I/O (v6 bulk load/save with pre-merged blobs), `set_frames()` — no runtime merge needed
- `src/sprite_encode.cpp/.h` — `subcodec::SpriteEncoder` class: OpenH264 encode + parse pipeline. `Params` takes content `width`/`height` in pixels (padding added internally). Encodes on a double-wide canvas (color left, alpha right) and returns `EncodeResult{color, alpha}`.
- `src/sprite_extractor.cpp/.h` — `subcodec::SpriteExtractor` class: raw YUV+alpha → padded canvas → SpriteEncoder → .mbs file with pre-merged row blobs. `Params` takes content `sprite_size` in pixels (padding always 16px internally)
- `tools/sprite_extract.cpp` — CLI: video file → `.mbs` via FFmpeg decode + SpriteEncoder
- `tools/sprite_mux.cpp` — CLI: `.mbs` files → composite H.264 stream via MuxSurface
- `third_party/h264bitstream/` — Vendored NAL unit / bitstream primitives (C)
- `third_party/openh264_codec` — Symlink to Telegram's OpenH264 at the sibling `../openh264/` directory (not vendored here; patches documented below)
- `test/` — 25 standalone C++ test programs (no framework)
- `Sources/SubcodecObjC/` — ObjC++ wrapper: SCSprite, SCMuxSurface, SCSpriteRegion, SCResizeResult, SCCompactionInfo, SCOpenH264Decoder, SCVideoToolboxDecoder, SCDecodedFrame, SCDecoding protocol
- `Sources/SpriteEncode/` — SwiftPM wrapper compilation units for sprite_encode.cpp/sprite_extractor.cpp
- `Tests/SubcodecTests/` — Swift XCTest suite with YUV fixtures (3 sprites × 160 frames)
- `docs/plans/` — Design documents
- `docs/superpowers/specs/` — Feature specs

## Tests

```bash
cd build && ctest
```

Each test is a standalone C++ executable (no framework):
- `test_cavlc` — CAVLC write encoding correctness
- `test_cavlc_read` — CAVLC read/write round-trip across all 5 VLC tables
- `test_cavlc_diag` — CAVLC diagnostic tests
- `test_cavlc_split` — CAVLC split encoding tests
- `test_ct_lut` — Coeff token lookup table tests
- `test_mb_p16x16` — P_16x16 macroblock encoder + MV prediction
- `test_mb_i16x16` — I_16x16 macroblock encoder
- `test_p_frame_ex` — Extended P-frame writer (all MB types)
- `test_h264_parse` — H.264 slice parser round-trip (write -> parse -> verify)
- `test_idr_frame_ex` — Extended IDR frame writer round-trip
- `test_mbs_format` — MBS binary format encoding/decoding
- `test_mbs_encode` — MBS frame encoding
- `test_mux` (requires OpenH264) — End-to-end: 4 sprites x 8 frames, encode -> mux_surface -> decode -> pixel-identical verification
- `test_mux_surface` (requires OpenH264) — Streaming mux surface: staggered sprite add/remove, mid-stream I_16x16 introduction, sprite looping (2-cycle pixel-identical verification), pixel verification
- `test_sprite_extractor` (requires OpenH264) — SpriteExtractor pipeline test
- `test_bs_copy_bits` — Bulk bit copy correctness (aligned, unaligned, random round-trip)
- `test_mux_perf` — Mux performance stress test: 1764 sprites, 160 frames, per-frame timing
- `test_high_profile` (requires OpenH264) — High Profile SPS acceptance + large grid (52K MBs) mux verification
- `test_ebsp_writer` — EbspWriter unit tests: flush_byte EBSP escaping, write_bits accumulation, exp-golomb LUT correctness, copy_blob aligned/unaligned/partial/sequence verification against bs_t+rbsp_to_ebsp reference, fast-path (5-arg copy_blob) correctness at all bit alignments with escape-free and boundary-escape scenarios
- `test_row_plans` — Row plan precomputation correctness: single sprite, 2x2 grid, partial grid with inactive slots, empty grid (all double-wide slots)
- `test_sprite_encode_alpha` (requires OpenH264) — SpriteEncoder double-wide canvas: alpha MB split, cbp_chroma=0 verification
- `test_mux_alpha` (requires OpenH264) — End-to-end alpha mux: 2 sprites with varying alpha, pixel-identical verification of color and alpha regions against independent reference decode
- `test_rbsp_writer` — RbspWriter + rbsp_to_ebsp_neon verification: compares two-pass (RbspWriter → rbsp_to_ebsp_neon) output against single-pass EbspWriter reference at all bit alignments, with escape-triggering patterns and random data
- `test_ipcm` (requires OpenH264) — I_PCM IDR frame round-trip: write all-I_PCM IDR with gradient pattern, decode via OpenH264, pixel-identical verification
- `test_resize` (requires OpenH264) — MuxSurface dynamic resize: compaction info query, grow/shrink resize, error handling (too few slots), frame counter preservation, pixel-identical verification of sprite content across resize

### Swift Tests (`swift test`)

**Note:** Generate YUV fixtures before running Swift tests: `cmake --build build --target fixtures`

- `testDecodedFrameCreation` — SCDecodedFrame data container
- `testSpriteExtractor` — YUV fixture → SpriteExtractor → .mbs round-trip (160 frames)
- `testSpriteEncoder` — YUV fixture → SpriteEncoder → H.264 stream (160 frames)
- `testEncoderDecodeRoundTrip` — Encode → OpenH264 decode → verify dimensions (8 frames)
- `testMuxSurfaceBasic` — MuxSurface create → add sprite → advance frame
- `testStaggeredAddRemove` — **Main e2e test**: 3 sprites × 160 frames, staggered add/remove, pixel-identical verification against independent reference decode
- `testVideoToolboxDecoder` — Encode 8 frames → VideoToolbox decode → verify frame count and dimensions
- `testDecoderCrossComparison` — Encode 8 frames → decode with both OpenH264 and VideoToolbox → pixel-by-pixel YUV comparison with +/-1 tolerance
- `testSpriteLooping` — 1 sprite × 320 frames (2 loops of 160), pixel-identical verification across loop boundary
- `testAdvanceSpriteIndependent` — 2 sprites with independent frame rates via `advanceSpriteAtSlot:` + `emitFrameIfNeededWithSink:`, pixel-identical verification that only advanced sprite progresses
- `testVideoToolboxPartialFill` — Partially-filled grid (10 sprites in 361-slot grid) decoded via VideoToolbox. Regression test for the write_skip_safe workaround — without it, VT rejects long skip_runs in partially-filled grids.
- `testVideoToolboxIPCM` — MuxSurface resize with I_PCM transition frame decoded via VideoToolbox. Verifies VT handles I_PCM IDR + post-resize P-frames.
- `testResizePerformance` — Resize performance: 420 sprites, resize 420→882 slots with real decoded pixels (OpenH264), wall-clock timing with performance gate (<200ms debug, ~5ms release).

## Sprite Multiplexing Pipeline

```
Input video/YUV+alpha -> SpriteEncoder (double-wide padded canvas: color left, alpha right)
    -> H264Parser -> MacroblockData (split into color + alpha halves)
    -> save to .mbs (MbsSprite, pre-merged color+alpha row blobs per frame)
    -> MuxSurface (double-wide grid: color+alpha side-by-side per slot) -> composite H.264 stream
    -> hardware decoder (color and alpha regions decoded in a single frame)
```

### How compositing works

1. **SpriteEncoder** (or **sprite_extract** CLI) encodes each sprite on a double-wide black-padded canvas: color left half (sprite content + padding border) and alpha right half (alpha-as-luma + neutral chroma Cb=Cr=128). For a 64x64 sprite with 16px padding, the canvas is 192x96 pixels (12x6 MBs). It parses the OpenH264 NAL output into `MacroblockData` via `H264Parser`, then splits into color (left half MBs) and alpha (right half MBs). Alpha MBs naturally have `cbp_chroma=0` (no chroma residual) since chroma is uniform 128.

2. **MBS encoding** (`mbs::encode_frame_merged`) serializes `MacroblockData` into the `.mbs` binary format (MBS v6, magic `MBS6`) with **real nC context** (not canonical nC=0) and **pre-merged color+alpha row blobs**. Color and alpha halves are encoded separately, then merged at encode time into a single blob per row: `[color_data][ue(inter_skip)][alpha_data]`, with leading/trailing skips relative to the full double-wide slot width. Alpha is always present — every sprite has both color and alpha data. The CAVLC is encoded with the actual neighbor-derived nC values, computed from the padded sprite canvas context. MBs are grouped into **row blobs**: each row's non-skip MBs are packed into a contiguous bitstream segment with interleaved skip_run exp-golomb codes. Each row's 6-byte header stores `leading_skips`, `trailing_skips`, packed `blob_bit_count` (15-bit count + 1-bit `has_long_zero_run` flag), `leading_zero_bits`, and `trailing_zero_bits`. The zero-run metadata is computed by scanning each merged blob at encode time. This means the CAVLC bitstream is already correct for the composite grid layout (see "Why real-nC works" below). No runtime merge is needed at load or mux time.

3. **MuxSurface** arranges sprites in a double-wide grid with shared padding borders. Each slot is `sprite_w * 2 - padding` MBs wide with color and alpha side-by-side, sharing a padding border between them. For the IDR frame (frame 0), all MBs are I_16x16 with DC prediction and zero residual (except MB(0,0) which needs a compensating luma DC coefficient since DC prediction defaults to 128 with no neighbors). This produces an all-black reference frame in ~1-2 bytes/MB. For P-frames, `advance_frame` has two phases: (a) `build_micro_ops` walks the precomputed `RowOp` plans and resolves all pointer chains into a flat `MicroOp` array (one entry per merged blob with data — inactive slots and all-skip rows are folded into skip counts); (b) `write_p_frame_micro` iterates the `MicroOp` array in a tight loop — `write_ue(skip)` + `copy_blob(merged_blob)` per op, using `EbspWriter` for inline EBSP escaping. When the blob's `has_long_zero_run` flag is false, `copy_blob` uses a fast path: only 3 boundary bytes go through `flush_byte` for EBSP escape checking, then the interior is bulk-copied (memcpy for aligned, NEON shift+write for non-aligned) with no EBSP checking — this is safe because the absence of 16-bit zero runs is alignment-invariant. No CAVLC re-encoding and no intermediate RBSP buffer needed. The composite grid layout is precomputed into flat `CompositeRowPlan` / `RowOp` arrays at `add_sprite`/`remove_sprite` time. `__builtin_prefetch` hides cache miss latency in both `build_micro_ops` and `write_p_frame_micro`.

4. New sprites are introduced mid-stream as I_16x16 MBs in P-frames (their frame 0 data), without requiring an IDR reset.

5. **Dynamic resize** (`MuxSurface::resize`) changes the grid size mid-stream. The caller provides decoded pixels of the last frame. MuxSurface emits new SPS/PPS + an all-I_PCM IDR with sprite pixels remapped to compacted slot positions in the new grid. Active sprites are compacted into slots 0..N-1 with frame counters preserved. Subsequent P-frames continue from the I_PCM reference. `check_compaction_opportunity` returns `CompactionInfo` (active/max slots, current/min grid MBs) so callers can decide when to resize. I_PCM costs 384 bytes/MB (up to 580 with EBSP escaping) — acceptable as a one-shot cost for an infrequent operation. The intermediate YUV planes use `make_unique_for_overwrite` + explicit `memset` (not `std::vector` fill) to avoid debug-mode per-element initialization overhead. The I_PCM IDR writer (`write_idr_ipcm`, inline in `mbs_mux_common.h`) uses single-pass EbspWriter with two paths: **black-MB fast path** (NEON detects all-black MBs Y=0/Cb=Cr=128, memcpy's precomputed EBSP pattern) and **non-black bulk path** (gathers MB samples into contiguous 384-byte buffer, single `flush_bytes` call with NEON-accelerated EBSP escaping). For a 420→882 slot resize (~45K MBs), this runs in ~2ms (Release) / ~16ms (Swift debug).

### Key design decisions and why

**Black-padded canvas (sprite + 1 MB border, hardcoded):**
Padding is always exactly 1 MB (16px) — hardcoded throughout the pipeline, not configurable via any API. All user-facing APIs take content-only dimensions; padding is added internally. Motion vectors in P-frames may reference pixels outside the sprite content area. The black padding ensures these references produce identical pixels in both the independent encode and the composite. OpenH264's MV range is capped at 16px (1 MB) to stay within the padding.

**I_16x16 for IDR background:**
The IDR frame uses all-I_16x16 with DC prediction to establish exact black pixels (Y=0, Cb=128, Cr=128). MB(0,0) has no neighbors so DC prediction defaults to 128 for luma; a compensating luma DC coefficient (`black_dc_level(qp)`) corrects this to Y=0. All other MBs predict 0 from already-decoded black neighbors → zero residual. This produces ~1-2 bytes/MB (vs ~385 bytes/MB with the previous I_PCM approach). Removed sprites become SKIP MBs referencing the black IDR — no active cleanup needed. Sprites loop indefinitely (frame counter wraps to 0 at `num_frames`), replaying their I_16x16 introduction frame at each loop boundary. Sprites are only removed via explicit `remove_sprite()`.

**Real-nC MBS encoding with row blobs (no CAVLC re-encoding at mux time):**
The 1-MB padding border ensures that the nC context for every content block is identical between the original sprite canvas and the composite grid:
- Content MBs neighbor either other content MBs from the same sprite (identical total_coeff) or SKIP padding (nC=0)
- This is true in both the original encode and the composite layout
- Therefore, CAVLC encoded with real nC on the sprite canvas is already correct for the composite

The same argument applies to MV prediction (SKIP padding has MV=0 in both contexts). Each row blob (exp-golomb skip runs + CAVLC blocks) can be copied verbatim at mux time via `EbspWriter::copy_blob`.

**Note:** Chroma DC blocks use nC=-1 (a fixed VLC table regardless of neighbors), so they never need re-encoding. Luma and chroma AC blocks use neighbor-derived nC, which is why real-nC encoding matters.

**Alpha channel (side-by-side in composite):**
Alpha is required for all sprites — callers pass an alpha plane alongside Y/Cb/Cr (all-255 for opaque). SpriteEncoder encodes color+alpha on a single double-wide OpenH264 canvas (2× padded width × padded height). Alpha uses luma=alpha values with neutral chroma (Cb=Cr=128), producing `cbp_chroma=0` for all alpha MBs — no chroma data stored. In the composite, each slot places color and alpha side-by-side with shared padding: `[pad][color][shared pad][alpha][pad]` = `sprite_w * 2 - padding` MBs per slot. Color and alpha row blobs are pre-merged at encode time (MBS v6) into a single blob per row: `[color_data][ue(inter_skip)][alpha_data]`, with leading/trailing skips relative to the full slot width. The mux loop emits one merged blob per RowOp via a single `copy_blob` call. No runtime merge needed at load or mux time. Removed sprites' alpha regions become Y=0 (transparent) via SKIP referencing the all-black IDR.

**No intra MBs in P-frames (OpenH264 patched):**
OpenH264 is patched (via `bSubcodecMode`) to prevent intra MB selection in P-slices and restrict all MBs to I_16x16/P_16x16/SKIP during encoding. This ensures P-frame MBs use only P_16x16 and SKIP (inter prediction from reference frame). I_16x16 MBs in P-frames are used only at the composite mux level for introducing new sprites — their I_16x16 data comes from the sprite's original IDR frame, not from OpenH264's P-frame encoding.

**OpenH264 for both encode and decode:**
Using the same library for encoding (in sprite_extract) and decoding (in test verification) guarantees consistent behavior. Previously used x264+FFmpeg but hit QP mismatches and format inconsistencies.

**Automatic profile/level selection:**
`write_headers` computes the H.264 level from the frame's MB count and selects Baseline Profile (up to Level 5.2 / 36,864 MBs) or High Profile (Level 6.0 / 139,264 MBs) automatically. High Profile uses CAVLC (not CABAC) and no 8x8 transforms — the bitstream content is identical to Baseline, just the SPS signals High Profile to unlock higher level limits. Required for 4K+ grids.

## Vendored OpenH264 Patches

> **Note:** These patches exist in Telegram's OpenH264 at `third-party/openh264/`. Subcodec does not carry its own OpenH264 copy — it uses the sibling directory via the `third_party/openh264_codec` symlink.

The OpenH264 used by subcodec has patches gated on `SEncParamExt::bSubcodecMode` (default false). When false, all encoder behavior is stock OpenH264. When true, sprite-compositing constraints activate. Set via `eparam.bSubcodecMode = true` before `InitializeExt()`. The flag is copied in `SWelsSvcCodingParam::ParamTranscode` (`encoder/core/inc/param_svc.h`).

**Conditional patches (bSubcodecMode=true):**

1. **No intra in P-frames** (`encoder/core/src/svc_base_layer_md.cpp`): `WelsMdFirstIntraMode()` returns false, preventing I_4x4/I_16x16 selection in P-slices.

2. **No I_4x4 in intra frames** (`encoder/core/src/svc_base_layer_md.cpp`): `WelsMdIntraFinePartition()` and `WelsMdIntraFinePartitionVaa()` skip I_4x4 evaluation — only I_16x16 allowed.

3. **No sub-partition modes** (`encoder/core/src/svc_base_layer_md.cpp`, `encoder/core/src/svc_mode_decision.cpp`): `WelsMdInterFinePartition()`, `WelsMdInterFinePartitionVaa()`, `WelsMdInterFinePartitionVaaOnScreen()` skip P_8x8/P_16x8/P_8x16 evaluation — only P_16x16/SKIP allowed.

4. **MV range cap** (`encoder/core/src/encoder_ext.cpp`): `GetMvMvdRange()` clamps `iMvRange` to 16 pixels max, matching the 1-MB padding border size.

5. **Padding reconstruction override** (`encoder/core/src/svc_encode_slice.cpp`): After encoding each MB, if it falls within the 1-MB border ring, reconstruction buffer is overwritten to exact black (Y=0, Cb=128, Cr=128). Hardcoded 1-MB padding.

6. **Log2MaxFrameNum = 4** (`encoder/core/src/au_set.cpp`): `WelsInitSps()` sets `uiLog2MaxFrameNum` to 4 (vs 15 stock) to match subcodec's H.264 parser. The bool is passed as a parameter through call sites in `paraset_strategy.cpp`.

**Unconditional patches (always active):**

7. **Level 6.0/6.1/6.2 support** (`api/wels/codec_app_def.h`, `common/inc/wels_common_defs.h`, `common/src/common_tables.cpp`, `decoder/core/src/au_parser.cpp`): Added H.264 Level 6.x entries (up to 139,264 MBs) to the level enum, limit table, level map, and decoder lookup. Stock OpenH264 maxes at Level 5.2 (36,864 MBs).

## Data Flow Details

### MacroblockData (types.h)

Stores all data needed to encode a macroblock:
- `mb_type` — MbType::SKIP, P_16x16, I_16x16
- `mv_x, mv_y` — Motion vector (half-pel, for P_16x16)
- `intra_pred_mode, intra_chroma_mode` — Prediction modes (for I_16x16)
- `luma_dc[16]` — I_16x16 DC coefficients
- `luma_ac[16][15]` — AC coefficients per 4x4 block
- `cb_dc[4], cr_dc[4], cb_ac[4][15], cr_ac[4][15]` — Chroma coefficients
- `cbp_luma, cbp_chroma` — Coded block pattern

### MbsEncodedFrame (types.h)

Owned frame data returned by `mbs::encode_frame_merged()`:
- `data` — `vector<uint8_t>` raw frame data (row metadata + merged blobs)
- `rows` — `vector<MbsRow>` pre-merged row descriptors (color+alpha combined)

### MbsFrame (types.h)

View into bulk-owned frame data (used by MbsSprite after load or set_frames):
- `merged_rows` — `span<MbsRow>` pre-merged color+alpha rows (slot_w-relative skips). Used by `build_micro_ops` for the P-frame mux path.

### MbsRow (types.h)

Per-row blob descriptor (6-byte on-disk header in MBS v6):
- `leading_skips` — Content SKIPs before first non-skip MB in row
- `trailing_skips` — Content SKIPs after last non-skip MB in row
- `blob_bit_count` — Packed uint16_t: [14:0] = total bits in row blob, [15] = `has_long_zero_run` flag
- `leading_zero_bits` — Zero bits at blob start (capped at 255)
- `trailing_zero_bits` — Zero bits at blob end (capped at 255)
- `blob_data` — Pointer into frame data buffer
- `bit_count()` — Accessor returning lower 15 bits of `blob_bit_count`
- `has_long_zero_run()` — Accessor returning top bit (true if any run of ≥16 consecutive zero bits)

### MbsSprite (types.h)

Binary MBS format sprite: per-frame `MbsFrame` views for streaming mux. Move-only. Every sprite has both color and alpha data (pre-merged in v6 format). Loaded from `.mbs` via `MbsSprite::load()` (single bulk read + view parse). Built from encoded frames via `set_frames()` which consolidates into bulk storage. Internally owns: `bulk_data_` (pre-merged blob bytes), `all_rows_` (merged MbsRow descriptors). All `MbsFrame` spans point into these.

Public fields: `width_mbs`, `height_mbs` (padded dimensions in MBs), `num_frames`, `qp`, `qp_delta_idr`, `qp_delta_p`, `frames` (vector of `MbsFrame` views). Padding is always 1 MB — not stored in the format or struct.

### FrameParams (types.h)

Frame dimensions and SPS parameters for the H.264 writers: `width_mbs`, `height_mbs`, `qp`, `log2_max_frame_num`, `pic_order_cnt_type`.

## Mux Performance

The mux path was heavily optimized. Key results at 1764 sprites (421x211 MB grid, double-wide with alpha):

| Metric | Value |
|---|---|
| Sprite add (1764) | ~35 ms (0.02 ms/sprite; v6 pre-merged blobs, no runtime merge) |
| Per-frame p50 | 0.18 ms |
| Per-frame avg | 0.18 ms |

The hot path in `advance_frame` → `write_p_frame_micro` is:
1. `build_micro_ops`: pre-resolve all blob pointers from `row_ops` + slot state into a flat `MicroOp` array (~33% of advance_frame time). Uses pre-merged rows (color+alpha combined at encode time in v6 format).
2. `write_p_frame_micro`: tight loop over MicroOps — `write_ue(skip)` + `copy_blob(merged_blob)` per op, with EbspWriter's inline EBSP escaping (~66% of advance_frame time). With LTO, `copy_blob` is inlined.

Key optimizations applied:
- **Pre-resolved MicroOps** (`build_micro_ops` walks `RowOp` plans once per frame and resolves all pointer chains `slot → sprite → frame → merged_rows → MbsRow` into a flat `MicroOp` array. The write loop iterates this array with zero pointer chasing, zero branching on inactive slots, and zero overlap conditionals)
- **Pre-merged color/alpha row blobs** (at encode time, `encode_frame_merged` merges each sprite row's color and alpha blobs into a single blob: `[color_data][ue(inter_skip)][alpha_data]`. Stored pre-merged in MBS v6 format — no runtime merge at load or mux time. Halves the number of `copy_blob` calls per frame. Merged row metadata uses slot-relative leading/trailing skips)
- **Single-pass EbspWriter** (`EbspWriter` writes directly to the output buffer with inline EBSP escape checking — no intermediate RBSP buffer, no separate `rbsp_to_ebsp` scan pass)
- **Zero-run metadata fast path** (each row blob is scanned at encode time for runs of ≥16 consecutive zero bits. If none exist, `copy_blob` skips EBSP escape checking for interior bytes — only 3 boundary bytes go through `flush_byte`, then the interior is bulk-copied via memcpy (aligned) or NEON shift+write (non-aligned). This is safe because the absence of 16-bit zero runs is alignment-invariant: bit shifting doesn't create or destroy bits, so no alignment can produce two consecutive `0x00` bytes)
- **NEON-accelerated non-aligned copy** (ARM NEON `vshlq_u8` processes 16 bytes per iteration for bit-shifted blob copies: two loads, two shifts, one OR, one store. Replaces scalar byte-at-a-time shift+write. Only used for escape-free blobs on the non-aligned path)
- **Exp-golomb LUT** (pre-computed bit patterns for values 0-4095 — skip run writes are a single `write_bits` call instead of per-bit `bs_write_ue`)
- **SWAR zero-byte detection** in `copy_blob` fallback path for blobs with long zero runs (8-byte chunks checked for zero bytes via `(v - 0x0101...) & ~v & 0x8080...`; safe regions memcpy'd directly)
- **Bulk sprite loading** (`MbsSprite::load` reads entire file payload in one `fread`, parses view types into it — 3 heap allocs per sprite instead of ~3,200)
- **Pre-built row blobs** eliminate CAVLC parsing at load time and enable row-level bulk copy at mux time
- **Real-nC MBS encoding** (eliminates CAVLC re-encoding at mux time — row blob copy instead)
- **Per-frame allocation reuse** (output buffer in MuxSurface, not per-frame heap allocs)
- **Zero-free buffer allocation** (`buf_` uses `make_unique_for_overwrite` — no zeroing)
- **All-I_16x16 IDR** (~1-2 bytes/MB vs ~385 bytes/MB with I_PCM) — negligible IDR overhead even for 4K+ grids
- **Precomputed row plans** (grid layout is fixed between `add_sprite`/`remove_sprite`. `build_row_plans` precomputes a flat `RowOp` array with skip counts and overlap offsets. The mux loop iterates this plan with zero divisions, bounds checks, or slot_idx computation)
- **Blob prefetch** (`__builtin_prefetch` on the next sprite's `blob_data` pointer hides L2/L3 cache miss latency. Both within-row and cross-row prefetch in both `build_micro_ops` and `write_p_frame_micro`)
- **Lazy row plan rebuild** (row plans are only rebuilt on the first `advance_frame` after `add_sprite`/`remove_sprite`, not on every add/remove. Eliminates O(N²) plan rebuild cost when adding N sprites sequentially)

**Build note:** For best performance, build with `-DCMAKE_BUILD_TYPE=Release -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON`. LTO enables cross-TU inlining of `copy_blob` into `write_p_frame_micro`, which is critical for performance (~40% improvement over non-LTO Release).

**Note:** `RbspWriter`, `rbsp_to_ebsp_neon`, and `write_p_frame_rbsp` (two-pass RBSP staging path) remain in the codebase for reference and testing. The active P-frame path is `write_p_frame_micro`. `bs_copy_bits` and `rbsp_to_ebsp` are used by the IDR path (`write_idr_black`), the encode-time merge in `encode_frame_merged`, and test reference comparisons. The resize I_PCM path (`write_idr_ipcm`) uses single-pass EbspWriter directly — no RBSP buffer or `rbsp_to_ebsp` needed.

## ObjC++ Wrapper (SubcodecObjC)

Test-quality ObjC++ bridge exposing the C++ API to Swift. `SC` prefix. One protocol and six classes:

- `SCSprite` — Two modes: **extractor** (`SCSprite.extractor(withSpriteSize:qp:outputPath:)` — raw YUV+alpha → .mbs file via SpriteExtractor) and **encoder** (`SCSprite.encoder(withWidth:height:qp:)` — raw content-size YUV+alpha → NAL data in memory via SpriteEncoder, for reference decode). Note: `finalizeExtraction()` not `finalize()` (avoids NSObject collision).
- `SCMuxSurface` — Wraps MuxSurface. `SCMuxSurface.create(withSpriteWidth:spriteHeight:maxSlots:qp:sink:)` takes content pixels (no padding param). `addSpriteAtPath:error:` returns `SCSpriteRegion *` (slot, colorRect, alphaRect). `advanceSpriteAtSlot:` schedules one sprite for emit+advance. `emitFrameIfNeededWithSink:error:` emits a P-frame if any sprites are scheduled. `advanceFrameWithSink:error:` convenience that schedules all sprites then emits. `resizeToMaxSlots:yPlane:cbPlane:crPlane:...` returns `SCResizeResult *` (array of `SCSpriteRegion`). `checkCompactionOpportunity` returns `SCCompactionInfo *`.
- `SCResizeResult` — Result of `resizeToMaxSlots:`: `regions` array of `SCSpriteRegion` with compacted slot assignments.
- `SCCompactionInfo` — Result of `checkCompactionOpportunity`: `activeSprites`, `maxSlots`, `currentGridMbs`, `minGridMbs`.
- `SCSpriteRegion` — Result of `addSpriteAtPath:error:`: `slot` index, `colorRect` and `alphaRect` as content pixel regions in composite frame.
- `SCDecoding` — Protocol defining shared decoder interface: `createDecoderWithError:` and `decodeStream:error:`.
- `SCOpenH264Decoder` — OpenH264 software decoder. Factory: `SCOpenH264Decoder.createDecoder()`. Conforms to `SCDecoding`.
- `SCVideoToolboxDecoder` — VideoToolbox hardware decoder. Factory: `SCVideoToolboxDecoder.createDecoder()`. Conforms to `SCDecoding`. Converts Annex B → AVCC internally. Outputs NV12, deinterleaves to separate Y/Cb/Cr planes for `SCDecodedFrame`.
- `SCDecodedFrame` — YUV plane data container (width, height, y, cb, cr as NSData).

## Production Readiness

### What's production-ready
The core C++ library (`libsubcodec`) — .mbs format, real-nC encoding, MuxSurface compositing with merged-blob micro-op path — is proven correct with pixel-identical verification across 160 frames in both C++ and Swift tests. Stress-tested at 1764 sprites with ~0.18ms/frame p50 mux time (LTO Release). Verified with ffmpeg decode of real sprite data.

### What's needed for a production Apple app

1. **VideoToolbox integration (partially done)** — `SCVideoToolboxDecoder` provides bulk synchronous decode via `VTDecompressionSession`. For production, still needs:
   - Streaming frame-at-a-time decode timed to display cadence (CADisplayLink)
   - Display pipeline (CVPixelBuffer → Metal texture or CALayer)
   - The current wrapper copies YUV planes per frame; production should pass CVPixelBuffers directly to the display layer

2. **Streaming frame API** — Current ObjC++ wrapper writes into pre-allocated buffers. Production needs frame-at-a-time output timed to display cadence (CADisplayLink or similar).

3. **Encoding can be offline** — SpriteExtractor/.mbs generation can happen at build time or on a server. The app only needs MuxSurface (compositing) + VideoToolbox (decode). OpenH264 encoder need not ship in the app binary.

4. **Thread safety, error recovery, memory pressure** — Not addressed in current wrapper.

## Known Issues

- **OpenH264 OOM at large resolutions:** OpenH264's decoder runs out of memory for frame sizes around 3K+ pixels per dimension. This only affects test verification — production uses VideoToolbox for decode.

- **I_PCM + I_16x16 mixing in IDR (OpenH264 bug):** OpenH264 returns `dsBitstreamError` when an IDR slice contains a mix of I_PCM and I_16x16 MBs due to `InitReadBits(pBs, 0)` corrupting bit-reader state after I_PCM parsing. The composite IDR uses all-I_16x16 (no mixing). The resize transition IDR uses all-I_PCM (no mixing). Both avoid the bug.

- **VideoToolbox rejects long skip_runs in partially-filled grids (worked around):** VT's H.264 decoder fails with `kVTVideoDecoderBadDataErr` (-8969) on structurally valid P-frames when large mb_skip_run values (from empty grid rows) interact with certain CAVLC blob patterns. The bitstream passes H264Parser and ffmpeg validation. Worked around by `write_skip_safe`: skip_runs exceeding `MAX_SKIP_RUN` (2048) are split by inserting dummy P_16x16 zero-residual MBs (4 bits each, semantically identical to SKIP). Tested by `testVideoToolboxPartialFill`.

## Profiling (advance_frame hot path)

### Tool: `bench_profile`

`tools/bench_profile.cpp` — parameterized profiling binary for `MuxSurface::advance_frame` and `MuxSurface::resize`. Uses `os_signpost` instrumentation, designed for `xctrace` CLI (non-interactive).

```bash
# Generate demo .mbs (one-time, requires FFmpeg)
cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build
./build/sprite_extract demo/input.mp4 demo/output0.mbs 64

# Build (MUST use Release for meaningful profiles)
cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --target bench_profile

# Profile advance_frame with xctrace
xctrace record --template 'Time Profiler' --output profile.trace \
  --launch -- ./build/bench_profile --mbs-path demo/output0.mbs \
  --sprite-count 1764 --frame-count 160 --loops 100

# Profile resize (420 active sprites, resize to 882 slots, 50 iterations)
xctrace record --template 'Time Profiler' --output resize.trace \
  --launch -- ./build/bench_profile --mbs-path demo/output0.mbs \
  --profile-resize --resize-from 420 --resize-to 882 --resize-loops 50

# Export trace to XML for automated analysis
xctrace export --input profile.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > profile.xml
```

CLI args: `--mbs-path <file>` or `--input <video> --sprite-size <N>`, `--sprite-count <N>` (default 1764), `--frame-count <N>` (default 160), `--loops <N>` (default 50, total frames = frame-count × loops), `--qp <N>` (default 26), `--profile-resize` (resize mode instead of advance_frame), `--resize-from <N>` (active sprites before resize, default 420), `--resize-to <N>` (target max_slots, default 882), `--resize-loops <N>` (iterations, default 10). The `--input` mode extracts .mbs from video via FFmpeg+SpriteExtractor (one-time setup, not profiled).

Sprites are pre-loaded into memory and added via `add_sprite(MbsSprite)` by move, so file I/O doesn't contaminate the profile. In advance_frame mode, only `advance_frame` is in the profiled section. In resize mode, each iteration creates a fresh MuxSurface with `resize-from` sprites, advances one frame, then times the resize to `resize-to` slots. Reports p50/avg/min/max across all iterations.

### Parsing xctrace XML export

The `time-profile` XML contains `<row>` elements with `<weight>`, `<tagged-backtrace>`, and `<sample-time>` children. Elements use `id`/`ref` deduplication — most rows reference the first occurrence via `ref="N"`. **Critical:** count samples (rows), don't sum weights. Weight refs often all point to the same 1ms value, making weight-based aggregation unreliable. Sample count gives the correct profile.

Parse pattern:
1. Build `id_map` (all elements with `id` attr → element)
2. For each `<row>`: resolve `<tagged-backtrace>` (may be ref), find `<backtrace>`, get `<frame>` list
3. `frames[0]` = leaf (self time). `frames[0].get('name')` = function name
4. Count samples per leaf function name

### Baseline profile (1764 sprites × 16K frames, demo/output0.mbs, LTO Release)

| Function | % CPU | Role |
|---|---|---|
| `write_p_frame_micro` (incl. inlined copy_blob) | 65% | Tight micro-op loop: write_ue + copy_blob per merged blob |
| `build_micro_ops` | 33% | Pre-resolve blob pointers from row_ops + slot state |
| `MuxSurface::advance_frame` | 1% | Frame dispatch overhead |
| Other (memmove, memset) | 1% | |

Hot files: `src/mbs_mux_common.cpp` (write_p_frame_micro, build_micro_ops, EbspWriter::copy_blob), `src/mux_surface.cpp` (advance_frame dispatch).

Of the advance_frame-only time (~0.18ms p50), `write_p_frame_micro` is ~66% and `build_micro_ops` is ~33%. The `build_micro_ops` cost is dominated by pointer chasing through `slot → sprite → frames[idx] → merged_rows[row]` for ~8,862 ops per frame.

### Profile-optimize loop

1. **Profile:** `xctrace record` → export XML → parse sample counts per function
2. **Analyze:** identify top self-time function, read its source
3. **Optimize:** make ONE targeted change
4. **Verify correctness:** `cd build && ctest` (all 25 tests must pass)
5. **Re-profile:** same xctrace command, compare sample distribution
6. **Commit or revert** based on results

### Important notes

- `test_mux_perf` is the existing wall-clock benchmark (1764 sprites, 160 frames, reports p50/p95/p99). Run it before and after optimizations for wall-clock comparison.
- `test_ebsp_writer` specifically tests copy_blob correctness at all bit alignments — run after any copy_blob changes.
- The demo .mbs file (`demo/output0.mbs`) must be generated first: `./build/sprite_extract demo/input.mp4 demo/output0.mbs 64`. It's a 64×64 sprite, 6×6 MBs padded, 160 frames.

## Conventions

- PascalCase for classes/structs (`MacroblockData`, `MbsSprite`, `MuxSurface`); snake_case for functions and variables; `UPPER_CASE` for enums and macros
- Namespaces: `subcodec`, `subcodec::cavlc`, `subcodec::frame_writer`, `subcodec::mbs`, `subcodec::mux`, `subcodec::tables`
- 4-space indentation
- `std::expected<T, Error>` for fallible operations; `std::span<uint8_t>` for output buffers
- RAII and `std::vector` for dynamic allocations; `std::unique_ptr` for pimpl
- C++23 for all library and test code; OpenH264 (Telegram's copy) compiled as C++11
- h264bitstream (vendored) remains C; `const_cast` used at `bs_t` interop boundaries
