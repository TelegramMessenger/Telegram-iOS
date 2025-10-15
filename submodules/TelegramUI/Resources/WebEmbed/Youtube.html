<!DOCTYPE html>
<html>
<head>
    <style>
        body { margin: 0; width:100%%; height:100%%; background-color:#000; }
        html { width:100%%; height:100%%; background-color:#000; }
        .container iframe, .container object, .container embed { position: absolute; top: 0; left: 0; width: 100%% !important; height: 100%% !important; }
    </style>
</head>
<body>
    <div class="container">
        <div id="player"></div>
    </div>
    <script src="https://www.youtube.com/iframe_api"></script>
    <script>
        var player;
        var iframe;
        var error = false;
        
        function invoke(command) {
            iframe.contentWindow.postMessage(JSON.stringify({ "event": "inject", "command": command }), "*");
        }
    
        var playbackState = 0;
        var duration = 0.0;
        var position = 0.0;
        var downloadProgress = 0.0;
        var quality = "";
        var availableQualities = "";
        var failed = false;
        var autostarted = false;
        var storyboardSpec = ""

        YT.ready(function() {
            player = new YT.Player("player", %@);
            player.setSize(window.innerWidth, window.innerHeight);
                 
            function getCurrentTime() {
                 downloadProgress = player.getVideoLoadedFraction();
                 position = player.getCurrentTime();
                 //storyboardSpec = player.getStoryboardFormat();
                 
                 updateState();
                 invoke("tick");
            }
            
            window.setInterval(getCurrentTime, 500);
            invoke("initialize");
        });
        
        function play() {
            player.playVideo();
        }
    
        function pause() {
            player.pauseVideo();
        }
    
        function seek(timestamp) {
            player.seekTo(timestamp, true);
        }
        
        function setRate(rate) {
            player.setPlaybackRate(rate);
        }
        
        function updateState() {
            window.location.href = "embed://onState?failed=" + failed + "&playback=" + playbackState + "&position=" + position + "&duration=" + duration + "&download=" + downloadProgress + '&quality=' + quality + '&availableQualities=' + availableQualities + '&storyboard=' + storyboardSpec;
        }

        function onReady(event) {
            window.location.href = "embed://onReady?data=" + event.data;
            iframe = document.getElementById("player");
            iframe.referrerPolicy = "origin";
            duration = player.getDuration();
            invoke("tick");
        }
    
        function onStateChange(event) {
            if (!error) {
                playbackState = event.data;
                updateState();
            }
            else {
                error = false;
            }
        }

        function onPlaybackQualityChange(event) {
            quality = event.data;
            updateState();
        }

        function onPlayerError(event) {
            if (event.data == 100) {
                error = true;
            }
            else if (event.data == 150) {
                failed = true;
            }
            updateState();
        }

        window.onresize = function() {
            player.setSize(window.innerWidth, window.innerHeight);
        }
    </script>
</body>
</html>
