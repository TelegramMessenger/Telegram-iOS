#ifndef VTASKQUEUE_H
#define VTASKQUEUE_H

#include <deque>

template <typename Task>
class TaskQueue {
    using lock_t = std::unique_lock<std::mutex>;
    std::deque<Task>      _q;
    bool                    _done{false};
    std::mutex              _mutex;
    std::condition_variable _ready;

public:
    bool try_pop(Task &task)
    {
        lock_t lock{_mutex, std::try_to_lock};
        if (!lock || _q.empty()) return false;
        task = std::move(_q.front());
        _q.pop_front();
        return true;
    }

    bool try_push(Task &&task)
    {
        {
            lock_t lock{_mutex, std::try_to_lock};
            if (!lock) return false;
            _q.push_back(std::move(task));
        }
        _ready.notify_one();
        return true;
    }

    void done()
    {
        {
            lock_t lock{_mutex};
            _done = true;
        }
        _ready.notify_all();
    }

    bool pop(Task &task)
    {
        lock_t lock{_mutex};
        while (_q.empty() && !_done) _ready.wait(lock);
        if (_q.empty()) return false;
        task = std::move(_q.front());
        _q.pop_front();
        return true;
    }

    void push(Task &&task)
    {
        {
            lock_t lock{_mutex};
            _q.push_back(std::move(task));
        }
        _ready.notify_one();
    }

};

#endif  // VTASKQUEUE_H
