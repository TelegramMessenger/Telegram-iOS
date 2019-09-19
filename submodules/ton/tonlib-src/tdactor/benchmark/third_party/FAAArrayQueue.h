/******************************************************************************
 * Copyright (c) 2014-2016, Pedro Ramalhete, Andreia Correia
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of Concurrency Freaks nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 ******************************************************************************
 */

#ifndef _FAA_ARRAY_QUEUE_HP_H_
#define _FAA_ARRAY_QUEUE_HP_H_

#include "HazardPointers.h"

#include <atomic>
#include <stdexcept>

namespace ConcurrencyFreaks {
/**
 * <h1> Fetch-And-Add Array Queue </h1>
 *
 * Each node has one array but we don't search for a vacant entry. Instead, we
 * use FAA to obtain an index in the array, for enqueueing or dequeuing.
 *
 * There are some similarities between this queue and the basic queue in YMC:
 * http://chaoran.me/assets/pdf/wfq-ppopp16.pdf
 * but it's not the same because the queue in listing 1 is obstruction-free, while
 * our algorithm is lock-free.
 * In FAAArrayQueue eventually a new node will be inserted (using Michael-Scott's
 * algorithm) and it will have an item pre-filled in the first position, which means
 * that at most, after BUFFER_SIZE steps, one item will be enqueued (and it can then
 * be dequeued). This kind of progress is lock-free.
 *
 * Each entry in the array may contain one of three possible values:
 * - A valid item that has been enqueued;
 * - nullptr, which means no item has yet been enqueued in that position;
 * - taken, a special value that means there was an item but it has been dequeued;
 *
 * Enqueue algorithm: FAA + CAS(null,item)
 * Dequeue algorithm: FAA + CAS(item,taken)
 * Consistency: Linearizable
 * enqueue() progress: lock-free
 * dequeue() progress: lock-free
 * Memory Reclamation: Hazard Pointers (lock-free)
 * Uncontended enqueue: 1 FAA + 1 CAS + 1 HP
 * Uncontended dequeue: 1 FAA + 1 CAS + 1 HP
 *
 *
 * <p>
 * Lock-Free Linked List as described in Maged Michael and Michael Scott's paper:
 * {@link http://www.cs.rochester.edu/~scott/papers/1996_PODC_queues.pdf}
 * <a href="http://www.cs.rochester.edu/~scott/papers/1996_PODC_queues.pdf">
 * Simple, Fast, and Practical Non-Blocking and Blocking Concurrent Queue Algorithms</a>
 * <p>
 * The paper on Hazard Pointers is named "Hazard Pointers: Safe Memory
 * Reclamation for Lock-Free objects" and it is available here:
 * http://web.cecs.pdx.edu/~walpole/class/cs510/papers/11.pdf
 *
 * @author Pedro Ramalhete
 * @author Andreia Correia
 */
template <typename T>
class FAAArrayQueue {
  static const long BUFFER_SIZE = 1024;  // 1024

 private:
  struct Node {
    std::atomic<int> deqidx;
    std::atomic<T*> items[BUFFER_SIZE];
    std::atomic<int> enqidx;
    std::atomic<Node*> next;

    // Start with the first entry pre-filled and enqidx at 1
    Node(T* item) : deqidx{0}, enqidx{1}, next{nullptr} {
      items[0].store(item, std::memory_order_relaxed);
      for (long i = 1; i < BUFFER_SIZE; i++) {
        items[i].store(nullptr, std::memory_order_relaxed);
      }
    }

    bool casNext(Node* cmp, Node* val) {
      return next.compare_exchange_strong(cmp, val);
    }
  };

  bool casTail(Node* cmp, Node* val) {
    return tail.compare_exchange_strong(cmp, val);
  }

  bool casHead(Node* cmp, Node* val) {
    return head.compare_exchange_strong(cmp, val);
  }

  // Pointers to head and tail of the list
  alignas(128) std::atomic<Node*> head;
  alignas(128) std::atomic<Node*> tail;

  static const int MAX_THREADS = 128;
  const int maxThreads;

  T* taken = (T*)new int();  // Muuuahahah !

  // We need just one hazard pointer
  HazardPointers<Node> hp{1, maxThreads};
  const int kHpTail = 0;
  const int kHpHead = 0;

 public:
  FAAArrayQueue(int maxThreads = MAX_THREADS) : maxThreads{maxThreads} {
    Node* sentinelNode = new Node(nullptr);
    sentinelNode->enqidx.store(0, std::memory_order_relaxed);
    head.store(sentinelNode, std::memory_order_relaxed);
    tail.store(sentinelNode, std::memory_order_relaxed);
  }

  ~FAAArrayQueue() {
    while (dequeue(0) != nullptr)
      ;                  // Drain the queue
    delete head.load();  // Delete the last node
    delete (int*)taken;
  }

  std::string className() {
    return "FAAArrayQueue";
  }

  void enqueue(T* item, const int tid) {
    while (true) {
      Node* ltail = hp.protect(kHpTail, tail, tid);
      const int idx = ltail->enqidx.fetch_add(1);
      if (idx > BUFFER_SIZE - 1) {  // This node is full
        if (ltail != tail.load())
          continue;
        Node* lnext = ltail->next.load();
        if (lnext == nullptr) {
          Node* newNode = new Node(item);
          if (ltail->casNext(nullptr, newNode)) {
            casTail(ltail, newNode);
            hp.clear(tid);
            return;
          }
          delete newNode;
        } else {
          casTail(ltail, lnext);
        }
        continue;
      }
      T* itemnull = nullptr;
      if (ltail->items[idx].compare_exchange_strong(itemnull, item)) {
        hp.clear(tid);
        return;
      }
    }
  }

  T* dequeue(const int tid) {
    while (true) {
      Node* lhead = hp.protect(kHpHead, head, tid);
      if (lhead->deqidx.load() >= lhead->enqidx.load() && lhead->next.load() == nullptr)
        break;
      const int idx = lhead->deqidx.fetch_add(1);
      if (idx > BUFFER_SIZE - 1) {  // This node has been drained, check if there is another one
        Node* lnext = lhead->next.load();
        if (lnext == nullptr)
          break;  // No more nodes in the queue
        if (casHead(lhead, lnext))
          hp.retire(lhead, tid);
        continue;
      }
      T* item = lhead->items[idx].exchange(taken);
      if (item == nullptr)
        continue;
      hp.clear(tid);
      return item;
    }
    hp.clear(tid);
    return nullptr;
  }
};
/**
 * <h1> Lazy Index Array Queue </h1>
 *
 * Same as Linear Array Queue but with lazy indexes for both enqueuers and dequeuers.
 *
 * This is a lock-free queue where each node contains an array of items.
 * Each entry in the array may contain on of three possible values:
 * - A valid item that has been enqueued;
 * - nullptr, which means no item has yet been enqueued in that position;
 * - taken, a special value that means there was an item but it has been dequeued;
 * The enqueue() searches for the first nullptr entry in the array and tries
 * to CAS from nullptr to its item.
 * The dequeue() searches for the first valid item in the array and tries to
 * CAS from item to "taken".
 *
 * Enqueue algorithm: Linear array search starting at lazy index with CAS(nullptr,item)
 * Dequeue algorithm: Linear array search starting at lazy index with CAS(item,taken)
 * Consistency: Linearizable
 * enqueue() progress: lock-free
 * dequeue() progress: lock-free
 * Memory Reclamation: Hazard Pointers (lock-free)
 * Uncontended enqueue: 1 CAS + 1 HP
 * Uncontended dequeue: 1 CAS + 1 HP
 *
 *
 * <p>
 * Lock-Free Linked List as described in Maged Michael and Michael Scott's paper:
 * {@link http://www.cs.rochester.edu/~scott/papers/1996_PODC_queues.pdf}
 * <a href="http://www.cs.rochester.edu/~scott/papers/1996_PODC_queues.pdf">
 * Simple, Fast, and Practical Non-Blocking and Blocking Concurrent Queue Algorithms</a>
 * <p>
 * The paper on Hazard Pointers is named "Hazard Pointers: Safe Memory
 * Reclamation for Lock-Free objects" and it is available here:
 * http://web.cecs.pdx.edu/~walpole/class/cs510/papers/11.pdf
 *
 * @author Pedro Ramalhete
 * @author Andreia Correia
 */
template <typename T>
class LazyIndexArrayQueue {
  static const long BUFFER_SIZE = 1024;

 private:
  struct Node {
    std::atomic<int> deqidx;
    std::atomic<T*> items[BUFFER_SIZE];
    std::atomic<int> enqidx;
    std::atomic<Node*> next;

    Node(T* item) : deqidx{0}, enqidx{0}, next{nullptr} {
      items[0].store(item, std::memory_order_relaxed);
      for (int i = 1; i < BUFFER_SIZE; i++) {
        items[i].store(nullptr, std::memory_order_relaxed);
      }
    }

    bool casNext(Node* cmp, Node* val) {
      return next.compare_exchange_strong(cmp, val);
    }
  };

  bool casTail(Node* cmp, Node* val) {
    return tail.compare_exchange_strong(cmp, val);
  }

  bool casHead(Node* cmp, Node* val) {
    return head.compare_exchange_strong(cmp, val);
  }

  // Pointers to head and tail of the list
  alignas(128) std::atomic<Node*> head;
  alignas(128) std::atomic<Node*> tail;

  static const int MAX_THREADS = 128;
  const int maxThreads;

  T* taken = (T*)new int();  // Muuuahahah !

  // We need just one hazard pointer
  HazardPointers<Node> hp{1, maxThreads};
  const int kHpTail = 0;
  const int kHpHead = 0;

 public:
  LazyIndexArrayQueue(int maxThreads = MAX_THREADS) : maxThreads{maxThreads} {
    Node* sentinelNode = new Node(nullptr);
    head.store(sentinelNode, std::memory_order_relaxed);
    tail.store(sentinelNode, std::memory_order_relaxed);
  }

  ~LazyIndexArrayQueue() {
    while (dequeue(0) != nullptr)
      ;                  // Drain the queue
    delete head.load();  // Delete the last node
    delete (int*)taken;
  }

  std::string className() {
    return "LazyIndexArrayQueue";
  }

  void enqueue(T* item, const int tid) {
    while (true) {
      Node* ltail = hp.protect(kHpTail, tail, tid);
      if (ltail->items[BUFFER_SIZE - 1].load() != nullptr) {  // This node is full
        if (ltail != tail.load())
          continue;
        Node* lnext = ltail->next.load();
        if (lnext == nullptr) {
          Node* newNode = new Node(item);
          if (ltail->casNext(nullptr, newNode)) {
            casTail(ltail, newNode);
            hp.clear(tid);
            return;
          }
          delete newNode;
        } else {
          casTail(ltail, lnext);
        }
        continue;
      }
      // Find the first null entry in items[] and try to CAS from null to item
      for (int i = ltail->enqidx.load(); i < BUFFER_SIZE; i++) {
        if (ltail->items[i].load() != nullptr)
          continue;
        T* itemnull = nullptr;
        if (ltail->items[i].compare_exchange_strong(itemnull, item)) {
          ltail->enqidx.store(i + 1, std::memory_order_release);
          hp.clear(tid);
          return;
        }
        if (ltail != tail.load())
          break;
      }
    }
  }

  T* dequeue(const int tid) {
    while (true) {
      Node* lhead = hp.protect(kHpHead, head, tid);
      if (lhead->items[BUFFER_SIZE - 1].load() == taken) {  // This node has been drained, check if there is another one
        Node* lnext = lhead->next.load();
        if (lnext == nullptr) {  // No more nodes in the queue
          hp.clear(tid);
          return nullptr;
        }
        if (casHead(lhead, lnext))
          hp.retire(lhead, tid);
        continue;
      }
      // Find the first non taken entry in items[] and try to CAS from item to taken
      for (int i = lhead->deqidx.load(); i < BUFFER_SIZE; i++) {
        T* item = lhead->items[i].load();
        if (item == nullptr) {
          hp.clear(tid);
          return nullptr;  // This node is empty
        }
        if (item == taken)
          continue;
        if (lhead->items[i].compare_exchange_strong(item, taken)) {
          lhead->deqidx.store(i + 1, std::memory_order_release);
          hp.clear(tid);
          return item;
        }
        if (lhead != head.load())
          break;
      }
    }
  }
};
}  // namespace ConcurrencyFreaks

#endif /* _FAA_ARRAY_QUEUE_HP_H_ */
