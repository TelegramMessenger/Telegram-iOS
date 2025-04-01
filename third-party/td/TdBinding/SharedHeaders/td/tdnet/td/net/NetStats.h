//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/SchedulerLocalStorage.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Time.h"

#include <atomic>
#include <memory>

namespace td {

class NetStatsCallback {
 public:
  virtual void on_read(uint64 bytes) = 0;
  virtual void on_write(uint64 bytes) = 0;
  NetStatsCallback() = default;
  NetStatsCallback(const NetStatsCallback &) = delete;
  NetStatsCallback &operator=(const NetStatsCallback &) = delete;
  virtual ~NetStatsCallback() = default;
};

struct NetStatsData {
  uint64 read_size = 0;
  uint64 write_size = 0;

  uint64 count = 0;
  double duration = 0;
};

inline NetStatsData operator+(const NetStatsData &a, const NetStatsData &b) {
  NetStatsData res;
  res.read_size = a.read_size + b.read_size;
  res.write_size = a.write_size + b.write_size;
  res.count = a.count + b.count;
  res.duration = a.duration + b.duration;
  return res;
}
inline NetStatsData operator-(const NetStatsData &a, const NetStatsData &b) {
  NetStatsData res;
  CHECK(a.read_size >= b.read_size);
  res.read_size = a.read_size - b.read_size;

  CHECK(a.write_size >= b.write_size);
  res.write_size = a.write_size - b.write_size;

  CHECK(a.count >= b.count);
  res.count = a.count - b.count;

  CHECK(a.duration >= b.duration);
  res.duration = a.duration - b.duration;

  return res;
}

inline StringBuilder &operator<<(StringBuilder &sb, const NetStatsData &data) {
  return sb << tag("Rx size", format::as_size(data.read_size)) << tag("Tx size", format::as_size(data.write_size))
            << tag("count", data.count) << tag("duration", format::as_time(data.duration));
}

class NetStats {
 public:
  class Callback {
   public:
    virtual void on_stats_updated() = 0;
    Callback() = default;
    Callback(const Callback &) = delete;
    Callback &operator=(const Callback &) = delete;
    virtual ~Callback() = default;
  };

  std::shared_ptr<NetStatsCallback> get_callback() const {
    return impl_;
  }

  NetStatsData get_stats() const {
    return impl_->get_stats();
  }

  // do it before get_callback
  void set_callback(unique_ptr<Callback> callback) {
    impl_->set_callback(std::move(callback));
  }

 private:
  class Impl final : public NetStatsCallback {
   public:
    NetStatsData get_stats() const {
      NetStatsData res;
      local_net_stats_.for_each([&](auto &stats) {
        res.read_size += stats.read_size.load(std::memory_order_relaxed);
        res.write_size += stats.write_size.load(std::memory_order_relaxed);
      });
      return res;
    }
    void set_callback(unique_ptr<Callback> callback) {
      callback_ = std::move(callback);
    }

   private:
    struct LocalNetStats {
      double last_update = 0;
      uint64 unsync_size = 0;
      std::atomic<uint64> read_size{0};
      std::atomic<uint64> write_size{0};
    };
    SchedulerLocalStorage<LocalNetStats> local_net_stats_;
    unique_ptr<Callback> callback_;

    void on_read(uint64 size) final {
      auto &stats = local_net_stats_.get();
      stats.read_size.fetch_add(size, std::memory_order_relaxed);

      on_change(stats, size);
    }
    void on_write(uint64 size) final {
      auto &stats = local_net_stats_.get();
      stats.write_size.fetch_add(size, std::memory_order_relaxed);

      on_change(stats, size);
    }

    void on_change(LocalNetStats &stats, uint64 size) {
      stats.unsync_size += size;
      auto now = Time::now();
      if (stats.unsync_size > 10000 || now - stats.last_update > 300) {
        stats.unsync_size = 0;
        stats.last_update = now;
        callback_->on_stats_updated();
      }
    }
  };
  std::shared_ptr<Impl> impl_{std::make_shared<Impl>()};
};

}  // namespace td
