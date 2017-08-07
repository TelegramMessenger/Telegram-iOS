function hidePlayButton() {
    var css = 'video::-webkit-media-controls { display: none !important }',
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

var video;

function fixPlayer() {
    var controls = document.getElementsByClassName('VolumeControl')[0];
    controls.style.display = 'none';
    
    video.setAttribute('webkit-playsinline', '');
    video.setAttribute('playsinline', '');
    video.webkitEnterFullscreen = undefined;
    
    hidePlayButton();
}

function play() {
    video.play();
}

function pause() {
    video.pause();
}

function showWatermark() {
    var logo = document.getElementsByClassName('vine-logo')[0];
    logo.style.display = 'block';
}

function hideWatermark() {
    var logo = document.getElementsByClassName('vine-logo')[0];
    logo.style.display = 'none';
}

function receiveMessage(evt) {
    if ((typeof evt.data) != 'string')
        return;
    
    try {
        var obj = JSON.parse(evt.data);
        if (!obj.event || obj.event != 'inject')
            return;
        
        if (obj.cmd == 'play')
            play();
        else if (obj.cmd == 'pause')
            pause();
        else if (obj.cmd == 'showWatermark')
            showWatermark();
        else if (obj.cmd == 'hideWatermark')
            hideWatermark();
    } catch (ex) { }
}

window.addEventListener('message', receiveMessage, false);

var video = document.getElementsByTagName('video')[0];

fixPlayer();
hidePlayButton();

video.addEventListener("playing", onPlaybackStart, false);

window.parent.postMessage(JSON.stringify({ "event": "src", "data": video.src }), '*');

function onPlaybackStart() {
    window.parent.postMessage('playbackStarted', '*');
}
