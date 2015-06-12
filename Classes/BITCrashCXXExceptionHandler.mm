/*
 * Author: Gwynne Raskind <gwraskin@microsoft.com>
 *
 * Copyright (c) 2015 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "BITCrashCXXExceptionHandler.h"
#import <vector>
#import <cxxabi.h>
#import <exception>
#import <stdexcept>
#import <typeinfo>
#import <string>
#import <pthread.h>
#import <dlfcn.h>
#import <execinfo.h>
#import <libkern/OSAtomic.h>

typedef std::vector<BITCrashUncaughtCXXExceptionHandler> BITCrashUncaughtCXXExceptionHandlerList;

static bool _BITCrashIsOurTerminateHandlerInstalled = false;
static std::terminate_handler _BITCrashOriginalTerminateHandler = nullptr;
static BITCrashUncaughtCXXExceptionHandlerList _BITCrashUncaughtExceptionHandlerList;
static OSSpinLock _BITCrashCXXExceptionHandlingLock = OS_SPINLOCK_INIT;

@implementation BITCrashUncaughtCXXExceptionHandlerManager

__attribute__((always_inline))
static inline void BITCrashIterateExceptionHandlers_unlocked(const BITCrashUncaughtCXXExceptionInfo &info)
{
    for (const auto &handler : _BITCrashUncaughtExceptionHandlerList) {
        handler(&info);
    }
}

static void BITCrashUncaughtCXXTerminateHandler(void)
{
    BITCrashUncaughtCXXExceptionInfo info = {
        .exception = nullptr,
        .exception_type_name = nullptr,
        .exception_message = nullptr,
        .exception_frames_count = 0,
        .exception_frames = nullptr,
    };
    auto p = std::current_exception();
    
    OSSpinLockLock(&_BITCrashCXXExceptionHandlingLock); {
      if (p) { // explicit operator bool
          info.exception = reinterpret_cast<const void *>(&p);
          info.exception_type_name = __cxxabiv1::__cxa_current_exception_type()->name();
        
          void *frames[128] = { nullptr };
        
          info.exception_frames_count = backtrace(&frames[0], sizeof(frames) / sizeof(frames[0])) - 1;
          info.exception_frames = reinterpret_cast<uintptr_t *>(&frames[1]);
        
          try {
              std::rethrow_exception(p);
          } catch (const std::exception &e) { // C++ exception.
              info.exception_message = e.what();
              BITCrashIterateExceptionHandlers_unlocked(info);
          } catch (const std::exception *e) { // C++ exception by pointer.
              info.exception_message = e->what();
              BITCrashIterateExceptionHandlers_unlocked(info);
          } catch (const std::string &e) { // C++ string as exception.
              info.exception_message = e.c_str();
              BITCrashIterateExceptionHandlers_unlocked(info);
          } catch (const std::string *e) { // C++ string pointer as exception.
              info.exception_message = e->c_str();
              BITCrashIterateExceptionHandlers_unlocked(info);
          } catch (const char *e) { // Plain string as exception.
              info.exception_message = e;
              BITCrashIterateExceptionHandlers_unlocked(info);
          } catch (id e) { // Objective-C exception. Pass it on to Foundation.
              OSSpinLockUnlock(&_BITCrashCXXExceptionHandlingLock);
              if (_BITCrashOriginalTerminateHandler != nullptr) {
                  _BITCrashOriginalTerminateHandler();
              }
              return;
          } catch (...) { // Any other kind of exception. No message.
              BITCrashIterateExceptionHandlers_unlocked(info);
          }
      }
    } OSSpinLockUnlock(&_BITCrashCXXExceptionHandlingLock); // In case terminate is called reentrantly by pasing it on
  
    if (_BITCrashOriginalTerminateHandler != nullptr) {
        _BITCrashOriginalTerminateHandler();
    } else {
        abort();
    }
}

+ (void)addCXXExceptionHandler:(BITCrashUncaughtCXXExceptionHandler)handler
{
    OSSpinLockLock(&_BITCrashCXXExceptionHandlingLock); {
        if (!_BITCrashIsOurTerminateHandlerInstalled) {
            _BITCrashOriginalTerminateHandler = std::set_terminate(BITCrashUncaughtCXXTerminateHandler);
            _BITCrashIsOurTerminateHandlerInstalled = true;
        }
        _BITCrashUncaughtExceptionHandlerList.push_back(handler);
    } OSSpinLockUnlock(&_BITCrashCXXExceptionHandlingLock);
}

+ (void)removeCXXExceptionHandler:(BITCrashUncaughtCXXExceptionHandler)handler
{
    OSSpinLockLock(&_BITCrashCXXExceptionHandlingLock); {
        auto i = std::find(_BITCrashUncaughtExceptionHandlerList.begin(), _BITCrashUncaughtExceptionHandlerList.end(), handler);
      
        if (i != _BITCrashUncaughtExceptionHandlerList.end()) {
          _BITCrashUncaughtExceptionHandlerList.erase(i);
        }
    
        if (_BITCrashIsOurTerminateHandlerInstalled) {
            if (_BITCrashUncaughtExceptionHandlerList.empty()) {
                std::terminate_handler previous_handler = std::set_terminate(_BITCrashOriginalTerminateHandler);
                
                if (previous_handler != BITCrashUncaughtCXXTerminateHandler) {
                    std::set_terminate(previous_handler);
                } else {
                    _BITCrashIsOurTerminateHandlerInstalled = false;
                    _BITCrashOriginalTerminateHandler = nullptr;
                }
            }
        }
    } OSSpinLockUnlock(&_BITCrashCXXExceptionHandlingLock);
}

@end
