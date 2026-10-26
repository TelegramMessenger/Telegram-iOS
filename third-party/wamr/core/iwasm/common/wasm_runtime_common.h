/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _WASM_COMMON_H
#define _WASM_COMMON_H

#include "bh_platform.h"
#include "bh_common.h"
#include "wasm_exec_env.h"
#include "wasm_native.h"
#include "../include/wasm_export.h"
#include "../interpreter/wasm.h"
#if WASM_ENABLE_GC != 0
#include "gc/gc_object.h"
#endif

#if WASM_ENABLE_LIBC_WASI != 0
#if WASM_ENABLE_UVWASI == 0
#include "posix.h"
#else
#include "uvwasi.h"
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Internal use for setting default running mode */
#define Mode_Default 0

#if WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0

#define PUT_I64_TO_ADDR(addr, value)       \
    do {                                   \
        *(int64 *)(addr) = (int64)(value); \
    } while (0)
#define PUT_V128_TO_ADDR(addr, value) \
    do {                              \
        *(V128 *)(addr) = (value);    \
    } while (0)
#define PUT_F64_TO_ADDR(addr, value)           \
    do {                                       \
        *(float64 *)(addr) = (float64)(value); \
    } while (0)
#define PUT_REF_TO_ADDR(addr, value)        \
    do {                                    \
        *(void **)(addr) = (void *)(value); \
    } while (0)

#define GET_I64_FROM_ADDR(addr) (*(int64 *)(addr))
#define GET_F64_FROM_ADDR(addr) (*(float64 *)(addr))
#define GET_REF_FROM_ADDR(addr) (*(void **)(addr))
#define GET_V128_FROM_ADDR(addr) (*(V128 *)(addr))

/* For STORE opcodes */
#define STORE_I64 PUT_I64_TO_ADDR
static inline void
STORE_U32(void *addr, uint32_t value)
{
    *(uint32_t *)(addr) = (uint32_t)(value);
}
static inline void
STORE_U16(void *addr, uint16_t value)
{
    *(uint16_t *)(addr) = (uint16_t)(value);
}
static inline void
STORE_U8(void *addr, uint8_t value)
{
    *(uint8 *)addr = value;
}

static inline void
STORE_V128(void *addr, V128 value)
{
    *(V128 *)addr = value;
}

/* For LOAD opcodes */
#define LOAD_I64(addr) (*(int64 *)(addr))
#define LOAD_F64(addr) (*(float64 *)(addr))
#define LOAD_I32(addr) (*(int32 *)(addr))
#define LOAD_U32(addr) (*(uint32 *)(addr))
#define LOAD_I16(addr) (*(int16 *)(addr))
#define LOAD_U16(addr) (*(uint16 *)(addr))
#define LOAD_V128(addr) (*(V128 *)(addr))

#define STORE_PTR(addr, ptr)          \
    do {                              \
        *(void **)addr = (void *)ptr; \
    } while (0)

#else /* WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0 */

#define PUT_V128_TO_ADDR(addr, value)        \
    do {                                     \
        uint32 *addr_u32 = (uint32 *)(addr); \
        addr_u32[0] = (value).i32x4[0];      \
        addr_u32[1] = (value).i32x4[1];      \
        addr_u32[2] = (value).i32x4[2];      \
        addr_u32[3] = (value).i32x4[3];      \
    } while (0)

#define PUT_I64_TO_ADDR(addr, value)         \
    do {                                     \
        uint32 *addr_u32 = (uint32 *)(addr); \
        union {                              \
            int64 val;                       \
            uint32 parts[2];                 \
        } u;                                 \
        u.val = (int64)(value);              \
        addr_u32[0] = u.parts[0];            \
        addr_u32[1] = u.parts[1];            \
    } while (0)
#define PUT_F64_TO_ADDR(addr, value)         \
    do {                                     \
        uint32 *addr_u32 = (uint32 *)(addr); \
        union {                              \
            float64 val;                     \
            uint32 parts[2];                 \
        } u;                                 \
        u.val = (value);                     \
        addr_u32[0] = u.parts[0];            \
        addr_u32[1] = u.parts[1];            \
    } while (0)
#if UINTPTR_MAX == UINT64_MAX
#define PUT_REF_TO_ADDR(addr, value)         \
    do {                                     \
        uint32 *addr_u32 = (uint32 *)(addr); \
        union {                              \
            void *val;                       \
            uint32 parts[2];                 \
        } u;                                 \
        u.val = (void *)(value);             \
        addr_u32[0] = u.parts[0];            \
        addr_u32[1] = u.parts[1];            \
    } while (0)
#else
#define PUT_REF_TO_ADDR(addr, value)        \
    do {                                    \
        *(void **)(addr) = (void *)(value); \
    } while (0)
#endif

static inline V128
GET_V128_FROM_ADDR(uint32 *addr)
{
    V128 ret;
    ret.i32x4[0] = addr[0];
    ret.i32x4[1] = addr[1];
    ret.i32x4[2] = addr[2];
    ret.i32x4[3] = addr[3];
    return ret;
}

static inline int64
GET_I64_FROM_ADDR(uint32 *addr)
{
    union {
        int64 val;
        uint32 parts[2];
    } u;
    u.parts[0] = addr[0];
    u.parts[1] = addr[1];
    return u.val;
}

static inline float64
GET_F64_FROM_ADDR(uint32 *addr)
{
    union {
        float64 val;
        uint32 parts[2];
    } u;
    u.parts[0] = addr[0];
    u.parts[1] = addr[1];
    return u.val;
}

#if UINTPTR_MAX == UINT64_MAX
static inline void *
GET_REF_FROM_ADDR(uint32 *addr)
{
    union {
        void *val;
        uint32 parts[2];
    } u;
    u.parts[0] = addr[0];
    u.parts[1] = addr[1];
    return u.val;
}
#else
#define GET_REF_FROM_ADDR(addr) (*(void **)(addr))
#endif

/* For STORE opcodes */
#define STORE_I64(addr, value)                      \
    do {                                            \
        uintptr_t addr_ = (uintptr_t)(addr);        \
        union {                                     \
            int64 val;                              \
            uint32 u32[2];                          \
            uint16 u16[4];                          \
            uint8 u8[8];                            \
        } u;                                        \
        if ((addr_ & (uintptr_t)7) == 0)            \
            *(int64 *)(addr) = (int64)(value);      \
        else {                                      \
            u.val = (int64)(value);                 \
            if ((addr_ & (uintptr_t)3) == 0) {      \
                ((uint32 *)(addr))[0] = u.u32[0];   \
                ((uint32 *)(addr))[1] = u.u32[1];   \
            }                                       \
            else if ((addr_ & (uintptr_t)1) == 0) { \
                ((uint16 *)(addr))[0] = u.u16[0];   \
                ((uint16 *)(addr))[1] = u.u16[1];   \
                ((uint16 *)(addr))[2] = u.u16[2];   \
                ((uint16 *)(addr))[3] = u.u16[3];   \
            }                                       \
            else {                                  \
                int32 t;                            \
                for (t = 0; t < 8; t++)             \
                    ((uint8 *)(addr))[t] = u.u8[t]; \
            }                                       \
        }                                           \
    } while (0)

static inline void
STORE_U32(void *addr, uint32_t value)
{
    uintptr_t addr_ = (uintptr_t)(addr);
    union {
        uint32_t val;
        uint16_t u16[2];
        uint8_t u8[4];
    } u;
    if ((addr_ & (uintptr_t)3) == 0)
        *(uint32_t *)(addr) = (uint32_t)(value);
    else {
        u.val = (uint32_t)(value);
        if ((addr_ & (uintptr_t)1) == 0) {
            ((uint16_t *)(addr))[0] = u.u16[0];
            ((uint16_t *)(addr))[1] = u.u16[1];
        }
        else {
            ((uint8_t *)(addr))[0] = u.u8[0];
            ((uint8_t *)(addr))[1] = u.u8[1];
            ((uint8_t *)(addr))[2] = u.u8[2];
            ((uint8_t *)(addr))[3] = u.u8[3];
        }
    }
}

static inline void
STORE_U8(void *addr, uint8_t value)
{
    *(uint8 *)addr = value;
}

static inline void
STORE_U16(void *addr, uint16_t value)
{
    union {
        uint16_t val;
        uint8_t u8[2];
    } u;
    u.val = (uint16_t)(value);
    ((uint8_t *)(addr))[0] = u.u8[0];
    ((uint8_t *)(addr))[1] = u.u8[1];
}

static inline void
STORE_V128(void *addr, V128 value)
{
    uintptr_t addr_ = (uintptr_t)(addr);
    union {
        V128 val;
        uint64 u64[2];
        uint32 u32[4];
        uint16 u16[8];
        uint8 u8[16];
    } u;

    if ((addr_ & (uintptr_t)15) == 0) {
        *(V128 *)addr = value;
    }
    else if ((addr_ & (uintptr_t)7) == 0) {
        u.val = value;
        ((uint64 *)(addr))[0] = u.u64[0];
        ((uint64 *)(addr))[1] = u.u64[1];
    }
    else if ((addr_ & (uintptr_t)3) == 0) {
        u.val = value;
        ((uint32 *)addr)[0] = u.u32[0];
        ((uint32 *)addr)[1] = u.u32[1];
        ((uint32 *)addr)[2] = u.u32[2];
        ((uint32 *)addr)[3] = u.u32[3];
    }
    else if ((addr_ & (uintptr_t)1) == 0) {
        u.val = value;
        ((uint16 *)addr)[0] = u.u16[0];
        ((uint16 *)addr)[1] = u.u16[1];
        ((uint16 *)addr)[2] = u.u16[2];
        ((uint16 *)addr)[3] = u.u16[3];
        ((uint16 *)addr)[4] = u.u16[4];
        ((uint16 *)addr)[5] = u.u16[5];
        ((uint16 *)addr)[6] = u.u16[6];
        ((uint16 *)addr)[7] = u.u16[7];
    }
    else {
        u.val = value;
        for (int i = 0; i < 16; i++)
            ((uint8 *)addr)[i] = u.u8[i];
    }
}

/* For LOAD opcodes */
static inline V128
LOAD_V128(void *addr)
{
    uintptr_t addr1 = (uintptr_t)addr;
    union {
        V128 val;
        uint64 u64[2];
        uint32 u32[4];
        uint16 u16[8];
        uint8 u8[16];
    } u;
    if ((addr1 & (uintptr_t)15) == 0)
        return *(V128 *)addr;

    if ((addr1 & (uintptr_t)7) == 0) {
        u.u64[0] = ((uint64 *)addr)[0];
        u.u64[1] = ((uint64 *)addr)[1];
    }
    else if ((addr1 & (uintptr_t)3) == 0) {
        u.u32[0] = ((uint32 *)addr)[0];
        u.u32[1] = ((uint32 *)addr)[1];
        u.u32[2] = ((uint32 *)addr)[2];
        u.u32[3] = ((uint32 *)addr)[3];
    }
    else if ((addr1 & (uintptr_t)1) == 0) {
        u.u16[0] = ((uint16 *)addr)[0];
        u.u16[1] = ((uint16 *)addr)[1];
        u.u16[2] = ((uint16 *)addr)[2];
        u.u16[3] = ((uint16 *)addr)[3];
        u.u16[4] = ((uint16 *)addr)[4];
        u.u16[5] = ((uint16 *)addr)[5];
        u.u16[6] = ((uint16 *)addr)[6];
        u.u16[7] = ((uint16 *)addr)[7];
    }
    else {
        for (int i = 0; i < 16; i++)
            u.u8[i] = ((uint8 *)addr)[i];
    }
    return u.val;
}

static inline int64
LOAD_I64(void *addr)
{
    uintptr_t addr1 = (uintptr_t)addr;
    union {
        int64 val;
        uint32 u32[2];
        uint16 u16[4];
        uint8 u8[8];
    } u;
    if ((addr1 & (uintptr_t)7) == 0)
        return *(int64 *)addr;

    if ((addr1 & (uintptr_t)3) == 0) {
        u.u32[0] = ((uint32 *)addr)[0];
        u.u32[1] = ((uint32 *)addr)[1];
    }
    else if ((addr1 & (uintptr_t)1) == 0) {
        u.u16[0] = ((uint16 *)addr)[0];
        u.u16[1] = ((uint16 *)addr)[1];
        u.u16[2] = ((uint16 *)addr)[2];
        u.u16[3] = ((uint16 *)addr)[3];
    }
    else {
        int32 t;
        for (t = 0; t < 8; t++)
            u.u8[t] = ((uint8 *)addr)[t];
    }
    return u.val;
}

static inline float64
LOAD_F64(void *addr)
{
    uintptr_t addr1 = (uintptr_t)addr;
    union {
        float64 val;
        uint32 u32[2];
        uint16 u16[4];
        uint8 u8[8];
    } u;
    if ((addr1 & (uintptr_t)7) == 0)
        return *(float64 *)addr;

    if ((addr1 & (uintptr_t)3) == 0) {
        u.u32[0] = ((uint32 *)addr)[0];
        u.u32[1] = ((uint32 *)addr)[1];
    }
    else if ((addr1 & (uintptr_t)1) == 0) {
        u.u16[0] = ((uint16 *)addr)[0];
        u.u16[1] = ((uint16 *)addr)[1];
        u.u16[2] = ((uint16 *)addr)[2];
        u.u16[3] = ((uint16 *)addr)[3];
    }
    else {
        int32 t;
        for (t = 0; t < 8; t++)
            u.u8[t] = ((uint8 *)addr)[t];
    }
    return u.val;
}

static inline int32
LOAD_I32(void *addr)
{
    uintptr_t addr1 = (uintptr_t)addr;
    union {
        int32 val;
        uint16 u16[2];
        uint8 u8[4];
    } u;
    if ((addr1 & (uintptr_t)3) == 0)
        return *(int32 *)addr;

    if ((addr1 & (uintptr_t)1) == 0) {
        u.u16[0] = ((uint16 *)addr)[0];
        u.u16[1] = ((uint16 *)addr)[1];
    }
    else {
        u.u8[0] = ((uint8 *)addr)[0];
        u.u8[1] = ((uint8 *)addr)[1];
        u.u8[2] = ((uint8 *)addr)[2];
        u.u8[3] = ((uint8 *)addr)[3];
    }
    return u.val;
}

static inline int16
LOAD_I16(void *addr)
{
    uintptr_t addr1 = (uintptr_t)addr;
    union {
        int16 val;
        uint8 u8[2];
    } u;
    if ((addr1 & (uintptr_t)1)) {
        u.u8[0] = ((uint8 *)addr)[0];
        u.u8[1] = ((uint8 *)addr)[1];
        return u.val;
    }
    return *(int16 *)addr;
}

#define LOAD_U32(addr) ((uint32)LOAD_I32(addr))
#define LOAD_U16(addr) ((uint16)LOAD_I16(addr))

#if UINTPTR_MAX == UINT32_MAX
#define STORE_PTR(addr, ptr) STORE_U32(addr, (uintptr_t)ptr)
#elif UINTPTR_MAX == UINT64_MAX
#define STORE_PTR(addr, ptr) STORE_I64(addr, (uintptr_t)ptr)
#endif

#endif /* WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS != 0 */

#if WASM_ENABLE_SHARED_MEMORY != 0
#define SHARED_MEMORY_LOCK(memory) shared_memory_lock(memory)
#define SHARED_MEMORY_UNLOCK(memory) shared_memory_unlock(memory)
#else
#define SHARED_MEMORY_LOCK(memory) (void)0
#define SHARED_MEMORY_UNLOCK(memory) (void)0
#endif

#define CLAMP_U64_TO_U32(value) \
    ((value) > UINT32_MAX ? UINT32_MAX : (uint32)(value))

typedef struct WASMModuleCommon {
    /* Module type, for module loaded from WASM bytecode binary,
       this field is Wasm_Module_Bytecode, and this structure should
       be treated as WASMModule structure;
       for module loaded from AOT binary, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModule structure. */
    uint32 module_type;

    /* The following uint8[1] member is a dummy just to indicate
       some module_type dependent members follow.
       Typically, it should be accessed by casting to the corresponding
       actual module_type dependent structure, not via this member. */
    uint8 module_data[1];
} WASMModuleCommon;

typedef struct WASMModuleInstanceCommon {
    /* Module instance type, for module instance loaded from WASM
       bytecode binary, this field is Wasm_Module_Bytecode, and this
       structure should be treated as WASMModuleInstance structure;
       for module instance loaded from AOT binary, this field is
       Wasm_Module_AoT, and this structure should be treated as
       AOTModuleInstance structure. */
    uint32 module_type;

    /* The following uint8[1] member is a dummy just to indicate
       some module_type dependent members follow.
       Typically, it should be accessed by casting to the corresponding
       actual module_type dependent structure, not via this member. */
    uint8 module_inst_data[1];
} WASMModuleInstanceCommon;

typedef struct WASMModuleMemConsumption {
    uint32 total_size;
    uint32 module_struct_size;
    uint32 types_size;
    uint32 imports_size;
    uint32 functions_size;
    uint32 tables_size;
    uint32 memories_size;
    uint32 globals_size;
    uint32 exports_size;
    uint32 table_segs_size;
    uint32 data_segs_size;
    uint32 const_strs_size;
#if WASM_ENABLE_AOT != 0
    uint32 aot_code_size;
#endif
} WASMModuleMemConsumption;

typedef struct WASMModuleInstMemConsumption {
    uint64 total_size;
    uint32 module_inst_struct_size;
    uint32 app_heap_size;
    uint64 memories_size;
    uint32 tables_size;
    uint32 globals_size;
    uint32 functions_size;
    uint32 exports_size;
} WASMModuleInstMemConsumption;

#if WASM_ENABLE_LIBC_WASI != 0
#if WASM_ENABLE_UVWASI == 0
typedef struct WASIContext {
    struct fd_table *curfds;
    struct fd_prestats *prestats;
    struct argv_environ_values *argv_environ;
    struct addr_pool *addr_pool;
    char *ns_lookup_buf;
    char **ns_lookup_list;
    char *argv_buf;
    char **argv_list;
    char *env_buf;
    char **env_list;
    uint32_t exit_code;
} WASIContext;
#else
typedef struct WASIContext {
    uvwasi_t uvwasi;
    uint32_t exit_code;
} WASIContext;
#endif
#endif

#if WASM_ENABLE_MULTI_MODULE != 0
typedef struct WASMRegisteredModule {
    bh_list_link l;
    /* point to a string pool */
    const char *module_name;
    WASMModuleCommon *module;
    /* to store the original module file buffer address */
    uint8 *orig_file_buf;
    uint32 orig_file_buf_size;
} WASMRegisteredModule;
#endif

typedef package_type_t PackageType;
typedef wasm_section_t WASMSection, AOTSection;

#if WASM_ENABLE_JIT != 0
typedef struct LLVMJITOptions {
    uint32 opt_level;
    uint32 size_level;
    uint32 segue_flags;
    bool quick_invoke_c_api_import;
} LLVMJITOptions;
#endif

#ifdef OS_ENABLE_HW_BOUND_CHECK
/* Signal info passing to interp/aot signal handler */
typedef struct WASMSignalInfo {
    WASMExecEnv *exec_env_tls;
#ifndef BH_PLATFORM_WINDOWS
    void *sig_addr;
#else
    EXCEPTION_POINTERS *exce_info;
#endif
} WASMSignalInfo;

/* Set exec_env of thread local storage */
void
wasm_runtime_set_exec_env_tls(WASMExecEnv *exec_env);

/* Get exec_env of thread local storage */
WASMExecEnv *
wasm_runtime_get_exec_env_tls(void);
#endif

struct InstantiationArgs2 {
    InstantiationArgs v1;
};

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_init(void);

/* Internal API */
RunningMode
wasm_runtime_get_default_running_mode(void);

#if WASM_ENABLE_JIT != 0
/* Internal API */
LLVMJITOptions *
wasm_runtime_get_llvm_jit_options(void);
#endif

#if WASM_ENABLE_GC != 0
/* Internal API */
uint32
wasm_runtime_get_gc_heap_size_default(void);
#endif

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_full_init(RuntimeInitArgs *init_args);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_running_mode_supported(RunningMode running_mode);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_set_default_running_mode(RunningMode running_mode);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_destroy(void);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN PackageType
get_package_type(const uint8 *buf, uint32 size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_xip_file(const uint8 *buf, uint32 size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMModuleCommon *
wasm_runtime_load(uint8 *buf, uint32 size, char *error_buf,
                  uint32 error_buf_size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMModuleCommon *
wasm_runtime_load_from_sections(WASMSection *section_list, bool is_aot,
                                char *error_buf, uint32 error_buf_size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_unload(WASMModuleCommon *module);

/* Internal API */
uint32
wasm_runtime_get_max_mem(uint32 max_memory_pages, uint32 module_init_page_count,
                         uint32 module_max_page_count);

/* Internal API */
WASMModuleInstanceCommon *
wasm_runtime_instantiate_internal(WASMModuleCommon *module,
                                  WASMModuleInstanceCommon *parent,
                                  WASMExecEnv *exec_env_main, uint32 stack_size,
                                  uint32 heap_size, uint32 max_memory_pages,
                                  char *error_buf, uint32 error_buf_size);

/* Internal API */
void
wasm_runtime_deinstantiate_internal(WASMModuleInstanceCommon *module_inst,
                                    bool is_sub_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMModuleInstanceCommon *
wasm_runtime_instantiate(WASMModuleCommon *module, uint32 default_stack_size,
                         uint32 host_managed_heap_size, char *error_buf,
                         uint32 error_buf_size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMModuleInstanceCommon *
wasm_runtime_instantiate_ex(WASMModuleCommon *module,
                            const InstantiationArgs *args, char *error_buf,
                            uint32 error_buf_size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN
bool
wasm_runtime_instantiation_args_create(struct InstantiationArgs2 **p);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN
void
wasm_runtime_instantiation_args_destroy(struct InstantiationArgs2 *p);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN
void
wasm_runtime_instantiation_args_set_default_stack_size(
    struct InstantiationArgs2 *p, uint32 v);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN
void
wasm_runtime_instantiation_args_set_host_managed_heap_size(
    struct InstantiationArgs2 *p, uint32 v);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN
void
wasm_runtime_instantiation_args_set_max_memory_pages(
    struct InstantiationArgs2 *p, uint32 v);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMModuleInstanceCommon *
wasm_runtime_instantiate_ex2(WASMModuleCommon *module,
                             const struct InstantiationArgs2 *args,
                             char *error_buf, uint32 error_buf_size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_set_running_mode(wasm_module_inst_t module_inst,
                              RunningMode running_mode);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN RunningMode
wasm_runtime_get_running_mode(wasm_module_inst_t module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_deinstantiate(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMModuleCommon *
wasm_runtime_get_module(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMFunctionInstanceCommon *
wasm_runtime_lookup_function(WASMModuleInstanceCommon *const module_inst,
                             const char *name);

/* Internal API */
WASMFuncType *
wasm_runtime_get_function_type(const WASMFunctionInstanceCommon *function,
                               uint32 module_type);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN uint32
wasm_func_get_param_count(WASMFunctionInstanceCommon *const func_inst,
                          WASMModuleInstanceCommon *const module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN uint32
wasm_func_get_result_count(WASMFunctionInstanceCommon *const func_inst,
                           WASMModuleInstanceCommon *const module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_func_get_param_types(WASMFunctionInstanceCommon *const func_inst,
                          WASMModuleInstanceCommon *const module_inst,
                          wasm_valkind_t *param_types);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_func_get_result_types(WASMFunctionInstanceCommon *const func_inst,
                           WASMModuleInstanceCommon *const module_inst,
                           wasm_valkind_t *result_types);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMExecEnv *
wasm_runtime_create_exec_env(WASMModuleInstanceCommon *module_inst,
                             uint32 stack_size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_destroy_exec_env(WASMExecEnv *exec_env);

#if WASM_ENABLE_COPY_CALL_STACK != 0
WASM_RUNTIME_API_EXTERN uint32_t
wasm_copy_callstack(const wasm_exec_env_t exec_env, WASMCApiFrame *buffer,
                    const uint32 length, const uint32 skip_n, char *error_buf,
                    uint32 error_buf_size);
#endif // WASM_ENABLE_COPY_CALL_STACK

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMModuleInstanceCommon *
wasm_runtime_get_module_inst(WASMExecEnv *exec_env);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_module_inst(WASMExecEnv *exec_env,
                             WASMModuleInstanceCommon *const module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_get_function_attachment(WASMExecEnv *exec_env);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_user_data(WASMExecEnv *exec_env, void *user_data);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_get_user_data(WASMExecEnv *exec_env);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_native_stack_boundary(WASMExecEnv *exec_env,
                                       uint8 *native_stack_boundary);

#if WASM_ENABLE_INSTRUCTION_METERING != 0
/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_instruction_count_limit(WASMExecEnv *exec_env,
                                         int instructions_to_execute);
#endif

#if WASM_CONFIGURABLE_BOUNDS_CHECKS != 0
/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN
void
wasm_runtime_set_bounds_checks(WASMModuleInstanceCommon *module_inst,
                               bool enable);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_bounds_checks_enabled(WASMModuleInstanceCommon *module_inst);
#endif

#ifdef OS_ENABLE_HW_BOUND_CHECK
/* Access exception check guard page to trigger the signal handler */
void
wasm_runtime_access_exce_check_guard_page();
#endif

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_call_wasm(WASMExecEnv *exec_env,
                       WASMFunctionInstanceCommon *function, uint32 argc,
                       uint32 argv[]);

WASM_RUNTIME_API_EXTERN bool
wasm_runtime_call_wasm_a(WASMExecEnv *exec_env,
                         WASMFunctionInstanceCommon *function,
                         uint32 num_results, wasm_val_t *results,
                         uint32 num_args, wasm_val_t *args);

WASM_RUNTIME_API_EXTERN bool
wasm_runtime_call_wasm_v(WASMExecEnv *exec_env,
                         WASMFunctionInstanceCommon *function,
                         uint32 num_results, wasm_val_t *results,
                         uint32 num_args, ...);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_call_indirect(WASMExecEnv *exec_env, uint32 element_index,
                           uint32 argc, uint32 argv[]);

#if WASM_ENABLE_DEBUG_INTERP != 0
/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN uint32
wasm_runtime_start_debug_instance_with_port(WASMExecEnv *exec_env,
                                            int32_t port);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN uint32
wasm_runtime_start_debug_instance(WASMExecEnv *exec_env);
#endif

bool
wasm_runtime_create_exec_env_singleton(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMExecEnv *
wasm_runtime_get_exec_env_singleton(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_application_execute_main(WASMModuleInstanceCommon *module_inst, int32 argc,
                              char *argv[]);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_application_execute_func(WASMModuleInstanceCommon *module_inst,
                              const char *name, int32 argc, char *argv[]);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_exception(WASMModuleInstanceCommon *module,
                           const char *exception);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN const char *
wasm_runtime_get_exception(WASMModuleInstanceCommon *module);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_clear_exception(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_terminate(WASMModuleInstanceCommon *module);

/* Internal API */
void
wasm_runtime_set_custom_data_internal(WASMModuleInstanceCommon *module_inst,
                                      void *custom_data);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_custom_data(WASMModuleInstanceCommon *module_inst,
                             void *custom_data);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_get_custom_data(WASMModuleInstanceCommon *module_inst);

/* Internal API */
uint64
wasm_runtime_module_malloc_internal(WASMModuleInstanceCommon *module_inst,
                                    WASMExecEnv *exec_env, uint64 size,
                                    void **p_native_addr);

/* Internal API */
uint64
wasm_runtime_module_realloc_internal(WASMModuleInstanceCommon *module_inst,
                                     WASMExecEnv *exec_env, uint64 ptr,
                                     uint64 size, void **p_native_addr);

/* Internal API */
void
wasm_runtime_module_free_internal(WASMModuleInstanceCommon *module_inst,
                                  WASMExecEnv *exec_env, uint64 ptr);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN uint64
wasm_runtime_module_malloc(WASMModuleInstanceCommon *module_inst, uint64 size,
                           void **p_native_addr);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_module_free(WASMModuleInstanceCommon *module_inst, uint64 ptr);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN uint64
wasm_runtime_module_dup_data(WASMModuleInstanceCommon *module_inst,
                             const char *src, uint64 size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_validate_app_addr(WASMModuleInstanceCommon *module_inst,
                               uint64 app_offset, uint64 size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_validate_app_str_addr(WASMModuleInstanceCommon *module_inst,
                                   uint64 app_str_offset);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_validate_native_addr(WASMModuleInstanceCommon *module_inst,
                                  void *native_ptr, uint64 size);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_addr_app_to_native(WASMModuleInstanceCommon *module_inst,
                                uint64 app_offset);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN uint64
wasm_runtime_addr_native_to_app(WASMModuleInstanceCommon *module_inst,
                                void *native_ptr);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_get_app_addr_range(WASMModuleInstanceCommon *module_inst,
                                uint64 app_offset, uint64 *p_app_start_offset,
                                uint64 *p_app_end_offset);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_get_native_addr_range(WASMModuleInstanceCommon *module_inst,
                                   uint8 *native_ptr,
                                   uint8 **p_native_start_addr,
                                   uint8 **p_native_end_addr);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN const uint8 *
wasm_runtime_get_custom_section(WASMModuleCommon *const module_comm,
                                const char *name, uint32 *len);

#if WASM_ENABLE_MULTI_MODULE != 0
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_module_reader(const module_reader reader,
                               const module_destroyer destroyer);

module_reader
wasm_runtime_get_module_reader(void);

module_destroyer
wasm_runtime_get_module_destroyer(void);

bool
wasm_runtime_register_module_internal(const char *module_name,
                                      WASMModuleCommon *module,
                                      uint8 *orig_file_buf,
                                      uint32 orig_file_buf_size,
                                      char *error_buf, uint32 error_buf_size);

void
wasm_runtime_unregister_module(const WASMModuleCommon *module);

WASMModuleCommon *
wasm_runtime_find_module_registered(const char *module_name);

bool
wasm_runtime_add_loading_module(const char *module_name, char *error_buf,
                                uint32 error_buf_size);

void
wasm_runtime_delete_loading_module(const char *module_name);

bool
wasm_runtime_is_loading_module(const char *module_name);

void
wasm_runtime_destroy_loading_module_list(void);

WASMModuleCommon *
wasm_runtime_search_sub_module(const WASMModuleCommon *parent_module,
                               const char *sub_module_name);

bool
wasm_runtime_register_sub_module(const WASMModuleCommon *parent_module,
                                 const char *sub_module_name,
                                 WASMModuleCommon *sub_module);

WASMModuleCommon *
wasm_runtime_load_depended_module(const WASMModuleCommon *parent_module,
                                  const char *sub_module_name, char *error_buf,
                                  uint32 error_buf_size);

bool
wasm_runtime_sub_module_instantiate(WASMModuleCommon *module,
                                    WASMModuleInstanceCommon *module_inst,
                                    uint32 stack_size, uint32 heap_size,
                                    uint32 max_memory_pages, char *error_buf,
                                    uint32 error_buf_size);
void
wasm_runtime_sub_module_deinstantiate(WASMModuleInstanceCommon *module_inst);
#endif

#if WASM_ENABLE_LIBC_WASI != 0 || WASM_ENABLE_MULTI_MODULE != 0
WASMExport *
loader_find_export(const WASMModuleCommon *module, const char *module_name,
                   const char *field_name, uint8 export_kind, char *error_buf,
                   uint32 error_buf_size);
#endif /* WASM_ENABLE_MULTI_MODULE */

bool
wasm_runtime_is_built_in_module(const char *module_name);

#if WASM_ENABLE_THREAD_MGR != 0
bool
wasm_exec_env_get_aux_stack(WASMExecEnv *exec_env, uint64 *start_offset,
                            uint32 *size);

bool
wasm_exec_env_set_aux_stack(WASMExecEnv *exec_env, uint64 start_offset,
                            uint32 size);
#endif

#if WASM_ENABLE_LIBC_WASI != 0
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_wasi_args_ex(WASMModuleCommon *module, const char *dir_list[],
                              uint32 dir_count, const char *map_dir_list[],
                              uint32 map_dir_count, const char *env_list[],
                              uint32 env_count, char *argv[], int argc,
                              int64 stdinfd, int64 stdoutfd, int64 stderrfd);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_wasi_args(WASMModuleCommon *module, const char *dir_list[],
                           uint32 dir_count, const char *map_dir_list[],
                           uint32 map_dir_count, const char *env_list[],
                           uint32 env_count, char *argv[], int argc);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_wasi_mode(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN WASMFunctionInstanceCommon *
wasm_runtime_lookup_wasi_start_function(WASMModuleInstanceCommon *module_inst);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN uint32_t
wasm_runtime_get_wasi_exit_code(WASMModuleInstanceCommon *module_inst);

bool
wasm_runtime_init_wasi(WASMModuleInstanceCommon *module_inst,
                       const char *dir_list[], uint32 dir_count,
                       const char *map_dir_list[], uint32 map_dir_count,
                       const char *env[], uint32 env_count,
                       const char *addr_pool[], uint32 addr_pool_size,
                       const char *ns_lookup_pool[], uint32 ns_lookup_pool_size,
                       char *argv[], uint32 argc, os_raw_file_handle stdinfd,
                       os_raw_file_handle stdoutfd, os_raw_file_handle stderrfd,
                       char *error_buf, uint32 error_buf_size);

void
wasm_runtime_destroy_wasi(WASMModuleInstanceCommon *module_inst);

void
wasm_runtime_set_wasi_ctx(WASMModuleInstanceCommon *module_inst,
                          WASIContext *wasi_ctx);

WASIContext *
wasm_runtime_get_wasi_ctx(WASMModuleInstanceCommon *module_inst);

WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_wasi_addr_pool(wasm_module_t module, const char *addr_pool[],
                                uint32 addr_pool_size);

WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_wasi_ns_lookup_pool(wasm_module_t module,
                                     const char *ns_lookup_pool[],
                                     uint32 ns_lookup_pool_size);
#endif /* end of WASM_ENABLE_LIBC_WASI */

#if WASM_ENABLE_GC != 0
void
wasm_runtime_set_gc_heap_handle(WASMModuleInstanceCommon *module_inst,
                                void *gc_heap_handle);

void *
wasm_runtime_get_gc_heap_handle(WASMModuleInstanceCommon *module_inst);
#endif

#if WASM_ENABLE_REF_TYPES != 0
/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_externref_obj2ref(WASMModuleInstanceCommon *module_inst, void *extern_obj,
                       uint32 *p_externref_idx);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_externref_ref2obj(uint32 externref_idx, void **p_extern_obj);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_externref_retain(uint32 externref_idx);

/**
 * Reclaim the externref objects/indexes which are not used by
 * module instance
 */
void
wasm_externref_reclaim(WASMModuleInstanceCommon *module_inst);

/**
 * Cleanup the externref objects/indexes of the module instance
 */
void
wasm_externref_cleanup(WASMModuleInstanceCommon *module_inst);
#endif /* end of WASM_ENABLE_REF_TYPES */

#if WASM_ENABLE_DUMP_CALL_STACK != 0
/**
 * @brief Internal implementation for dumping or printing callstack line
 *
 * @note if dump_or_print is true, then print to stdout directly;
 * if dump_or_print is false, but *buf is NULL, then return the length of the
 * line;
 * if dump_or_print is false, and *buf is not NULL, then dump content to
 * the memory pointed by *buf, and adjust *buf and *len according to actual
 * bytes dumped, and return the actual dumped length
 *
 * @param line_buf current line to dump or print
 * @param dump_or_print whether to print to stdout or dump to buf
 * @param buf [INOUT] pointer to the buffer
 * @param len [INOUT] pointer to remaining length
 * @return bytes printed to stdout or dumped to buf
 */
uint32
wasm_runtime_dump_line_buf_impl(const char *line_buf, bool dump_or_print,
                                char **buf, uint32 *len);
#endif /* end of WASM_ENABLE_DUMP_CALL_STACK != 0 */

/* Get module of the current exec_env */
WASMModuleCommon *
wasm_exec_env_get_module(WASMExecEnv *exec_env);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_register_natives(const char *module_name,
                              NativeSymbol *native_symbols,
                              uint32 n_native_symbols);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_register_natives_raw(const char *module_name,
                                  NativeSymbol *native_symbols,
                                  uint32 n_native_symbols);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN bool
wasm_runtime_unregister_natives(const char *module_name,
                                NativeSymbol *native_symbols);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_create_context_key(void (*dtor)(WASMModuleInstanceCommon *inst,
                                             void *ctx));

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_destroy_context_key(void *key);

/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_context(WASMModuleInstanceCommon *inst, void *key, void *ctx);
/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void
wasm_runtime_set_context_spread(WASMModuleInstanceCommon *inst, void *key,
                                void *ctx);
/* See wasm_export.h for description */
WASM_RUNTIME_API_EXTERN void *
wasm_runtime_get_context(WASMModuleInstanceCommon *inst, void *key);

bool
wasm_runtime_invoke_native(WASMExecEnv *exec_env, void *func_ptr,
                           const WASMFuncType *func_type, const char *signature,
                           void *attachment, uint32 *argv, uint32 argc,
                           uint32 *ret);

bool
wasm_runtime_invoke_native_raw(WASMExecEnv *exec_env, void *func_ptr,
                               const WASMFuncType *func_type,
                               const char *signature, void *attachment,
                               uint32 *argv, uint32 argc, uint32 *ret);

void
wasm_runtime_read_v128(const uint8 *bytes, uint64 *ret1, uint64 *ret2);

void
wasm_runtime_dump_module_mem_consumption(const WASMModuleCommon *module);

void
wasm_runtime_dump_module_inst_mem_consumption(
    const WASMModuleInstanceCommon *module_inst);

void
wasm_runtime_dump_exec_env_mem_consumption(const WASMExecEnv *exec_env);

bool
wasm_runtime_get_table_elem_type(const WASMModuleCommon *module_comm,
                                 uint32 table_idx, uint8 *out_elem_type,
#if WASM_ENABLE_GC != 0
                                 WASMRefType **out_ref_type,
#endif
                                 uint32 *out_min_size, uint32 *out_max_size);

bool
wasm_runtime_get_table_inst_elem_type(
    const WASMModuleInstanceCommon *module_inst_comm, uint32 table_idx,
    uint8 *out_elem_type,
#if WASM_ENABLE_GC != 0
    WASMRefType **out_ref_type,
#endif
    uint32 *out_min_size, uint32 *out_max_size);

bool
wasm_runtime_get_export_func_type(const WASMModuleCommon *module_comm,
                                  const WASMExport *export_,
                                  WASMFuncType **out);

bool
wasm_runtime_get_export_global_type(const WASMModuleCommon *module_comm,
                                    const WASMExport *export_,
                                    uint8 *out_val_type, bool *out_mutability);

bool
wasm_runtime_get_export_memory_type(const WASMModuleCommon *module_comm,
                                    const WASMExport *export_,
                                    uint32 *out_min_page, uint32 *out_max_page);

bool
wasm_runtime_get_export_table_type(const WASMModuleCommon *module_comm,
                                   const WASMExport *export_,
                                   uint8 *out_elem_type,
#if WASM_ENABLE_GC != 0
                                   WASMRefType **out_ref_type,
#endif
                                   uint32 *out_min_size, uint32 *out_max_size);

bool
wasm_runtime_invoke_c_api_native(WASMModuleInstanceCommon *module_inst,
                                 void *func_ptr, WASMFuncType *func_type,
                                 uint32 argc, uint32 *argv, bool with_env,
                                 void *wasm_c_api_env);

struct CApiFuncImport;
/* A quick version of wasm_runtime_invoke_c_api_native to directly invoke
   wasm-c-api import function from jitted code to improve performance */
bool
wasm_runtime_quick_invoke_c_api_native(WASMModuleInstanceCommon *module_inst,
                                       struct CApiFuncImport *c_api_import,
                                       wasm_val_t *params, uint32 param_count,
                                       wasm_val_t *results,
                                       uint32 result_count);

void
wasm_runtime_show_app_heap_corrupted_prompt(void);

#if WASM_ENABLE_LOAD_CUSTOM_SECTION != 0
void
wasm_runtime_destroy_custom_sections(WASMCustomSection *section_list);
#endif

WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_import_func_linked(const char *module_name,
                                   const char *func_name);

WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_import_global_linked(const char *module_name,
                                     const char *global_name);

WASM_RUNTIME_API_EXTERN bool
wasm_runtime_begin_blocking_op(WASMExecEnv *exec_env);

WASM_RUNTIME_API_EXTERN void
wasm_runtime_end_blocking_op(WASMExecEnv *exec_env);

void
wasm_runtime_interrupt_blocking_op(WASMExecEnv *exec_env);

WASM_RUNTIME_API_EXTERN bool
wasm_runtime_detect_native_stack_overflow(WASMExecEnv *exec_env);

WASM_RUNTIME_API_EXTERN bool
wasm_runtime_detect_native_stack_overflow_size(WASMExecEnv *exec_env,
                                               uint32 requested_size);

WASM_RUNTIME_API_EXTERN bool
wasm_runtime_is_underlying_binary_freeable(WASMModuleCommon *const module);

#if WASM_ENABLE_LINUX_PERF != 0
bool
wasm_runtime_get_linux_perf(void);

void
wasm_runtime_set_linux_perf(bool flag);
#endif

#if WASM_ENABLE_SHARED_HEAP != 0
bool
wasm_runtime_check_and_update_last_used_shared_heap(
    WASMModuleInstanceCommon *module_inst, uintptr_t app_offset, size_t bytes,
    uintptr_t *shared_heap_start_off_p, uintptr_t *shared_heap_end_off_p,
    uint8 **shared_heap_base_addr_adj_p, bool is_memory64);
#endif

#ifdef __cplusplus
}
#endif

#endif /* end of _WASM_COMMON_H */
