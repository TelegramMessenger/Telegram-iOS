#include "types.h"
#include "mbs_format.h"
#include <cstdio>

namespace subcodec {

void MbsSprite::set_frames(std::vector<MbsEncodedFrame>&& encoded) {
    num_frames = static_cast<uint16_t>(encoded.size());

    size_t total_data = 0;
    size_t total_rows = 0;
    for (auto& ef : encoded) {
        total_data += ef.data.size();
        total_rows += ef.rows.size();
    }

    bulk_data_ = std::make_unique_for_overwrite<uint8_t[]>(total_data);
    all_rows_.resize(total_rows);
    frames.resize(encoded.size());

    size_t data_off = 0;
    size_t row_off = 0;
    for (size_t i = 0; i < encoded.size(); i++) {
        auto& ef = encoded[i];
        size_t dsz = ef.data.size();
        size_t rsz = ef.rows.size();

        std::memcpy(bulk_data_.get() + data_off, ef.data.data(), dsz);

        for (size_t r = 0; r < rsz; r++) {
            all_rows_[row_off + r] = ef.rows[r];
            if (ef.rows[r].blob_data) {
                ptrdiff_t blob_off = ef.rows[r].blob_data - ef.data.data();
                all_rows_[row_off + r].blob_data = bulk_data_.get() + data_off + blob_off;
            }
        }

        frames[i].merged_rows = std::span<MbsRow>(all_rows_.data() + row_off, rsz);

        data_off += dsz;
        row_off += rsz;
    }
}

std::expected<MbsSprite, Error> MbsSprite::load(const std::filesystem::path& path) {
    FILE* f = fopen(path.c_str(), "rb");
    if (!f) return std::unexpected(Error::IO_ERROR);

    uint32_t magic;
    MbsSprite sp;
    uint8_t flags;

    bool ok = true;
    ok &= fread(&magic,            4, 1, f) == 1;
    ok &= fread(&sp.width_mbs,     2, 1, f) == 1;
    ok &= fread(&sp.height_mbs,    2, 1, f) == 1;
    ok &= fread(&sp.num_frames,    2, 1, f) == 1;
    ok &= fread(&sp.qp,            1, 1, f) == 1;
    ok &= fread(&sp.qp_delta_idr,  1, 1, f) == 1;
    ok &= fread(&sp.qp_delta_p,    1, 1, f) == 1;
    ok &= fread(&flags,            1, 1, f) == 1;

    if (!ok || magic != MBS_MAGIC_V6) {
        fclose(f);
        return std::unexpected(Error::IO_ERROR);
    }

    int h = sp.height_mbs;
    int nf = sp.num_frames;

    long header_pos = ftell(f);
    fseek(f, 0, SEEK_END);
    long file_size = ftell(f);
    fseek(f, header_pos, SEEK_SET);
    size_t payload_size = static_cast<size_t>(file_size - header_pos);

    sp.bulk_data_ = std::make_unique_for_overwrite<uint8_t[]>(payload_size);
    if (fread(sp.bulk_data_.get(), 1, payload_size, f) != payload_size) {
        fclose(f);
        return std::unexpected(Error::IO_ERROR);
    }
    fclose(f);

    sp.all_rows_.resize(static_cast<size_t>(nf) * h);
    sp.frames.resize(nf);

    const uint8_t* ptr = sp.bulk_data_.get();
    const uint8_t* end = ptr + payload_size;

    for (int i = 0; i < nf; i++) {
        if (ptr + 4 > end) return std::unexpected(Error::PARSE_ERROR);
        uint32_t sz;
        std::memcpy(&sz, ptr, 4);
        ptr += 4;

        if (ptr + sz > end) return std::unexpected(Error::PARSE_ERROR);
        const uint8_t* fp = ptr;
        const uint8_t* fe = ptr + sz;

        size_t row_base = static_cast<size_t>(i) * h;
        for (int y = 0; y < h; y++) {
            if (fp + 6 > fe) return std::unexpected(Error::PARSE_ERROR);
            auto& row = sp.all_rows_[row_base + y];
            row.leading_skips = fp[0];
            row.trailing_skips = fp[1];
            row.blob_bit_count = static_cast<uint16_t>(fp[2] | (fp[3] << 8));
            row.leading_zero_bits = fp[4];
            row.trailing_zero_bits = fp[5];
            fp += 6;
            int blob_bytes = (row.bit_count() + 7) / 8;
            if (fp + blob_bytes > fe) return std::unexpected(Error::PARSE_ERROR);
            row.blob_data = (row.bit_count() > 0) ? fp : nullptr;
            fp += blob_bytes;
        }

        sp.frames[i].merged_rows = std::span<MbsRow>(&sp.all_rows_[row_base], h);
        ptr += sz;
    }

    return sp;
}

std::expected<void, Error> MbsSprite::save(const std::filesystem::path& path) const {
    FILE* f = fopen(path.c_str(), "wb");
    if (!f) return std::unexpected(Error::IO_ERROR);

    uint32_t magic = MBS_MAGIC_V6;
    uint8_t flags = 0;
    bool ok = true;

    ok &= fwrite(&magic,          4, 1, f) == 1;
    ok &= fwrite(&width_mbs,      2, 1, f) == 1;
    ok &= fwrite(&height_mbs,     2, 1, f) == 1;
    ok &= fwrite(&num_frames,     2, 1, f) == 1;
    ok &= fwrite(&qp,             1, 1, f) == 1;
    ok &= fwrite(&qp_delta_idr,   1, 1, f) == 1;
    ok &= fwrite(&qp_delta_p,     1, 1, f) == 1;
    ok &= fwrite(&flags,          1, 1, f) == 1;

    for (int i = 0; i < num_frames; i++) {
        uint32_t sz = 0;
        for (auto& row : frames[i].merged_rows) {
            sz += 6 + (row.bit_count() + 7) / 8;
        }
        ok &= fwrite(&sz, 4, 1, f) == 1;

        for (auto& row : frames[i].merged_rows) {
            uint8_t hdr[6];
            hdr[0] = row.leading_skips;
            hdr[1] = row.trailing_skips;
            hdr[2] = static_cast<uint8_t>(row.blob_bit_count & 0xFF);
            hdr[3] = static_cast<uint8_t>((row.blob_bit_count >> 8) & 0xFF);
            hdr[4] = row.leading_zero_bits;
            hdr[5] = row.trailing_zero_bits;
            ok &= fwrite(hdr, 1, 6, f) == 6;
            int blob_bytes = (row.bit_count() + 7) / 8;
            if (blob_bytes > 0 && row.blob_data)
                ok &= fwrite(row.blob_data, 1, blob_bytes, f) == static_cast<size_t>(blob_bytes);
        }
    }

    fclose(f);
    return ok ? std::expected<void, Error>{} : std::unexpected(Error::IO_ERROR);
}

} // namespace subcodec
