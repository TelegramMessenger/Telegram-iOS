import { TimeRangesStub } from "./TimeRangesStub.js"
import { TextTrackStub, TextTrackListStub } from "./TextTrackStub.js"

export class VideoElementStub extends EventTarget {
    constructor() {
        super();

        this.bridgeId = window.nextInternalId;
        window.nextInternalId += 1;
        window.bridgeObjectMap[this.bridgeId] = this;

        this._currentTime = 0.0;
        this.duration = NaN;
        this.paused = true;
        this.playbackRate = 1.0;
        this.volume = 1.0;
        this.muted = false;
        this.readyState = 0;
        this.networkState = 0;
        this.buffered = new TimeRangesStub();
        this.seeking = false;
        this.loop = false;
        this.autoplay = false;
        this.controls = false;
        this.error = null;
        this.src = '';
        this.videoWidth = 0;
        this.videoHeight = 0;
        this.textTracks = new TextTrackListStub();
        this.isWaiting = false;

        window.bridgeInvokeAsync(this.bridgeId, "VideoElement", "constructor", {
        });

        setTimeout(() => {
            this.readyState = 4; // HAVE_ENOUGH_DATA
            this.dispatchEvent(new Event('loadedmetadata'));
            this.dispatchEvent(new Event('loadeddata'));
            this.dispatchEvent(new Event('canplay'));
            this.dispatchEvent(new Event('canplaythrough'));
        }, 0);
    }

    get currentTime() {
        return this._currentTime;
    }

    set currentTime(value) {
        if (this._currentTime != value) {
            this._currentTime = value;

            this.dispatchEvent(new Event('seeking'));

            window.bridgeInvokeAsync(this.bridgeId, "VideoElement", "setCurrentTime", {
                "currentTime": value
            }).then((result) => {
                this.dispatchEvent(new Event('seeked'));
            })
        }
    }

    bridgeUpdateBuffered(value) {
        const updatedRanges = value;
        var ranges = [];
        for (var i = 0; i < updatedRanges.length; i += 2) {
            ranges.push({
                start: updatedRanges[i],
                end: updatedRanges[i + 1]
            });
        }
        this.buffered._ranges = ranges;
    }
    
    bridgeUpdateStatus(dict) {
        var paused = !dict["isPlaying"];
        var isWaiting = dict["isWaiting"];
        var currentTime = dict["currentTime"];

        if (this.paused != paused) {
            this.paused = paused;

            if (paused) {
                this.dispatchEvent(new Event('pause'));
            } else {
                this.dispatchEvent(new Event('play'));
                this.dispatchEvent(new Event('playing'));
            }
        }

        if (this.isWaiting != isWaiting) {
            this.isWaiting = isWaiting;
            if (isWaiting) {
                this.dispatchEvent(new Event('waiting'));
            }
        }

        if (this._currentTime != currentTime) {
            this._currentTime = currentTime;
            this.dispatchEvent(new Event('timeupdate'));
        }
    }

    play() {
        if (this.paused) {
            return window.bridgeInvokeAsync(this.bridgeId, "VideoElement", "play", {
            }).then((result) => {
                this.dispatchEvent(new Event('play'));
                this.dispatchEvent(new Event('playing'));
            })
        } else {
            return Promise.resolve();
        }
    }

    pause() {
        if (!this.paused) {
            this.paused = true;
            this.dispatchEvent(new Event('pause'));

            return window.bridgeInvokeAsync(this.bridgeId, "VideoElement", "pause", {
            }).then((result) => {
            })
        }
    }

    canPlayType(type) {
        return 'probably';
    }

    _getMedia() {
        return window.mediaSourceMap[this.src];
    }

    /*_simulateTimeUpdate() {
        if (this._isPlaying) {
            // Simulate time progression
            setTimeout(() => {
                var bufferedEnd = 0.0;
                
                const media = this._getMedia();
                if (media) {
                    if (media.sourceBuffers.length != 0) {
                        this.buffered = media.sourceBuffers._buffers[0].buffered;
                        bufferedEnd = this.buffered.length == 0 ? 0 : this.buffered.end(this.buffered.length - 1);
                    }
                }

                // Consume buffered data
                if (this.currentTime < bufferedEnd) {
                    // Advance currentTime
                    this._currentTime += 0.1 * this.playbackRate; // Increment currentTime
                    this.dispatchEvent(new Event('timeupdate'));

                    // Continue simulation
                    this._simulateTimeUpdate();
                } else {
                    console.log("Buffer underrun");
                    // Buffer underrun
                    this._isPlaying = false;
                    this.paused = true;
                    this.dispatchEvent(new Event('waiting'));
                    // The player should react by buffering more data
                }
            }, 100);
        }
    }*/

    addTextTrack(kind, label, language) {
        const textTrack = new TextTrackStub(kind, label, language);
        this.textTracks._add(textTrack);
        return textTrack;
    }
}
