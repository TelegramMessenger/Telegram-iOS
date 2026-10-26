#include "bh_read_file.h"

#include <sys/stat.h>
#include <fcntl.h>
#if defined(_WIN32) || defined(_WIN32_)
#include <io.h>
#else
#include <unistd.h>
#endif

#if defined(_WIN32) || defined(_WIN32_)

#if defined(__MINGW32__) && !defined(_SH_DENYNO)
#define _SH_DENYNO 0x40
#endif

char *
bh_read_file_to_buffer(const char *filename, uint32 *ret_size)
{
    char *buffer;
    int file;
    uint32 file_size, buf_size, read_size;
    struct stat stat_buf;

    if (!filename || !ret_size) {
        printf("Read file to buffer failed: invalid filename or ret size.\n");
        return NULL;
    }

    if (_sopen_s(&file, filename, _O_RDONLY | _O_BINARY, _SH_DENYNO, 0)) {
        printf("Read file to buffer failed: open file %s failed.\n", filename);
        return NULL;
    }

    if (fstat(file, &stat_buf) != 0) {
        printf("Read file to buffer failed: fstat file %s failed.\n", filename);
        _close(file);
        return NULL;
    }
    file_size = (uint32)stat_buf.st_size;

    /* At lease alloc 1 byte to avoid malloc failed */
    buf_size = file_size > 0 ? file_size : 1;

    if (!(buffer = (char *)BH_MALLOC(buf_size))) {
        printf("Read file to buffer failed: alloc memory failed.\n");
        _close(file);
        return NULL;
    }
#if WASM_ENABLE_MEMORY_TRACING != 0
    printf("Read file, total size: %u\n", file_size);
#endif

    read_size = _read(file, buffer, file_size);
    _close(file);

    if (read_size < file_size) {
        printf("Read file to buffer failed: read file content failed.\n");
        BH_FREE(buffer);
        return NULL;
    }

    *ret_size = file_size;
    return buffer;
}
#else /* else of defined(_WIN32) || defined(_WIN32_) */
char *
bh_read_file_to_buffer(const char *filename, uint32 *ret_size)
{
    char *buffer;
    int file;
    uint32 file_size, buf_size, read_size;
    struct stat stat_buf;

    if (!filename || !ret_size) {
        printf("Read file to buffer failed: invalid filename or ret size.\n");
        return NULL;
    }

    if ((file = open(filename, O_RDONLY, 0)) == -1) {
        printf("Read file to buffer failed: open file %s failed.\n", filename);
        return NULL;
    }

    if (fstat(file, &stat_buf) != 0) {
        printf("Read file to buffer failed: fstat file %s failed.\n", filename);
        close(file);
        return NULL;
    }

    file_size = (uint32)stat_buf.st_size;

    /* At lease alloc 1 byte to avoid malloc failed */
    buf_size = file_size > 0 ? file_size : 1;

    if (!(buffer = BH_MALLOC(buf_size))) {
        printf("Read file to buffer failed: alloc memory failed.\n");
        close(file);
        return NULL;
    }
#if WASM_ENABLE_MEMORY_TRACING != 0
    printf("Read file, total size: %u\n", file_size);
#endif

    read_size = (uint32)read(file, buffer, file_size);
    close(file);

    if (read_size < file_size) {
        printf("Read file to buffer failed: read file content failed.\n");
        BH_FREE(buffer);
        return NULL;
    }

    *ret_size = file_size;
    return buffer;
}
#endif /* end of defined(_WIN32) || defined(_WIN32_) */
