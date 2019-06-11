function fixPlayer() {
    var controls = document.getElementsByClassName('controls')[0];
    controls.style.display = 'none';
    
    var sidedock = document.getElementsByClassName('sidedock')[0];
    sidedock.style.display = 'none';
    
    var video = document.getElementsByTagName('video')[0];
    video.setAttribute('webkit-playsinline', '');
    video.setAttribute('playsinline', '');
    video.webkitEnterFullscreen = undefined;
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

function initialPlay() {
    var playButton = document.getElementsByClassName('play')[0];
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
        else if (obj.cmd == 'initialPlay')
            initialPlay();
        else if (obj.cmd == 'switchToPIP')
            switchToPIP();
    } catch (ex) { }
}

window.addEventListener('message', receiveMessage, false);
