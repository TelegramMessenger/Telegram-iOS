/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

/**
 * @file   lib_export.h
 *
 */

#ifndef _LIB_EXPORT_H_
#define _LIB_EXPORT_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NativeSymbol {
    const char *symbol;
    void *func_ptr;
    const char *signature;
    /* attachment which can be retrieved in native API by
       calling wasm_runtime_get_function_attachment(exec_env) */
    void *attachment;
} NativeSymbol;

/* clang-format off */
#define EXPORT_WASM_API(symbol) \
    { #symbol, (void *)symbol, NULL, NULL }
#define EXPORT_WASM_API2(symbol) \
    { #symbol, (void *)symbol##_wrapper, NULL, NULL }

#define EXPORT_WASM_API_WITH_SIG(symbol, signature) \
    { #symbol, (void *)symbol, signature, NULL }
#define EXPORT_WASM_API_WITH_SIG2(symbol, signature) \
    { #symbol, (void *)symbol##_wrapper, signature, NULL }

#define EXPORT_WASM_API_WITH_ATT(symbol, signature, attachment) \
    { #symbol, (void *)symbol, signature, attachment }
#define EXPORT_WASM_API_WITH_ATT2(symbol, signature, attachment) \
    { #symbol, (void *)symbol##_wrapper, signature, attachment }
/* clang-format on */

/**
 * Get the exported APIs of base lib
 *
 * @param p_base_lib_apis return the exported API array of base lib
 *
 * @return the number of the exported API
 */
uint32_t
get_base_lib_export_apis(NativeSymbol **p_base_lib_apis);

#ifdef __cplusplus
}
#endif

#endif /* end of _LIB_EXPORT_H_ */
