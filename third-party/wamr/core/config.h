/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _CONFIG_H_
#define _CONFIG_H_

/* clang-format off */
#if !defined(BUILD_TARGET_X86_64) \
    && !defined(BUILD_TARGET_AMD_64) \
    && !defined(BUILD_TARGET_AARCH64) \
    && !defined(BUILD_TARGET_X86_32) \
    && !defined(BUILD_TARGET_ARM) \
    && !defined(BUILD_TARGET_ARM_VFP) \
    && !defined(BUILD_TARGET_THUMB) \
    && !defined(BUILD_TARGET_THUMB_VFP) \
    && !defined(BUILD_TARGET_MIPS) \
    && !defined(BUILD_TARGET_XTENSA) \
    && !defined(BUILD_TARGET_RISCV64_LP64D) \
    && !defined(BUILD_TARGET_RISCV64_LP64) \
    && !defined(BUILD_TARGET_RISCV32_ILP32D) \
    && !defined(BUILD_TARGET_RISCV32_ILP32F) \
    && !defined(BUILD_TARGET_RISCV32_ILP32) \
    && !defined(BUILD_TARGET_ARC)
/* clang-format on */
#if defined(__x86_64__) || defined(__x86_64)
#define BUILD_TARGET_X86_64
#elif defined(__amd64__) || defined(__amd64)
#define BUILD_TARGET_AMD_64
#elif defined(__aarch64__)
#define BUILD_TARGET_AARCH64
#elif defined(__i386__) || defined(__i386) || defined(i386)
#define BUILD_TARGET_X86_32
#elif defined(__thumb__)
#define BUILD_TARGET_THUMB
#define BUILD_TARGET "THUMBV4T"
#elif defined(__arm__)
#define BUILD_TARGET_ARM
#define BUILD_TARGET "ARMV4T"
#elif defined(__mips__) || defined(__mips) || defined(mips)
#define BUILD_TARGET_MIPS
#elif defined(__XTENSA__)
#define BUILD_TARGET_XTENSA
#elif defined(__riscv) && (__riscv_xlen == 64)
#define BUILD_TARGET_RISCV64_LP64D
#elif defined(__riscv) && (__riscv_xlen == 32) && !defined(__riscv_flen)
#define BUILD_TARGET_RISCV32_ILP32
#elif defined(__riscv) && (__riscv_xlen == 32) && (__riscv_flen == 32)
#define BUILD_TARGET_RISCV32_ILP32F
#elif defined(__riscv) && (__riscv_xlen == 32) && (__riscv_flen == 64)
#define BUILD_TARGET_RISCV32_ILP32D
#elif defined(__arc__)
#define BUILD_TARGET_ARC
#else
#error "Build target isn't set"
#endif
#endif

#ifndef BH_DEBUG
#define BH_DEBUG 0
#endif

#define MEM_ALLOCATOR_EMS 0
#define MEM_ALLOCATOR_TLSF 1

/* Default memory allocator */
#define DEFAULT_MEM_ALLOCATOR MEM_ALLOCATOR_EMS

#ifndef WASM_ENABLE_INTERP
#define WASM_ENABLE_INTERP 0
#endif

#ifndef WASM_ENABLE_AOT
#define WASM_ENABLE_AOT 0
#endif

#ifndef WASM_ENABLE_DYNAMIC_AOT_DEBUG
#define WASM_ENABLE_DYNAMIC_AOT_DEBUG 0
#endif

#ifndef WASM_ENABLE_WORD_ALIGN_READ
#define WASM_ENABLE_WORD_ALIGN_READ 0
#endif

#define AOT_MAGIC_NUMBER 0x746f6100
#define AOT_CURRENT_VERSION 5

#ifndef WASM_ENABLE_JIT
#define WASM_ENABLE_JIT 0
#endif

#ifndef WASM_ENABLE_LAZY_JIT
#define WASM_ENABLE_LAZY_JIT 0
#endif

#ifndef WASM_ORC_JIT_BACKEND_THREAD_NUM
/* The number of backend threads created by runtime */
#define WASM_ORC_JIT_BACKEND_THREAD_NUM 4
#endif

#if WASM_ORC_JIT_BACKEND_THREAD_NUM < 1
#error "WASM_ORC_JIT_BACKEND_THREAD_NUM must be greater than 0"
#endif

#ifndef WASM_ORC_JIT_COMPILE_THREAD_NUM
/* The number of compilation threads created by LLVM JIT */
#define WASM_ORC_JIT_COMPILE_THREAD_NUM 4
#endif

#if WASM_ORC_JIT_COMPILE_THREAD_NUM < 1
#error "WASM_ORC_JIT_COMPILE_THREAD_NUM must be greater than 0"
#endif

#if (WASM_ENABLE_AOT == 0) && (WASM_ENABLE_JIT != 0)
/* LLVM JIT can only be enabled when AOT is enabled */
#undef WASM_ENABLE_JIT
#define WASM_ENABLE_JIT 0

#undef WASM_ENABLE_LAZY_JIT
#define WASM_ENABLE_LAZY_JIT 0
#endif

#ifndef WASM_ENABLE_FAST_JIT
#define WASM_ENABLE_FAST_JIT 0
#endif

#ifndef WASM_ENABLE_FAST_JIT_DUMP
#define WASM_ENABLE_FAST_JIT_DUMP 0
#endif

#ifndef FAST_JIT_DEFAULT_CODE_CACHE_SIZE
#define FAST_JIT_DEFAULT_CODE_CACHE_SIZE 10 * 1024 * 1024
#endif

#ifndef WASM_ENABLE_WAMR_COMPILER
#define WASM_ENABLE_WAMR_COMPILER 0
#endif

#ifndef WASM_ENABLE_LIBC_BUILTIN
#define WASM_ENABLE_LIBC_BUILTIN 0
#endif

#ifndef WASM_ENABLE_LIBC_WASI
#define WASM_ENABLE_LIBC_WASI 0
#endif

#ifndef WASM_ENABLE_UVWASI
#define WASM_ENABLE_UVWASI 0
#endif

#ifndef WASM_ENABLE_WASI_NN
#define WASM_ENABLE_WASI_NN 0
#endif

#ifndef WASM_ENABLE_WASI_NN_GPU
#define WASM_ENABLE_WASI_NN_GPU 0
#endif

#ifndef WASM_ENABLE_WASI_NN_EXTERNAL_DELEGATE
#define WASM_ENABLE_WASI_NN_EXTERNAL_DELEGATE 0
#endif

#ifndef WASM_ENABLE_WASI_EPHEMERAL_NN
#define WASM_ENABLE_WASI_EPHEMERAL_NN 0
#endif

/* Default disable libc emcc */
#ifndef WASM_ENABLE_LIBC_EMCC
#define WASM_ENABLE_LIBC_EMCC 0
#endif

#ifndef WASM_ENABLE_LIB_RATS
#define WASM_ENABLE_LIB_RATS 0
#endif

#ifndef WASM_ENABLE_LIB_PTHREAD
#define WASM_ENABLE_LIB_PTHREAD 0
#endif

#ifndef WASM_ENABLE_LIB_PTHREAD_SEMAPHORE
#define WASM_ENABLE_LIB_PTHREAD_SEMAPHORE 0
#endif

#ifndef WASM_ENABLE_LIB_WASI_THREADS
#define WASM_ENABLE_LIB_WASI_THREADS 0
#endif

#ifndef WASM_ENABLE_HEAP_AUX_STACK_ALLOCATION
#define WASM_ENABLE_HEAP_AUX_STACK_ALLOCATION WASM_ENABLE_LIB_WASI_THREADS
#elif WASM_ENABLE_HEAP_AUX_STACK_ALLOCATION == 0 \
    && WASM_ENABLE_LIB_WASI_THREADS == 1
#error "Heap aux stack allocation must be enabled for WASI threads"
#endif

#ifndef WASM_ENABLE_COPY_CALL_STACK
#define WASM_ENABLE_COPY_CALL_STACK 0
#endif

#ifndef WASM_ENABLE_BASE_LIB
#define WASM_ENABLE_BASE_LIB 0
#endif

#ifndef WASM_ENABLE_APP_FRAMEWORK
#define WASM_ENABLE_APP_FRAMEWORK 0
#endif

#ifndef WASM_HAVE_MREMAP
#define WASM_HAVE_MREMAP 0
#endif

/* Bulk memory operation */
#ifndef WASM_ENABLE_BULK_MEMORY
#define WASM_ENABLE_BULK_MEMORY 0
#endif

/* Shared memory */
#ifndef WASM_ENABLE_SHARED_MEMORY
#define WASM_ENABLE_SHARED_MEMORY 0
#endif

/* Thread manager */
#ifndef WASM_ENABLE_THREAD_MGR
#define WASM_ENABLE_THREAD_MGR 0
#endif

/* Source debugging */
#ifndef WASM_ENABLE_DEBUG_INTERP
#define WASM_ENABLE_DEBUG_INTERP 0
#endif

#if WASM_ENABLE_DEBUG_INTERP != 0
#ifndef DEBUG_EXECUTION_MEMORY_SIZE
/* 0x85000 is the size required by lldb, if this is changed to a smaller value,
 * then the debugger will not be able to evaluate user expressions, other
 * functionality such as breakpoint and stepping are not influenced by this */
#define DEBUG_EXECUTION_MEMORY_SIZE 0x85000
#endif
#endif /* end of WASM_ENABLE_DEBUG_INTERP != 0 */

#ifndef WASM_ENABLE_DEBUG_AOT
#define WASM_ENABLE_DEBUG_AOT 0
#endif

/* Custom sections */
#ifndef WASM_ENABLE_LOAD_CUSTOM_SECTION
#define WASM_ENABLE_LOAD_CUSTOM_SECTION 0
#endif

/* WASM log system */
#ifndef WASM_ENABLE_LOG
#define WASM_ENABLE_LOG 1
#endif

/* When this flag is set, WAMR will not automatically
 * initialize sockets on Windows platforms. The host
 * application is responsible for calling WSAStartup()
 * before executing WAMR code that uses sockets, and
 * calling WSACleanup() after.
 * This flag passes control of socket initialization from
 * WAMR to the host application. */
#ifndef WASM_ENABLE_HOST_SOCKET_INIT
#define WASM_ENABLE_HOST_SOCKET_INIT 0
#endif

#ifndef WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS
#if defined(BUILD_TARGET_X86_32) || defined(BUILD_TARGET_X86_64) \
    || defined(BUILD_TARGET_AARCH64)
#define WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS 1
#else
#define WASM_CPU_SUPPORTS_UNALIGNED_ADDR_ACCESS 0
#endif
#endif

/* WASM Interpreter labels-as-values feature */
#ifndef WASM_ENABLE_LABELS_AS_VALUES
#ifdef __GNUC__
#define WASM_ENABLE_LABELS_AS_VALUES 1
#else
#define WASM_ENABLE_LABELS_AS_VALUES 0
#endif
#endif

/* Enable fast interpreter or not */
#ifndef WASM_ENABLE_FAST_INTERP
#define WASM_ENABLE_FAST_INTERP 0
#endif

#if WASM_ENABLE_FAST_INTERP != 0
#define WASM_DEBUG_PREPROCESSOR 0
#endif

/* Enable opcode counter or not */
#ifndef WASM_ENABLE_OPCODE_COUNTER
#define WASM_ENABLE_OPCODE_COUNTER 0
#endif

/* Support a module with dependency, other modules */
#ifndef WASM_ENABLE_MULTI_MODULE
#define WASM_ENABLE_MULTI_MODULE 0
#endif

/* Enable wasm mini loader or not */
#ifndef WASM_ENABLE_MINI_LOADER
#define WASM_ENABLE_MINI_LOADER 0
#endif

/* Disable boundary check with hardware trap or not,
 * enable it by default if it is supported */
#ifndef WASM_DISABLE_HW_BOUND_CHECK
#define WASM_DISABLE_HW_BOUND_CHECK 0
#endif

/* Disable native stack access boundary check with hardware
 * trap or not, enable it by default if it is supported */
#ifndef WASM_DISABLE_STACK_HW_BOUND_CHECK
#define WASM_DISABLE_STACK_HW_BOUND_CHECK 0
#endif

/* Disable SIMD unless it is manually enabled somewhere */
#ifndef WASM_ENABLE_SIMD
#define WASM_ENABLE_SIMD 0
#endif

/* Disable SIMDe (used in the fast interpreter for SIMD opcodes)
unless used elsewhere */
#ifndef WASM_ENABLE_SIMDE
#define WASM_ENABLE_SIMDE 0
#endif

/* GC performance profiling */
#ifndef WASM_ENABLE_GC_PERF_PROFILING
#define WASM_ENABLE_GC_PERF_PROFILING 0
#endif

/* Memory profiling */
#ifndef WASM_ENABLE_MEMORY_PROFILING
#define WASM_ENABLE_MEMORY_PROFILING 0
#endif

/* Memory tracing */
#ifndef WASM_ENABLE_MEMORY_TRACING
#define WASM_ENABLE_MEMORY_TRACING 0
#endif

/* Performance profiling */
#ifndef WASM_ENABLE_PERF_PROFILING
#define WASM_ENABLE_PERF_PROFILING 0
#endif

/* Dump call stack */
#ifndef WASM_ENABLE_DUMP_CALL_STACK
#define WASM_ENABLE_DUMP_CALL_STACK 0
#endif

/* AOT stack frame */
#ifndef WASM_ENABLE_AOT_STACK_FRAME
#define WASM_ENABLE_AOT_STACK_FRAME 0
#endif

/* Heap verification */
#ifndef BH_ENABLE_GC_VERIFY
#define BH_ENABLE_GC_VERIFY 0
#endif

/* Heap corruption check, enabled by default */
#ifndef BH_ENABLE_GC_CORRUPTION_CHECK
#define BH_ENABLE_GC_CORRUPTION_CHECK 1
#endif

/* Enable global heap pool if heap verification is enabled */
#if BH_ENABLE_GC_VERIFY != 0
#define WASM_ENABLE_GLOBAL_HEAP_POOL 1
#endif

/* Global heap pool */
#ifndef WASM_ENABLE_GLOBAL_HEAP_POOL
#define WASM_ENABLE_GLOBAL_HEAP_POOL 0
#endif

#ifndef WASM_ENABLE_SPEC_TEST
#define WASM_ENABLE_SPEC_TEST 0
#endif

#ifndef WASM_ENABLE_WASI_TEST
#define WASM_ENABLE_WASI_TEST 0
#endif

/* Global heap pool size in bytes */
#ifndef WASM_GLOBAL_HEAP_SIZE
#define WASM_GLOBAL_HEAP_SIZE (10 * 1024 * 1024)
#endif

/* Default length of queue */
#ifndef DEFAULT_QUEUE_LENGTH
#define DEFAULT_QUEUE_LENGTH 50
#endif

/* The max percentage of global heap that app memory space can grow */
#ifndef APP_MEMORY_MAX_GLOBAL_HEAP_PERCENT
#define APP_MEMORY_MAX_GLOBAL_HEAP_PERCENT 1 / 3
#endif

/* Default min/max heap size of each app */
#ifndef APP_HEAP_SIZE_DEFAULT
#define APP_HEAP_SIZE_DEFAULT (8 * 1024)
#endif
#define APP_HEAP_SIZE_MIN (256)
/* The ems memory allocator supports maximal heap size 1GB,
   see ems_gc_internal.h */
#define APP_HEAP_SIZE_MAX (1024 * 1024 * 1024)

/* Default min/max gc heap size of each app */
#ifndef GC_HEAP_SIZE_DEFAULT
#define GC_HEAP_SIZE_DEFAULT (128 * 1024)
#endif
#define GC_HEAP_SIZE_MIN (4 * 1024)
#define GC_HEAP_SIZE_MAX (1024 * 1024 * 1024)

/* Default wasm stack size of each app */
#if defined(BUILD_TARGET_X86_64) || defined(BUILD_TARGET_AMD_64)
#define DEFAULT_WASM_STACK_SIZE (16 * 1024)
#else
#define DEFAULT_WASM_STACK_SIZE (12 * 1024)
#endif
/* Min auxiliary stack size of each wasm thread */
#define WASM_THREAD_AUX_STACK_SIZE_MIN (256)

/* Default/min native stack size of each app thread */
#if !(defined(APP_THREAD_STACK_SIZE_DEFAULT) \
      && defined(APP_THREAD_STACK_SIZE_MIN))
#if defined(BH_PLATFORM_ZEPHYR) || defined(BH_PLATFORM_ALIOS_THINGS) \
    || defined(BH_PLATFORM_ESP_IDF) || defined(BH_PLATFORM_OPENRTOS)
#define APP_THREAD_STACK_SIZE_DEFAULT (6 * 1024)
#define APP_THREAD_STACK_SIZE_MIN (4 * 1024)
#elif defined(PTHREAD_STACK_DEFAULT) && defined(PTHREAD_STACK_MIN)
#define APP_THREAD_STACK_SIZE_DEFAULT PTHREAD_STACK_DEFAULT
#define APP_THREAD_STACK_SIZE_MIN PTHREAD_STACK_MIN
#elif WASM_ENABLE_UVWASI != 0
/* UVWASI requires larger native stack */
#define APP_THREAD_STACK_SIZE_DEFAULT (64 * 1024)
#define APP_THREAD_STACK_SIZE_MIN (48 * 1024)
#else
#define APP_THREAD_STACK_SIZE_DEFAULT (128 * 1024)
#define APP_THREAD_STACK_SIZE_MIN (24 * 1024)
#endif
#endif /* end of !(defined(APP_THREAD_STACK_SIZE_DEFAULT) \
                   && defined(APP_THREAD_STACK_SIZE_MIN)) */

/* Max native stack size of each app thread */
#if !defined(APP_THREAD_STACK_SIZE_MAX)
#define APP_THREAD_STACK_SIZE_MAX (8 * 1024 * 1024)
#endif

/* Reserved bytes to the native thread stack boundary, throw native
 * stack overflow exception if the guard boundary is reached
 *
 * WASM_STACK_GUARD_SIZE needs to be large enough for:
 *
 * - native functions
 *
 *   w/o hw bound check, the overhead (aot_call_function etc) + the native
 *   function itself. as of writing this, the former is about 1000 bytes
 *   on macOS amd64.
 *
 *   with hw bound check, theoretically, only needs to cover the logic to
 *   set up the jmp_buf stack.
 *
 * - aot runtime functions
 *   eg. aot_enlarge_memory.
 *
 * - w/o hw bound check, the interpreter loop
 *
 *   the stack consumption heavily depends on compiler settings,
 *   especially for huge functions like the classic interpreter's
 *   wasm_interp_call_func_bytecode:
 *
 *     200 bytes (release build, macOS/amd64)
 *     2600 bytes (debug build, macOS/amd64)
 *
 * - platform-provided functions (eg. libc)
 *
 *   the following are examples of the stack consumptions observed for
 *   host APIs.
 *
 *   snprintf: (used by eg. wasm_runtime_set_exception)
 *   - about 1600 bytes on macOS/amd64
 *   - about 2000 bytes on Ubuntu amd64 20.04
 *
 *   gethostbyname:
 *   - 3KB-6KB on macOS/amd64
 *   - 10KB on Ubuntu amd64 20.04
 *
 *   getaddrinfo:
 *   - 4KB-17KB on macOS/amd64
 *   - 12KB on Ubuntu amd64 20.04
 *   - 0.3-1.5KB on NuttX/esp32s3
 *
 * - stack check wrapper functions generated by the aot compiler
 *   (--stack-bounds-checks=1)
 *
 *   wamrc issues a warning
 *   "precheck functions themselves consume relatively large amount of stack"
 *   when it detects wrapper functions requiring more than 1KB.
 *
 * - the ABI-defined red zone. eg. 128 bytes for SYSV x86-64 ABI.
 *   cf. https://en.wikipedia.org/wiki/Red_zone_(computing)
 *
 * Note: on platforms with lazy function binding, don't forget to consider
 * the symbol resolution overhead on the first call. For example,
 * on Ubuntu amd64 20.04, it seems to consume about 1500 bytes.
 * For some reasons, macOS amd64 12.7.4 seems to resolve symbols eagerly.
 * (Observed with a binary with traditional non-chained fixups.)
 * The latest macOS seems to apply chained fixups in kernel on page-in time.
 * (thus it wouldn't consume userland stack.)
 */
#ifndef WASM_STACK_GUARD_SIZE
#if WASM_ENABLE_UVWASI != 0
/* UVWASI requires larger native stack */
#define WASM_STACK_GUARD_SIZE (4096 * 6)
#else
/*
 * Use a larger default for platforms like macOS/Linux.
 *
 * For example, the classic interpreter loop which ended up with a trap
 * (wasm_runtime_set_exception) would consume about 2KB stack on x86-64
 * macOS. On Ubuntu amd64 20.04, it seems to consume a bit more.
 *
 * Although product-mini/platforms/nuttx always overrides
 * WASM_STACK_GUARD_SIZE, exclude NuttX here just in case.
 */
#if defined(__APPLE__) || (defined(__unix__) && !defined(__NuttX__))
#if BH_DEBUG != 0 /* assumption: BH_DEBUG matches CMAKE_BUILD_TYPE=Debug */
#define WASM_STACK_GUARD_SIZE (1024 * 5)
#else
#define WASM_STACK_GUARD_SIZE (1024 * 3)
#endif
#else
/*
 * Otherwise, assume very small requirement for now.
 *
 * Embedders for very small devices likely fine-tune WASM_STACK_GUARD_SIZE
 * for their specific applications anyway.
 */
#define WASM_STACK_GUARD_SIZE 1024
#endif
#endif
#endif

/* Guard page count for stack overflow check with hardware trap */
#ifndef STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT
#if defined(__APPLE__) && defined(__aarch64__)
/* Note: on macOS/iOS arm64, the user page size is 16KB */
#define STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT 1
#else
#define STACK_OVERFLOW_CHECK_GUARD_PAGE_COUNT 3
#endif
#endif

/* Default wasm block address cache size and conflict list size */
#ifndef BLOCK_ADDR_CACHE_SIZE
#define BLOCK_ADDR_CACHE_SIZE 64
#endif
#define BLOCK_ADDR_CONFLICT_SIZE 2

/* Default max thread num per cluster. Can be overwrite by
    wasm_runtime_set_max_thread_num */
#define CLUSTER_MAX_THREAD_NUM 4

#ifndef WASM_ENABLE_TAIL_CALL
#define WASM_ENABLE_TAIL_CALL 0
#endif

#ifndef WASM_ENABLE_CUSTOM_NAME_SECTION
#define WASM_ENABLE_CUSTOM_NAME_SECTION 0
#endif

#ifndef WASM_ENABLE_REF_TYPES
#define WASM_ENABLE_REF_TYPES 0
#endif

#ifndef WASM_ENABLE_GC
#define WASM_ENABLE_GC 0
#endif

#ifndef WASM_CONST_EXPR_STACK_SIZE
#if WASM_ENABLE_GC != 0
#define WASM_CONST_EXPR_STACK_SIZE 8
#else
#define WASM_CONST_EXPR_STACK_SIZE 4
#endif
#endif

#ifndef WASM_ENABLE_STRINGREF
#define WASM_ENABLE_STRINGREF 0
#endif

#ifndef GC_REFTYPE_MAP_SIZE_DEFAULT
#define GC_REFTYPE_MAP_SIZE_DEFAULT 64
#endif

#ifndef GC_RTTOBJ_MAP_SIZE_DEFAULT
#define GC_RTTOBJ_MAP_SIZE_DEFAULT 64
#endif

#ifndef WASM_ENABLE_EXCE_HANDLING
#define WASM_ENABLE_EXCE_HANDLING 0
#endif

#ifndef WASM_ENABLE_TAGS
#define WASM_ENABLE_TAGS 0
#endif

#ifndef WASM_ENABLE_SGX_IPFS
#define WASM_ENABLE_SGX_IPFS 0
#endif

#ifndef WASM_MEM_ALLOC_WITH_USER_DATA
#define WASM_MEM_ALLOC_WITH_USER_DATA 0
#endif

#ifndef WASM_ENABLE_WASM_CACHE
#define WASM_ENABLE_WASM_CACHE 0
#endif

#ifndef WASM_ENABLE_STATIC_PGO
#define WASM_ENABLE_STATIC_PGO 0
#endif

/* Disable writing linear memory base address to GS segment register,
   by default only in linux x86-64, linear memory base addr is written
   to GS segment register before calling wasm/aot function. */
#ifndef WASM_DISABLE_WRITE_GS_BASE
#define WASM_DISABLE_WRITE_GS_BASE 0
#endif

/* Configurable bounds checks */
#ifndef WASM_CONFIGURABLE_BOUNDS_CHECKS
#define WASM_CONFIGURABLE_BOUNDS_CHECKS 0
#endif

/* Some chip cannot support external ram with rwx attr at the same time,
   it has to map it into 2 spaces of idbus and dbus, code in dbus can be
   read/written and read/executed in ibus. so there are 2 steps to execute
   the code, first, copy & do relocation in dbus space, and second execute
   it in ibus space, since in the 2 spaces the contents are the same,
   so we call it bus mirror.
 */
#ifndef WASM_MEM_DUAL_BUS_MIRROR
#define WASM_MEM_DUAL_BUS_MIRROR 0
#endif

/* The max number of module instance contexts. */
#ifndef WASM_MAX_INSTANCE_CONTEXTS
#define WASM_MAX_INSTANCE_CONTEXTS 8
#endif

/* linux perf support */
#ifndef WASM_ENABLE_LINUX_PERF
#define WASM_ENABLE_LINUX_PERF 0
#endif

/* Support registering quick AOT/JIT function entries of some func types
   to speed up the calling process of invoking the AOT/JIT functions of
   these types from the host embedder */
#ifndef WASM_ENABLE_QUICK_AOT_ENTRY
#define WASM_ENABLE_QUICK_AOT_ENTRY 1
#endif

/* Support AOT intrinsic functions which can be called from the AOT code
   when `--disable-llvm-intrinsics` flag or
   `--enable-builtin-intrinsics=<intr1,intr2,...>` is used by wamrc to
   generate the AOT file */
#ifndef WASM_ENABLE_AOT_INTRINSICS
#define WASM_ENABLE_AOT_INTRINSICS 1
#endif

/* Disable memory64 by default */
#ifndef WASM_ENABLE_MEMORY64
#define WASM_ENABLE_MEMORY64 0
#endif

/* Disable multi-memory by default */
#ifndef WASM_ENABLE_MULTI_MEMORY
#define WASM_ENABLE_MULTI_MEMORY 0
#endif

#ifndef WASM_TABLE_MAX_SIZE
#define WASM_TABLE_MAX_SIZE 1024
#endif

#ifndef WASM_MEM_ALLOC_WITH_USAGE
#define WASM_MEM_ALLOC_WITH_USAGE 0
#endif

#ifndef WASM_ENABLE_FUZZ_TEST
#define WASM_ENABLE_FUZZ_TEST 0
#endif

#if WASM_ENABLE_FUZZ_TEST != 0
#ifndef WASM_MEM_ALLOC_MAX_SIZE
/* In oss-fuzz, the maximum RAM is ~2.5G */
#define WASM_MEM_ALLOC_MAX_SIZE (2U * 1024 * 1024 * 1024)
#endif
#endif /* WASM_ENABLE_FUZZ_TEST != 0 */

#ifndef WASM_ENABLE_SHARED_HEAP
#define WASM_ENABLE_SHARED_HEAP 0
#endif

#ifndef WASM_ENABLE_SHRUNK_MEMORY
#define WASM_ENABLE_SHRUNK_MEMORY 1
#endif

#ifndef WASM_ENABLE_AOT_VALIDATOR
#define WASM_ENABLE_AOT_VALIDATOR 0
#endif

#ifndef WASM_ENABLE_INSTRUCTION_METERING
#define WASM_ENABLE_INSTRUCTION_METERING 0
#endif

#ifndef WASM_ENABLE_EXTENDED_CONST_EXPR
#define WASM_ENABLE_EXTENDED_CONST_EXPR 0
#endif

#endif /* end of _CONFIG_H_ */
