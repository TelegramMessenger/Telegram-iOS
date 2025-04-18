function initialize() {
    var controls = document.getElementsByClassName("vp-controls-wrapper")[0];
    if (controls != null) {
        controls.style.display = "none";
    }
    
    var sidedock = document.getElementsByClassName("vp-sidedock")[0];
    if (sidedock != null) {
        sidedock.style.display = "none";
    }
    
//    var video = document.getElementsByTagName("video")[0];
//    if (video != null) {
//        video.setAttribute("webkit-playsinline", "");
//        video.setAttribute("playsinline", "");
//        video.webkitEnterFullscreen = undefined;
//    }
}

function eventFire(el, etype){
    if (el.fireEvent) {
        el.fireEvent("on" + etype);
    } else {
        var evObj = document.createEvent("Events");
        evObj.initEvent(etype, true, false);
        el.dispatchEvent(evObj);
    }
}

function autoplay() {
    var playButton = document.getElementsByClassName("play")[0];
    if (playButton != null) {
        eventFire(playButton, "click");
    }
}

function receiveMessage(evt) {
    if ((typeof evt.data) != "string")
        return;
    
    try {
        var obj = JSON.parse(evt.data);
        if (!obj.event || obj.event != "inject")
            return;
        
        if (obj.command == "initialize")
            initialize();
        else if (obj.command == "autoplay")
            autoplay();
    } catch (ex) { }
}

window.addEventListener("message", receiveMessage, false);
