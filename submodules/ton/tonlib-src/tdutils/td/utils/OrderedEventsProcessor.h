/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"

#include <utility>

namespace td {

// Process states in order defined by their Id
template <class DataT>
class OrderedEventsProcessor {
 public:
  using SeqNo = uint64;

  OrderedEventsProcessor() = default;
  explicit OrderedEventsProcessor(SeqNo offset) : offset_(offset), begin_(offset_), end_(offset_) {
  }

  template <class FunctionT>
  void clear(FunctionT &&function) {
    for (auto &it : data_array_) {
      if (it.second) {
        function(std::move(it.first));
      }
    }
    *this = OrderedEventsProcessor();
  }
  void clear() {
    *this = OrderedEventsProcessor();
  }
  template <class FromDataT, class FunctionT>
  void add(SeqNo seq_no, FromDataT &&data, FunctionT &&function) {
    LOG_CHECK(seq_no >= begin_) << seq_no << ">=" << begin_;  // or ignore?

    if (seq_no == begin_) {  // run now
      begin_++;
      function(seq_no, std::forward<FromDataT>(data));

      while (begin_ < end_) {
        auto &data_flag = data_array_[static_cast<size_t>(begin_ - offset_)];
        if (!data_flag.second) {
          break;
        }
        function(begin_, std::move(data_flag.first));
        data_flag.second = false;
        begin_++;
      }
      if (begin_ > end_) {
        end_ = begin_;
      }
      if (begin_ == end_) {
        offset_ = begin_;
      }

      // try_compactify
      auto begin_pos = static_cast<size_t>(begin_ - offset_);
      if (begin_pos > 5 && begin_pos * 2 > data_array_.size()) {
        data_array_.erase(data_array_.begin(), data_array_.begin() + begin_pos);
        offset_ = begin_;
      }
    } else {
      auto pos = static_cast<size_t>(seq_no - offset_);
      auto need_size = pos + 1;
      if (data_array_.size() < need_size) {
        data_array_.resize(need_size);
      }
      data_array_[pos].first = std::forward<FromDataT>(data);
      data_array_[pos].second = true;
      if (end_ < seq_no + 1) {
        end_ = seq_no + 1;
      }
    }
  }

  bool has_events() const {
    return begin_ != end_;
  }
  SeqNo max_unfinished_seq_no() {
    return end_ - 1;
  }
  SeqNo max_finished_seq_no() {
    return begin_ - 1;
  }

 private:
  SeqNo offset_ = 1;
  SeqNo begin_ = 1;
  SeqNo end_ = 1;
  std::vector<std::pair<DataT, bool>> data_array_;
};

}  // namespace td
