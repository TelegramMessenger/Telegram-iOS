import Hls from "hls.js";
import { VideoElementStub } from "./VideoElementStub.js"
import { MediaSourceStub, SourceBufferStub } from "./MediaSourceStub.js"

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

var useStubs = true;

window.nextInternalId = 0;
window.mediaSourceMap = {};

// Replace the global MediaSource with our stub
if (useStubs && typeof window !== 'undefined') {
    window.MediaSource = MediaSourceStub;
    window.ManagedMediaSource = MediaSourceStub;
    window.SourceBuffer = SourceBufferStub;
    URL.createObjectURL = function(ms) {
        const url = "blob:mock-media-source:" + ms.internalId;
        window.mediaSourceMap[url] = ms;
        return url;
    };
}


function postPlayerEvent(eventName, eventData) {
    if (window.webkit && window.webkit.messageHandlers) {
        window.webkit.messageHandlers.performAction.postMessage({'event': eventName, 'data': eventData});
    }
};

var video;
var hls;

var isManifestParsed = false;
var isFirstFrameReady = false;

var currentTimeUpdateTimeout = null;

export function playerInitialize(params) {
    video.muted = false;

    video.addEventListener('loadeddata', (event) => {
        if (!isFirstFrameReady) {
            isFirstFrameReady = true;
            refreshPlayerStatus();
        }
    });
    video.addEventListener("playing", function() {
        refreshPlayerStatus();
    });
    video.addEventListener("pause", function() { 
        refreshPlayerStatus();
    });
    video.addEventListener("seeking", function() { 
        refreshPlayerStatus();
    });
    video.addEventListener("waiting", function() { 
        refreshPlayerStatus();
    });

    hls = new Hls({
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
    hls.on(Hls.Events.MANIFEST_PARSED, function() {
        isManifestParsed = true;
        refreshPlayerStatus();
    });

    hls.on(Hls.Events.LEVEL_SWITCHED, function() {
        refreshPlayerStatus();
    });
    hls.on(Hls.Events.LEVELS_UPDATED, function() {
        refreshPlayerStatus();
    });

    hls.loadSource('master.m3u8');
    hls.attachMedia(video);
}

export function playerLoad(initialLevelIndex) {
    hls.startLevel = initialLevelIndex;
    hls.startLoad(-1, false);
}

export function playerPlay() {
    video.play();
}

export function playerPause() {
    video.pause();
}

export function playerSetBaseRate(value) {
    video.playbackRate = value;
}

export function playerSetLevel(level) {
    if (level >= 0) {
        hls.currentLevel = level;
    } else {
        hls.currentLevel = -1;
    }
}

export function playerSeek(value) {
    video.currentTime = value;
}

export function playerSetIsMuted(value) {
    video.muted = value;
}

function getLevels() {
    var levels = [];
    for (var i = 0; i < hls.levels.length; i++) {
        var level = hls.levels[i];
        levels.push({
            'index': i,
            'bitrate': level.bitrate || 0,
            'width': level.width || 0,
            'height': level.height || 0
        });
    }
    return levels;
}

function refreshPlayerStatus() {
    var isPlaying = false;
    if (!video.paused && !video.ended && video.readyState > 2) {
        isPlaying = true;
    }

    postPlayerEvent('playerStatus', {
        'isReady': isManifestParsed,
        'isFirstFrameReady': isFirstFrameReady,
        'isPlaying': !video.paused,
        'rate': isPlaying ? video.playbackRate : 0.0,
        'defaultRate': video.playbackRate,
        'levels': getLevels(),
        'currentLevel': hls.currentLevel
    });

    refreshPlayerCurrentTime();

    if (isPlaying) {
        if (currentTimeUpdateTimeout == null) {
            currentTimeUpdateTimeout = setTimeout(() => {
                refreshPlayerCurrentTime();
            }, 200);
        }
    } else {
        if(currentTimeUpdateTimeout != null){
            clearTimeout(currentTimeUpdateTimeout);
            currentTimeUpdateTimeout = null;
        }
    }
}

function refreshPlayerCurrentTime() {
    postPlayerEvent('playerCurrentTime', {
        'value': video.currentTime
    });
    currentTimeUpdateTimeout = setTimeout(() => {
        refreshPlayerCurrentTime()
    }, 200);
}

window.onload = () => {
    if (useStubs) {
        video = new VideoElementStub();
    } else {
        video = document.createElement('video');
        video.playsInline = true;
        video.controls = true;
        document.body.appendChild(video);
    }

    postPlayerEvent('windowOnLoad', {
    });
};

window.playerInitialize = playerInitialize;
window.playerLoad = playerLoad;
window.playerPlay = playerPlay;
window.playerPause = playerPause;
window.playerSetBaseRate = playerSetBaseRate;
window.playerSetLevel = playerSetLevel;
window.playerSeek = playerSeek;
window.playerSetIsMuted = playerSetIsMuted;
window.bridgeInvokeCallback = bridgeInvokeCallback;