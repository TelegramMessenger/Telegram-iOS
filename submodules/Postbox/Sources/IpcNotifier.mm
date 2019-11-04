#import <sys/event.h>
#import <sys/stat.h>
#import <sys/time.h>
#import <sys/errno.h>
#import <unistd.h>

#import "IpcNotifier.h"

// Write a byte to a pipe to notify anyone waiting for data on the pipe
static void notifyFd(int fd) {
    while (true) {
        char c = 0;
        ssize_t ret = write(fd, &c, 1);
        if (ret == 1) {
            break;
        }
        
        // If the pipe's buffer is full, we need to read some of the old data in
        // it to make space. We don't just read in the code waiting for
        // notifications so that we can notify multiple waiters with a single
        // write.
        assert(ret == -1 && errno == EAGAIN);
        char buff[1024];
        read(fd, buff, sizeof buff);
    }
}

namespace {
    // A RAII holder for a file descriptor which automatically closes the wrapped fd
    // when it's deallocated
    class FdHolder {
        int fd = -1;
        void close() {
            if (fd != -1) {
                ::close(fd);
            }
            fd = -1;
        }
        
        FdHolder& operator=(FdHolder const&) = delete;
        FdHolder(FdHolder const&) = delete;
        
    public:
        FdHolder() { }
        ~FdHolder() { close(); }
        operator int() const { return fd; }
        
        FdHolder& operator=(int newFd) {
            close();
            fd = newFd;
            return *this;
        }
    };
}

// Inter-thread and inter-process notifications of changes are done using a
// named pipe in the filesystem next to the Realm file. Everyone who wants to be
// notified of commits waits for data to become available on the pipe, and anyone
// who commits a write transaction writes data to the pipe after releasing the
// write lock. Note that no one ever actually *reads* from the pipe: the data
// actually written is meaningless, and trying to read from a pipe from multiple
// processes at once is fraught with race conditions.

// When a RLMRealm instance is created, we add a CFRunLoopSource to the current
// thread's runloop. On each cycle of the run loop, the run loop checks each of
// its sources for work to do, which in the case of CFRunLoopSource is just
// checking if CFRunLoopSourceSignal has been called since the last time it ran,
// and if so invokes the function pointer supplied when the source is created,
// which in our case just invokes `[realm handleExternalChange]`.

// Listening for external changes is done using kqueue() on a background thread.
// kqueue() lets us efficiently wait until the amount of data which can be read
// from one or more file descriptors has changed, and tells us which of the file
// descriptors it was that changed. We use this to wait on both the shared named
// pipe, and a local anonymous pipe. When data is written to the named pipe, we
// signal the runloop source and wake up the target runloop, and when data is
// written to the anonymous pipe the background thread removes the runloop
// source from the runloop and and shuts down.

@implementation RLMNotifier {
    // Realm to notify of changes
    void (^_notify)();
    // Runloop which notifications are delivered on
    CFRunLoopRef _runLoop;
    
    // Read-write file descriptor for the named pipe which is waited on for
    // changes and written to when a commit is made
    FdHolder _notifyFd;
    // File descriptor for the kqueue
    FdHolder _kq;
    // The two ends of an anonymous pipe used to notify the kqueue() thread that
    // it should be shut down.
    FdHolder _shutdownReadFd;
    FdHolder _shutdownWriteFd;
}

- (instancetype)initWithBasePath:(NSString *)basePath notify:( void (^ _Nonnull)())notify {
    self = [super init];
    if (self) {
        _notify = [notify copy];
        
        _kq = kqueue();
        if (_kq == -1) {
            return nil;
        }
        
        const char *path = [basePath stringByAppendingString:@"postbox.note"].UTF8String;
        
        // Create and open the named pipe
        int ret = mkfifo(path, 0600);
        if (ret == -1) {
            int err = errno;
            if (err == ENOTSUP) {
                // Filesystem doesn't support named pipes, so try putting it in tmp instead
                // Hash collisions are okay here because they just result in doing
                // extra work, as opposed to correctness problems
                static NSString *tmpDir = NSTemporaryDirectory();
                path = [tmpDir stringByAppendingFormat:@"poxtbox_%llu.note", (unsigned long long)[basePath hash]].UTF8String;
                ret = mkfifo(path, 0600);
                err = errno;
            }
            // the fifo already existing isn't an error
            if (ret == -1 && err != EEXIST) {
                return nil;
            }
        }
        
        _notifyFd = open(path, O_RDWR);
        if (_notifyFd == -1) {
            return nil;
        }
        
        // Make writing to the pipe return -1 when the pipe's buffer is full
        // rather than blocking until there's space available
        ret = fcntl(_notifyFd, F_SETFL, O_NONBLOCK);
        if (ret == -1) {
            return nil;
        }
        
        // Create the anonymous pipe
        int pipeFd[2];
        ret = pipe(pipeFd);
        if (ret == -1) {
            return nil;
        }
        
        _shutdownReadFd = pipeFd[0];
        _shutdownWriteFd = pipeFd[1];
    }
    return self;
}

- (void)listen {
    // Set up the kqueue
    // EVFILT_READ indicates that we care about data being available to read
    // on the given file descriptor.
    // EV_CLEAR makes it wait for the amount of data available to be read to
    // change rather than just returning when there is any data to read.
    struct kevent ke[2];
    EV_SET(&ke[0], _notifyFd, EVFILT_READ, EV_ADD | EV_CLEAR, 0, 0, 0);
    EV_SET(&ke[1], _shutdownReadFd, EVFILT_READ, EV_ADD | EV_CLEAR, 0, 0, 0);
    int ret = kevent(_kq, ke, 2, nullptr, 0, nullptr);
    assert(ret == 0);
    
    while (true) {
        struct kevent event;
        // Wait for data to become on either fd
        // Return code is number of bytes available or -1 on error
        ret = kevent(_kq, nullptr, 0, &event, 1, nullptr);
        assert(ret >= 0);
        if (ret == 0) {
            // Spurious wakeup; just wait again
            continue;
        }
        
        // Check which file descriptor had activity: if it's the shutdown
        // pipe, then someone called -stop; otherwise it's the named pipe
        // and someone committed a write transaction
        if (event.ident == (uint32_t)_shutdownReadFd) {
            return;
        }
        assert(event.ident == (uint32_t)_notifyFd);
        
        _notify();
    }
}

- (void)stop {
    notifyFd(_shutdownWriteFd);
}

- (void)notifyOtherRealms {
    notifyFd(_notifyFd);
}
@end
