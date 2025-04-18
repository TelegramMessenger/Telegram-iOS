import { TimeRangesStub } from "./TimeRangesStub.js"
import { TextTrackStub, TextTrackListStub } from "./TextTrackStub.js"

export class VideoElementStub extends EventTarget {
    constructor(id) {
        super();

        this.instanceId = id;

        this.bridgeId = window.nextInternalId;
        window.nextInternalId += 1;
        window.bridgeObjectMap[this.bridgeId] = this;

        this._currentTime = 0.0;
        this.duration = NaN;
        this.paused = true;
        this._playbackRate = 1.0;
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
        this._src = '';
        this.videoWidth = 0;
        this.videoHeight = 0;
        this.textTracks = new TextTrackListStub();
        this.isWaiting = false;
        this.currentMedia = null;

        window.bridgeInvokeAsync(this.bridgeId, "VideoElement", "constructor", {
            "instanceId": this.instanceId
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
                "instanceId": this.instanceId,
                "currentTime": value
            }).then((result) => {
                this.dispatchEvent(new Event('seeked'));
            })
        }
    }

    get playbackRate() {
        return this._playbackRate;
    }

    set playbackRate(value) {
        this._playbackRate = value;

        window.bridgeInvokeAsync(this.bridgeId, "VideoElement", "setPlaybackRate", {
            "instanceId": this.instanceId,
            "playbackRate": value
        }).then((result) => {
        })
    }

    get src() {
        return this._src;
    }

    set src(value) {
        if (this.currentMedia) {
            this.currentMedia.removeEventListener("bufferChanged", false);
        }

        this._src = value;
        var media = window.mediaSourceMap[this._src];
        this.currentMedia = media;
        if (media) {
            media.addEventListener("bufferChanged", () => {
                this.updateBufferedFromMediaSource();
            }, false);
            window.bridgeInvokeAsync(this.bridgeId, "VideoElement", "setMediaSource", {
                "instanceId": this.instanceId,
                "mediaSourceId": media.bridgeId
            }).then((result) => {
            })
        }
    }

    removeAttribute(name) {
        if (name === "src") {
            this._src = "";
        }
    }

    querySelectorAll(name) {
        if (global.isJsCore) {
            return [];
        } else {
            const fragment = document.createDocumentFragment();
            return fragment.querySelectorAll('*');
        }
    }

    removeChild(child) {
    }

    updateBufferedFromMediaSource() {
        var currentMedia = this.currentMedia;
        if (currentMedia) {
            this.buffered._ranges = currentMedia.getBufferedRanges();
        } else {
            this.buffered._ranges = [];
        }
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
                "instanceId": this.instanceId,
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
                "instanceId": this.instanceId,
            }).then((result) => {
            })
        }
    }

    canPlayType(type) {
        return 'probably';
    }

    addTextTrack(kind, label, language) {
        const textTrack = new TextTrackStub(kind, label, language);
        this.textTracks._add(textTrack);
        return textTrack;
    }

    load() {
    }

    notifySeeked() {
        this.dispatchEvent(new Event('seeking'));
        this.dispatchEvent(new Event('seeked'));
    }
}
