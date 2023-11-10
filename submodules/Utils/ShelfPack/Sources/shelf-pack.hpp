#ifndef SHELF_PACK_HPP
#define SHELF_PACK_HPP

#include <algorithm>
#include <cstdint>
#include <deque>
#include <limits>
#include <map>
#include <vector>

namespace mapbox {

const char * const SHELF_PACK_VERSION = "2.1.1";



class Bin {
    friend class ShelfPack;

public:
    /**
     * Create a new Bin.
     *
     * @class  Bin
     * @param  {int32_t}  id          Unique bin identifier
     * @param  {int32_t}  [w1=-1]     Width of the new Bin
     * @param  {int32_t}  [h1=-1]     Height of the new Bin
     * @param  {int32_t}  [maxw1=-1]  Maximum Width of the new Bin
     * @param  {int32_t}  [maxh1=-1]  Maximum Height of the new Bin
     * @param  {int32_t}  [x1=-1]     X location of the Bin
     * @param  {int32_t}  [y1=-1]     Y location of the Bin
     *
     * @example
     * Bin b(-1, 12, 16);
     */
    explicit Bin(
        int32_t id1 = -1,
        int32_t w1 = -1,
        int32_t h1 = -1,
        int32_t maxw1 = -1,
        int32_t maxh1 = -1,
        int32_t x1 = -1,
        int32_t y1 = -1
    ) : id(id1), w(w1), h(h1), maxw(maxw1), maxh(maxh1), x(x1), y(y1), refcount_(0) {

        if (maxw == -1) {
            maxw = w;
        }
        if (maxh == -1) {
            maxh = h;
        }
    }

    int32_t id;
    int32_t w;
    int32_t h;
    int32_t maxw;
    int32_t maxh;
    int32_t x;
    int32_t y;

    int32_t refcount() const { return refcount_; }

private:

    int32_t refcount_;
};


class Shelf {
public:
    /**
     * Create a new Shelf.
     *
     * @class  Shelf
     * @param  {int32_t}  y1   Top coordinate of the new shelf
     * @param  {int32_t}  w1   Width of the new shelf
     * @param  {int32_t}  h1   Height of the new shelf
     *
     * @example
     * Shelf shelf(64, 512, 24);
     */
    explicit Shelf(int32_t y1, int32_t w1, int32_t h1) :
        x_(0), y_(y1), w_(w1), h_(h1), wfree_(w1) { }


    /**
     * Allocate a single bin into the shelf.
     * Bin is stored in a `bins_` container.
     * Returned pointer is stable until the shelf is destroyed.
     *
     * @param    {int32_t}  id    Unique bin identifier, pass -1 to generate a new one
     * @param    {int32_t}  w1     Width of the bin to allocate
     * @param    {int32_t}  h1     Height of the bin to allocate
     * @returns  {Bin*}     `Bin` pointer with `id`, `x`, `y`, `w`, `h` members
     *
     * @example
     * Bin* result = shelf.alloc(-1, 12, 16);
     */
    Bin* alloc(int32_t id, int32_t w1, int32_t h1) {
        if (w1 > wfree_ || h1 > h_) {
            return nullptr;
        }
        int32_t x1 = x_;
        x_ += w1;
        wfree_ -= w1;
        bins_.emplace_back(id, w1, h1, w1, h_, x1, y_);
        return &bins_.back();
    }


    /**
     * Resize the shelf.
     *
     * @param    {int32_t}  w1  Requested new width of the shelf
     * @returns  {bool}     `true` if resize succeeded, `false` if failed
     *
     * @example
     * shelf.resize(512);
     */
    bool resize(int32_t w1) {
        wfree_ += (w1 - w_);
        w_ = w1;
        return true;
    }

    int32_t x() const { return x_; }
    int32_t y() const { return y_; }
    int32_t w() const { return w_; }
    int32_t h() const { return h_; }
    int32_t wfree() const { return wfree_; }

private:
    int32_t x_;
    int32_t y_;
    int32_t w_;
    int32_t h_;
    int32_t wfree_;

    std::deque<Bin> bins_;
};



class ShelfPack {
public:

    struct ShelfPackOptions {
        inline ShelfPackOptions() : autoResize(false) { };
        bool autoResize;
    };

    struct PackOptions {
        inline PackOptions() : inPlace(false) { };
        bool inPlace;
    };


    /**
     * Create a new ShelfPack bin allocator.
     *
     * Uses the Shelf Best Height Fit algorithm from
     * http://clb.demon.fi/files/RectangleBinPack.pdf
     *
     * @class  ShelfPack
     * @param  {int32_t}  [w=64]  Initial width of the sprite
     * @param  {int32_t}  [h=64]  Initial width of the sprite
     * @param  {ShelfPackOptions}  [options]
     * @param  {bool} [options.autoResize=false]  If `true`, the sprite will automatically grow
     *
     * @example
     * ShelfPack::ShelfPackOptions options;
     * options.autoResize = false;
     * ShelfPack sprite = new ShelfPack(64, 64, options);
     */
    explicit ShelfPack(int32_t w = 0, int32_t h = 0, const ShelfPackOptions &options = ShelfPackOptions{}) {
        width_ = w > 0 ? w : 64;
        height_ = h > 0 ? h : 64;
        autoResize_ = options.autoResize;
        maxId_ = 0;
    }


    /**
     * Batch pack multiple bins into the sprite.
     *
     * @param   {vector<Bin>}   bins   Array of requested bins - each object should have `w`, `h` values
     * @param   {PackOptions}   [options]
     * @param   {bool} [options.inPlace=false] If `true`, the supplied bin objects will be updated inplace with `x` and `y` values
     * @returns {vector<Bin*>}   Array of Bin pointers - each bin is a struct with `x`, `y`, `w`, `h` values
     *
     * @example
     * std::vector<Bin> moreBins;
     * moreBins.emplace_back(-1, 12, 24);
     * moreBins.emplace_back(-1, 12, 12);
     * moreBins.emplace_back(-1, 10, 10);
     *
     * ShelfPack::PackOptions options;
     * options.inPlace = true;
     * std::vector<Bin*> results = sprite.pack(moreBins, options);
     */
    std::vector<Bin*> pack(std::vector<Bin> &bins, const PackOptions &options = PackOptions{}) {
        std::vector<Bin*> results;

        for (auto& bin : bins) {
            if (bin.w > 0 && bin.h > 0) {
                Bin* allocation = packOne(bin.id, bin.w, bin.h);
                if (!allocation) {
                    continue;
                }
                if (options.inPlace) {
                    bin.id = allocation->id;
                    bin.x = allocation->x;
                    bin.y = allocation->y;
                }
                results.push_back(allocation);
            }
        }

        shrink();

        return results;
    }


    /**
     * Pack a single bin into the sprite.
     *
     * @param   {int32_t}  id     Unique bin identifier, pass -1 to generate a new one
     * @param   {int32_t}  w      Width of the bin to allocate
     * @param   {int32_t}  h      Height of the bin to allocate
     * @returns {Bin*}     Pointer to a packed Bin with `id`, `x`, `y`, `w`, `h` members
     *
     * @example
     * Bin* result = sprite.packOne(-1, 12, 16);
     */
    Bin* packOne(int32_t id, int32_t w, int32_t h) {
        int32_t y = 0;
        int32_t waste = 0;
        struct {
            Shelf* pshelf = nullptr;
            Bin* pfreebin = nullptr;
            int32_t waste = std::numeric_limits<std::int32_t>::max();
        } best;

        // if id was supplied, attempt a lookup..
        if (id != -1) {
            Bin* pbin = getBin(id);
            if (pbin) {   // we packed this bin already
                ref(*pbin);
                return pbin;
            }
            maxId_ = std::max(id, maxId_);
        } else {
            id = ++maxId_;
        }

        // First try to reuse a free bin..
        for (auto& freebin : freebins_) {
            // exactly the right height and width, use it..
            if (h == freebin->maxh && w == freebin->maxw) {
                return allocFreebin(freebin, id, w, h);
            }
            // not enough height or width, skip it..
            if (h > freebin->maxh || w > freebin->maxw) {
                continue;
            }
            // extra height or width, minimize wasted area..
            if (h <= freebin->maxh && w <= freebin->maxw) {
                waste = (freebin->maxw * freebin->maxh) - (w * h);
                if (waste < best.waste) {
                    best.waste = waste;
                    best.pfreebin = freebin;
                }
            }
        }

        // Next find the best shelf
        for (auto& shelf : shelves_) {
            y += shelf.h();

            // not enough width on this shelf, skip it..
            if (w > shelf.wfree()) {
                continue;
            }
            // exactly the right height, pack it..
            if (h == shelf.h()) {
                return allocShelf(shelf, id, w, h);
            }
            // not enough height, skip it..
            if (h > shelf.h()) {
                continue;
            }
            // extra height, minimize wasted area..
            if (h < shelf.h()) {
                waste = (shelf.h() - h) * w;
                if (waste < best.waste) {
                    best.waste = waste;
                    best.pshelf = &shelf;
                }
            }
        }

        if (best.pfreebin) {
            return allocFreebin(best.pfreebin, id, w, h);
        }

        if (best.pshelf) {
            return allocShelf(*best.pshelf, id, w, h);
        }

        // No free bins or shelves.. add shelf..
        if (h <= (height_ - y) && w <= width_) {
            shelves_.emplace_back(y, width_, h);
            return allocShelf(shelves_.back(), id, w, h);
        }

        // No room for more shelves..
        // If `autoResize` option is set, grow the sprite as follows:
        //  * double whichever sprite dimension is smaller (`w1` or `h1`)
        //  * if sprite dimensions are equal, grow width before height
        //  * accomodate very large bin requests (big `w` or `h`)
        if (autoResize_) {
            int32_t h1, h2, w1, w2;

            h1 = h2 = height_;
            w1 = w2 = width_;

            if (w1 <= h1 || w > w1) {   // grow width..
                w2 = std::max(w, w1) * 2;
            }
            if (h1 < w1 || h > h1) {    // grow height..
                h2 = std::max(h, h1) * 2;
            }

            resize(w2, h2);
            return packOne(id, w, h);  // retry
        }

        return nullptr;
    }


    /**
     *
     * Shrink the width/height of the sprite to the bare minimum.
     * Since shelf-pack doubles first width, then height when running out of shelf space
     * this can result in fairly large unused space both in width and height if that happens
     * towards the end of bin packing.
     */
    void shrink() {
        if (shelves_.size()) {
            int32_t w2 = 0;
            int32_t h2 = 0;

            for (auto& shelf : shelves_) {
                h2 += shelf.h();
                w2 = std::max(shelf.w() - shelf.wfree(), w2);
            }

            resize(w2, h2);
        }
    }


    /**
     * Return a packed bin given its id, or nullptr if the id is not found
     *
     * @param    {int32_t}  id  Unique identifier for this bin,
     * @returns  {Bin*}     Pointer to a packed Bin with `id`, `x`, `y`, `w`, `h` members
     *
     * @example
     * Bin* result = sprite.getBin(5);
     */
    Bin* getBin(int32_t id) {
        std::map<int32_t, Bin*>::iterator it = usedbins_.find(id);
        return (it == usedbins_.end()) ? nullptr : it->second;
    }


    /**
     * Increment the ref count of a bin and update statistics.
     *
     * @param    {Bin&}      bin  Bin reference
     * @returns  {int32_t}   New refcount of the bin
     *
     * @example
     * Bin* bin = sprite.getBin(5);
     * if (bin) {
     *     sprite.ref(*bin);
     * }
     */
    int32_t ref(Bin& bin) {
        if (++bin.refcount_ == 1) {   // a new Bin.. record height in stats historgram..
            int32_t h = bin.h;
            stats_[h] = (stats_[h] | 0) + 1;
        }

        return bin.refcount_;
    };


    /**
     * Decrement the ref count of a bin and update statistics.
     * The bin will be automatically marked as free space once the refcount reaches 0.
     * Memory for the bin is not freed, as unreferenced bins may be reused later.
     *
     * @param    {Bin&}     bin  Bin reference
     * @returns  {int32_t}  New refcount of the bin
     *
     * @example
     * Bin* bin = sprite.getBin(5);
     * if (bin) {
     *     sprite.unref(*bin);
     * }
     */
    int32_t unref(Bin& bin) {
        if (bin.refcount_ == 0) {
            return 0;
        }

        if (--bin.refcount_ == 0) {
            stats_[bin.h]--;
            usedbins_.erase(bin.id);
            freebins_.push_back(&bin);
        }

        return bin.refcount_;
    }


    /**
     * Clear the sprite and reset statistics.
     *
     * @example
     * sprite.clear();
     */
    void clear() {
        shelves_.clear();
        freebins_.clear();
        usedbins_.clear();
        stats_.clear();
        maxId_ = 0;
    }


    /**
     * Resize the sprite.
     *
     * @param   {int32_t}  w  Requested new sprite width
     * @param   {int32_t}  h  Requested new sprite height
     * @returns {bool}     `true` if resize succeeded, `false` if failed
     *
     * @example
     * sprite.resize(256, 256);
     */
    bool resize(int32_t w, int32_t h) {
        width_ = w;
        height_ = h;
        for (auto& shelf : shelves_) {
            shelf.resize(width_);
        }
        return true;
    }

    int32_t width() const { return width_; }
    int32_t height() const { return height_; }


private:

    /**
     * Called by packOne() to allocate a bin by reusing an existing freebin
     *
     * @private
     * @param    {Bin*}       bin    Pointer to a freebin to reuse
     * @param    {int32_t}    w      Width of the bin to allocate
     * @param    {int32_t}    h      Height of the bin to allocate
     * @param    {int32_t}    id     Unique identifier for this bin
     * @returns  {Bin*}       Pointer to a Bin with `id`, `x`, `y`, `w`, `h` properties
     *
     * @example
     * Bin* bin = sprite.allocFreebin(pfreebin, 12, 16, 5);
     */
    Bin* allocFreebin(Bin* bin, int32_t id, int32_t w, int32_t h) {
        freebins_.erase(std::remove(freebins_.begin(), freebins_.end(), bin), freebins_.end());
        bin->id = id;
        bin->w = w;
        bin->h = h;
        bin->refcount_ = 0;
        usedbins_[id] = bin;
        ref(*bin);
        return bin;
    }


    /**
     * Called by `packOne() to allocate bin on an existing shelf
     * Memory for the bin is allocated on the heap by `shelf.alloc()`
     *
     * @private
     * @param    {Shelf&}    shelf  Reference to the shelf to allocate the bin on
     * @param    {int32_t}   w      Width of the bin to allocate
     * @param    {int32_t}   h      Height of the bin to allocate
     * @param    {int32_t}   id     Unique identifier for this bin
     * @returns  {Bin*}      Pointer to a Bin with `id`, `x`, `y`, `w`, `h` properties
     *
     * @example
     * Bin* bin = sprite.allocShelf(shelf, 12, 16, 5);
     */
    Bin* allocShelf(Shelf& shelf, int32_t id, int32_t w, int32_t h) {
        Bin* pbin = shelf.alloc(id, w, h);
        if (pbin) {
            usedbins_[id] = pbin;
            ref(*pbin);
        }
        return pbin;
    }


    int32_t width_;
    int32_t height_;
    int32_t maxId_;
    bool autoResize_;

    std::deque<Shelf> shelves_;
    std::map<int32_t, Bin*> usedbins_;
    std::vector<Bin*> freebins_;
    std::map<int32_t, int32_t> stats_;
};


}  // namespace mapbox

#endif
