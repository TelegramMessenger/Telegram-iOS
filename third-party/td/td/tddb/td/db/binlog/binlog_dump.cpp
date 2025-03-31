//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/binlog/Binlog.h"

#include "td/db/DbKey.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/Stat.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_parsers.h"

#include <map>

struct Trie {
  Trie() {
    nodes_.resize(1);
  }

  void add(td::Slice value) {
    do_add(0, PSLICE() << value << '\0');
  }

  void dump() {
    if (nodes_[0].sum == 0) {  // division by zero
      return;
    }
    LOG(PLAIN) << "TOTAL: " << nodes_[0].sum;
    do_dump("", 0);
  }

 private:
  struct FullNode {
    int next[256] = {};
    int sum = 0;
  };
  td::vector<FullNode> nodes_;

  void do_add(int event_id, td::Slice value) {
    nodes_[event_id].sum++;
    if (value.empty()) {
      return;
    }

    auto c = static_cast<td::uint8>(value[0]);
    auto next_event_id = nodes_[event_id].next[c];
    if (next_event_id == 0) {
      next_event_id = static_cast<int>(nodes_.size());
      nodes_.emplace_back();
      nodes_[event_id].next[c] = next_event_id;
    }
    do_add(next_event_id, value.substr(1));
  }

  void do_dump(td::string path, int v) {
    bool is_word_end = !path.empty() && path.back() == '\0';

    bool need_stop = false;
    int next_count = 0;
    for (int c = 0; c < 256; c++) {
      if (nodes_[v].next[c] != 0) {
        need_stop |= c >= 128 || !(td::is_alpha(static_cast<char>(c)) || c == '.' || c == '_');
        next_count++;
      }
    }
    need_stop |= next_count == 0 || (next_count >= 2 && nodes_[v].sum <= nodes_[0].sum / 100);

    if (is_word_end || need_stop) {
      if (is_word_end) {
        path.pop_back();
      } else if (next_count != 1 || nodes_[v].next[0] == 0) {
        path.push_back('*');
      }
      LOG(PLAIN) << nodes_[v].sum << " " << td::StringBuilder::FixedDouble(nodes_[v].sum * 100.0 / nodes_[0].sum, 2)
                 << "% [" << td::format::escaped(path) << "]";
      return;
    }
    for (int c = 0; c < 256; c++) {
      auto next_event_id = nodes_[v].next[c];
      if (next_event_id == 0) {
        continue;
      }
      do_dump(path + static_cast<char>(c), next_event_id);
    }
  }
};

enum Magic { ConfigPmcMagic = 0x1f18, BinlogPmcMagic = 0x4327 };

int main(int argc, char *argv[]) {
  if (argc < 2) {
    LOG(PLAIN) << "Usage: binlog_dump <binlog_file_name>";
    return 1;
  }
  td::string binlog_file_name = argv[1];
  auto r_stat = td::stat(binlog_file_name);
  if (r_stat.is_error() || r_stat.ok().size_ == 0 || !r_stat.ok().is_reg_) {
    LOG(PLAIN) << "Wrong binlog file name specified";
    LOG(PLAIN) << "Usage: binlog_dump <binlog_file_name>";
    return 1;
  }

  struct Info {
    std::size_t full_size = 0;
    std::size_t compressed_size = 0;
    Trie trie;
    Trie compressed_trie;
  };
  std::map<td::uint64, Info> info;

  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(ERROR));
  td::Binlog binlog;
  binlog
      .init(
          binlog_file_name,
          [&](auto &event) {
            info[0].compressed_size += event.raw_event_.size();
            info[event.type_].compressed_size += event.raw_event_.size();
            if (event.type_ == ConfigPmcMagic || event.type_ == BinlogPmcMagic) {
              auto key = td::TlParser(event.get_data()).template fetch_string<td::Slice>();
              info[event.type_].compressed_trie.add(key);
            }
          },
          td::DbKey::raw_key("cucumber"), td::DbKey::empty(), -1,
          [&](auto &event) mutable {
            info[0].full_size += event.raw_event_.size();
            info[event.type_].full_size += event.raw_event_.size();
            if (event.type_ == ConfigPmcMagic || event.type_ == BinlogPmcMagic) {
              auto key = td::TlParser(event.get_data()).template fetch_string<td::Slice>();
              info[event.type_].trie.add(key);
            }
            LOG(PLAIN) << "LogEvent[" << td::tag("event_id", td::format::as_hex(event.id_))
                       << td::tag("type", event.type_) << td::tag("flags", event.flags_)
                       << td::tag("size", event.get_data().size())
                       << td::tag("data", td::format::escaped(event.get_data())) << "]\n";
          })
      .ensure();

  for (auto &it : info) {
    LOG(PLAIN) << td::tag("handler", td::format::as_hex(it.first))
               << td::tag("full_size", td::format::as_size(it.second.full_size))
               << td::tag("compressed_size", td::format::as_size(it.second.compressed_size));
    it.second.trie.dump();
    if (it.second.full_size != it.second.compressed_size) {
      it.second.compressed_trie.dump();
    }
  }

  return 0;
}
