---
title: Synchronous Concurrency
layout: docs
permalink: /docs/synchronous-concurrency.html
prevPage: subtree-rasterization.html
nextPage: corner-rounding.html
---

Both `ASViewController` and `ASCellNode` have a property called `neverShowPlaceholders`.  

By setting this property to YES, the main thread will be blocked until display has completed for the cell or view controller's view.

Using this option does not eliminate all of the performance advantages of Texture. Normally, a given node has been preloading and is almost done when it reaches the screen, so the blocking time is very short.  Even if the rangeTuningParameters are set to 0 this option outperforms UIKit.  While the main thread is waiting, all subnode display executes concurrently, thus synchronous concurrency.

See the <a href="https://goo.gl/KJijuX">NSSpain 2015 talk video</a> for a visual walkthrough of this behavior.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
node.neverShowPlaceholders = YES;
</pre>
<pre lang="swift" class = "swiftCode hidden">
node.neverShowPlaceholders = true
</pre>
</div>
</div>
<br>

Usually, if a cell hasn't finished its display pass before it has reached the screen it will show placeholders until it has drawing its content.  Setting this option to YES makes your scrolling node or ASViewController act more like UIKit, and in fact makes Texture scrolling visually indistinguishable from UIKit's, except that it's faster.

<img src="/static/images/synchronous-concurrency.jpg" width="50%">
