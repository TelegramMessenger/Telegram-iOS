function initialize() {
    var video = document.getElementsByTagName("video")[0];
    if (video != null) {
        video.setAttribute("webkit-playsinline", "");
        video.setAttribute("playsinline", "");
        video.webkitExitFullscreen = undefined;
        
        video.play();
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
    } catch (ex) { }
}

window.addEventListener("message", receiveMessage, false);
