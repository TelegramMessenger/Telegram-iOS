function initialize() {
    var css = "video::-webkit-media-controls { display: none !important } video::--webkit-media-controls-play-button { display: none !important; -webkit-appearance: none; } video::-webkit-media-controls-start-playback-button { display: none !important; -webkit-appearance: none; }",
    head = document.head || document.getElementsByTagName("head")[0],
    style = document.createElement("style");
    
    style.type = "text/css";
    if (style.styleSheet) {
        style.styleSheet.cssText = css;
    } else {
        style.appendChild(document.createTextNode(css));
    }
    
    head.appendChild(style);
}

function tick() {
    var watermark = document.getElementsByClassName("ytp-watermark")[0];
    if (watermark != null) {
//        watermark.style.display = "none";
    }
    
    var button = document.getElementsByClassName("ytp-large-play-button")[0];
    if (button != null) {
//        button.style.display = "none";
//        button.style.opacity = "0";
    }
    
    var progress = document.getElementsByClassName("ytp-spinner-container")[0];
    if (progress != null) {
//        progress.style.display = "none";
//        progress.style.opacity = "0";
    }
    
    var pause = document.getElementsByClassName("ytp-pause-overlay")[0];
    if (pause != null) {
//        pause.style.display = "none";
//        pause.style.opacity = "0";
    }
    
    var chrome = document.getElementsByClassName("ytp-chrome-top")[0];
    if (chrome != null) {
//        chrome.style.display = "none";
//        chrome.style.opacity = "0";
    }
    
    var paid = document.getElementsByClassName("ytp-paid-content-overlay")[0];
    if (paid != null) {
//        paid.style.display = "none";
//        paid.style.opacity = "0";
    }
    
    var gradient = document.getElementsByClassName("ytp-gradient-top")[0];
    if (gradient != null) {
//        gradient.style.display = "none";
//        gradient.style.opacity = "0";
    }
    
    var end = document.getElementsByClassName("html5-endscreen")[0];
    if (end != null) {
//        end.style.display = "none";
//        end.style.opacity = "0";
    }
    
    var elements = document.getElementsByClassName("ytp-ce-element");
    for (var i = 0; i < elements.length; i++) {
        var element = elements[i]
//        element.style.display = "none";
//        element.style.opacity = "0";
    }
    
    var video = document.getElementsByTagName("video")[0];
    if (video != null) {
        video.setAttribute("webkit-playsinline", "");
        video.setAttribute("playsinline", "");
        video.webkitEnterFullscreen = undefined;
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
        else if (obj.command == "tick")
            tick();
    } catch (ex) { }
}
    
window.addEventListener("message", receiveMessage, false);
