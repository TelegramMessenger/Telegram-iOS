// WebAssembly C API

/**
 * @file   wasm_c_api.h
 *
 * @brief  This file defines the WebAssembly C APIs
 */

#ifndef _WASM_C_API_H_
#define _WASM_C_API_H_

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <assert.h>

#ifndef WASM_API_EXTERN
#if defined(_MSC_BUILD)
#if defined(COMPILING_WASM_RUNTIME_API)
#define WASM_API_EXTERN __declspec(dllexport)
#else
#define WASM_API_EXTERN __declspec(dllimport)
#endif
#else
#define WASM_API_EXTERN
#endif
#endif

#if defined(__GNUC__) || defined(__clang__)
#define WASM_API_DEPRECATED __attribute__((deprecated))
#elif defined(_MSC_VER)
#define WASM_API_DEPRECATED __declspec(deprecated)
#else
#pragma message("WARNING: You need to implement DEPRECATED for this compiler")
#define WASM_API_DEPRECATED
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* clang-format off */

///////////////////////////////////////////////////////////////////////////////
// Auxiliaries

// Machine types
#if defined(__STDC_VERSION__) && (__STDC_VERSION__) > 199901L
inline void assertions(void) {
  static_assert(sizeof(float) == sizeof(uint32_t), "incompatible float type");
  static_assert(sizeof(double) == sizeof(uint64_t), "incompatible double type");
  static_assert(sizeof(intptr_t) == sizeof(uint32_t) ||
                sizeof(intptr_t) == sizeof(uint64_t),
                "incompatible pointer type");
}
#endif

typedef char byte_t;
typedef float float32_t;
typedef double float64_t;


// Ownership

#define own

// The qualifier `own` is used to indicate ownership of data in this API.
// It is intended to be interpreted similar to a `const` qualifier:
//
// - `own wasm_xxx_t*` owns the pointed-to data
// - `own wasm_xxx_t` distributes to all fields of a struct or union `xxx`
// - `own wasm_xxx_vec_t` owns the vector as well as its elements(!)
// - an `own` function parameter passes ownership from caller to callee
// - an `own` function result passes ownership from callee to caller
// - an exception are `own` pointer parameters named `out`, which are copy-back
//   output parameters passing back ownership from callee to caller
//
// Own data is created by `wasm_xxx_new` functions and some others.
// It must be released with the corresponding `wasm_xxx_delete` function.
//
// Deleting a reference does not necessarily delete the underlying object,
// it merely indicates that this owner no longer uses it.
//
// For vectors, `const wasm_xxx_vec_t` is used informally to indicate that
// neither the vector nor its elements should be modified.
// TODO: introduce proper `wasm_xxx_const_vec_t`?


#define WASM_DECLARE_OWN(name) \
  typedef struct wasm_##name##_t wasm_##name##_t; \
  \
  WASM_API_EXTERN void wasm_##name##_delete(own wasm_##name##_t*);


// Vectors
// size: capacity
// num_elems: current number of elements
// size_of_elem: size of one element
#define WASM_DECLARE_VEC(name, ptr_or_none) \
  typedef struct wasm_##name##_vec_t { \
    size_t size; \
    wasm_##name##_t ptr_or_none* data; \
    size_t num_elems; \
    size_t size_of_elem; \
    void *lock; \
  } wasm_##name##_vec_t; \
  \
  WASM_API_EXTERN void wasm_##name##_vec_new_empty(own wasm_##name##_vec_t* out); \
  WASM_API_EXTERN void wasm_##name##_vec_new_uninitialized( \
    own wasm_##name##_vec_t* out, size_t); \
  WASM_API_EXTERN void wasm_##name##_vec_new( \
    own wasm_##name##_vec_t* out, \
    size_t, own wasm_##name##_t ptr_or_none const[]); \
  WASM_API_EXTERN void wasm_##name##_vec_copy( \
    own wasm_##name##_vec_t* out, const wasm_##name##_vec_t*); \
  WASM_API_EXTERN void wasm_##name##_vec_delete(own wasm_##name##_vec_t*);


// Byte vectors

typedef byte_t wasm_byte_t;
WASM_DECLARE_VEC(byte, )

typedef wasm_byte_vec_t wasm_name_t;

#define wasm_name wasm_byte_vec
#define wasm_name_new wasm_byte_vec_new
#define wasm_name_new_empty wasm_byte_vec_new_empty
#define wasm_name_new_new_uninitialized wasm_byte_vec_new_uninitialized
#define wasm_name_copy wasm_byte_vec_copy
#define wasm_name_delete wasm_byte_vec_delete

static inline void wasm_name_new_from_string(
  own wasm_name_t* out, const char* s
) {
  wasm_name_new(out, strlen(s), s);
}

static inline void wasm_name_new_from_string_nt(
  own wasm_name_t* out, const char* s
) {
  wasm_name_new(out, strlen(s) + 1, s);
}


///////////////////////////////////////////////////////////////////////////////
// Runtime Environment

// Configuration

WASM_DECLARE_OWN(config)

#ifndef MEM_ALLOC_OPTION_DEFINED
#define MEM_ALLOC_OPTION_DEFINED
/* same definition from wasm_export.h */
/* Memory allocator type */
typedef enum {
    /* pool mode, allocate memory from user defined heap buffer */
    Alloc_With_Pool = 0,
    /* user allocator mode, allocate memory from user defined
       malloc function */
    Alloc_With_Allocator,
    /* system allocator mode, allocate memory from system allocator,
       or, platform's os_malloc function */
    Alloc_With_System_Allocator,
} mem_alloc_type_t;

/* Memory allocator option */
typedef union MemAllocOption {
    struct {
        void *heap_buf;
        uint32_t heap_size;
    } pool;
    struct {
        void *malloc_func;
        void *realloc_func;
        void *free_func;
        /* allocator user data, only used when
          WASM_MEM_ALLOC_WITH_USER_DATA is defined */
        void *user_data;
    } allocator;
} MemAllocOption;
#endif /* MEM_ALLOC_OPTION_DEFINED */

/* Runtime configuration */
struct wasm_config_t {
    mem_alloc_type_t mem_alloc_type;
    MemAllocOption mem_alloc_option;
    uint32_t segue_flags;
    bool enable_linux_perf;
    /*TODO: wasi args*/
};

#ifndef INSTANTIATION_ARGS_OPTION_DEFINED
#define INSTANTIATION_ARGS_OPTION_DEFINED
/* WASM module instantiation arguments */
typedef struct InstantiationArgs {
    uint32_t default_stack_size;
    uint32_t host_managed_heap_size;
    uint32_t max_memory_pages;
} InstantiationArgs;
#endif /* INSTANTIATION_ARGS_OPTION_DEFINED */

/*
 * by default:
 * - mem_alloc_type is Alloc_With_System_Allocator
 * - mem_alloc_option is all 0
 * - enable_linux_perf is false
 */
WASM_API_EXTERN own wasm_config_t* wasm_config_new(void);

// Embedders may provide custom functions for manipulating configs.
WASM_API_EXTERN own wasm_config_t*
wasm_config_set_mem_alloc_opt(wasm_config_t *, mem_alloc_type_t, MemAllocOption *);

WASM_API_EXTERN own wasm_config_t*
wasm_config_set_linux_perf_opt(wasm_config_t *, bool);

/**
 * Enable using GS register as the base address of linear memory in linux x86_64,
 * which may speedup the linear memory access for LLVM AOT/JIT:
 *   bit0 to bit4 denotes i32.load, i64.load, f32.load, f64.load, v128.load
 *   bit8 to bit12 denotes i32.store, i64.store, f32.store, f64.store, v128.store
 * For example, 0x01 enables i32.load, 0x0100 enables i32.store.
 * To enable all load/store operations, use 0x1F1F
 */
WASM_API_EXTERN wasm_config_t*
wasm_config_set_segue_flags(wasm_config_t *config, uint32_t segue_flags);

// Engine

WASM_DECLARE_OWN(engine)

/**
 * Create a new engine
 *
 * Note: for the engine new/delete operations, including this,
 * wasm_engine_new_with_config, wasm_engine_new_with_args, and
 * wasm_engine_delete, if the platform has mutex initializer,
 * then they are thread-safe: we use a global lock to lock the
 * operations of the engine. Otherwise they are not thread-safe:
 * when there are engine new/delete operations happening
 * simultaneously in multiple threads, developer must create
 * the lock by himself, and add the lock when calling these
 * functions.
 */
WASM_API_EXTERN own wasm_engine_t* wasm_engine_new(void);
WASM_API_EXTERN own wasm_engine_t* wasm_engine_new_with_config(wasm_config_t*);
WASM_API_DEPRECATED WASM_API_EXTERN own wasm_engine_t *
wasm_engine_new_with_args(mem_alloc_type_t type, const MemAllocOption *opts);

// Store

WASM_DECLARE_OWN(store)

WASM_API_EXTERN own wasm_store_t* wasm_store_new(wasm_engine_t*);


///////////////////////////////////////////////////////////////////////////////
// Type Representations

// Type attributes

typedef uint8_t wasm_mutability_t;
enum wasm_mutability_enum {
  WASM_CONST,
  WASM_VAR,
};

typedef struct wasm_limits_t {
  uint32_t min;
  uint32_t max;
} wasm_limits_t;

static const uint32_t wasm_limits_max_default = 0xffffffff;


// Generic

#define WASM_DECLARE_TYPE(name) \
  WASM_DECLARE_OWN(name) \
  WASM_DECLARE_VEC(name, *) \
  \
  WASM_API_EXTERN own wasm_##name##_t* wasm_##name##_copy(const wasm_##name##_t*);


// Value Types

WASM_DECLARE_TYPE(valtype)

#ifndef WASM_VALKIND_T_DEFINED
#define WASM_VALKIND_T_DEFINED
typedef uint8_t wasm_valkind_t;
enum wasm_valkind_enum {
  WASM_I32,
  WASM_I64,
  WASM_F32,
  WASM_F64,
  WASM_V128,
  WASM_EXTERNREF = 128,
  WASM_FUNCREF,
};
#endif

WASM_API_EXTERN own wasm_valtype_t* wasm_valtype_new(wasm_valkind_t);

WASM_API_EXTERN wasm_valkind_t wasm_valtype_kind(const wasm_valtype_t*);

static inline bool wasm_valkind_is_num(wasm_valkind_t k) {
  return k < WASM_EXTERNREF;
}
static inline bool wasm_valkind_is_ref(wasm_valkind_t k) {
  return k >= WASM_EXTERNREF;
}

static inline bool wasm_valtype_is_num(const wasm_valtype_t* t) {
  return wasm_valkind_is_num(wasm_valtype_kind(t));
}
static inline bool wasm_valtype_is_ref(const wasm_valtype_t* t) {
  return wasm_valkind_is_ref(wasm_valtype_kind(t));
}


// Function Types

WASM_DECLARE_TYPE(functype)

WASM_API_EXTERN own wasm_functype_t* wasm_functype_new(
  own wasm_valtype_vec_t* params, own wasm_valtype_vec_t* results);

WASM_API_EXTERN const wasm_valtype_vec_t* wasm_functype_params(const wasm_functype_t*);
WASM_API_EXTERN const wasm_valtype_vec_t* wasm_functype_results(const wasm_functype_t*);


// Global Types

WASM_DECLARE_TYPE(globaltype)

WASM_API_EXTERN own wasm_globaltype_t* wasm_globaltype_new(
  own wasm_valtype_t*, wasm_mutability_t);

WASM_API_EXTERN const wasm_valtype_t* wasm_globaltype_content(const wasm_globaltype_t*);
WASM_API_EXTERN wasm_mutability_t wasm_globaltype_mutability(const wasm_globaltype_t*);


// Table Types

WASM_DECLARE_TYPE(tabletype)

WASM_API_EXTERN own wasm_tabletype_t* wasm_tabletype_new(
  own wasm_valtype_t*, const wasm_limits_t*);

WASM_API_EXTERN const wasm_valtype_t* wasm_tabletype_element(const wasm_tabletype_t*);
WASM_API_EXTERN const wasm_limits_t* wasm_tabletype_limits(const wasm_tabletype_t*);


// Memory Types

WASM_DECLARE_TYPE(memorytype)

WASM_API_EXTERN own wasm_memorytype_t* wasm_memorytype_new(const wasm_limits_t*);

WASM_API_EXTERN const wasm_limits_t* wasm_memorytype_limits(const wasm_memorytype_t*);


// Extern Types

WASM_DECLARE_TYPE(externtype)

typedef uint8_t wasm_externkind_t;
enum wasm_externkind_enum {
  WASM_EXTERN_FUNC,
  WASM_EXTERN_GLOBAL,
  WASM_EXTERN_TABLE,
  WASM_EXTERN_MEMORY,
};

WASM_API_EXTERN wasm_externkind_t wasm_externtype_kind(const wasm_externtype_t*);

WASM_API_EXTERN wasm_externtype_t* wasm_functype_as_externtype(wasm_functype_t*);
WASM_API_EXTERN wasm_externtype_t* wasm_globaltype_as_externtype(wasm_globaltype_t*);
WASM_API_EXTERN wasm_externtype_t* wasm_tabletype_as_externtype(wasm_tabletype_t*);
WASM_API_EXTERN wasm_externtype_t* wasm_memorytype_as_externtype(wasm_memorytype_t*);

WASM_API_EXTERN wasm_functype_t* wasm_externtype_as_functype(wasm_externtype_t*);
WASM_API_EXTERN wasm_globaltype_t* wasm_externtype_as_globaltype(wasm_externtype_t*);
WASM_API_EXTERN wasm_tabletype_t* wasm_externtype_as_tabletype(wasm_externtype_t*);
WASM_API_EXTERN wasm_memorytype_t* wasm_externtype_as_memorytype(wasm_externtype_t*);

WASM_API_EXTERN const wasm_externtype_t* wasm_functype_as_externtype_const(const wasm_functype_t*);
WASM_API_EXTERN const wasm_externtype_t* wasm_globaltype_as_externtype_const(const wasm_globaltype_t*);
WASM_API_EXTERN const wasm_externtype_t* wasm_tabletype_as_externtype_const(const wasm_tabletype_t*);
WASM_API_EXTERN const wasm_externtype_t* wasm_memorytype_as_externtype_const(const wasm_memorytype_t*);

WASM_API_EXTERN const wasm_functype_t* wasm_externtype_as_functype_const(const wasm_externtype_t*);
WASM_API_EXTERN const wasm_globaltype_t* wasm_externtype_as_globaltype_const(const wasm_externtype_t*);
WASM_API_EXTERN const wasm_tabletype_t* wasm_externtype_as_tabletype_const(const wasm_externtype_t*);
WASM_API_EXTERN const wasm_memorytype_t* wasm_externtype_as_memorytype_const(const wasm_externtype_t*);


// Import Types

WASM_DECLARE_TYPE(importtype)

WASM_API_EXTERN own wasm_importtype_t* wasm_importtype_new(
  own wasm_name_t* module, own wasm_name_t* name, own wasm_externtype_t*);

WASM_API_EXTERN const wasm_name_t* wasm_importtype_module(const wasm_importtype_t*);
WASM_API_EXTERN const wasm_name_t* wasm_importtype_name(const wasm_importtype_t*);
WASM_API_EXTERN const wasm_externtype_t* wasm_importtype_type(const wasm_importtype_t*);
WASM_API_EXTERN bool wasm_importtype_is_linked(const wasm_importtype_t*);


// Export Types

WASM_DECLARE_TYPE(exporttype)

WASM_API_EXTERN own wasm_exporttype_t* wasm_exporttype_new(
  own wasm_name_t*, own wasm_externtype_t*);

WASM_API_EXTERN const wasm_name_t* wasm_exporttype_name(const wasm_exporttype_t*);
WASM_API_EXTERN const wasm_externtype_t* wasm_exporttype_type(const wasm_exporttype_t*);


///////////////////////////////////////////////////////////////////////////////
// Runtime Objects

// Values

#ifndef WASM_VAL_T_DEFINED
#define WASM_VAL_T_DEFINED
struct wasm_ref_t;

typedef struct wasm_val_t {
  wasm_valkind_t kind;
  uint8_t _paddings[7];
  union {
    int32_t i32;
    int64_t i64;
    float32_t f32;
    float64_t f64;
    struct wasm_ref_t* ref;
  } of;
} wasm_val_t;
#endif

WASM_API_EXTERN void wasm_val_delete(own wasm_val_t* v);
WASM_API_EXTERN void wasm_val_copy(own wasm_val_t* out, const wasm_val_t*);

WASM_DECLARE_VEC(val, )


// References

#define WASM_DECLARE_REF_BASE(name) \
  WASM_DECLARE_OWN(name) \
  \
  WASM_API_EXTERN own wasm_##name##_t* wasm_##name##_copy(const wasm_##name##_t*); \
  WASM_API_EXTERN bool wasm_##name##_same(const wasm_##name##_t*, const wasm_##name##_t*); \
  \
  WASM_API_EXTERN void* wasm_##name##_get_host_info(const wasm_##name##_t*); \
  WASM_API_EXTERN void wasm_##name##_set_host_info(wasm_##name##_t*, void*); \
  WASM_API_EXTERN void wasm_##name##_set_host_info_with_finalizer( \
    wasm_##name##_t*, void*, void (*)(void*));

#define WASM_DECLARE_REF(name) \
  WASM_DECLARE_REF_BASE(name) \
  \
  WASM_API_EXTERN wasm_ref_t* wasm_##name##_as_ref(wasm_##name##_t*); \
  WASM_API_EXTERN wasm_##name##_t* wasm_ref_as_##name(wasm_ref_t*); \
  WASM_API_EXTERN const wasm_ref_t* wasm_##name##_as_ref_const(const wasm_##name##_t*); \
  WASM_API_EXTERN const wasm_##name##_t* wasm_ref_as_##name##_const(const wasm_ref_t*);

#define WASM_DECLARE_SHARABLE_REF(name) \
  WASM_DECLARE_REF(name) \
  WASM_DECLARE_OWN(shared_##name) \
  \
  WASM_API_EXTERN own wasm_shared_##name##_t* wasm_##name##_share(const wasm_##name##_t*); \
  WASM_API_EXTERN own wasm_##name##_t* wasm_##name##_obtain(wasm_store_t*, const wasm_shared_##name##_t*);


WASM_DECLARE_REF_BASE(ref)


// Frames

WASM_DECLARE_OWN(frame)
WASM_DECLARE_VEC(frame, *)
WASM_API_EXTERN own wasm_frame_t* wasm_frame_copy(const wasm_frame_t*);

WASM_API_EXTERN struct wasm_instance_t* wasm_frame_instance(const wasm_frame_t*);
WASM_API_EXTERN uint32_t wasm_frame_func_index(const wasm_frame_t*);
WASM_API_EXTERN size_t wasm_frame_func_offset(const wasm_frame_t*);
WASM_API_EXTERN size_t wasm_frame_module_offset(const wasm_frame_t*);


// Traps

typedef wasm_name_t wasm_message_t;  // null terminated

WASM_DECLARE_REF(trap)

WASM_API_EXTERN own wasm_trap_t* wasm_trap_new(wasm_store_t* store, const wasm_message_t*);

WASM_API_EXTERN void wasm_trap_message(const wasm_trap_t*, own wasm_message_t* out);
WASM_API_EXTERN own wasm_frame_t* wasm_trap_origin(const wasm_trap_t*);
WASM_API_EXTERN void wasm_trap_trace(const wasm_trap_t*, own wasm_frame_vec_t* out);


// Foreign Objects

WASM_DECLARE_REF(foreign)

WASM_API_EXTERN own wasm_foreign_t* wasm_foreign_new(wasm_store_t*);


// Modules
// WASM_DECLARE_SHARABLE_REF(module)

#ifndef WASM_MODULE_T_DEFINED
#define WASM_MODULE_T_DEFINED
struct WASMModuleCommon;
typedef struct WASMModuleCommon *wasm_module_t;
#endif

#ifndef LOAD_ARGS_OPTION_DEFINED
#define LOAD_ARGS_OPTION_DEFINED
typedef struct LoadArgs {
    char *name;
    /* True by default, used by wasm-c-api only.
    If false, the wasm input buffer (wasm_byte_vec_t) is referenced by the
    module instead of being cloned. Hence, it can be freed after module loading. */
    bool clone_wasm_binary;
    /* This option is only used by the AOT/wasm loader (see wasm_export.h) */
    bool wasm_binary_freeable;
    /* false by default, if true, don't resolve the symbols yet. The
       wasm_runtime_load_ex has to be followed by a wasm_runtime_resolve_symbols
       call */
    bool no_resolve;
    /* TODO: more fields? */
} LoadArgs;
#endif /* LOAD_ARGS_OPTION_DEFINED */

WASM_API_EXTERN own wasm_module_t* wasm_module_new(
  wasm_store_t*, const wasm_byte_vec_t* binary);

// please refer to wasm_runtime_load_ex(...) in core/iwasm/include/wasm_export.h
WASM_API_EXTERN own wasm_module_t* wasm_module_new_ex(
  wasm_store_t*, wasm_byte_vec_t* binary, LoadArgs *args);

WASM_API_EXTERN void wasm_module_delete(own wasm_module_t*);

WASM_API_EXTERN bool wasm_module_validate(wasm_store_t*, const wasm_byte_vec_t* binary);

WASM_API_EXTERN void wasm_module_imports(const wasm_module_t*, own wasm_importtype_vec_t* out);
WASM_API_EXTERN void wasm_module_exports(const wasm_module_t*, own wasm_exporttype_vec_t* out);

WASM_API_EXTERN void wasm_module_serialize(wasm_module_t*, own wasm_byte_vec_t* out);
WASM_API_EXTERN own wasm_module_t* wasm_module_deserialize(wasm_store_t*, const wasm_byte_vec_t*);

typedef wasm_module_t wasm_shared_module_t;
WASM_API_EXTERN own wasm_shared_module_t* wasm_module_share(wasm_module_t*);
WASM_API_EXTERN own wasm_module_t* wasm_module_obtain(wasm_store_t*, wasm_shared_module_t*);
WASM_API_EXTERN void wasm_shared_module_delete(own wasm_shared_module_t*);

WASM_API_EXTERN bool wasm_module_set_name(wasm_module_t*, const char* name);
WASM_API_EXTERN const char *wasm_module_get_name(wasm_module_t*);

WASM_API_EXTERN bool wasm_module_is_underlying_binary_freeable(const wasm_module_t *module);


// Function Instances

WASM_DECLARE_REF(func)

typedef own wasm_trap_t* (*wasm_func_callback_t)(
  const wasm_val_vec_t* args, own wasm_val_vec_t *results);
typedef own wasm_trap_t* (*wasm_func_callback_with_env_t)(
  void* env, const wasm_val_vec_t *args, wasm_val_vec_t *results);

WASM_API_EXTERN own wasm_func_t* wasm_func_new(
  wasm_store_t*, const wasm_functype_t*, wasm_func_callback_t);
WASM_API_EXTERN own wasm_func_t* wasm_func_new_with_env(
  wasm_store_t*, const wasm_functype_t* type, wasm_func_callback_with_env_t,
  void* env, void (*finalizer)(void*));

WASM_API_EXTERN own wasm_functype_t* wasm_func_type(const wasm_func_t*);
WASM_API_EXTERN size_t wasm_func_param_arity(const wasm_func_t*);
WASM_API_EXTERN size_t wasm_func_result_arity(const wasm_func_t*);

WASM_API_EXTERN own wasm_trap_t* wasm_func_call(
  const wasm_func_t*, const wasm_val_vec_t* args, wasm_val_vec_t* results);


// Global Instances

WASM_DECLARE_REF(global)

WASM_API_EXTERN own wasm_global_t* wasm_global_new(
  wasm_store_t*, const wasm_globaltype_t*, const wasm_val_t*);

WASM_API_EXTERN own wasm_globaltype_t* wasm_global_type(const wasm_global_t*);

WASM_API_EXTERN void wasm_global_get(const wasm_global_t*, own wasm_val_t* out);
WASM_API_EXTERN void wasm_global_set(wasm_global_t*, const wasm_val_t*);


// Table Instances

WASM_DECLARE_REF(table)

typedef uint32_t wasm_table_size_t;

WASM_API_EXTERN own wasm_table_t* wasm_table_new(
  wasm_store_t*, const wasm_tabletype_t*, wasm_ref_t* init);

WASM_API_EXTERN own wasm_tabletype_t* wasm_table_type(const wasm_table_t*);

WASM_API_EXTERN own wasm_ref_t* wasm_table_get(const wasm_table_t*, wasm_table_size_t index);
WASM_API_EXTERN bool wasm_table_set(wasm_table_t*, wasm_table_size_t index, wasm_ref_t*);

WASM_API_EXTERN wasm_table_size_t wasm_table_size(const wasm_table_t*);
WASM_API_EXTERN bool wasm_table_grow(wasm_table_t*, wasm_table_size_t delta, wasm_ref_t* init);


// Memory Instances

WASM_DECLARE_REF(memory)

typedef uint32_t wasm_memory_pages_t;

static const size_t MEMORY_PAGE_SIZE = 0x10000;

WASM_API_EXTERN own wasm_memory_t* wasm_memory_new(wasm_store_t*, const wasm_memorytype_t*);

WASM_API_EXTERN own wasm_memorytype_t* wasm_memory_type(const wasm_memory_t*);

WASM_API_EXTERN byte_t* wasm_memory_data(wasm_memory_t*);
WASM_API_EXTERN size_t wasm_memory_data_size(const wasm_memory_t*);

WASM_API_EXTERN wasm_memory_pages_t wasm_memory_size(const wasm_memory_t*);
WASM_API_EXTERN bool wasm_memory_grow(wasm_memory_t*, wasm_memory_pages_t delta);


// Externals

WASM_DECLARE_REF(extern)
WASM_DECLARE_VEC(extern, *)

WASM_API_EXTERN wasm_externkind_t wasm_extern_kind(const wasm_extern_t*);
WASM_API_EXTERN own wasm_externtype_t* wasm_extern_type(const wasm_extern_t*);

WASM_API_EXTERN wasm_extern_t* wasm_func_as_extern(wasm_func_t*);
WASM_API_EXTERN wasm_extern_t* wasm_global_as_extern(wasm_global_t*);
WASM_API_EXTERN wasm_extern_t* wasm_table_as_extern(wasm_table_t*);
WASM_API_EXTERN wasm_extern_t* wasm_memory_as_extern(wasm_memory_t*);

WASM_API_EXTERN wasm_func_t* wasm_extern_as_func(wasm_extern_t*);
WASM_API_EXTERN wasm_global_t* wasm_extern_as_global(wasm_extern_t*);
WASM_API_EXTERN wasm_table_t* wasm_extern_as_table(wasm_extern_t*);
WASM_API_EXTERN wasm_memory_t* wasm_extern_as_memory(wasm_extern_t*);

WASM_API_EXTERN const wasm_extern_t* wasm_func_as_extern_const(const wasm_func_t*);
WASM_API_EXTERN const wasm_extern_t* wasm_global_as_extern_const(const wasm_global_t*);
WASM_API_EXTERN const wasm_extern_t* wasm_table_as_extern_const(const wasm_table_t*);
WASM_API_EXTERN const wasm_extern_t* wasm_memory_as_extern_const(const wasm_memory_t*);

WASM_API_EXTERN const wasm_func_t* wasm_extern_as_func_const(const wasm_extern_t*);
WASM_API_EXTERN const wasm_global_t* wasm_extern_as_global_const(const wasm_extern_t*);
WASM_API_EXTERN const wasm_table_t* wasm_extern_as_table_const(const wasm_extern_t*);
WASM_API_EXTERN const wasm_memory_t* wasm_extern_as_memory_const(const wasm_extern_t*);


// Module Instances

WASM_DECLARE_REF(instance)

WASM_API_EXTERN own wasm_instance_t* wasm_instance_new(
  wasm_store_t*, const wasm_module_t*, const wasm_extern_vec_t *imports,
  own wasm_trap_t** trap
);

// please refer to wasm_runtime_instantiate(...) in core/iwasm/include/wasm_export.h
WASM_API_EXTERN own wasm_instance_t* wasm_instance_new_with_args(
  wasm_store_t*, const wasm_module_t*, const wasm_extern_vec_t *imports,
  own wasm_trap_t** trap, const uint32_t stack_size, const uint32_t heap_size
);

// please refer to wasm_runtime_instantiate_ex(...) in core/iwasm/include/wasm_export.h
WASM_API_EXTERN own wasm_instance_t* wasm_instance_new_with_args_ex(
  wasm_store_t*, const wasm_module_t*, const wasm_extern_vec_t *imports,
  own wasm_trap_t** trap, const InstantiationArgs *inst_args
);

WASM_API_EXTERN void wasm_instance_exports(const wasm_instance_t*, own wasm_extern_vec_t* out);

// Return total wasm functions' execution time in ms
WASM_API_EXTERN double wasm_instance_sum_wasm_exec_time(const wasm_instance_t*);
// Return execution time in ms of a given wasm function with
// func_name. If the function is not found, return 0.
WASM_API_EXTERN double wasm_instance_get_wasm_func_exec_time(const wasm_instance_t*, const char *);

///////////////////////////////////////////////////////////////////////////////
// Convenience

// Vectors

#define WASM_EMPTY_VEC {0, NULL, 0, 0, NULL}
#define WASM_ARRAY_VEC(array) {sizeof(array)/sizeof(*(array)), array, sizeof(array)/sizeof(*(array)), sizeof(*(array)), NULL}


// Value Type construction short-hands

static inline own wasm_valtype_t* wasm_valtype_new_i32(void) {
  return wasm_valtype_new(WASM_I32);
}
static inline own wasm_valtype_t* wasm_valtype_new_i64(void) {
  return wasm_valtype_new(WASM_I64);
}
static inline own wasm_valtype_t* wasm_valtype_new_f32(void) {
  return wasm_valtype_new(WASM_F32);
}
static inline own wasm_valtype_t* wasm_valtype_new_f64(void) {
  return wasm_valtype_new(WASM_F64);
}
static inline own wasm_valtype_t* wasm_valtype_new_v128(void) {
  return wasm_valtype_new(WASM_V128);
}

static inline own wasm_valtype_t* wasm_valtype_new_anyref(void) {
  return wasm_valtype_new(WASM_EXTERNREF);
}
static inline own wasm_valtype_t* wasm_valtype_new_funcref(void) {
  return wasm_valtype_new(WASM_FUNCREF);
}


// Function Types construction short-hands

static inline own wasm_functype_t* wasm_functype_new_0_0(void) {
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new_empty(&params);
  wasm_valtype_vec_new_empty(&results);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_1_0(
  own wasm_valtype_t* p
) {
  wasm_valtype_t* ps[1] = {p};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 1, ps);
  wasm_valtype_vec_new_empty(&results);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_2_0(
  own wasm_valtype_t* p1, own wasm_valtype_t* p2
) {
  wasm_valtype_t* ps[2] = {p1, p2};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 2, ps);
  wasm_valtype_vec_new_empty(&results);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_3_0(
  own wasm_valtype_t* p1, own wasm_valtype_t* p2, own wasm_valtype_t* p3
) {
  wasm_valtype_t* ps[3] = {p1, p2, p3};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 3, ps);
  wasm_valtype_vec_new_empty(&results);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_0_1(
  own wasm_valtype_t* r
) {
  wasm_valtype_t* rs[1] = {r};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new_empty(&params);
  wasm_valtype_vec_new(&results, 1, rs);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_1_1(
  own wasm_valtype_t* p, own wasm_valtype_t* r
) {
  wasm_valtype_t* ps[1] = {p};
  wasm_valtype_t* rs[1] = {r};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 1, ps);
  wasm_valtype_vec_new(&results, 1, rs);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_2_1(
  own wasm_valtype_t* p1, own wasm_valtype_t* p2, own wasm_valtype_t* r
) {
  wasm_valtype_t* ps[2] = {p1, p2};
  wasm_valtype_t* rs[1] = {r};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 2, ps);
  wasm_valtype_vec_new(&results, 1, rs);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_3_1(
  own wasm_valtype_t* p1, own wasm_valtype_t* p2, own wasm_valtype_t* p3,
  own wasm_valtype_t* r
) {
  wasm_valtype_t* ps[3] = {p1, p2, p3};
  wasm_valtype_t* rs[1] = {r};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 3, ps);
  wasm_valtype_vec_new(&results, 1, rs);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_0_2(
  own wasm_valtype_t* r1, own wasm_valtype_t* r2
) {
  wasm_valtype_t* rs[2] = {r1, r2};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new_empty(&params);
  wasm_valtype_vec_new(&results, 2, rs);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_1_2(
  own wasm_valtype_t* p, own wasm_valtype_t* r1, own wasm_valtype_t* r2
) {
  wasm_valtype_t* ps[1] = {p};
  wasm_valtype_t* rs[2] = {r1, r2};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 1, ps);
  wasm_valtype_vec_new(&results, 2, rs);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_2_2(
  own wasm_valtype_t* p1, own wasm_valtype_t* p2,
  own wasm_valtype_t* r1, own wasm_valtype_t* r2
) {
  wasm_valtype_t* ps[2] = {p1, p2};
  wasm_valtype_t* rs[2] = {r1, r2};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 2, ps);
  wasm_valtype_vec_new(&results, 2, rs);
  return wasm_functype_new(&params, &results);
}

static inline own wasm_functype_t* wasm_functype_new_3_2(
  own wasm_valtype_t* p1, own wasm_valtype_t* p2, own wasm_valtype_t* p3,
  own wasm_valtype_t* r1, own wasm_valtype_t* r2
) {
  wasm_valtype_t* ps[3] = {p1, p2, p3};
  wasm_valtype_t* rs[2] = {r1, r2};
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 3, ps);
  wasm_valtype_vec_new(&results, 2, rs);
  return wasm_functype_new(&params, &results);
}


// Value construction short-hands

static inline void wasm_val_init_ptr(own wasm_val_t* out, void* p) {
#if UINTPTR_MAX == UINT32_MAX
  out->kind = WASM_I32;
  out->of.i32 = (intptr_t)p;
#elif UINTPTR_MAX == UINT64_MAX
  out->kind = WASM_I64;
  out->of.i64 = (intptr_t)p;
#endif
}

static inline void* wasm_val_ptr(const wasm_val_t* val) {
#if UINTPTR_MAX == UINT32_MAX
  return (void*)(intptr_t)val->of.i32;
#elif UINTPTR_MAX == UINT64_MAX
  return (void*)(intptr_t)val->of.i64;
#endif
}

#define WASM_I32_VAL(i) {.kind = WASM_I32, ._paddings = {0}, .of = {.i32 = i}}
#define WASM_I64_VAL(i) {.kind = WASM_I64, ._paddings = {0}, .of = {.i64 = i}}
#define WASM_F32_VAL(z) {.kind = WASM_F32, ._paddings = {0}, .of = {.f32 = z}}
#define WASM_F64_VAL(z) {.kind = WASM_F64, ._paddings = {0}, .of = {.f64 = z}}
#define WASM_REF_VAL(r) {.kind = WASM_EXTERNREF, ._paddings = {0}, .of = {.ref = r}}
#define WASM_INIT_VAL {.kind = WASM_EXTERNREF, ._paddings = {0}, .of = {.ref = NULL}}

#define KILOBYTE(n) ((n) * 1024)

// Create placeholders filled in `wasm_externvec_t* imports` for `wasm_instance_new()`
WASM_API_EXTERN wasm_extern_t *wasm_extern_new_empty(wasm_store_t *,  wasm_externkind_t);

///////////////////////////////////////////////////////////////////////////////

#undef own

/* clang-format on */

#ifdef __cplusplus
} // extern "C"
#endif

#endif // #ifdef _WASM_C_API_H_
