import "event-target-polyfill";
import {decode, encode} from "base-64";

import { VideoElementStub } from "./VideoElementStub.js"
import { MediaSourceStub, SourceBufferStub } from "./MediaSourceStub.js"
import { XMLHttpRequestStub } from "./XMLHttpRequestStub.js"

global.isJsCore = false;

if (!global.btoa) {
    global.btoa = encode;
}

if (!global.atob) {
    global.atob = decode;
}

if (typeof window === 'undefined') {
    global.isJsCore = true;

    global.navigator = {
        userAgent: "Telegram"
    };

    global.now = function() {
        return _JsCorePolyfills.performanceNow();
    };
    
    global.window = {
    };

    global.URL = {
    };

    window.webkit = {
    };
    window.webkit.messageHandlers = {
    };
    window.webkit.messageHandlers.performAction = {
    };
    window.webkit.messageHandlers.performAction.postMessage = function(dict) {
        _JsCorePolyfills.postMessage(dict);
    };

    global.self.location = {
        href: "http://127.0.0.1"
    };
    global.self.setTimeout = global.setTimeout;
    global.self.setInterval = global.setInterval;
    global.self.clearTimeout = global.clearTimeout;
    global.self.clearInterval = global.clearTimeout;
    global.self.URL = global.URL;
    global.self.Date = global.Date;
}

import Hls from "hls.js";

window.bridgeObjectMap = {};
window.bridgeCallbackMap = {};

function bridgeInvokeAsync(bridgeId, className, methodName, params) {
    var promiseResolve;
    var promiseReject;
    var result = new Promise(function(resolve, reject) {
        promiseResolve = resolve;
        promiseReject = reject;
    });
    const callbackId = window.nextInternalId;
    window.nextInternalId += 1;
    window.bridgeCallbackMap[callbackId] = promiseResolve;

    if (window.webkit.messageHandlers) {
        window.webkit.messageHandlers.performAction.postMessage({
            'event': 'bridgeInvoke',
            'data': {
                'bridgeId': bridgeId,
                'className': className,
                'methodName': methodName,
                'params': params,
                'callbackId': callbackId
            }
        });
    }

    return result;
}
window.bridgeInvokeAsync = bridgeInvokeAsync

export function bridgeInvokeCallback(callbackId, result) {
    const callback = window.bridgeCallbackMap[callbackId];
    if (callback) {
        callback(result);
    }
}

window.nextInternalId = 0;
window.mediaSourceMap = {};

// Replace the global MediaSource with our stub
if (typeof window !== 'undefined') {
    window.MediaSource = MediaSourceStub;
    window.ManagedMediaSource = MediaSourceStub;
    window.SourceBuffer = SourceBufferStub;
    window.XMLHttpRequest = XMLHttpRequestStub;

    URL.createObjectURL = function(ms) {
        const url = "blob:mock-media-source:" + ms.internalId;
        window.mediaSourceMap[url] = ms;
        return url;
    };

    URL.revokeObjectURL = function(url) {
    };

    if (global.isJsCore) {
        global.HTMLVideoElement = VideoElementStub;

        global.self.MediaSource = window.MediaSource;
        global.self.ManagedMediaSource = window.ManagedMediaSource;
        global.self.SourceBuffer = window.SourceBuffer;
        global.self.XMLHttpRequest = window.XMLHttpRequest;
        global.self.HTMLVideoElement = VideoElementStub;
    }
}

function postPlayerEvent(id, eventName, eventData) {
    if (window.webkit && window.webkit.messageHandlers) {
        window.webkit.messageHandlers.performAction.postMessage({'instanceId': id, 'event': eventName, 'data': eventData});
    }
}

export class HlsPlayerInstance {
    constructor(id) {
        this.id = id;
        this.isManifestParsed = false;
        this.currentTimeUpdateTimeout = null;
        this.notifySeekedOnNextStatusUpdate = false;
        this.video = new VideoElementStub(this.id);
    }

    playerInitialize(params) {
        this.video.addEventListener("playing", () => {
            this.refreshPlayerStatus();
        });
        this.video.addEventListener("pause", () => { 
            this.refreshPlayerStatus();
        });
        this.video.addEventListener("seeking", () => { 
            this.refreshPlayerStatus();
        });
        this.video.addEventListener("waiting", () => { 
            this.refreshPlayerStatus();
        });
    
        this.hls = new Hls({
            startLevel: 0,
            testBandwidth: false,
            debug: params['debug'] || true,
            autoStartLoad: false,
            backBufferLength: 30,
            maxBufferLength: 60,
            maxMaxBufferLength: 60,
            maxFragLookUpTolerance: 0.001,
            nudgeMaxRetry: 10000
        });
        this.hls.on(Hls.Events.MANIFEST_PARSED, () => {
            this.isManifestParsed = true;
            this.refreshPlayerStatus();
        });
    
        this.hls.on(Hls.Events.LEVEL_SWITCHED, () => {
            this.refreshPlayerStatus();
        });
        this.hls.on(Hls.Events.LEVELS_UPDATED, () => {
            this.refreshPlayerStatus();
        });
    
        this.hls.loadSource(params["urlPrefix"] + "master.m3u8");
        this.hls.attachMedia(this.video);
    }

    playerLoad(initialLevelIndex) {
        this.hls.startLevel = initialLevelIndex;
        this.hls.startLoad(-1, false);
    }

    playerPlay() {
        this.video.play();
    }

    playerPause() {
        this.video.pause();
    }

    playerSetBaseRate(value) {
        this.video.playbackRate = value;
    }

    playerSetLevel(level) {
        if (level >= 0) {
            this.hls.currentLevel = level;
        } else {
            this.hls.currentLevel = -1;
        }
    }

    playerSetCapAutoLevel(level) {
        if (level >= 0) {
            this.hls.autoLevelCapping = level;
        } else {
            this.hls.autoLevelCapping = -1;
            //this.hls.currentLevel = -1;
        }
    }

    playerSeek(value) {
        this.video.currentTime = value;
    }

    playerSetIsMuted(value) {
        this.video.muted = value;
    }

    getLevels() {
        var levels = [];
        for (var i = 0; i < this.hls.levels.length; i++) {
            var level = this.hls.levels[i];
            levels.push({
                'index': i,
                'bitrate': level.bitrate || 0,
                'width': level.width || 0,
                'height': level.height || 0
            });
        }
        return levels;
    }

    refreshPlayerStatus() {
        var isPlaying = false;
        if (!this.video.paused && !this.video.ended && this.video.readyState > 2) {
            isPlaying = true;
        }
    
        postPlayerEvent(this.id, 'playerStatus', {
            'isReady': this.isManifestParsed,
            'isPlaying': !this.video.paused,
            'rate': isPlaying ? this.video.playbackRate : 0.0,
            'defaultRate': this.video.playbackRate,
            'levels': this.getLevels(),
            'currentLevel': this.hls.currentLevel
        });
    
        this.refreshPlayerCurrentTime();
    
        if (isPlaying) {
            if (this.currentTimeUpdateTimeout == null) {
                this.currentTimeUpdateTimeout = setTimeout(() => {
                    this.refreshPlayerCurrentTime();
                }, 200);
            }
        } else {
            if(this.currentTimeUpdateTimeout != null){
                clearTimeout(this.currentTimeUpdateTimeout);
                this.currentTimeUpdateTimeout = null;
            }
        }

        if (this.notifySeekedOnNextStatusUpdate) {
            this.notifySeekedOnNextStatusUpdate = false;
            this.video.notifySeeked();
        }
    }

    playerNotifySeekedOnNextStatusUpdate() {
        this.notifySeekedOnNextStatusUpdate = true;
    }

    refreshPlayerCurrentTime() {
        postPlayerEvent(this.id, 'playerCurrentTime', {
            'value': this.video.currentTime
        });
        this.currentTimeUpdateTimeout = setTimeout(() => {
            this.refreshPlayerCurrentTime()
        }, 200);
    }
}

window.invokeOnLoad = function() {
    postPlayerEvent(this.id, 'windowOnLoad', {
    });
}

window.onload = () => {
    window.invokeOnLoad();
};

window.hlsPlayer_instances = {};

window.hlsPlayer_makeInstance = function(id) {
    window.hlsPlayer_instances[id] = new HlsPlayerInstance(id);
}

window.hlsPlayer_destroyInstance = function(id) {
    const instance = window.hlsPlayer_instances[id];
    if (instance) {
        delete window.hlsPlayer_instances[id];
        instance.video.pause();
        instance.hls.destroy();
    }
}

window.bridgeInvokeCallback = bridgeInvokeCallback;

if (global.isJsCore) {
    window.onload();
}
