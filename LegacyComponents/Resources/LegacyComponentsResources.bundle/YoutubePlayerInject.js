function fixChrome() {
    var watermark = document.getElementsByClassName('ytp-watermark')[0];
    watermark.style.display = 'none';
    
    var button = document.getElementsByClassName('ytp-large-play-button')[0];
    button.style.display = 'none';
    button.style.opacity = '0';
    
    var video = document.getElementsByTagName('video')[0];
    video.setAttribute('webkit-playsinline', '');
    video.setAttribute('playsinline', '');
    video.webkitEnterFullscreen = undefined;
}

function initial() {
    var css = 'video::-webkit-media-controls { display:none !important; }',
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

function switchToPIP() {
    var video = document.getElementsByTagName('video')[0];
    video.webkitSetPresentationMode('picture-in-picture');
}

function receiveMessage(evt) {
    try {
        var obj = JSON.parse(evt.data);
        if (obj.cmd == 'fixChrome')
            fixChrome();
        else if (obj.cmd == 'initial')
            initial();
        else if (obj.cmd == 'switchToPIP')
            switchToPIP();
    } catch (ex) { }
}
    
window.addEventListener('message', receiveMessage, false);
