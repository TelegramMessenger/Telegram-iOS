//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/benchmark.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/MpscPollableQueue.h"
#include "td/utils/port/sleep.h"
#include "td/utils/port/thread.h"
#include "td/utils/queue.h"
#include "td/utils/Random.h"

// TODO: check system calls
// TODO: all return values must be checked

#include <atomic>

#if TD_PORT_POSIX
#include <pthread.h>
#include <sched.h>
#include <semaphore.h>
#include <sys/syscall.h>
#include <unistd.h>
#endif

#if TD_LINUX
#include <sys/eventfd.h>
#endif

#define MODE std::memory_order_relaxed

// void set_affinity(int mask) {
//   pid_t pid = gettid();
//   int syscallres = syscall(__NR_sched_setaffinity, pid, sizeof(mask), &mask);
//   if (syscallres) {
//     perror("Failed to set affinity");
//   }
// }

using qvalue_t = int;

class Backoff {
  int cnt = 0;

 public:
  bool next() {
    cnt++;
    if (cnt < 50) {
      return true;
    } else {
      td::usleep_for(1);
      return cnt < 500;
    }
  }
};

#if TD_PORT_POSIX
// Just for testing, not production
class PipeQueue {
  int input;
  int output;

 public:
  void init() {
    int new_pipe[2];
    int res = pipe(new_pipe);
    CHECK(res == 0);
    output = new_pipe[0];
    input = new_pipe[1];
  }

  void put(qvalue_t value) {
    auto len = write(input, &value, sizeof(value));
    CHECK(len == sizeof(value));
  }

  qvalue_t get() {
    qvalue_t res;
    auto len = read(output, &res, sizeof(res));
    CHECK(len == sizeof(res));
    return res;
  }

  void destroy() {
    close(input);
    close(output);
  }
};

class VarQueue {
  std::atomic<qvalue_t> data{0};

 public:
  void init() {
    data.store(-1, MODE);
  }

  void put(qvalue_t value) {
    data.store(value, MODE);
  }

  qvalue_t try_get() {
    __sync_synchronize();  // TODO: it is wrong place for barrier, but it results in fastest queue
    qvalue_t res = data.load(MODE);
    return res;
  }

  void acquire() {
    data.store(-1, MODE);
  }

  qvalue_t get() {
    qvalue_t res;
    Backoff backoff;

    do {
      res = try_get();
    } while (res == -1 && (backoff.next(), true));
    acquire();

    return res;
  }

  void destroy() {
  }
};

class SemQueue {
  sem_t sem;
  VarQueue q;

 public:
  void init() {
    q.init();
    sem_init(&sem, 0, 0);
  }

  void put(qvalue_t value) {
    q.put(value);
    sem_post(&sem);
  }

  qvalue_t get() {
    sem_wait(&sem);
    qvalue_t res = q.get();
    return res;
  }

  void destroy() {
    q.destroy();
    sem_destroy(&sem);
  }

  // HACK for benchmark
  void reader_flush() {
  }

  void writer_flush() {
  }

  void writer_put(qvalue_t value) {
    put(value);
  }

  int reader_wait() {
    return 1;
  }

  qvalue_t reader_get_unsafe() {
    return get();
  }
};
#endif

#if TD_LINUX
class EventfdQueue {
  int fd;
  VarQueue q;

 public:
  void init() {
    q.init();
    fd = eventfd(0, 0);
  }
  void put(qvalue_t value) {
    q.put(value);
    td::int64 x = 1;
    auto len = write(fd, &x, sizeof(x));
    CHECK(len == sizeof(x));
  }
  qvalue_t get() {
    td::int64 x;
    auto len = read(fd, &x, sizeof(x));
    CHECK(len == sizeof(x));
    CHECK(x == 1);
    return q.get();
  }
  void destroy() {
    q.destroy();
    close(fd);
  }
};
#endif

const int queue_buf_size = 1 << 10;

class BufferQueue {
  struct node {
    qvalue_t val;
    char pad[64 - sizeof(std::atomic<qvalue_t>)];
  };
  node q[queue_buf_size];

  struct Position {
    std::atomic<td::uint32> i{0};
    char pad[64 - sizeof(std::atomic<td::uint32>)];

    td::uint32 local_read_i;
    td::uint32 local_write_i;
    char pad2[64 - sizeof(td::uint32) * 2];

    void init() {
      i = 0;
      local_read_i = 0;
      local_write_i = 0;
    }
  };

  Position writer;
  Position reader;

 public:
  void init() {
    writer.init();
    reader.init();
  }

  bool reader_empty() {
    return reader.local_write_i == reader.local_read_i;
  }

  bool writer_empty() {
    return writer.local_write_i == writer.local_read_i + queue_buf_size;
  }

  int reader_ready() {
    return static_cast<int>(reader.local_write_i - reader.local_read_i);
  }

  int writer_ready() {
    return static_cast<int>(writer.local_read_i + queue_buf_size - writer.local_write_i);
  }

  qvalue_t get_unsafe() {
    return q[reader.local_read_i++ & (queue_buf_size - 1)].val;
  }

  void flush_reader() {
    reader.i.store(reader.local_read_i, std::memory_order_release);
  }

  int update_reader() {
    reader.local_write_i = writer.i.load(std::memory_order_acquire);
    return reader_ready();
  }

  void put_unsafe(qvalue_t val) {
    q[writer.local_write_i++ & (queue_buf_size - 1)].val = val;
  }

  void flush_writer() {
    writer.i.store(writer.local_write_i, std::memory_order_release);
  }

  int update_writer() {
    writer.local_read_i = reader.i.load(std::memory_order_acquire);
    return writer_ready();
  }

  int wait_reader() {
    Backoff backoff;
    int res = 0;
    while (res == 0) {
      backoff.next();
      res = update_reader();
    }
    return res;
  }

  qvalue_t get_noflush() {
    if (!reader_empty()) {
      return get_unsafe();
    }

    Backoff backoff;
    while (true) {
      backoff.next();
      if (update_reader()) {
        return get_unsafe();
      }
    }
  }

  qvalue_t get() {
    qvalue_t res = get_noflush();
    flush_reader();
    return res;
  }

  void put_noflush(qvalue_t val) {
    if (!writer_empty()) {
      put_unsafe(val);
      return;
    }
    if (!update_writer()) {
      LOG(FATAL) << "Put strong failed";
    }
    put_unsafe(val);
  }

  void put(qvalue_t val) {
    put_noflush(val);
    flush_writer();
  }

  void destroy() {
  }
};

#if TD_LINUX
class BufferedFdQueue {
  int fd;
  std::atomic<int> wait_flag{0};
  BufferQueue q;
  char pad[64];

 public:
  void init() {
    q.init();
    fd = eventfd(0, 0);
    (void)pad[0];
  }
  void put(qvalue_t value) {
    q.put(value);
    td::int64 x = 1;
    __sync_synchronize();
    if (wait_flag.load(MODE)) {
      auto len = write(fd, &x, sizeof(x));
      CHECK(len == sizeof(x));
    }
  }
  void put_noflush(qvalue_t value) {
    q.put_noflush(value);
  }
  void flush_writer() {
    q.flush_writer();
    td::int64 x = 1;
    __sync_synchronize();
    if (wait_flag.load(MODE)) {
      auto len = write(fd, &x, sizeof(x));
      CHECK(len == sizeof(x));
    }
  }
  void flush_reader() {
    q.flush_reader();
  }

  qvalue_t get_unsafe_flush() {
    qvalue_t res = q.get_unsafe();
    q.flush_reader();
    return res;
  }

  qvalue_t get_unsafe() {
    return q.get_unsafe();
  }

  int wait_reader() {
    int res = 0;
    Backoff backoff;
    while (res == 0 && backoff.next()) {
      res = q.update_reader();
    }
    if (res != 0) {
      return res;
    }

    td::int64 x;
    wait_flag.store(1, MODE);
    __sync_synchronize();
    while (!(res = q.update_reader())) {
      auto len = read(fd, &x, sizeof(x));
      CHECK(len == sizeof(x));
      __sync_synchronize();
    }
    wait_flag.store(0, MODE);
    return res;
  }

  qvalue_t get() {
    if (!q.reader_empty()) {
      return get_unsafe_flush();
    }

    Backoff backoff;
    while (backoff.next()) {
      if (q.update_reader()) {
        return get_unsafe_flush();
      }
    }

    td::int64 x;
    wait_flag.store(1, MODE);
    __sync_synchronize();
    while (!q.update_reader()) {
      auto len = read(fd, &x, sizeof(x));
      CHECK(len == sizeof(x));
      __sync_synchronize();
    }
    wait_flag.store(0, MODE);
    return get_unsafe_flush();
  }
  void destroy() {
    q.destroy();
    close(fd);
  }
};

class FdQueue {
  int fd;
  std::atomic<int> wait_flag{0};
  VarQueue q;
  char pad[64];

 public:
  void init() {
    q.init();
    fd = eventfd(0, 0);
    (void)pad[0];
  }
  void put(qvalue_t value) {
    q.put(value);
    td::int64 x = 1;
    __sync_synchronize();
    if (wait_flag.load(MODE)) {
      auto len = write(fd, &x, sizeof(x));
      CHECK(len == sizeof(x));
    }
  }
  qvalue_t get() {
    // td::int64 x;
    // auto len = read(fd, &x, sizeof(x));
    // CHECK(len == sizeof(x));
    // return q.get();

    Backoff backoff;
    qvalue_t res = -1;
    do {
      res = q.try_get();
    } while (res == -1 && backoff.next());
    if (res != -1) {
      q.acquire();
      return res;
    }

    td::int64 x;
    wait_flag.store(1, MODE);
    __sync_synchronize();
    // while (res == -1 && read(fd, &x, sizeof(x)) == sizeof(x)) {
    //   res = q.try_get();
    // }
    do {
      __sync_synchronize();
      res = q.try_get();
    } while (res == -1 && read(fd, &x, sizeof(x)) == sizeof(x));
    q.acquire();
    wait_flag.store(0, MODE);
    return res;
  }
  void destroy() {
    q.destroy();
    close(fd);
  }
};
#endif

#if TD_PORT_POSIX
class SemBackoffQueue {
  sem_t sem;
  VarQueue q;

 public:
  void init() {
    q.init();
    sem_init(&sem, 0, 0);
  }

  void put(qvalue_t value) {
    q.put(value);
    sem_post(&sem);
  }

  qvalue_t get() {
    Backoff backoff;
    int sem_flag = -1;
    do {
      sem_flag = sem_trywait(&sem);
    } while (sem_flag != 0 && backoff.next());
    if (sem_flag != 0) {
      sem_wait(&sem);
    }
    return q.get();
  }

  void destroy() {
    q.destroy();
    sem_destroy(&sem);
  }
};

class SemCheatQueue {
  sem_t sem;
  VarQueue q;

 public:
  void init() {
    q.init();
    sem_init(&sem, 0, 0);
  }

  void put(qvalue_t value) {
    q.put(value);
    sem_post(&sem);
  }

  qvalue_t get() {
    Backoff backoff;
    qvalue_t res = -1;
    do {
      res = q.try_get();
    } while (res == -1 && backoff.next());
    sem_wait(&sem);
    if (res != -1) {
      q.acquire();
      return res;
    }
    return q.get();
  }

  void destroy() {
    q.destroy();
    sem_destroy(&sem);
  }
};

template <class QueueT>
class QueueBenchmark2 final : public td::Benchmark {
  QueueT client, server;
  int connections_n, queries_n;

  int server_active_connections;
  int client_active_connections;
  td::vector<td::int64> server_conn;
  td::vector<td::int64> client_conn;

  td::string name;

 public:
  QueueBenchmark2(int connections_n, td::string name) : connections_n(connections_n), name(std::move(name)) {
  }

  td::string get_description() const final {
    return name;
  }

  void start_up() final {
    client.init();
    server.init();
  }

  void tear_down() final {
    client.destroy();
    server.destroy();
  }

  void server_process(qvalue_t value) {
    int no = value & 0x00FFFFFF;
    auto co = static_cast<int>(static_cast<td::uint32>(value) >> 24);
    CHECK(co >= 0 && co < connections_n);
    CHECK(no == server_conn[co]++);

    client.writer_put(value);
    client.writer_flush();
    if (no + 1 >= queries_n) {
      server_active_connections--;
    }
  }

  void *server_run(void *) {
    server_conn = td::vector<td::int64>(connections_n);
    server_active_connections = connections_n;

    while (server_active_connections > 0) {
      int cnt = server.reader_wait();
      CHECK(cnt != 0);
      while (cnt-- > 0) {
        server_process(server.reader_get_unsafe());
        server.reader_flush();
      }
      // client.writer_flush();
      server.reader_flush();
    }
    return nullptr;
  }

  void client_process(qvalue_t value) {
    int no = value & 0x00FFFFFF;
    auto co = static_cast<int>(static_cast<td::uint32>(value) >> 24);
    CHECK(co >= 0 && co < connections_n);
    CHECK(no == client_conn[co]++);
    if (no + 1 < queries_n) {
      server.writer_put(value + 1);
      server.writer_flush();
    } else {
      client_active_connections--;
    }
  }

  void *client_run(void *) {
    client_conn = td::vector<td::int64>(connections_n);
    client_active_connections = connections_n;
    CHECK(queries_n < (1 << 24));

    for (int i = 0; i < connections_n; i++) {
      server.writer_put(static_cast<qvalue_t>(i) << 24);
    }
    server.writer_flush();

    while (client_active_connections > 0) {
      int cnt = client.reader_wait();
      CHECK(cnt != 0);
      while (cnt-- > 0) {
        client_process(client.reader_get_unsafe());
        client.reader_flush();
      }
      // server.writer_flush();
      client.reader_flush();
    }
    // system("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq");
    return nullptr;
  }

  static void *client_run_gateway(void *arg) {
    return static_cast<QueueBenchmark2 *>(arg)->client_run(nullptr);
  }

  static void *server_run_gateway(void *arg) {
    return static_cast<QueueBenchmark2 *>(arg)->server_run(nullptr);
  }

  void run(int n) final {
    pthread_t client_thread_id;
    pthread_t server_thread_id;

    queries_n = (n + connections_n - 1) / connections_n;

    pthread_create(&client_thread_id, nullptr, client_run_gateway, this);
    pthread_create(&server_thread_id, nullptr, server_run_gateway, this);

    pthread_join(client_thread_id, nullptr);
    pthread_join(server_thread_id, nullptr);
  }
};

template <class QueueT>
class QueueBenchmark final : public td::Benchmark {
  QueueT client, server;
  const int connections_n;
  int queries_n;

  td::string name;

 public:
  QueueBenchmark(int connections_n, td::string name) : connections_n(connections_n), name(std::move(name)) {
  }

  td::string get_description() const final {
    return name;
  }

  void start_up() final {
    client.init();
    server.init();
  }

  void tear_down() final {
    client.destroy();
    server.destroy();
  }

  void *server_run(void *) {
    td::vector<td::int64> conn(connections_n);
    int active_connections = connections_n;
    while (active_connections > 0) {
      qvalue_t value = server.get();
      int no = value & 0x00FFFFFF;
      auto co = static_cast<int>(value >> 24);
      CHECK(co >= 0 && co < connections_n);
      CHECK(no == conn[co]++);
      client.put(value);
      if (no + 1 >= queries_n) {
        active_connections--;
      }
    }
    return nullptr;
  }

  void *client_run(void *) {
    td::vector<td::int64> conn(connections_n);
    CHECK(queries_n < (1 << 24));
    for (int i = 0; i < connections_n; i++) {
      server.put(static_cast<qvalue_t>(i) << 24);
    }
    int active_connections = connections_n;
    while (active_connections > 0) {
      qvalue_t value = client.get();
      int no = value & 0x00FFFFFF;
      auto co = static_cast<int>(value >> 24);
      CHECK(co >= 0 && co < connections_n);
      CHECK(no == conn[co]++);
      if (no + 1 < queries_n) {
        server.put(value + 1);
      } else {
        active_connections--;
      }
    }
    // system("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq");
    return nullptr;
  }

  void *client_run2(void *) {
    td::vector<td::int64> conn(connections_n);
    CHECK(queries_n < (1 << 24));
    for (int query = 0; query < queries_n; query++) {
      for (int i = 0; i < connections_n; i++) {
        server.put((static_cast<td::int64>(i) << 24) + query);
      }
      for (int i = 0; i < connections_n; i++) {
        qvalue_t value = client.get();
        int no = value & 0x00FFFFFF;
        auto co = static_cast<int>(value >> 24);
        CHECK(co >= 0 && co < connections_n);
        CHECK(no == conn[co]++);
      }
    }
    // system("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq");
    return nullptr;
  }

  static void *client_run_gateway(void *arg) {
    return static_cast<QueueBenchmark *>(arg)->client_run(nullptr);
  }

  static void *server_run_gateway(void *arg) {
    return static_cast<QueueBenchmark *>(arg)->server_run(nullptr);
  }

  void run(int n) final {
    pthread_t client_thread_id;
    pthread_t server_thread_id;

    queries_n = (n + connections_n - 1) / connections_n;

    pthread_create(&client_thread_id, nullptr, client_run_gateway, this);
    pthread_create(&server_thread_id, nullptr, server_run_gateway, this);

    pthread_join(client_thread_id, nullptr);
    pthread_join(server_thread_id, nullptr);
  }
};

template <class QueueT>
class RingBenchmark final : public td::Benchmark {
  static constexpr int QN = 504;

  struct Thread {
    int int_id;
    pthread_t id;
    QueueT queue;
    Thread *next;
    char pad[64];

    void *run() {
      qvalue_t value;
      do {
        int cnt = queue.reader_wait();
        CHECK(cnt == 1);
        value = queue.reader_get_unsafe();
        queue.reader_flush();

        next->queue.writer_put(value - 1);
        next->queue.writer_flush();
      } while (value >= QN);
      return nullptr;
    }
  };

  Thread q[QN];

 public:
  static void *run_gateway(void *arg) {
    return static_cast<Thread *>(arg)->run();
  }

  void start_up() final {
    for (int i = 0; i < QN; i++) {
      q[i].int_id = i;
      q[i].queue.init();
      q[i].next = &q[(i + 1) % QN];
    }
  }

  void tear_down() final {
    for (int i = 0; i < QN; i++) {
      q[i].queue.destroy();
    }
  }

  void run(int n) final {
    for (int i = 0; i < QN; i++) {
      pthread_create(&q[i].id, nullptr, run_gateway, &q[i]);
    }

    if (n < 1000) {
      n = 1000;
    }
    q[0].queue.writer_put(n);
    q[0].queue.writer_flush();

    for (int i = 0; i < QN; i++) {
      pthread_join(q[i].id, nullptr);
    }
  }
};
#endif

/*
#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
static void test_queue() {
  td::vector<td::thread> threads;
  static constexpr size_t THREAD_COUNT = 100;
  td::vector<td::MpscPollableQueue<int>> queues(THREAD_COUNT);
  for (auto &q : queues) {
    q.init();
  }
  for (size_t i = 0; i < THREAD_COUNT; i++) {
    threads.emplace_back([&q = queues[i]] {
      while (true) {
        auto ready_count = q.reader_wait_nonblock();
        while (ready_count-- > 0) {
          q.reader_get_unsafe();
        }
        q.reader_get_event_fd().wait(1000);
      }
    });
  }

  for (size_t iter = 0; iter < THREAD_COUNT; iter++) {
    td::usleep_for(100);
    for (int i = 0; i < 5; i++) {
      queues[td::Random::fast(0, THREAD_COUNT - 1)].writer_put(1);
    }
  }

  for (size_t i = 0; i < THREAD_COUNT; i++) {
    threads[i].join();
  }
}
#endif
*/

int main() {
#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
  // test_queue();
#endif

#if TD_PORT_POSIX
  // td::bench(RingBenchmark<SemQueue>());
  // td::bench(RingBenchmark<td::PollQueue<qvalue_t>>());

#define BENCH_Q2(Q, N) td::bench(QueueBenchmark2<Q<qvalue_t>>(N, #Q "(" #N ")"))

#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
  BENCH_Q2(td::InfBackoffQueue, 1);
  BENCH_Q2(td::MpscPollableQueue, 1);
  BENCH_Q2(td::PollQueue, 1);

  BENCH_Q2(td::InfBackoffQueue, 10);
  BENCH_Q2(td::MpscPollableQueue, 10);
  BENCH_Q2(td::PollQueue, 10);

  BENCH_Q2(td::InfBackoffQueue, 100);
  BENCH_Q2(td::MpscPollableQueue, 100);
  BENCH_Q2(td::PollQueue, 100);

  BENCH_Q2(td::PollQueue, 4);
  BENCH_Q2(td::PollQueue, 10);
  BENCH_Q2(td::PollQueue, 100);
#endif

#define BENCH_Q(Q, N) td::bench(QueueBenchmark<Q>(N, #Q "(" #N ")"))

#if TD_LINUX
  BENCH_Q(BufferQueue, 1);
  BENCH_Q(BufferedFdQueue, 1);
  BENCH_Q(FdQueue, 1);
#endif
  BENCH_Q(PipeQueue, 1);
  BENCH_Q(SemCheatQueue, 1);
  BENCH_Q(SemQueue, 1);
  BENCH_Q(VarQueue, 1);

#if TD_LINUX
  BENCH_Q(BufferQueue, 4);
  BENCH_Q(BufferQueue, 10);
  BENCH_Q(BufferQueue, 100);
#endif
#endif
}
