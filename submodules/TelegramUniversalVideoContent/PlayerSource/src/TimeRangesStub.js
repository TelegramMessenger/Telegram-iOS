
export class TimeRangesStub {
    constructor() {
        this._ranges = [];
    }

    get length() {
        return this._ranges.length;
    }

    start(index) {
        if (index < 0 || index >= this._ranges.length) {
            throw new DOMException('Invalid index', 'IndexSizeError');
        }
        return this._ranges[index].start;
    }

    end(index) {
        if (index < 0 || index >= this._ranges.length) {
            throw new DOMException('Invalid index', 'IndexSizeError');
        }
        return this._ranges[index].end;
    }

    // Helper method to add a range
    _addRange(start, end) {
        this._ranges.push({ start, end });
        this._normalizeRanges();
    }

    // Helper method to remove ranges that overlap with a given range
    _removeRange(start, end) {
        let updatedRanges = [];
        for (let range of this._ranges) {
            if (range.end <= start || range.start >= end) {
                // No overlap, keep the range as is
                updatedRanges.push(range);
            } else if (range.start < start && range.end > end) {
                // The range fully covers the removal range, split into two ranges
                updatedRanges.push({ start: range.start, end: start });
                updatedRanges.push({ start: end, end: range.end });
            } else if (range.start >= start && range.end <= end) {
                // The range is entirely within the removal range, remove it
                // Do not add to updatedRanges
            } else if (range.start < start && range.end > start && range.end <= end) {
                // The range overlaps with the removal range on the left
                updatedRanges.push({ start: range.start, end: start });
            } else if (range.start >= start && range.start < end && range.end > end) {
                // The range overlaps with the removal range on the right
                updatedRanges.push({ start: end, end: range.end });
            }
        }
        this._ranges = updatedRanges;
    }

    // Normalize and merge overlapping ranges
    _normalizeRanges() {
        this._ranges.sort((a, b) => a.start - b.start);
        let normalized = [];
        for (let range of this._ranges) {
            if (normalized.length === 0) {
                normalized.push(range);
            } else {
                let last = normalized[normalized.length - 1];
                if (range.start <= last.end) {
                    last.end = Math.max(last.end, range.end);
                } else {
                    normalized.push(range);
                }
            }
        }
        this._ranges = normalized;
    }
}