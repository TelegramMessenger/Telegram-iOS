/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "third_party/FAAArrayQueue.h"
#include "third_party/HazardPointers.h"
#include "third_party/LazyIndexArrayQueue.h"
#include "third_party/MoodyCamelQueue.h"

#if TG_LCR_QUEUE
#include "third_party/LCRQueue.h"

extern "C" {
#include "third_party/mp-queue.h"
}

#include <linux/futex.h>
#include <sys/syscall.h>
#include <unistd.h>
#endif

#include "td/actor/core/ActorLocker.h"
#include "td/actor/actor.h"

#include "td/utils/benchmark.h"
#include "td/utils/crypto.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/MpmcQueue.h"
#include "td/utils/MpmcWaiter.h"
#include "td/utils/port/thread.h"
#include "td/utils/queue.h"
#include "td/utils/Random.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"
#include "td/utils/UInt.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <condition_variable>
#include <functional>
#include <mutex>
#include <queue>
#include <string>

using td::int32;
using td::uint32;

// Concurrent SHA256 benchmark
// Simplified ton Cell and Block structures
struct CellRef {
  int32 cell_id{0};
  td::MutableSlice hash_slice;
};
struct Cell {
  bool has_hash = false;
  td::UInt256 hash;
  td::MutableSlice data;
  std::array<CellRef, 4> next{};
};

struct Block {
  std::string data;
  std::vector<Cell> cells;
  Cell &get_cell(int32 id) {
    return cells[id];
  }
  const Cell &get_cell(int32 id) const {
    return cells[id];
  }
};

class Generator {
 public:
  static std::string random_bytes(int length) {
    std::string res(length, ' ');
    for (auto &c : res) {
      c = static_cast<char>(td::Random::fast_uint32() % 256);
    }
    return res;
  }

  static Block random_block(int cells_count) {
    const size_t cell_size = 256;
    Block block;
    block.data = random_bytes(td::narrow_cast<int>(cell_size * cells_count));
    block.cells.reserve(cells_count);
    for (int i = 0; i < cells_count; i++) {
      Cell cell;
      cell.data = td::MutableSlice(block.data).substr(i * cell_size, cell_size);
      for (int j = 0; j < 4; j++) {
        cell.next[j] = [&] {
          CellRef cell_ref;
          if (i == 0) {
            return cell_ref;
          }
          cell_ref.cell_id = td::Random::fast(0, i - 1);
          cell_ref.hash_slice = cell.data.substr(cell_size - 128 + j * 32, 32);
          return cell_ref;
        }();
      }
      block.cells.push_back(std::move(cell));
    }
    return block;
  }
};

class BlockSha256Baseline {
 public:
  static std::string get_description() {
    return "Baseline";
  }
  static void calc_hash(Block &block) {
    for (auto &cell : block.cells) {
      td::sha256(cell.data, as_slice(cell.hash));
    }
  }
  static td::Status check(Block &block) {
    for (auto &cell : block.cells) {
      for (auto &cell_ref : cell.next) {
        if (cell_ref.hash_slice.empty()) {
          continue;
        }
        if (cell_ref.hash_slice != as_slice(block.get_cell(cell_ref.cell_id).hash)) {
          return td::Status::Error("Sha mismatch");
        }
      }
    }
    return td::Status::OK();
  }
  static void calc_refs(Block &block) {
    for (auto &cell : block.cells) {
      for (auto &cell_ref : cell.next) {
        if (cell_ref.hash_slice.empty()) {
          continue;
        }
        cell_ref.hash_slice.copy_from(as_slice(block.get_cell(cell_ref.cell_id).hash));
      }
      td::sha256(cell.data, as_slice(cell.hash));
    }
  }
};

class BlockSha256Threads {
 public:
  static std::string get_description() {
    return "Threads";
  }
  template <class Iterator, class F>
  static void parallel_map(Iterator begin, Iterator end, F &&f) {
    size_t size = end - begin;
    auto threads_count = std::max(td::thread::hardware_concurrency(), 1u) * 2;
    auto thread_part_size = (size + threads_count - 1) / threads_count;
    std::vector<td::thread> threads;
    for (size_t i = 0; i < size; i += thread_part_size) {
      auto part_begin = begin + i;
      auto part_size = std::min(thread_part_size, size - i);
      auto part_end = part_begin + part_size;
      threads.push_back(td::thread([part_begin, part_end, &f] {
        for (auto it = part_begin; it != part_end; it++) {
          f(*it);
        }
      }));
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }
  static void calc_hash(Block &block) {
    parallel_map(block.cells.begin(), block.cells.end(),
                 [](Cell &cell) { td::sha256(cell.data, as_slice(cell.hash)); });
  }
  static td::Status check_refs(Block &block) {
    std::atomic<bool> mismatch{false};
    parallel_map(block.cells.begin(), block.cells.end(), [&](Cell &cell) {
      for (auto &cell_ref : cell.next) {
        if (cell_ref.hash_slice.empty()) {
          continue;
        }
        if (cell_ref.hash_slice != as_slice(block.get_cell(cell_ref.cell_id).hash)) {
          mismatch = true;
          break;
        }
      }
    });
    if (mismatch) {
      return td::Status::Error("sha256 mismatch");
    }
    return td::Status::OK();
  }
};

class InfBackoff {
 private:
  int cnt = 0;

 public:
  bool next() {
    cnt++;
    if (cnt < 50) {
      return true;
    } else {
      td::this_thread::yield();
      return true;
    }
  }
};

template <class Q>
class BlockSha256MpmcQueue {
 public:
  static std::string get_description() {
    return Q::get_description();
  }
  static void calc_hash(Block &block) {
    std::vector<td::thread> threads;
    auto threads_count = std::max(td::thread::hardware_concurrency(), 1u) * 2;
    auto queue = std::make_unique<Q>(threads_count + 1);
    for (size_t thread_id = 0; thread_id < threads_count; thread_id++) {
      threads.push_back(td::thread([&, thread_id] {
        while (true) {
          auto f = queue->pop(thread_id);
          if (!f) {
            return;
          }
          f();
        }
      }));
    }
    for (auto &cell : block.cells) {
      queue->push([&cell]() { td::sha256(cell.data, as_slice(cell.hash)); }, threads_count);
    }
    for (size_t thread_id = 0; thread_id < threads_count; thread_id++) {
      queue->push(nullptr, threads_count);
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }
};
template <class Q>
class BlockSha256MpmcQueueCellPtr {
 public:
  static std::string get_description() {
    return "ptr " + Q::get_description();
  }
  static void calc_hash(Block &block) {
    std::vector<td::thread> threads;
    auto threads_count = std::max(td::thread::hardware_concurrency(), 1u) * 2;
    auto queue = std::make_unique<Q>(threads_count + 1);
    Cell poison;
    for (size_t thread_id = 0; thread_id < threads_count; thread_id++) {
      threads.push_back(td::thread([&, thread_id] {
        while (true) {
          auto cell = queue->pop(thread_id);
          if (cell == &poison) {
            return;
          }
          td::sha256(cell->data, as_slice(cell->hash));
        }
      }));
    }
    for (auto &cell : block.cells) {
      queue->push(&cell, threads_count);
    }
    for (size_t thread_id = 0; thread_id < threads_count; thread_id++) {
      queue->push(&poison, threads_count);
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }
};
std::atomic<int> flag;
class ActorExecutorBenchmark : public td::Benchmark {
  std::string get_description() const {
    return "Executor Benchmark";
  }

  void run(int n) {
    using namespace td::actor::core;
    using namespace td::actor;
    using td::actor::detail::ActorMessageCreator;
    struct Dispatcher : public SchedulerDispatcher {
      void add_to_queue(ActorInfoPtr ptr, SchedulerId scheduler_id, bool need_poll) override {
        //queue.push_back(std::move(ptr));
        q.push(ptr, 0);
      }
      void set_alarm_timestamp(const ActorInfoPtr &actor_info_ptr) override {
        UNREACHABLE();
      }
      SchedulerId get_scheduler_id() const override {
        return SchedulerId{0};
      }
      std::deque<ActorInfoPtr> queue;
      td::MpmcQueue<ActorInfoPtr> q{1};
    };
    Dispatcher dispatcher;

    class TestActor : public Actor {
     public:
      void close() {
        stop();
      }

     private:
      void start_up() override {
        //LOG(ERROR) << "start up";
      }
      void tear_down() override {
      }
      void wake_up() override {
        //LOG(ERROR) << "wake up";
      }
    };
    ActorInfoCreator actor_info_creator;
    auto actor = actor_info_creator.create(std::make_unique<TestActor>(),
                                           ActorInfoCreator::Options().on_scheduler(SchedulerId{0}).with_name("A"));
    auto actor2 = actor_info_creator.create(std::make_unique<TestActor>(),
                                            ActorInfoCreator::Options().on_scheduler(SchedulerId{0}).with_name("B"));

    {
      ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options().with_from_queue());
      for (int i = 0; i < n; i++) {
        //int old = i;
        //flag.compare_exchange_strong(old, i + 1, std::memory_order_acquire, std::memory_order_relaxed);
        ActorExecutor executor2(*actor2, dispatcher, ActorExecutor::Options());
      }
    }
    for (int i = 0; i < 0; i++) {
      {
        ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options().with_from_queue());
        executor.send_immediate(
            [&] {
              ActorExecutor executor2(*actor2, dispatcher, ActorExecutor::Options());
              executor2.send_immediate(
                  [&] {
                    ActorExecutor executor3(*actor, dispatcher, ActorExecutor::Options());
                    executor3.send(td::actor::core::ActorSignals::one(td::actor::core::ActorSignals::Wakeup));
                  },
                  0);
            },
            0);
      }
      dispatcher.q.pop(0);
    }

    //{
    //ActorExecutor executor(*actor, dispatcher, ActorExecutor::Options());
    //executor.send(
    //ActorMessageCreator::lambda([&] { static_cast<TestActor &>(ActorExecuteContext::get()->actor()).close(); }));
    //}
    dispatcher.queue.clear();
  }
};
namespace actor_signal_query_test {
using namespace td::actor;
class Master;
class Worker : public td::actor::Actor {
 public:
  Worker(std::shared_ptr<td::Destructor> watcher, ActorId<Master> master)
      : watcher_(std::move(watcher)), master_(std::move(master)) {
  }
  void wake_up() override;

 private:
  std::shared_ptr<td::Destructor> watcher_;
  ActorId<Master> master_;
};
class Master : public td::actor::Actor {
 public:
  Master(std::shared_ptr<td::Destructor> watcher, int n) : watcher_(std::move(watcher)), n_(n) {
  }

  void start_up() override {
    worker_ = create_actor<Worker>(ActorOptions().with_name("Worker"), watcher_, actor_id(this));
    send_signals(worker_, ActorSignals::wakeup());
  }

  void wake_up() override {
    n_--;
    if (n_ <= 0) {
      return stop();
    }
    send_signals(worker_, ActorSignals::wakeup());
  }

 private:
  std::shared_ptr<td::Destructor> watcher_;
  ActorOwn<Worker> worker_;
  int n_;
};
void Worker::wake_up() {
  send_signals(master_, ActorSignals::wakeup());
}
}  // namespace actor_signal_query_test
class ActorSignalQuery : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "ActorSignalQuery";
  }
  void run(int n) override {
    using namespace actor_signal_query_test;
    size_t threads_count = 1;
    Scheduler scheduler{{threads_count}};

    scheduler.run_in_context([&] {
      auto watcher = td::create_shared_destructor([] { td::actor::SchedulerContext::get()->stop(); });

      create_actor<Master>(ActorOptions().with_name(PSLICE() << "Master"), watcher, n).release();
    });
    scheduler.run();
  }
};

namespace actor_query_test {
using namespace td::actor;
class Master;
class Worker : public td::actor::Actor {
 public:
  Worker(std::shared_ptr<td::Destructor> watcher) : watcher_(std::move(watcher)) {
  }
  void query(int x, ActorId<Master> master);

 private:
  std::shared_ptr<td::Destructor> watcher_;
};
class Master : public td::actor::Actor {
 public:
  Master(std::shared_ptr<td::Destructor> watcher, int n) : watcher_(std::move(watcher)), n_(n) {
  }

  void start_up() override {
    worker_ = create_actor<Worker>(ActorOptions().with_name("Worker"), watcher_);
    send_closure(worker_, &Worker::query, n_, actor_id(this));
  }

  void answer(int x, int y) {
    if (x == 0) {
      return stop();
    }
    send_closure(worker_, &Worker::query, x - 1, actor_id(this));
  }

 private:
  std::shared_ptr<td::Destructor> watcher_;
  ActorOwn<Worker> worker_;
  int n_;
};
void Worker::query(int x, ActorId<Master> master) {
  send_closure(master, &Master::answer, x, x + x);
}
}  // namespace actor_query_test
class ActorQuery : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "ActorQuery";
  }
  void run(int n) override {
    using namespace actor_query_test;
    size_t threads_count = 1;
    Scheduler scheduler({threads_count});

    scheduler.run_in_context([&] {
      auto watcher = td::create_shared_destructor([] { td::actor::SchedulerContext::get()->stop(); });

      create_actor<Master>(ActorOptions().with_name(PSLICE() << "Master"), watcher, n).release();
    });
    scheduler.run();
  }
};

namespace actor_dummy_query_test {
using namespace td::actor;
class Master;
class Worker : public td::actor::Actor {
 public:
  Worker(std::shared_ptr<td::Destructor> watcher) : watcher_(std::move(watcher)) {
  }
  void query(int x, int *y) {
    *y = x + x;
  }
  void start_up() override {
  }

 private:
  std::shared_ptr<td::Destructor> watcher_;
};
class Master : public td::actor::Actor {
 public:
  Master(std::shared_ptr<td::Destructor> watcher, int n) : watcher_(std::move(watcher)), n_(n) {
  }

  void start_up() override {
    worker_ = create_actor<Worker>(ActorOptions().with_name("Worker"), watcher_);
    int res;
    for (int i = 0; i < n_; i++) {
      send_closure(worker_, &Worker::query, i, &res);
      CHECK(res == i + i);
    }
    stop();
  }

 private:
  std::shared_ptr<td::Destructor> watcher_;
  ActorOwn<Worker> worker_;
  int n_;
};
}  // namespace actor_dummy_query_test
class ActorDummyQuery : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "ActorDummyQuery";
  }
  void run(int n) override {
    using namespace actor_dummy_query_test;
    size_t threads_count = 1;
    Scheduler scheduler({threads_count});

    scheduler.run_in_context([&] {
      auto watcher = td::create_shared_destructor([] { td::actor::SchedulerContext::get()->stop(); });

      create_actor<Master>(ActorOptions().with_name(PSLICE() << "Master"), watcher, n).release();
    });

    scheduler.run();
  }
};

namespace actor_task_query_test {
using namespace td::actor;
class Master;
class Worker : public td::actor::Actor {
 public:
  Worker(int x, ActorId<Master> master) : x_(x), master_(std::move(master)) {
  }
  void start_up() override;

 private:
  int x_;
  ActorId<Master> master_;
};
class Master : public td::actor::Actor {
 public:
  Master(std::shared_ptr<td::Destructor> watcher, int n) : watcher_(std::move(watcher)), n_(n) {
  }

  void start_up() override {
    create_actor<Worker>(ActorOptions().with_name("Worker"), n_, actor_id(this)).release();
  }

  void answer(int x, int y) {
    if (x == 0) {
      return stop();
    }
    create_actor<Worker>(ActorOptions().with_name("Worker"), x - 1, actor_id(this)).release();
  }

 private:
  std::shared_ptr<td::Destructor> watcher_;
  ActorOwn<Worker> worker_;
  int n_;
};
void Worker::start_up() {
  send_closure(master_, &Master::answer, x_, x_ + x_);
  stop();
}
}  // namespace actor_task_query_test
class ActorTaskQuery : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "ActorTaskQuery";
  }
  void run(int n) override {
    using namespace actor_task_query_test;
    size_t threads_count = 1;
    Scheduler scheduler({threads_count});

    scheduler.run_in_context([&] {
      auto watcher = td::create_shared_destructor([] { td::actor::SchedulerContext::get()->stop(); });

      create_actor<Master>(ActorOptions().with_name(PSLICE() << "Master"), watcher, n).release();
    });
    scheduler.run();
  }
};
class BlockSha256Actors {
 public:
  static std::string get_description() {
    return "Actors";
  }
  template <class Iterator, class F>
  static void parallel_map(Iterator begin, Iterator end, F &&f) {
    auto threads_count = std::max(td::thread::hardware_concurrency(), 1u) * 2;
    using namespace td::actor;
    Scheduler scheduler({threads_count});

    scheduler.run_in_context([&] {
      auto watcher = td::create_shared_destructor([] { td::actor::SchedulerContext::get()->stop(); });
      class Worker : public td::actor::Actor {
       public:
        Worker(std::shared_ptr<td::Destructor> watcher, td::Promise<> promise)
            : watcher_(std::move(watcher)), promise_(std::move(promise)) {
        }
        void start_up() override {
          promise_.set_value(td::Unit());
          stop();
        }

       private:
        std::shared_ptr<td::Destructor> watcher_;
        td::Promise<> promise_;
      };

      for (auto it = begin; it != end; it++) {
        create_actor<Worker>(ActorOptions().with_name(PSLICE() << "Worker#"), watcher,
                             td::Promise<>([&, it](td::Unit) { f(*it); }))
            .release();
      }
    });
    scheduler.run();
  }
  static void calc_hash(Block &block) {
    parallel_map(block.cells.begin(), block.cells.end(),
                 [](Cell &cell) { td::sha256(cell.data, as_slice(cell.hash)); });
  }
};

class ActorLockerBenchmark : public td::Benchmark {
 public:
  explicit ActorLockerBenchmark(int threads_n) : threads_n_(threads_n) {
  }
  std::string get_description() const override {
    return PSTRING() << "ActorLockerBenchmark " << threads_n_;
  }
  void run(int n) override {
    std::vector<td::thread> threads(threads_n_);
    using namespace td::actor::core;
    ActorState state;
    std::atomic<int> ready{0};
    for (auto &thread : threads) {
      thread = td::thread([&] {
        ActorLocker locker(&state);
        ready++;
        while (ready != threads_n_) {
          td::this_thread::yield();
        }
        for (int i = 0; i < n / threads_n_; i++) {
          if (locker.add_signals(ActorSignals::one(ActorSignals::Kill))) {
            while (!locker.try_unlock(ActorState::Flags{})) {
            }
          }
        }
      });
    }
    for (auto &thread : threads) {
      thread.join();
    }
  }

 private:
  int threads_n_;
};

template <class Impl>
class CalcHashSha256Benchmark : public td::Benchmark {
 public:
  std::string get_description() const override {
    return "CheckSha256: " + impl_.get_description();
  }
  void start_up_n(int n) override {
    block_ = Generator::random_block(n);
  }

  void run(int n) override {
    Impl::calc_hash(block_);
  }

 private:
  Impl impl_;
  Block block_;
};

/*
template <class T>
class MpmcQueueInterface {
 public:
  explicit MpmcQueueInterface(size_t thread_n);
  static std::string get_description();
  void push(T value, size_t thread_id);
  T pop(size_t thread_id);
  bool try_pop(T &value, size_t thread_id);
};
*/

// Simple bounded mpmc queue
template <class ValueT>
class BoundedMpmcQueue {
 public:
  explicit BoundedMpmcQueue(size_t threads_n) : data_(1 << 20) {
  }
  static std::string get_description() {
    return "BoundedMpmc queue";
  }
  void push(ValueT value, size_t = 0) {
    auto pos = write_pos_.fetch_add(1, std::memory_order_relaxed);
    auto generation = pos / data_.size() * 2 + 0;
    auto &element = data_[pos % data_.size()];

    InfBackoff backoff;
    while (element.generation.load(std::memory_order_acquire) != generation) {
      backoff.next();
    }
    element.value = std::move(value);
    element.generation.fetch_add(1, std::memory_order_release);
  }

  ValueT pop(size_t = 0) {
    auto pos = read_pos_.fetch_add(1, std::memory_order_relaxed);
    auto generation = pos / data_.size() * 2 + 1;
    auto &element = data_[pos % data_.size()];

    InfBackoff backoff;
    while (element.generation.load(std::memory_order_acquire) != generation) {
      backoff.next();
    }
    auto result = std::move(element.value);
    element.generation.fetch_add(1, std::memory_order_release);
    return result;
  }
  bool try_pop(ValueT &value, size_t = 0) {
    auto pos = read_pos_.load(std::memory_order_relaxed);
    auto generation = pos / data_.size() * 2 + 1;
    auto &element = data_[pos % data_.size()];

    if (element.generation.load(std::memory_order_acquire) != generation) {
      return false;
    }
    if (!read_pos_.compare_exchange_strong(pos, pos + 1, std::memory_order_acq_rel)) {
      return false;
    }
    value = std::move(element.value);
    element.generation.fetch_add(1, std::memory_order_release);
    return true;
  }

 private:
  std::atomic<td::uint64> write_pos_{0};
  char pad[128];
  std::atomic<td::uint64> read_pos_{0};
  char pad2[128];
  struct Element {
    std::atomic<td::uint32> generation{0};
    ValueT value;
    //char pad2[128];
  };
  std::vector<Element> data_;
  char pad3[128];
};

template <class Impl>
class MpmcQueueBenchmark : public td::Benchmark {
 public:
  MpmcQueueBenchmark(int n, int m) : n_(n), m_(m) {
  }
  std::string get_description() const override {
    return PSTRING() << "MpmcQueueBenchmark " << n_ << " " << m_ << " " << Impl::get_description();
  }

  void run(int n) override {
    std::vector<td::thread> n_threads(n_);
    std::vector<td::thread> m_threads(m_);
    auto impl = std::make_unique<Impl>(n_ + m_ + 1);
    size_t thread_id = 0;
    for (auto &thread : m_threads) {
      thread = td::thread([&, thread_id] {
        while (true) {
          size_t value = impl->pop(thread_id);
          if (!value) {
            break;
          }
        }
      });
      thread_id++;
    }
    for (auto &thread : n_threads) {
      thread = td::thread([&, thread_id] {
        for (int i = 0; i < n / n_; i++) {
          impl->push(static_cast<size_t>(i + 1), thread_id);
        }
      });
      thread_id++;
    }
    for (auto &thread : n_threads) {
      thread.join();
    }
    for (int i = 0; i < m_; i++) {
      impl->push(0, thread_id);
    }
    for (auto &thread : m_threads) {
      thread.join();
    }
    impl.reset();
  }

 private:
  int n_;
  int m_;
};

class Cheat {
 public:
  explicit Cheat(size_t thread_n) : impl_(static_cast<int>(thread_n)) {
  }
  static std::string get_description() {
    return "td::MpmcQueue (cheat)";
  }
  void push(size_t value, size_t thread_id) {
    impl_.push(reinterpret_cast<size_t *>(value + 1), static_cast<int>(thread_id));
  }
  size_t pop(size_t thread_id) {
    auto res = impl_.pop(thread_id);
    return reinterpret_cast<size_t>(res) - 1;
  }
  bool try_pop(size_t &value, size_t thread_id) {
    size_t *was;
    if (impl_.try_pop(was, thread_id)) {
      value = reinterpret_cast<size_t>(was) - 1;
      return true;
    }
    return false;
  }

 private:
  td::MpmcQueue<size_t *> impl_;
};

using ConcurrencyFreaks::FAAArrayQueue;
using ConcurrencyFreaks::LazyIndexArrayQueue;
#if TG_LCR_QUEUE
using ConcurrencyFreaks::LCRQueue;
#endif

template <class Impl>
class CfQueue {
 public:
  explicit CfQueue(size_t thread_n) : impl_(static_cast<int>(thread_n)) {
  }
  static std::string get_description() {
    return "TODO";
  }
  void push(size_t value, size_t thread_id) {
    impl_.enqueue(reinterpret_cast<size_t *>(value + 1), static_cast<int>(thread_id));
  }
  size_t pop(size_t thread_id) {
    size_t res;
    while (!try_pop(res, thread_id)) {
      td::this_thread::yield();
    }
    return res;
  }
  bool try_pop(size_t &value, size_t thread_id) {
    auto ptr = impl_.dequeue(static_cast<int>(thread_id));
    if (!ptr) {
      return false;
    }
    value = reinterpret_cast<size_t>(ptr) - 1;
    return true;
  }

 private:
  Impl impl_;
};

#if TG_LCR_QUEUE
template <>
std::string CfQueue<LCRQueue<size_t>>::get_description() {
  return "LCRQueue (cf)";
}
#endif
template <>
std::string CfQueue<LazyIndexArrayQueue<size_t>>::get_description() {
  return "LazyIndexArrayQueue (cf)";
}
template <>
std::string CfQueue<FAAArrayQueue<size_t>>::get_description() {
  return "FAAArrayQueue (cf)";
}
template <class Impl, class T>
class CfQueueT {
 public:
  explicit CfQueueT(size_t thread_n) : impl_(static_cast<int>(thread_n)) {
  }
  static std::string get_description() {
    return "TODO";
  }
  void push(T *value, size_t thread_id) {
    impl_.enqueue(value, static_cast<int>(thread_id));
  }
  T *pop(size_t thread_id) {
    td::detail::Backoff backoff;
    while (true) {
      auto ptr = impl_.dequeue(static_cast<int>(thread_id));
      if (!ptr) {
        backoff.next();
      } else {
        return ptr;
      }
    }
  }
  bool try_pop(T *&value, size_t thread_id) {
    value = impl_.dequeue(static_cast<int>(thread_id));
    return value != nullptr;
  }

 private:
  Impl impl_;
};

#if TG_LCR_QUEUE
template <>
std::string CfQueueT<LCRQueue<Cell>, Cell>::get_description() {
  return "LCRQueue (cf)";
}
#endif
template <>
std::string CfQueueT<LazyIndexArrayQueue<Cell>, Cell>::get_description() {
  return "LazyIndexArrayQueue (cf)";
}
template <>
std::string CfQueueT<FAAArrayQueue<Cell>, Cell>::get_description() {
  return "FAAArrayQueue (cf)";
}

template <class Value>
class MoodyQueue {
 public:
  explicit MoodyQueue(size_t) {
  }
  static std::string get_description() {
    return "moodycamel queue";
  }
  void push(Value v, size_t) {
    q.enqueue(v);
  }
  Value pop(size_t) {
    Value res;
    while (!q.try_dequeue(res)) {
    }
    return res;
  }
  bool try_pop(Value &value, size_t) {
    return q.try_dequeue(value);
  }

 private:
  moodycamel::ConcurrentQueue<Value> q;
};

#if TG_LCR_QUEUE
class MpQueue {
 public:
  explicit MpQueue(size_t) {
    q_ = alloc_mp_queue();
  }
  ~MpQueue() {
    free_mp_queue(q_);
    clear_thread_ids();
  }
  void push(size_t value, size_t) {
    mpq_push(q_, reinterpret_cast<void *>(value + 1), 0);
  }
  size_t pop(size_t) {
    td::detail::Backoff backoff;
    while (true) {
      auto ptr = mpq_pop(q_, 0);
      if (!ptr) {
        backoff.next();
      } else {
        return reinterpret_cast<size_t>(ptr) - 1;
      }
    }
  }
  bool try_pop(size_t &value, size_t) {
    auto ptr = mpq_pop(q_, 0);
    if (!ptr) {
      return false;
    }
    value = reinterpret_cast<size_t>(ptr) - 1;
    return true;
  }

  static std::string get_description() {
    return "mp-queue";
  }

 public:
  struct mp_queue *q_;
};

class Semaphore {
 public:
  Semaphore() {
    impl->value = 0;
    impl->waiting = 0;
  }
  void wait() {
    mp_sem_wait(impl.get());
  }
  void post() {
    mp_sem_post(impl.get());
  }
  std::unique_ptr<mp_sem_t> impl = std::make_unique<mp_semaphore>();
};

template <class Q, class T>
class SemQueue {
 public:
  static std::string get_description() {
    return "Sem + " + Q::get_description();
  }
  explicit SemQueue(size_t threads_n) : impl(threads_n) {
  }
  T pop(size_t thread_id) {
    T res;
    td::detail::Backoff backoff;
    while (!impl.try_pop(res, thread_id)) {
      if (!backoff.next()) {
        sem.wait();
      }
    }
    return res;
  }
  void push(T value, size_t thread_id) {
    impl.push(std::move(value), thread_id);
    sem.post();
  }

 private:
  Semaphore sem;
  Q impl;
};
#endif

template <class T>
class StupidQueue {
 public:
  explicit StupidQueue(size_t) {
  }
  static std::string get_description() {
    return "Mutex queue";
  }
  T pop(size_t) {
    std::unique_lock<std::mutex> guard(mutex_);
    cv_.wait(guard, [&] { return !queue_.empty(); });
    auto front = queue_.front();
    queue_.pop();
    return front;
  }
  void push(T value, size_t) {
    {
      std::unique_lock<std::mutex> guard(mutex_);
      queue_.push(std::move(value));
    }
    cv_.notify_one();
  }
  bool try_pop(T &value, size_t) {
    std::lock_guard<std::mutex> guard(mutex_);
    if (!queue_.empty()) {
      value = std::move(queue_.front());
      queue_.pop();
      return true;
    }
    return false;
  }

 private:
  std::mutex mutex_;
  std::queue<T> queue_;
  std::condition_variable cv_;
};

template <class Q, class W, class T>
class WaitQueue {
 public:
  static std::string get_description() {
    return "Wait + " + Q::get_description();
  }
  explicit WaitQueue(size_t threads_n) : impl(threads_n) {
  }
  T pop(size_t thread_id) {
    T res;
    int yields = 0;
    while (!impl.try_pop(res, thread_id)) {
      yields = waiter.wait(yields, static_cast<uint32>(thread_id));
    }
    waiter.stop_wait(yields, static_cast<uint32>(thread_id));
    return res;
  }
  void push(T value, size_t thread_id) {
    impl.push(std::move(value), static_cast<uint32>(thread_id));
    waiter.notify();
  }

 private:
  W waiter;
  Q impl;
};

void run_queue_bench(int n, int m) {
  bench(MpmcQueueBenchmark<WaitQueue<td::MpmcQueue<size_t>, td::MpmcWaiter, size_t>>(n, m), 2);
  bench(MpmcQueueBenchmark<td::MpmcQueue<size_t>>(n, m), 2);
  bench(MpmcQueueBenchmark<td::MpmcQueueOld<size_t>>(n, m), 2);
  bench(MpmcQueueBenchmark<Cheat>(n, m), 2);
  bench(MpmcQueueBenchmark<CfQueue<FAAArrayQueue<size_t>>>(n, m), 2);
  bench(MpmcQueueBenchmark<CfQueue<LazyIndexArrayQueue<size_t>>>(n, m), 2);
  bench(MpmcQueueBenchmark<StupidQueue<size_t>>(n, m), 2);
  //bench(MpmcQueueBenchmark<MpQueue>(n, m), 2);
#if TG_LCR_QUEUE
  bench(MpmcQueueBenchmark<CfQueue<LCRQueue<size_t>>>(n, m), 2);
#endif
}

struct Sem {
 public:
  void post() {
    if (++cnt_ == 0) {
      {
        std::unique_lock<std::mutex> lk(mutex_);
      }
      cnd_.notify_one();
    }
  }
  void wait(int cnt = 1) {
    auto was = cnt_.fetch_sub(cnt);
    if (was >= cnt) {
      return;
    }
    std::unique_lock<std::mutex> lk(mutex_);
    cnd_.wait(lk, [&] { return cnt_ >= 0; });
  }

 private:
  std::mutex mutex_;
  std::condition_variable cnd_;
  std::atomic<int> cnt_{0};
};

class ChainedSpawn : public td::Benchmark {
 public:
  ChainedSpawn(bool use_io) : use_io_(use_io) {
  }
  std::string get_description() const {
    return PSTRING() << "Chained create_actor use_io(" << use_io_ << ")";
  }

  void run(int n) {
    class Task : public td::actor::Actor {
     public:
      Task(int n, Sem *sem) : n_(n), sem_(sem) {
      }
      void start_up() override {
        if (n_ == 0) {
          sem_->post();
        } else {
          td::actor::create_actor<Task>("Task", n_ - 1, sem_).release();
        }
        stop();
      };

     private:
      int n_;
      Sem *sem_{nullptr};
    };
    td::actor::Scheduler scheduler{{8}};
    auto sch = td::thread([&] { scheduler.run(); });

    Sem sem;
    scheduler.run_in_context_external([&] {
      for (int i = 0; i < n; i++) {
        td::actor::create_actor<Task>(td::actor::ActorOptions().with_name("Task").with_poll(use_io_), 1000, &sem)
            .release();
        sem.wait();
      }
      td::actor::SchedulerContext::get()->stop();
    });

    sch.join();
  }

 private:
  bool use_io_{false};
};

class ChainedSpawnInplace : public td::Benchmark {
 public:
  ChainedSpawnInplace(bool use_io) : use_io_(use_io) {
  }
  std::string get_description() const {
    return PSTRING() << "Chained send_signal(self) use_io(" << use_io_ << ")";
  }

  void run(int n) {
    class Task : public td::actor::Actor {
     public:
      Task(int n, Sem *sem) : n_(n), sem_(sem) {
      }
      void loop() override {
        if (n_ == 0) {
          sem_->post();
          stop();
        } else {
          n_--;
          send_signals(actor_id(this), td::actor::ActorSignals::wakeup());
        }
      };

     private:
      int n_;
      Sem *sem_;
    };
    td::actor::Scheduler scheduler{{8}};
    auto sch = td::thread([&] { scheduler.run(); });

    Sem sem;
    scheduler.run_in_context_external([&] {
      for (int i = 0; i < n; i++) {
        td::actor::create_actor<Task>(td::actor::ActorOptions().with_name("Task").with_poll(use_io_), 1000, &sem)
            .release();
        sem.wait();
      }
      td::actor::SchedulerContext::get()->stop();
    });

    sch.join();
  }

 private:
  bool use_io_{false};
};

class PingPong : public td::Benchmark {
 public:
  PingPong(bool use_io) : use_io_(use_io) {
  }
  std::string get_description() const {
    return PSTRING() << "PingPong use_io(" << use_io_ << ")";
  }

  void run(int n) {
    if (n < 3) {
      n = 3;
    }
    class Task : public td::actor::Actor {
     public:
      explicit Task(Sem *sem) : sem_(sem) {
      }
      void set_peer(td::actor::ActorId<Task> peer) {
        peer_ = peer;
      }
      void ping(int n) {
        if (n < 0) {
          sem_->post();
          stop();
        }
        send_closure(peer_, &Task::ping, n - 1);
      }

     private:
      td::actor::ActorId<Task> peer_;
      Sem *sem_;
    };
    td::actor::Scheduler scheduler{{8}};
    auto sch = td::thread([&] { scheduler.run(); });

    Sem sem;
    scheduler.run_in_context_external([&] {
      for (int i = 0; i < n; i++) {
        auto a = td::actor::create_actor<Task>(td::actor::ActorOptions().with_name("Task").with_poll(use_io_), &sem)
                     .release();
        auto b = td::actor::create_actor<Task>(td::actor::ActorOptions().with_name("Task").with_poll(use_io_), &sem)
                     .release();
        send_closure(a, &Task::set_peer, b);
        send_closure(b, &Task::set_peer, a);
        send_closure(a, &Task::ping, 1000);
        sem.wait(2);
      }
      td::actor::SchedulerContext::get()->stop();
    });

    sch.join();
  }

 private:
  bool use_io_{false};
};

class SpawnMany : public td::Benchmark {
 public:
  SpawnMany(bool use_io) : use_io_(use_io) {
  }
  std::string get_description() const {
    return PSTRING() << "Spawn many use_io(" << use_io_ << ")";
  }

  void run(int n) {
    class Task : public td::actor::Actor {
     public:
      Task(Sem *sem) : sem_(sem) {
      }
      void start_up() override {
        sem_->post();
        stop();
      };

     private:
      Sem *sem_;
    };
    td::actor::Scheduler scheduler{{8}};
    Sem sem;
    auto sch = td::thread([&] { scheduler.run(); });
    scheduler.run_in_context_external([&] {
      for (int i = 0; i < n; i++) {
        int spawn_cnt = 10000;
        for (int j = 0; j < spawn_cnt; j++) {
          td::actor::create_actor<Task>(td::actor::ActorOptions().with_name("Task").with_poll(use_io_), &sem).release();
        }
        sem.wait(spawn_cnt);
      }
      td::actor::SchedulerContext::get()->stop();
    });
    sch.join();
  }

 private:
  bool use_io_{false};
};

class YieldMany : public td::Benchmark {
 public:
  YieldMany(bool use_io) : use_io_(use_io) {
  }
  std::string get_description() const {
    return PSTRING() << "Yield many use_io(" << use_io_ << ")";
  }

  void run(int n) {
    int num_yield = 1000;
    unsigned tasks_per_cpu = 50;
    unsigned cpu_n = td::thread::hardware_concurrency();
    class Task : public td::actor::Actor {
     public:
      explicit Task(int n, Sem *sem) : n_(n), sem_(sem) {
      }
      void loop() override {
        if (n_ == 0) {
          sem_->post();
          stop();
        } else {
          n_--;
          yield();
        }
      };

     private:
      int n_;
      Sem *sem_;
    };
    td::actor::Scheduler scheduler{{cpu_n}};
    auto sch = td::thread([&] { scheduler.run(); });
    unsigned tasks = tasks_per_cpu * cpu_n;
    Sem sem;
    scheduler.run_in_context_external([&] {
      for (int i = 0; i < n; i++) {
        for (unsigned j = 0; j < tasks; j++) {
          td::actor::create_actor<Task>(td::actor::ActorOptions().with_name("Task").with_poll(use_io_), num_yield, &sem)
              .release();
        }
        sem.wait(tasks);
      }
    });

    scheduler.run_in_context_external([&] { td::actor::SchedulerContext::get()->stop(); });
    sch.join();
  }

 private:
  bool use_io_{false};
};

int main(int argc, char **argv) {
  if (argc > 1) {
    if (argv[1][0] == 'a') {
      bench_n(MpmcQueueBenchmark<td::MpmcQueue<size_t>>(1, 1), 1 << 26);
      //bench_n(MpmcQueueBenchmark<MpQueue>(1, 40), 1 << 20);
      //bench_n(MpmcQueueBenchmark<CfQueue<LCRQueue<size_t>>>(1, 40), 1 << 20);
    } else {
      bench_n(MpmcQueueBenchmark<td::MpmcQueueOld<size_t>>(1, 1), 1 << 26);
      //bench_n(MpmcQueueBenchmark<CfQueue<LCRQueue<size_t>>>(1, 40), 1 << 20);
      //bench_n(MpmcQueueBenchmark<CfQueue<FAAArrayQueue<size_t>>>(1, 1), 1 << 26);
    }
    return 0;
  }

  bench(YieldMany(false));
  bench(YieldMany(true));
  bench(SpawnMany(false));
  bench(SpawnMany(true));
  bench(PingPong(false));
  bench(PingPong(true));
  bench(ChainedSpawnInplace(false));
  bench(ChainedSpawnInplace(true));
  bench(ChainedSpawn(false));
  bench(ChainedSpawn(true));
  return 0;

  bench(ActorDummyQuery());
  bench(ActorExecutorBenchmark());
  bench(ActorSignalQuery());
  bench(ActorQuery());
  bench(ActorTaskQuery());
  bench(CalcHashSha256Benchmark<BlockSha256Actors>());
  bench(CalcHashSha256Benchmark<BlockSha256Threads>());
  bench(CalcHashSha256Benchmark<BlockSha256Baseline>());
  bench(ActorLockerBenchmark(1));
  bench(ActorLockerBenchmark(2));
  bench(ActorLockerBenchmark(5));
  bench(ActorLockerBenchmark(20));

  bench(CalcHashSha256Benchmark<BlockSha256MpmcQueueCellPtr<td::MpmcQueue<Cell *>>>());
  bench(CalcHashSha256Benchmark<BlockSha256MpmcQueueCellPtr<td::MpmcQueueOld<Cell *>>>());
  bench(CalcHashSha256Benchmark<BlockSha256MpmcQueueCellPtr<CfQueueT<FAAArrayQueue<Cell>, Cell>>>());

  bench(CalcHashSha256Benchmark<BlockSha256MpmcQueueCellPtr<StupidQueue<Cell *>>>());
  bench(CalcHashSha256Benchmark<BlockSha256MpmcQueueCellPtr<CfQueueT<LazyIndexArrayQueue<Cell>, Cell>>>());
#if TG_LCR_QUEUE
  bench(CalcHashSha256Benchmark<BlockSha256MpmcQueueCellPtr<CfQueueT<LCRQueue<Cell>, Cell>>>());
#endif
  bench(CalcHashSha256Benchmark<BlockSha256MpmcQueueCellPtr<MoodyQueue<Cell *>>>());
  bench(CalcHashSha256Benchmark<BlockSha256MpmcQueueCellPtr<BoundedMpmcQueue<Cell *>>>());

  bench(CalcHashSha256Benchmark<BlockSha256MpmcQueue<BoundedMpmcQueue<std::function<void()>>>>());
  bench(CalcHashSha256Benchmark<BlockSha256MpmcQueue<td::MpmcQueue<std::function<void()>>>>());

  run_queue_bench(1, 10);
  run_queue_bench(1, 1);
  run_queue_bench(2, 10);
  run_queue_bench(2, 2);
  run_queue_bench(10, 10);

  run_queue_bench(2, 2);
  run_queue_bench(1, 10);
  run_queue_bench(10, 1);
  run_queue_bench(10, 10);

  return 0;
}
