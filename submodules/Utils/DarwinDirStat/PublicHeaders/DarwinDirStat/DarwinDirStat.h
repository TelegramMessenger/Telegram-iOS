#ifndef DarwinDirStat_h
#define DarwinDirStat_h

#import <Foundation/Foundation.h>

struct darwin_dirstat {
    off_t total_size;
    uint64_t descendants;
};

int dirstat_np(const char *path, int flags, struct darwin_dirstat *ds, size_t dirstat_size);


#endif
