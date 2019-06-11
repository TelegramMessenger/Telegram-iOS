var video;

function hidePlayButton() {
    var css = 'video::-webkit-media-controls { display: none !important } video::--webkit-media-controls-play-button { display: none !important; -webkit-appearance: none; } video::-webkit-media-controls-start-playback-button { display: none !important; -webkit-appearance: none; }',
    head = document.head || document.getElementsByTagName('head')[0],
    style = document.createElement('style');
    
    style.type = 'text/css';
    if (style.styleSheet){
        style.styleSheet.cssText = css;
    } else {
        style.appendChild(document.createTextNode(css));
    }
    
    head.appendChild(style);
}

function fixPlayer() {
    var controls = document.getElementsByClassName('player-controls-bottom')[0];
    if (controls == null) {
        controls = document.getElementsByClassName('player-overlay-container')[0];
    }
    if (controls != null) {
        controls.style.display = 'none';
    }
    
    var topBar = document.getElementById('top-bar');
    if (topBar == null) {
        topBar = document.getElementsByClassName('player-controls-top')[0];
    }
    if (topBar != null) {
        topBar.style.display = 'none';
    }
    
    var pauseOverlay = document.getElementsByClassName('player-play-overlay')[0];
    if (pauseOverlay == null) {
        pauseOverlay = document.getElementsByClassName('player-controls-bottom')[0];
    }
    if (pauseOverlay != null) {
        pauseOverlay.style.display = 'none';
    }
    
    var statusOverlay = document.getElementsByClassName('player-streamstatus')[0];
    if (statusOverlay != null) {
        statusOverlay.style.right = undefined;
        statusOverlay.style.left = '0px';
        statusOverlay.style.padding = '1.5em 1.5em 5.5em 2.5em';
    }
    
    var recommendationOverlay = document.getElementById('js-player-recommendations-overlay');
    if (recommendationOverlay != null) {
        recommendationOverlay.style.display = 'none';
    }
    
    var adOverlay = document.getElementsByClassName('player-ad-overlay')[0];
    if (adOverlay != null) {
        adOverlay.style.display = 'none';
    }
    
    var alertOverlay = document.getElementById('js-player-alert-container');
    if (alertOverlay != null) {
        alertOverlay.style.display = 'none';
    }
    
    var video = document.getElementsByTagName('video')[0];
    video.setAttribute('webkit-playsinline', '');
    video.setAttribute('playsinline', '');
    video.webkitEnterFullscreen = undefined;
    
    video.addEventListener("playing", onPlaybackStart, false);
    
    video.play();
    
    hidePlayButton();
    
    var ageButton = document.getElementById('mature-link');
    if (ageButton != null) {
        eventFire(ageButton, 'click');
    }
}

function onPlaybackStart() {
    window.parent.postMessage('playbackStarted', '*');
}

function switchToPIP() {
    var video = document.getElementsByTagName('video')[0];
    video.webkitSetPresentationMode('picture-in-picture');
}

function eventFire(el, etype){
    if (el.fireEvent) {
        el.fireEvent('on' + etype);
    } else {
        var evObj = document.createEvent('Events');
        evObj.initEvent(etype, true, false);
        el.dispatchEvent(evObj);
    }
}

function play() {
    var playButton = document.getElementsByClassName('js-control-playpause-button')[0];
    if (playButton == null) {
        playButton = document.getElementsByClassName('player-button--playpause')[0];
    }
    
    eventFire(playButton, 'click');
}

function receiveMessage(evt) {
    if ((typeof evt.data) != 'string')
        return;
    
    try {
        var obj = JSON.parse(evt.data);
        if (!obj.event || obj.event != 'inject')
            return;
        
        if (obj.cmd == 'fixPlayer')
            fixPlayer();
        else if (obj.cmd == 'play')
            play();
        else if (obj.cmd == 'switchToPIP')
            switchToPIP();
    } catch (ex) { }
}

window.addEventListener('message', receiveMessage, false);

