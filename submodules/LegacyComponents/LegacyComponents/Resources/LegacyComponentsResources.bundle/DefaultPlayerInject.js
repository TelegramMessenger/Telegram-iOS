function fixInline() {
    var video = document.getElementsByTagName('video')[0];
    video.setAttribute('webkit-playsinline', '');
    video.setAttribute('playsinline', '');
    video.webkitExitFullscreen = undefined;
    
    video.play();
}

function receiveMessage(evt) {
    try {
        var obj = JSON.parse(evt.data);
        if (obj.cmd == 'fixInline')
            fixInline();
    } catch (ex) { }
}

window.addEventListener('message', receiveMessage, false);
