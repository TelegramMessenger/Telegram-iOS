#include "mux_surface.h"
#include "frame_writer.h"
#include <algorithm>
#include <cstring>

namespace subcodec {

std::expected<MuxSurface, Error>
MuxSurface::create(const Params& params, FrameSink sink) {
    if (params.max_slots <= 0) return std::unexpected(Error::INVALID_INPUT);
    if (params.sprite_width <= 0 || params.sprite_width % 16 != 0 ||
        params.sprite_height <= 0 || params.sprite_height % 16 != 0)
        return std::unexpected(Error::INVALID_INPUT);

    constexpr int padding_mbs = 1;
    int content_w_mbs = params.sprite_width / 16;
    int content_h_mbs = params.sprite_height / 16;
    int sw = content_w_mbs + 2 * padding_mbs;
    int sh = content_h_mbs + 2 * padding_mbs;
    int slot_w = sw * 2 - padding_mbs;
    int stride_x = slot_w - padding_mbs;
    int stride_y = sh - padding_mbs;

    mux::build_ct_lut();
    mux::build_ue_lut();

    int cols = mux::ceil_sqrt(params.max_slots);
    int rows = mux::ceil_div(params.max_slots, cols);
    int total_w = stride_x * cols + padding_mbs;
    int total_h = stride_y * rows + padding_mbs;
    int num_mbs = total_w * total_h;

    MuxSurface s;
    s.params_ = params;
    s.sprite_w_mbs_ = sw;
    s.sprite_h_mbs_ = sh;
    s.content_w_ = params.sprite_width;
    s.content_h_ = params.sprite_height;
    s.total_w_ = total_w;
    s.total_h_ = total_h;
    s.cols_ = cols;
    s.rows_ = rows;
    s.stride_x_ = stride_x;
    s.stride_y_ = stride_y;
    s.frame_num_ = 0;
    s.num_mbs_ = num_mbs;
    s.slots_.resize(static_cast<size_t>(params.max_slots));
    s.slot_infos_.resize(static_cast<size_t>(params.max_slots));

    s.buf_size_ = static_cast<size_t>(num_mbs) * 600 + 4096;
    s.buf_ = std::make_unique_for_overwrite<uint8_t[]>(s.buf_size_);
    s.rbsp_buf_size_ = s.buf_size_;
    s.rbsp_buf_ = std::make_unique_for_overwrite<uint8_t[]>(s.rbsp_buf_size_);
    s.micro_ops_.reserve(static_cast<size_t>(params.max_slots) * static_cast<size_t>(sh) * 2);

    FrameParams fp{};
    fp.width_mbs = static_cast<uint16_t>(total_w);
    fp.height_mbs = static_cast<uint16_t>(total_h);
    fp.qp = params.qp;
    fp.log2_max_frame_num = static_cast<uint8_t>(s.log2_max_frame_num_);

    std::span<uint8_t> out{s.buf_.get(), s.buf_size_};
    size_t offset = frame_writer::write_headers(out, fp);
    if (offset == 0) return std::unexpected(Error::OUT_OF_SPACE);

    auto idr_result = mux::write_idr_black(total_w, total_h,
                                            params.qp_delta_idr,
                                            s.log2_max_frame_num_,
                                            out.subspan(offset));
    if (!idr_result) return std::unexpected(idr_result.error());
    offset += *idr_result;

    sink(std::span<const uint8_t>{s.buf_.get(), offset});

    return std::move(s);
}

std::expected<MuxSurface::SpriteRegion, Error> MuxSurface::add_sprite(const std::filesystem::path& mbs_path) {
    int slot_idx = -1;
    for (int i = 0; i < params_.max_slots; i++) {
        if (!slots_[i].sprite) {
            slot_idx = i;
            break;
        }
    }
    if (slot_idx < 0) return std::unexpected(Error::OUT_OF_SPACE);

    auto result = MbsSprite::load(mbs_path);
    if (!result) return std::unexpected(result.error());

    if (result->width_mbs != sprite_w_mbs_ ||
        result->height_mbs != sprite_h_mbs_) {
        return std::unexpected(Error::INVALID_INPUT);
    }

    slots_[slot_idx].sprite = std::move(*result);
    slots_[slot_idx].current_frame = 0;
    slots_[slot_idx].active = true;
    slots_[slot_idx].needs_emit = true;
    plans_dirty_ = true;
    dirty_ = true;

    constexpr int padding_px = 16;
    int col = slot_idx % cols_;
    int row = slot_idx / cols_;
    int color_x = col * stride_x_ * 16 + padding_px;
    int color_y = row * stride_y_ * 16 + padding_px;
    int content_w_mbs = sprite_w_mbs_ - 2;
    int alpha_x = color_x + (content_w_mbs + 1) * 16;

    SpriteRegion region;
    region.slot = slot_idx;
    region.color = {color_x, color_y, content_w_, content_h_};
    region.alpha = {alpha_x, color_y, content_w_, content_h_};
    return region;
}

std::expected<MuxSurface::SpriteRegion, Error> MuxSurface::add_sprite(MbsSprite sprite) {
    int slot_idx = -1;
    for (int i = 0; i < params_.max_slots; i++) {
        if (!slots_[i].sprite) {
            slot_idx = i;
            break;
        }
    }
    if (slot_idx < 0) return std::unexpected(Error::OUT_OF_SPACE);

    if (sprite.width_mbs != sprite_w_mbs_ ||
        sprite.height_mbs != sprite_h_mbs_) {
        return std::unexpected(Error::INVALID_INPUT);
    }

    slots_[slot_idx].sprite = std::move(sprite);
    slots_[slot_idx].current_frame = 0;
    slots_[slot_idx].active = true;
    slots_[slot_idx].needs_emit = true;
    plans_dirty_ = true;
    dirty_ = true;

    constexpr int padding_px = 16;
    int col = slot_idx % cols_;
    int row = slot_idx / cols_;
    int color_x = col * stride_x_ * 16 + padding_px;
    int color_y = row * stride_y_ * 16 + padding_px;
    int content_w_mbs = sprite_w_mbs_ - 2;
    int alpha_x = color_x + (content_w_mbs + 1) * 16;

    SpriteRegion region;
    region.slot = slot_idx;
    region.color = {color_x, color_y, content_w_, content_h_};
    region.alpha = {alpha_x, color_y, content_w_, content_h_};
    return region;
}

void MuxSurface::remove_sprite(int slot) {
    if (slot < 0 || slot >= params_.max_slots) return;
    slots_[slot].sprite.reset();
    slots_[slot].active = false;
    slots_[slot].current_frame = 0;
    plans_dirty_ = true;
}

CompactionInfo MuxSurface::check_compaction_opportunity() const {
    int active = 0;
    for (int i = 0; i < params_.max_slots; i++) {
        if (slots_[i].active) active++;
    }

    int min_grid_mbs = 0;
    if (active > 0) {
        int cols = mux::ceil_sqrt(active);
        int rows = mux::ceil_div(active, cols);
        int slot_w = sprite_w_mbs_ * 2 - 1;  /* padding_mbs = 1 */
        int sx = slot_w - 1;
        int sy = sprite_h_mbs_ - 1;
        int tw = sx * cols + 1;
        int th = sy * rows + 1;
        min_grid_mbs = tw * th;
    }

    return CompactionInfo{
        active,
        params_.max_slots,
        total_w_ * total_h_,
        min_grid_mbs
    };
}

std::expected<MuxSurface::ResizeResult, Error> MuxSurface::resize(
    int new_max_slots,
    std::span<const uint8_t> decoded_y,
    std::span<const uint8_t> decoded_cb,
    std::span<const uint8_t> decoded_cr,
    int decoded_width,
    int decoded_height,
    int stride_y,
    int stride_cb,
    int stride_cr,
    FrameSink sink) {

    /* Count active sprites */
    int active_count = 0;
    for (int i = 0; i < params_.max_slots; i++) {
        if (slots_[i].active) active_count++;
    }

    /* Validate */
    if (new_max_slots < active_count)
        return std::unexpected(Error::INVALID_INPUT);
    if (decoded_width != total_w_ * 16 || decoded_height != total_h_ * 16)
        return std::unexpected(Error::INVALID_INPUT);

    /* Collect active sprites with their old slot positions */
    struct SpriteInfo {
        MbsSprite sprite;
        int current_frame;
        int old_col, old_row;
    };
    std::vector<SpriteInfo> active_sprites;
    active_sprites.reserve(active_count);

    for (int i = 0; i < params_.max_slots; i++) {
        if (slots_[i].active && slots_[i].sprite) {
            int col = i % cols_;
            int row = i / cols_;
            active_sprites.push_back({
                std::move(*slots_[i].sprite),
                slots_[i].current_frame,
                col, row
            });
        }
    }

    /* Save old grid layout for pixel remapping */
    int old_stride_x = stride_x_;
    int old_stride_y_val = stride_y_;

    /* Compute new grid layout (same algorithm as create()) */
    constexpr int padding_mbs = 1;
    int slot_w = sprite_w_mbs_ * 2 - padding_mbs;
    int new_stride_x = slot_w - padding_mbs;
    int new_stride_y_val = sprite_h_mbs_ - padding_mbs;

    int new_cols = mux::ceil_sqrt(new_max_slots);
    int new_rows = mux::ceil_div(new_max_slots, new_cols);
    int new_total_w = new_stride_x * new_cols + padding_mbs;
    int new_total_h = new_stride_y_val * new_rows + padding_mbs;
    int new_num_mbs = new_total_w * new_total_h;

    /* Build the remapped YUV planes for the new grid */
    int new_w_px = new_total_w * 16;
    int new_h_px = new_total_h * 16;
    int new_cw = new_w_px / 2;
    int new_ch = new_h_px / 2;

    size_t y_size = static_cast<size_t>(new_w_px) * new_h_px;
    size_t c_size = static_cast<size_t>(new_cw) * new_ch;
    auto new_y_buf = std::make_unique_for_overwrite<uint8_t[]>(y_size);
    auto new_cb_buf = std::make_unique_for_overwrite<uint8_t[]>(c_size);
    auto new_cr_buf = std::make_unique_for_overwrite<uint8_t[]>(c_size);
    memset(new_y_buf.get(), 0, y_size);
    memset(new_cb_buf.get(), 128, c_size);
    memset(new_cr_buf.get(), 128, c_size);
    uint8_t* new_y = new_y_buf.get();
    uint8_t* new_cb = new_cb_buf.get();
    uint8_t* new_cr = new_cr_buf.get();

    /* Copy sprite pixel regions from old to new positions */
    int sprite_h_px = sprite_h_mbs_ * 16;
    int slot_w_px = slot_w * 16;

    for (int si = 0; si < (int)active_sprites.size(); si++) {
        auto& sp = active_sprites[si];

        int old_x_px = sp.old_col * old_stride_x * 16;
        int old_y_px = sp.old_row * old_stride_y_val * 16;

        int new_col = si % new_cols;
        int new_row = si / new_cols;
        int new_x_px = new_col * new_stride_x * 16;
        int new_y_px = new_row * new_stride_y_val * 16;

        /* Copy luma */
        for (int r = 0; r < sprite_h_px; r++) {
            const uint8_t* src = decoded_y.data() + (old_y_px + r) * stride_y + old_x_px;
            uint8_t* dst = new_y + (new_y_px + r) * new_w_px + new_x_px;
            memcpy(dst, src, slot_w_px);
        }

        /* Copy chroma */
        int old_cx = old_x_px / 2;
        int old_cy = old_y_px / 2;
        int new_cx = new_x_px / 2;
        int new_cy = new_y_px / 2;
        int slot_cw = slot_w_px / 2;
        int sprite_ch = sprite_h_px / 2;

        for (int r = 0; r < sprite_ch; r++) {
            memcpy(new_cb + (new_cy + r) * new_cw + new_cx,
                   decoded_cb.data() + (old_cy + r) * stride_cb + old_cx, slot_cw);
            memcpy(new_cr + (new_cy + r) * new_cw + new_cx,
                   decoded_cr.data() + (old_cy + r) * stride_cr + old_cx, slot_cw);
        }
    }

    /* Reallocate frame buffers if new grid is larger.
     * buf_ at 600 bytes/MB is sufficient for both I_PCM (580 bytes/MB)
     * and subsequent P-frames. rbsp_buf_ is used for I_PCM output. */
    size_t new_buf_size = static_cast<size_t>(new_num_mbs) * 600 + 4096;
    if (new_buf_size > buf_size_) {
        buf_size_ = new_buf_size;
        buf_ = std::make_unique_for_overwrite<uint8_t[]>(buf_size_);
        rbsp_buf_size_ = buf_size_;
        rbsp_buf_ = std::make_unique_for_overwrite<uint8_t[]>(rbsp_buf_size_);
    }

    /* Write new SPS/PPS into buf_ */
    FrameParams fp{};
    fp.width_mbs = static_cast<uint16_t>(new_total_w);
    fp.height_mbs = static_cast<uint16_t>(new_total_h);
    fp.qp = params_.qp;
    fp.log2_max_frame_num = static_cast<uint8_t>(log2_max_frame_num_);

    std::span<uint8_t> hdr_out{buf_.get(), buf_size_};
    size_t hdr_offset = frame_writer::write_headers(hdr_out, fp);
    if (hdr_offset == 0) return std::unexpected(Error::OUT_OF_SPACE);

    /* Write I_PCM IDR into rbsp_buf_ (reused, avoids separate allocation) */
    auto idr_result = mux::write_idr_ipcm(
        new_total_w, new_total_h,
        log2_max_frame_num_,
        new_y, new_w_px,
        new_cb, new_cw,
        new_cr, new_cw,
        {rbsp_buf_.get(), rbsp_buf_size_});

    if (!idr_result) return std::unexpected(idr_result.error());

    /* Emit SPS+PPS then I_PCM IDR */
    sink(std::span<const uint8_t>{buf_.get(), hdr_offset});
    sink(std::span<const uint8_t>{rbsp_buf_.get(), *idr_result});

    /* Update internal state */
    params_.max_slots = new_max_slots;
    total_w_ = new_total_w;
    total_h_ = new_total_h;
    cols_ = new_cols;
    rows_ = new_rows;
    stride_x_ = new_stride_x;
    stride_y_ = new_stride_y_val;
    num_mbs_ = new_num_mbs;
    frame_num_ = 0;

    /* Resize slot arrays */
    slots_.clear();
    slots_.resize(static_cast<size_t>(new_max_slots));
    slot_infos_.resize(static_cast<size_t>(new_max_slots));
    micro_ops_.reserve(static_cast<size_t>(new_max_slots) *
                       static_cast<size_t>(sprite_h_mbs_) * 2);

    /* Assign sprites to compacted slots and build result */
    ResizeResult result;
    result.regions.reserve(active_sprites.size());

    constexpr int padding_px = 16;
    int content_w_mbs = sprite_w_mbs_ - 2;

    for (int si = 0; si < (int)active_sprites.size(); si++) {
        slots_[si].sprite = std::move(active_sprites[si].sprite);
        slots_[si].current_frame = active_sprites[si].current_frame;
        slots_[si].active = true;

        int col = si % new_cols;
        int row = si / new_cols;
        int color_x = col * new_stride_x * 16 + padding_px;
        int color_y = row * new_stride_y_val * 16 + padding_px;
        int alpha_x = color_x + (content_w_mbs + 1) * 16;

        SpriteRegion region;
        region.slot = si;
        region.color = {color_x, color_y, content_w_, content_h_};
        region.alpha = {alpha_x, color_y, content_w_, content_h_};
        result.regions.push_back(region);
    }

    plans_dirty_ = true;

    return result;
}

void MuxSurface::rebuild_row_plans_() {
    bool active_buf[4096];
    bool* active = (params_.max_slots <= 4096) ? active_buf
        : new bool[static_cast<size_t>(params_.max_slots)];
    for (int i = 0; i < params_.max_slots; i++) {
        active[i] = slots_[i].active;
    }
    constexpr int padding_mbs = 1;
    mux::build_row_plans(active, params_.max_slots,
                         sprite_w_mbs_, sprite_h_mbs_,
                         padding_mbs,
                         total_w_, total_h_,
                         row_plans_, row_ops_);
    if (active != active_buf) delete[] active;
}

void MuxSurface::advance_sprite(int slot) {
    if (slot < 0 || slot >= params_.max_slots) return;
    auto& sl = slots_[slot];
    if (!sl.active || !sl.sprite) return;

    sl.needs_emit = true;
    dirty_ = true;
}

std::expected<bool, Error> MuxSurface::emit_frame_if_needed(FrameSink sink) {
    if (!dirty_) return false;

    if (plans_dirty_) {
        rebuild_row_plans_();
        plans_dirty_ = false;
    }

    frame_num_++;

    int max_slots = params_.max_slots;

    for (int slot = 0; slot < max_slots; slot++) {
        auto& sl = slots_[slot];
        if (sl.active && sl.sprite && sl.needs_emit) {
            slot_infos_[slot].sprite = &(*sl.sprite);
            slot_infos_[slot].frame_index = sl.current_frame;
        } else {
            slot_infos_[slot].sprite = nullptr;
            slot_infos_[slot].frame_index = 0;
        }
    }

    int trailing_skip = mux::build_micro_ops(
        slot_infos_.data(),
        row_plans_.data(), total_h_,
        row_ops_.data(),
        sprite_w_mbs_, 1,
        micro_ops_);

    std::span<uint8_t> out{buf_.get(), buf_size_};
    auto p_result = mux::write_p_frame_micro(
        micro_ops_.data(), static_cast<int>(micro_ops_.size()), trailing_skip,
        frame_num_,
        log2_max_frame_num_,
        params_.qp_delta_p,
        out);

    if (!p_result) return std::unexpected(p_result.error());

    sink(std::span<const uint8_t>{buf_.get(), *p_result});

    // Advance emitted sprites and clear needs_emit
    for (int slot = 0; slot < max_slots; slot++) {
        auto& sl = slots_[slot];
        if (sl.needs_emit && sl.active && sl.sprite) {
            sl.current_frame++;
            if (sl.current_frame >= sl.sprite->num_frames)
                sl.current_frame = 0;
        }
        sl.needs_emit = false;
    }

    dirty_ = false;
    return true;
}

std::expected<void, Error> MuxSurface::advance_frame(FrameSink sink) {
    // Mark all active sprites for emit, then emit + advance
    for (int i = 0; i < params_.max_slots; i++) {
        auto& sl = slots_[i];
        if (sl.active && sl.sprite)
            sl.needs_emit = true;
    }
    dirty_ = true;
    auto r = emit_frame_if_needed(std::move(sink));
    if (!r) return std::unexpected(r.error());
    return {};
}

} // namespace subcodec
