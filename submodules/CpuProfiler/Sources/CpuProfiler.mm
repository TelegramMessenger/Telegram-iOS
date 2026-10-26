#import <CpuProfiler/CpuProfiler.h>

#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <pthread.h>
#import <unistd.h>

#include <algorithm>
#include <atomic>
#include <map>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace {

// Deep enough for the call stacks that matter here (media pipelines nest ~20 frames)
// without making a single sample expensive.
constexpr int kMaxFrames = 48;

// A merged call tree keeps samples that differ only in their leaf frame together,
// which is what makes the report readable; distinct-stack lists fragment badly.
struct TreeNode {
    int count = 0;
    std::map<uintptr_t, TreeNode> children;
};

struct ThreadRecord {
    uint64_t threadId = 0;
    std::string name;
    uint64_t firstCpuMicroseconds = 0;
    uint64_t lastCpuMicroseconds = 0;
    bool hasFirstCpu = false;
    int sampleCount = 0;
    TreeNode root;
};

/// arm64e signs return addresses stored on the stack. An app built for plain arm64
/// still walks through system frames that were pushed by arm64e code, so the signature
/// bits have to come off before the address means anything. iOS user-space addresses
/// fit comfortably in 40 bits.
inline uintptr_t strippedPointer(uintptr_t value) {
#if __has_feature(ptrauth_calls)
    return (uintptr_t)ptrauth_strip((void *)value, ptrauth_key_return_address);
#else
    return value & 0x000000ffffffffffULL;
#endif
}

#if defined(__arm64__)

/// Reads one thread's stack. The caller must have suspended `thread`, and must resume it
/// before doing anything that allocates.
int walkStack(thread_t thread, uintptr_t stackLow, uintptr_t stackHigh, uintptr_t *frames) {
    arm_thread_state64_t state;
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
    if (thread_get_state(thread, ARM_THREAD_STATE64, (thread_state_t)&state, &stateCount) != KERN_SUCCESS) {
        return 0;
    }

    int count = 0;
    const uintptr_t pc = (uintptr_t)arm_thread_state64_get_pc(state);
    const uintptr_t lr = strippedPointer((uintptr_t)arm_thread_state64_get_lr(state));
    uintptr_t framePointer = (uintptr_t)arm_thread_state64_get_fp(state);

    if (pc != 0) {
        frames[count++] = pc;
    }
    // The leaf's caller is only in lr until the prologue has pushed it.
    if (lr != 0 && lr != pc) {
        frames[count++] = lr;
    }

    while (count < kMaxFrames) {
        if (framePointer < stackLow || framePointer + 2 * sizeof(uintptr_t) > stackHigh) {
            break;
        }
        if ((framePointer & 0x7) != 0) {
            break;
        }
        const uintptr_t nextFramePointer = *(uintptr_t *)framePointer;
        const uintptr_t returnAddress = strippedPointer(*(uintptr_t *)(framePointer + sizeof(uintptr_t)));
        if (returnAddress == 0) {
            break;
        }
        frames[count++] = returnAddress;
        // The chain grows towards the base of the stack; anything else is a corrupt or
        // half-written frame record and walking it further reads garbage.
        if (nextFramePointer <= framePointer) {
            break;
        }
        framePointer = nextFramePointer;
    }

    return count;
}

#endif

NSString *describeAddress(uintptr_t address, std::unordered_set<uintptr_t> &imageBases) {
    Dl_info info;
    if (dladdr((const void *)address, &info) != 0 && info.dli_fname != nullptr) {
        imageBases.insert((uintptr_t)info.dli_fbase);

        const char *lastSlash = strrchr(info.dli_fname, '/');
        const char *imageName = lastSlash != nullptr ? lastSlash + 1 : info.dli_fname;
        const unsigned long imageOffset = (unsigned long)(address - (uintptr_t)info.dli_fbase);

        if (info.dli_sname != nullptr && info.dli_saddr != nullptr) {
            return [NSString stringWithFormat:@"%s+0x%lx  (%s+0x%lx)",
                    imageName,
                    imageOffset,
                    info.dli_sname,
                    (unsigned long)(address - (uintptr_t)info.dli_saddr)];
        }
        return [NSString stringWithFormat:@"%s+0x%lx", imageName, imageOffset];
    }
    return [NSString stringWithFormat:@"0x%lx", (unsigned long)address];
}

NSString * _Nullable uuidStringForImageHeader(const struct mach_header_64 *header) {
    const uint8_t *cursor = (const uint8_t *)header + sizeof(struct mach_header_64);
    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmd == LC_UUID) {
            const struct uuid_command *uuidCommand = (const struct uuid_command *)command;
            const uint8_t *u = uuidCommand->uuid;
            return [NSString stringWithFormat:@"%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
                    u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7],
                    u[8], u[9], u[10], u[11], u[12], u[13], u[14], u[15]];
        }
        if (command->cmdsize == 0) {
            break;
        }
        cursor += command->cmdsize;
    }
    return nil;
}

void appendTree(NSMutableString *output, const TreeNode &node, int depth, int threshold, std::unordered_set<uintptr_t> &imageBases) {
    if (depth > 40) {
        return;
    }

    std::vector<std::pair<uintptr_t, const TreeNode *>> children;
    children.reserve(node.children.size());
    for (const auto &entry : node.children) {
        children.emplace_back(entry.first, &entry.second);
    }
    std::sort(children.begin(), children.end(), [](const auto &lhs, const auto &rhs) {
        return lhs.second->count > rhs.second->count;
    });

    for (const auto &child : children) {
        if (child.second->count < threshold) {
            continue;
        }
        [output appendFormat:@"  %5d  %*s%@\n",
         child.second->count,
         depth * 2, "",
         describeAddress(child.first, imageBases)];
        appendTree(output, *child.second, depth + 1, threshold, imageBases);
    }
}

NSString *runProfile(double duration, double sampleRate) {
    const double interval = 1.0 / std::max(1.0, sampleRate);

    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);

    const uint64_t startAbsolute = mach_absolute_time();
    const uint64_t durationAbsolute = (uint64_t)(duration * 1.0e9 * (double)timebase.denom / (double)timebase.numer);
    const uint64_t endAbsolute = startAbsolute + durationAbsolute;

    const thread_t samplerThread = mach_thread_self();

    std::unordered_map<uint64_t, ThreadRecord> records;
    int totalSamples = 0;
    int suspendFailures = 0;
    uintptr_t frames[kMaxFrames];

    while (mach_absolute_time() < endAbsolute) {
        const uint64_t tickStart = mach_absolute_time();

        thread_act_array_t threads = nullptr;
        mach_msg_type_number_t threadCount = 0;
        if (task_threads(mach_task_self(), &threads, &threadCount) == KERN_SUCCESS) {
            for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
                const thread_t thread = threads[i];
                if (thread == samplerThread) {
                    continue;
                }

                thread_identifier_info_data_t identifierInfo;
                mach_msg_type_number_t identifierCount = THREAD_IDENTIFIER_INFO_COUNT;
                if (thread_info(thread, THREAD_IDENTIFIER_INFO, (thread_info_t)&identifierInfo, &identifierCount) != KERN_SUCCESS) {
                    continue;
                }

                thread_basic_info_data_t basicInfo;
                mach_msg_type_number_t basicCount = THREAD_BASIC_INFO_COUNT;
                if (thread_info(thread, THREAD_BASIC_INFO, (thread_info_t)&basicInfo, &basicCount) != KERN_SUCCESS) {
                    continue;
                }
                if ((basicInfo.flags & TH_FLAGS_IDLE) != 0) {
                    continue;
                }

                const uint64_t cpuMicroseconds =
                    (uint64_t)basicInfo.user_time.seconds * 1000000ull + (uint64_t)basicInfo.user_time.microseconds +
                    (uint64_t)basicInfo.system_time.seconds * 1000000ull + (uint64_t)basicInfo.system_time.microseconds;

                ThreadRecord &record = records[identifierInfo.thread_id];
                record.threadId = identifierInfo.thread_id;
                if (!record.hasFirstCpu) {
                    record.hasFirstCpu = true;
                    record.firstCpuMicroseconds = cpuMicroseconds;
                }
                record.lastCpuMicroseconds = cpuMicroseconds;

                // Only threads the kernel says are on-CPU are worth a stack: this is a CPU
                // profile, and it keeps the number of suspensions per tick to a handful.
                if (basicInfo.run_state != TH_STATE_RUNNING) {
                    continue;
                }

                // The name and stack bounds are read before suspending on purpose.
                // pthread_from_mach_thread_np walks the pthread list under a lock, and
                // taking that lock while the owner is suspended deadlocks.
                const pthread_t handle = pthread_from_mach_thread_np(thread);
                if (handle == nullptr) {
                    continue;
                }
                if (record.name.empty()) {
                    char nameBuffer[64] = {0};
                    if (pthread_getname_np(handle, nameBuffer, sizeof(nameBuffer)) == 0 && nameBuffer[0] != '\0') {
                        record.name = nameBuffer;
                    }
                }
                const uintptr_t stackHigh = (uintptr_t)pthread_get_stackaddr_np(handle);
                const uintptr_t stackLow = stackHigh - pthread_get_stacksize_np(handle);

#if defined(__arm64__)
                if (thread_suspend(thread) != KERN_SUCCESS) {
                    suspendFailures += 1;
                    continue;
                }
                const int frameCount = walkStack(thread, stackLow, stackHigh, frames);
                thread_resume(thread);

                // Everything past this point allocates, so it must not run while suspended.
                if (frameCount > 0) {
                    record.sampleCount += 1;
                    totalSamples += 1;
                    record.root.count += 1;
                    TreeNode *node = &record.root;
                    for (int frameIndex = frameCount - 1; frameIndex >= 0; frameIndex--) {
                        TreeNode &child = node->children[frames[frameIndex]];
                        child.count += 1;
                        node = &child;
                    }
                }
#else
                (void)stackLow;
                (void)stackHigh;
                (void)frames;
#endif
            }

            for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
                mach_port_deallocate(mach_task_self(), threads[i]);
            }
            vm_deallocate(mach_task_self(), (vm_address_t)threads, threadCount * sizeof(thread_t));
        }

        const uint64_t elapsedNanoseconds = (mach_absolute_time() - tickStart) * timebase.numer / timebase.denom;
        const double remaining = interval - (double)elapsedNanoseconds / 1.0e9;
        if (remaining > 0.0) {
            usleep((useconds_t)(remaining * 1.0e6));
        }
    }

    mach_port_deallocate(mach_task_self(), samplerThread);

    const double wallSeconds =
        (double)((mach_absolute_time() - startAbsolute) * timebase.numer / timebase.denom) / 1.0e9;

    std::vector<const ThreadRecord *> sorted;
    sorted.reserve(records.size());
    for (const auto &entry : records) {
        sorted.push_back(&entry.second);
    }
    std::sort(sorted.begin(), sorted.end(), [](const ThreadRecord *lhs, const ThreadRecord *rhs) {
        return (lhs->lastCpuMicroseconds - lhs->firstCpuMicroseconds) > (rhs->lastCpuMicroseconds - rhs->firstCpuMicroseconds);
    });

    std::unordered_set<uintptr_t> imageBases;
    NSMutableString *output = [[NSMutableString alloc] init];

    double totalCpuPercent = 0.0;
    for (const ThreadRecord *record : sorted) {
        totalCpuPercent += (double)(record->lastCpuMicroseconds - record->firstCpuMicroseconds) / 1.0e6 / wallSeconds * 100.0;
    }

    [output appendFormat:@"CPU profile: %.2fs wall, %d samples at %.0f Hz, %d threads, %.1f%% of one core total\n",
     wallSeconds, totalSamples, sampleRate, (int)records.size(), totalCpuPercent];
    [output appendFormat:@"Thermal state: %@, low power mode: %@, processors: %lu active of %lu\n\n",
     @[@"nominal", @"fair", @"serious", @"critical"][std::min<NSInteger>(3, (NSInteger)[[NSProcessInfo processInfo] thermalState])],
     [[NSProcessInfo processInfo] isLowPowerModeEnabled] ? @"yes" : @"no",
     (unsigned long)[[NSProcessInfo processInfo] activeProcessorCount],
     (unsigned long)[[NSProcessInfo processInfo] processorCount]];

    if (suspendFailures > 0) {
        [output appendFormat:@"(%d suspend failures)\n\n", suspendFailures];
    }

    for (const ThreadRecord *record : sorted) {
        const double cpuPercent =
            (double)(record->lastCpuMicroseconds - record->firstCpuMicroseconds) / 1.0e6 / wallSeconds * 100.0;
        if (cpuPercent < 0.5 && record->sampleCount == 0) {
            continue;
        }

        [output appendFormat:@"Thread 0x%llx %@ — %.1f%% cpu, %d samples\n",
         (unsigned long long)record->threadId,
         record->name.empty() ? @"(unnamed)" : [NSString stringWithUTF8String:record->name.c_str()],
         cpuPercent,
         record->sampleCount];

        if (record->sampleCount > 0) {
            // Below 2% of a thread's own samples the tree is noise from unrelated work.
            const int threshold = std::max(2, record->sampleCount / 50);
            appendTree(output, record->root, 0, threshold, imageBases);
        }
        [output appendString:@"\n"];
    }

    [output appendString:@"Binary Images:\n"];
    const uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const struct mach_header *header = _dyld_get_image_header(i);
        if (header == nullptr || imageBases.find((uintptr_t)header) == imageBases.end()) {
            continue;
        }
        const char *path = _dyld_get_image_name(i);
        const char *lastSlash = path != nullptr ? strrchr(path, '/') : nullptr;
        NSString *uuid = uuidStringForImageHeader((const struct mach_header_64 *)header);
        [output appendFormat:@"  0x%lx  %s  <%@>\n",
         (unsigned long)(uintptr_t)header,
         lastSlash != nullptr ? lastSlash + 1 : (path != nullptr ? path : "?"),
         uuid != nil ? uuid : @"?"];
    }

    return output;
}

std::atomic<bool> profilerIsRunning{false};

}  // namespace

@implementation CpuProfiler

+ (BOOL)isRunning {
    return profilerIsRunning.load();
}

+ (void)collectProfileWithDuration:(NSTimeInterval)duration
                        sampleRate:(double)sampleRate
                        completion:(void (^)(NSString * _Nullable))completion {
    bool expected = false;
    if (!profilerIsRunning.compare_exchange_strong(expected, true)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil);
        });
        return;
    }

    // User-interactive so the sampler itself is not the thread that gets descheduled
    // when the device is busy — which is exactly when a profile is being taken.
    dispatch_queue_attr_t attributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
    dispatch_queue_t queue = dispatch_queue_create("org.telegram.CpuProfiler", attributes);
    dispatch_async(queue, ^{
        NSString *report = runProfile(duration, sampleRate);
        profilerIsRunning.store(false);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(report);
        });
    });
}

@end
