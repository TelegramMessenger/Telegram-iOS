//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/tests.h"
#include "td/utils/utf8.h"

#include <algorithm>

class RangeSet {
  template <class T>
  static auto find(T &ranges, td::int64 begin) {
    return std::lower_bound(ranges.begin(), ranges.end(), begin,
                            [](const Range &range, td::int64 begin) { return range.end < begin; });
  }
  auto find(td::int64 begin) const {
    return find(ranges_, begin);
  }
  auto find(td::int64 begin) {
    return find(ranges_, begin);
  }

 public:
  struct Range {
    td::int64 begin;
    td::int64 end;
  };

  static constexpr td::int64 BIT_SIZE = 1024;

  static RangeSet create_one_range(td::int64 end, td::int64 begin = 0) {
    RangeSet res;
    res.ranges_.push_back({begin, end});
    return res;
  }

  static td::Result<RangeSet> decode(td::CSlice data) {
    if (!td::check_utf8(data)) {
      return td::Status::Error("Invalid encoding");
    }
    td::uint32 curr = 0;
    bool is_empty = false;
    RangeSet res;
    for (auto begin = data.ubegin(); begin != data.uend();) {
      td::uint32 size;
      begin = td::next_utf8_unsafe(begin, &size);

      if (!is_empty && size != 0) {
        res.ranges_.push_back({curr * BIT_SIZE, (curr + size) * BIT_SIZE});
      }
      curr += size;
      is_empty = !is_empty;
    }
    return res;
  }

  td::string encode(td::int64 prefix_size = -1) const {
    td::vector<td::uint32> sizes;
    td::uint32 all_end = 0;

    if (prefix_size != -1) {
      prefix_size = (prefix_size + BIT_SIZE - 1) / BIT_SIZE * BIT_SIZE;
    }
    for (auto it : ranges_) {
      if (prefix_size != -1 && it.begin >= prefix_size) {
        break;
      }
      if (prefix_size != -1 && it.end > prefix_size) {
        it.end = prefix_size;
      }

      CHECK(it.begin % BIT_SIZE == 0);
      CHECK(it.end % BIT_SIZE == 0);
      auto begin = td::narrow_cast<td::uint32>(it.begin / BIT_SIZE);
      auto end = td::narrow_cast<td::uint32>(it.end / BIT_SIZE);
      if (sizes.empty()) {
        if (begin != 0) {
          sizes.push_back(0);
          sizes.push_back(begin);
        }
      } else {
        sizes.push_back(begin - all_end);
      }
      sizes.push_back(end - begin);
      all_end = end;
    }

    td::string res;
    for (auto c : sizes) {
      td::append_utf8_character(res, c);
    }
    return res;
  }

  td::int64 get_ready_prefix_size(td::int64 offset, td::int64 file_size = -1) const {
    auto it = find(offset);
    if (it == ranges_.end()) {
      return 0;
    }
    if (it->begin > offset) {
      return 0;
    }
    CHECK(offset >= it->begin);
    CHECK(offset <= it->end);
    auto end = it->end;
    if (file_size != -1 && end > file_size) {
      end = file_size;
    }
    if (end < offset) {
      return 0;
    }
    return end - offset;
  }

  td::int64 get_total_size(td::int64 file_size) const {
    td::int64 res = 0;
    for (auto it : ranges_) {
      if (it.begin >= file_size) {
        break;
      }
      if (it.end > file_size) {
        it.end = file_size;
      }
      res += it.end - it.begin;
    }
    return res;
  }

  td::int64 get_ready_parts(td::int64 offset_part, td::int32 part_size) const {
    auto offset = offset_part * part_size;
    auto it = find(offset);
    if (it == ranges_.end()) {
      return 0;
    }
    if (it->begin > offset) {
      return 0;
    }
    return (it->end - offset) / part_size;
  }

  bool is_ready(td::int64 begin, td::int64 end) const {
    auto it = find(begin);
    if (it == ranges_.end()) {
      return false;
    }
    return it->begin <= begin && end <= it->end;
  }

  void set(td::int64 begin, td::int64 end) {
    CHECK(begin % BIT_SIZE == 0);
    CHECK(end % BIT_SIZE == 0);
    // 1. skip all with r.end < begin
    auto it_begin = find(begin);

    // 2. combine with all r.begin <= end
    auto it_end = it_begin;
    for (; it_end != ranges_.end() && it_end->begin <= end; ++it_end) {
    }

    if (it_begin == it_end) {
      ranges_.insert(it_begin, Range{begin, end});
    } else {
      begin = td::min(begin, it_begin->begin);
      --it_end;
      end = td::max(end, it_end->end);
      *it_end = Range{begin, end};
      ranges_.erase(it_begin, it_end);
    }
  }

  td::vector<td::int32> as_vector(td::int32 part_size) const {
    td::vector<td::int32> res;
    for (const auto &it : ranges_) {
      auto begin = td::narrow_cast<td::int32>((it.begin + part_size - 1) / part_size);
      auto end = td::narrow_cast<td::int32>(it.end / part_size);
      while (begin < end) {
        res.push_back(begin++);
      }
    }
    return res;
  }

 private:
  td::vector<Range> ranges_;
};

TEST(Bitmask, simple) {
  auto validate_encoding = [](auto &rs) {
    auto str = rs.encode();
    RangeSet rs2 = RangeSet::decode(str).move_as_ok();
    auto str2 = rs2.encode();
    rs = std::move(rs2);
    CHECK(str2 == str);
  };
  {
    RangeSet rs;
    td::int32 S = 128 * 1024;
    td::int32 O = S * 5000;
    for (int i = 1; i < 30; i++) {
      if (i % 2 == 0) {
        rs.set(O + S * i, O + S * (i + 1));
      }
    }
    validate_encoding(rs);
  }
  {
    RangeSet rs;
    td::int32 S = 1024;
    auto get = [&](auto p) {
      return rs.get_ready_prefix_size(p * S) / S;
    };
    auto set = [&](auto l, auto r) {
      rs.set(l * S, r * S);
      validate_encoding(rs);
      ASSERT_TRUE(rs.is_ready(l * S, r * S));
      ASSERT_TRUE(get(l) >= (r - l));
    };
    set(6, 7);
    ASSERT_EQ(1, get(6));
    ASSERT_EQ(0, get(5));
    set(8, 9);
    ASSERT_EQ(0, get(7));
    set(7, 8);
    ASSERT_EQ(2, get(7));
    ASSERT_EQ(3, get(6));
    set(3, 5);
    ASSERT_EQ(1, get(4));
    set(4, 6);
    ASSERT_EQ(5, get(4));
    set(10, 11);
    set(9, 10);
    ASSERT_EQ(8, get(3));
    set(14, 16);
    set(12, 13);
    ASSERT_EQ(8, get(3));

    ASSERT_EQ(10, rs.get_ready_prefix_size(S * 3, S * 3 + 10));
    ASSERT_TRUE(!rs.is_ready(S * 11, S * 12));
    ASSERT_EQ(3, rs.get_ready_parts(2, S * 2));
    ASSERT_EQ(td::vector<td::int32>({2, 3, 4, 7}), rs.as_vector(S * 2));
  }
}
