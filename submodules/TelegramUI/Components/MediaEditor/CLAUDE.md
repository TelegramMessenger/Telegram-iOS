# MediaEditor

## Story and chat video writer (`MediaEditorVideoStreamingWriter`)

A story's or a chat video's export on the modern pipeline (`FetchVideoMediaResource`, `MediaEditorVideoExport`
subject `.video`) writes through `MediaEditorVideoStreamingWriter` instead of `AVAssetWriter`: VideoToolbox encodes,
`AVAudioConverter` makes AAC, and FFmpeg's mp4 muxer (`FFMpegMP4StreamWriter` in `FFMpegBinding`) writes the file with
space for `moov` reserved after `ftyp`. Finishing the file writes only its head (`moov` into the reserved space, the
`mdat` size), so everything after the head is final the moment it is written; that is what a later parallel upload
relies on. Chat videos still on the legacy converter (`TGMediaVideoConverter`), avatars, stickers and the other
`MediaEditorVideoExport` callers are unchanged.

**Stories and chat videos upload while they are exported** whenever this writer is used:
`FetchVideoMediaResource` hands the growing file to `MediaBox` in 512 KB `dataPart`s (a chat video once it is past
10 MB, a story from the start), through
`MediaEditorVideoExport.streamingFileGrowth`, then the rest, the final head (`replaceHeader` over `0 ..< headerEnd`)
and completion. The uploader (`MultipartUploadManager`) holds back every part the head touches until the file is
complete, reading the head's length from the resource's `headerSize` when the first data arrives; the fetch registers the
real `headerEnd` for the resource (`setStreamingVideoHeaderSize` in `LocalMediaResources`) before handing over any data,
so a long video's head (several parts) is never sent with the placeholder in it. Small parts (`saveFilePart`) cannot
carry a file over 10 MB, and an uploader that already sent a part cannot change its part size, so nothing is handed over
below 10 MB, and `MultipartUploadManager` switches an incomplete source that grows past 10 MB before its first part to
512 KB big parts (`MultipartUploadTests` covers both). Stories upload with `forceNoBigParts` (`uploadedStoryContent`),
so they keep 128 KB small parts whatever their size, also when streamed, and need no threshold.

Turning it off, separately for stories and chats:
- app config `ios_killswitch_disable_story_streaming_video_writer` / `ios_killswitch_disable_chat_streaming_video_writer`
  (read in `TelegramAccountAuxiliaryMethods`, passed to the fetch);
- Debug Settings ▸ "Stories: legacy video writer" / "Chat videos: legacy video writer", mirrored into
  `MediaEditorVideoExport.forceLegacyStoryWriter` / `forceLegacyChatWriter` by `SharedAccountContext` and read when an
  export starts.

Measured against `AVAssetWriter` (the experiment in `~/Projects/_Experiments/ParallelUpload`, iPhone 17 Pro Max):
identical decoded frames and audio packets, 2–3% faster, less peak memory.

None of these shows up as a build error; each one was a bug:

- **No frame duration to `VTCompressionSessionEncodeFrame`** (`.invalid`), as `AVAssetWriter` does: a duration
  changes the encoder's decisions. `MaxKeyFrameInterval = 30` matches `AVAssetWriter`'s default keyframes.
- **The encoder queue is capped, adaptively.** Without a cap the composer outruns the encoder and memory grows until
  jetsam. A fixed cap below the encoder's frame delay deadlocks (the encoder holds frames for B-frame reordering and
  returns nothing): the cap starts at 8 and grows by one whenever the queue stays full for 20 ms with nothing encoded.
- **Every data callback runs in an `autoreleasepool`**, as `AVAssetWriterInput.requestMediaDataWhenReady` does;
  without it the composer's autoreleased images keep every source frame alive until the export ends.
- VideoToolbox reports `dts > pts` for reordered frames, which libavformat rejects (`write_packet: Invalid argument`).
  A video's DTS is the smallest PTS not yet used, once as many frames as the reorder depth (in frames, measured on the
  first 16 packets) have arrived. **A shift in time does not work**: screen recordings and other variable-frame-rate
  sources space frames unevenly, and a shift measured on the first frames is too small later. The export harness
  scenarios `story-` / `chat-video-variable-frame-rate-trimmed-streaming` cover it
  (`Harness/run-export-harness.sh export <out> <ids>`; the export scenarios do not compose frames under the
  `MediaEditorExportTests` ios_unit_test).
- **A writer failure while a frame is being composed must still end the export**: `encodeVideo` returns `false` when
  the append failed, since `markVideoAsFinished` has already stopped the writer from calling it again; returning `true`
  left the export, and the chat message, in processing forever.
- AAC priming goes into the edit list (negative first PTS), the encoder's tail padding is trimmed through the last
  packet's duration.
- **Packets are written in 0.5 s runs per track** (`FFMpegMP4StreamWriter`, `av_write_frame`), as `AVAssetWriter`
  does, not FFmpeg's packet-by-packet interleaving: each run is one chunk, so `stco`/`stsc` stay small; packet-by-packet
  they took half of `moov`. A stream that stops early is waited for at most 10 s of buffered packets.
- **The reservation and the upper bound must agree.** `reservedMoovSize` assumes per video sample 5 bytes (`stsz`,
  `sdtp`), one `stts` and one `ctts` entry each (variable frame rate, B-frames) and a keyframe every eighth frame, and
  20 bytes per chunk; the muxer's bound counts the real runs and chunks. A bound above the reservation moves `moov` to
  the end (below), so loosening the bound or tightening the reservation silently loses faststart.
- **A reservation that turns out too small is not an error**: `FFMpegMP4StreamWriter` compares an upper bound of the
  `moov` size from the written sample counts with the reservation before the trailer and, if it may not fit, writes
  `moov` at the end and turns the reserved space into a `free` box (a valid file, just not head-first).
