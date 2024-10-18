import { TimeRangesStub } from "./TimeRangesStub.js"

function bytesToBase64(bytes) {
    const binString = Array.from(bytes, (byte) =>
        String.fromCodePoint(byte),
    ).join("");
    return btoa(binString);
}

export class SourceBufferListStub extends EventTarget {
    constructor() {
        super();
        this._buffers = [];
    }

    _add(buffer) {
        this._buffers.push(buffer);
        this.dispatchEvent(new Event('addsourcebuffer'));
    }

    _remove(buffer) {
        const index = this._buffers.indexOf(buffer);
        if (index === -1) {
            return false;
        }
        this._buffers.splice(index, 1);
        this.dispatchEvent(new Event('removesourcebuffer'));
        return true;
    }

    get length() {
        return this._buffers.length;
    }

    item(index) {
        return this._buffers[index];
    }

    [Symbol.iterator]() {
        return this._buffers[Symbol.iterator]();
    }
}

export class SourceBufferStub extends EventTarget {
    constructor(mediaSource, mimeType) {
        super();
        this.mediaSource = mediaSource;
        this.mimeType = mimeType;
        this.updating = false;
        this.buffered = new TimeRangesStub();
        this.timestampOffset = 0;
        this.appendWindowStart = 0;
        this.appendWindowEnd = Infinity;

        this.bridgeId = window.nextInternalId;
        window.nextInternalId += 1;
        window.bridgeObjectMap[this.bridgeId] = this;

        window.bridgeInvokeAsync(this.bridgeId, "SourceBuffer", "constructor", {
            "mediaSourceId": this.mediaSource.bridgeId,
            "mimeType": mimeType
        });
    }

    appendBuffer(data) {
        if (this.updating) {
            throw new DOMException('SourceBuffer is updating', 'InvalidStateError');
        }
        this.updating = true;
        this.dispatchEvent(new Event('updatestart'));

        window.bridgeInvokeAsync(this.bridgeId, "SourceBuffer", "appendBuffer", {
            "data": bytesToBase64(data)
        }).then((result) => {
            const updatedRanges = result["ranges"];
            var ranges = [];
            for (var i = 0; i < updatedRanges.length; i += 2) {
                ranges.push({
                    start: updatedRanges[i],
                    end: updatedRanges[i + 1]
                });
            }
            this.buffered._ranges = ranges;

            this.mediaSource._reopen();
            this.mediaSource.emitUpdatedBuffer();

            this.updating = false;
            this.dispatchEvent(new Event('update'));
            this.dispatchEvent(new Event('updateend'));
        });
    }

    abort() {
        if (this.updating) {
            this.updating = false;
            this.dispatchEvent(new Event('abort'));

            window.bridgeInvokeAsync(this.bridgeId, "SourceBuffer", "abort", {}).then((result) => {
            });
        }
    }

    remove(start, end) {
        if (this.updating) {
            throw new DOMException('SourceBuffer is updating', 'InvalidStateError');
        }
        this.updating = true;
        this.dispatchEvent(new Event('updatestart'));

        window.bridgeInvokeAsync(this.bridgeId, "SourceBuffer", "remove", {
            "start": start,
            "end": end
        }).then((result) => {
            const updatedRanges = result["ranges"];
            var ranges = [];
            for (var i = 0; i < updatedRanges.length; i += 2) {
                ranges.push({
                    start: updatedRanges[i],
                    end: updatedRanges[i + 1]
                });
            }
            this.buffered._ranges = ranges;

            this.mediaSource._reopen();
            this.mediaSource.emitUpdatedBuffer();

            this.updating = false;
            this.dispatchEvent(new Event('update'));
            this.dispatchEvent(new Event('updateend'));
        });
    }
}

export class MediaSourceStub extends EventTarget {
    constructor() {
        super();

        this.internalId = window.nextInternalId;
        window.nextInternalId += 1;

        this.bridgeId = window.nextInternalId;
        window.nextInternalId += 1;
        window.bridgeObjectMap[this.bridgeId] = this;

        this.sourceBuffers = new SourceBufferListStub();
        this.activeSourceBuffers = new SourceBufferListStub();
        this.readyState = 'closed';
        this._duration = NaN;

        window.bridgeInvokeAsync(this.bridgeId, "MediaSource", "constructor", {
            "id": this.internalId
        });

        // Simulate asynchronous opening of MediaSource
        setTimeout(() => {
            this.readyState = 'open';
            this.dispatchEvent(new Event('sourceopen'));
        }, 0);
    }

    static isTypeSupported(mimeType) {
        // Assume all MIME types are supported in this stub
        return true;
    }

    emitUpdatedBuffer() {
        this.dispatchEvent(new Event("bufferChanged"));
    }

    getBufferedRanges() {
        if (this.sourceBuffers._buffers.length != 0) {
            return this.sourceBuffers._buffers[0].buffered._ranges;
        }
        return [];
    }

    addSourceBuffer(mimeType) {
        if (this.readyState !== 'open') {
            throw new DOMException('MediaSource is not open', 'InvalidStateError');
        }
        const sourceBuffer = new SourceBufferStub(this, mimeType);
        this.sourceBuffers._add(sourceBuffer);
        this.activeSourceBuffers._add(sourceBuffer);

        this.dispatchEvent(new Event("bufferChanged"));

        window.bridgeInvokeAsync(this.bridgeId, "MediaSource", "updateSourceBuffers", {
            "ids": this.sourceBuffers._buffers.map((sb) => sb.bridgeId)
        }).then((result) => {
        })

        return sourceBuffer;
    }

    removeSourceBuffer(sourceBuffer) {
        if (!this.sourceBuffers._remove(sourceBuffer)) {
            throw new DOMException('SourceBuffer not found', 'NotFoundError');
        }
        this.activeSourceBuffers._remove(sourceBuffer);

        this.dispatchEvent(new Event("bufferChanged"));

        window.bridgeInvokeAsync(this.bridgeId, "MediaSource", "updateSourceBuffers", {
            "ids": this.sourceBuffers._buffers.map((sb) => sb.bridgeId)
        }).then((result) => {
        })
    }

    endOfStream(error) {
        if (this.readyState !== 'open') {
            throw new DOMException('MediaSource is not open', 'InvalidStateError');
        }
        this.readyState = 'ended';
        this.dispatchEvent(new Event('sourceended'));
    }

    _reopen() {
        if (this.readyState !== 'open') {
            this.readyState = 'open';
            this.dispatchEvent(new Event('sourceopen'));
        }
    }

    set duration(value) {
        if (this.readyState === 'closed') {
            throw new DOMException('MediaSource is closed', 'InvalidStateError');
        }
        this._duration = value;

        window.bridgeInvokeAsync(this.bridgeId, "MediaSource", "setDuration", {
            "duration": value
        }).then((result) => {
        })
    }

    get duration() {
        return this._duration;
    }
}
