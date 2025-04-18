
function base64ToArrayBuffer(base64) {
    var binaryString = atob(base64);
    var bytes = new Uint8Array(binaryString.length);
    for (var i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes.buffer;
}

export class XMLHttpRequestStub extends EventTarget {
    constructor() {
        super();

        this.bridgeId = window.nextInternalId;
        window.nextInternalId += 1;

        this.readyState = 0;
        this.status = 0;
        this.statusText = "";
        this.responseText = "";
        this.responseXML = null;
        this._responseData = null;
        this.onreadystatechange = null;
        this._requestHeaders = {};
        this._responseHeaders = {};
        this._method = "";
        this._url = "";
        this._async = true;
        this._user = null;
        this._password = null;
        this._responseType = "";
    }
  
    open(method, url, async = true, user = null, password = null) {
        this._method = method;
        this._url = url;
        this._async = async;
        this._user = user;
        this._password = password;
        this.readyState = 1; // Opened
        this._triggerReadyStateChange();
    }
  
    setRequestHeader(header, value) {
        this._requestHeaders[header] = value;
    }
  
    getResponseHeader(header) {
        return this._responseHeaders[header.toLowerCase()] || null;
    }
  
    getAllResponseHeaders() {
        return Object.entries(this._responseHeaders)
            .map(([header, value]) => `${header}: ${value}`)
            .join('\r\n');
    }
  
    send(body = null) {
        this.readyState = 2;
        this._triggerReadyStateChange();

        this.readyState = 3; // Loading
        this._triggerReadyStateChange();

        this.dispatchEvent(new Event("loadstart"));

        window.bridgeInvokeAsync(this.bridgeId, "XMLHttpRequest", "load", {
            "id": this.bridgeId,
            "url": this._url,
            "requestHeaders": this._requestHeaders
        }).then((result) => {
            if (result["error"]) {
                this.dispatchEvent(new Event("error"));
            } else {
                this.status = result["status"];
                this.statusText = result["statusText"];

                if (result["responseData"]) {
                    if (this._responseType === "arraybuffer") {
                        this._responseData = base64ToArrayBuffer(result["responseData"]);
                    } else {
                        this.responseText = atob(result["responseData"]);
                    }
                    this.responseXML = null;
                } else {
                    this.response = null;
                    this.responseText = result["responseText"] || null;
                    this.responseXML = result["responseXML"] || null;
                }
                this._responseHeaders = result["responseHeaders"];

                this.readyState = 4; // Done
                this._triggerReadyStateChange();

                this.dispatchEvent(new Event("load"));
            }

            this.dispatchEvent(new Event("loadend"));
        });
    }
  
    abort() {
        this.dispatchEvent(new Event("abort"));

        window.bridgeInvokeAsync(this.bridgeId, "XMLHttpRequest", "abort", {
            "id": this.bridgeId
        });
        this.readyState = 0;
        this.status = 0;
        this.statusText = '';
        this.responseText = '';
        this.responseXML = null;
        this._responseHeaders = {};
        this._triggerReadyStateChange();
    }
  
    overrideMimeType(mime) {
    }
  
    set responseType(type) {
        this._responseType = type;
    }
  
    get responseType() {
        return this._responseType;
    }
  
    get response() {
        if (this._responseType === '' || this._responseType === 'text') {
            return this.responseText;
        }
        return this._responseData;
    }
  
    _triggerReadyStateChange() {
        this.dispatchEvent(new Event('readystatechange'));
        if (typeof this.onreadystatechange === 'function') {
            this.onreadystatechange();
        }
    }
  
    // Additional methods to simulate responses
    _setResponse(status, statusText, responseText, responseHeaders = {}) {
      this.status = status;
      this.statusText = statusText;
      this.responseText = responseText;
      this._responseHeaders = responseHeaders;
    }
}
