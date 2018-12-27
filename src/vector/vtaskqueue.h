/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the LGPL License, Version 2.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.gnu.org/licenses/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
