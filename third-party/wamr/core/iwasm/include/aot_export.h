/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

/**
 * @file   aot_export.h
 *
 * @brief  This file defines the exported AOT compilation APIs
 */

#ifndef _AOT_EXPORT_H
#define _AOT_EXPORT_H

#include <stdint.h>
#include <stdbool.h>

#include "aot_comp_option.h"

#ifdef __cplusplus
extern "C" {
#endif

struct AOTCompData;
typedef struct AOTCompData *aot_comp_data_t;

struct AOTCompContext;
typedef struct AOTCompContext *aot_comp_context_t;

struct AOTObjectData;
typedef struct AOTObjectData *aot_obj_data_t;

aot_comp_data_t
aot_create_comp_data(void *wasm_module, const char *target_arch,
                     bool gc_enabled);

void
aot_destroy_comp_data(aot_comp_data_t comp_data);

#if WASM_ENABLE_DEBUG_AOT != 0
typedef void *dwarf_extractor_handle_t;
dwarf_extractor_handle_t
create_dwarf_extractor(aot_comp_data_t comp_data, char *file_name);
#endif

enum {
    AOT_FORMAT_FILE,
    AOT_OBJECT_FILE,
    AOT_LLVMIR_UNOPT_FILE,
    AOT_LLVMIR_OPT_FILE,
};

bool
aot_compiler_init(void);

void
aot_compiler_destroy(void);

aot_comp_context_t
aot_create_comp_context(aot_comp_data_t comp_data, aot_comp_option_t option);

void
aot_destroy_comp_context(aot_comp_context_t comp_ctx);

bool
aot_compile_wasm(aot_comp_context_t comp_ctx);

aot_obj_data_t
aot_obj_data_create(aot_comp_context_t comp_ctx);

void
aot_obj_data_destroy(aot_obj_data_t obj_data);

uint32_t
aot_get_aot_file_size(aot_comp_context_t comp_ctx, aot_comp_data_t comp_data,
                      aot_obj_data_t obj_data);

uint8_t *
aot_emit_aot_file_buf(aot_comp_context_t comp_ctx, aot_comp_data_t comp_data,
                      uint32_t *p_aot_file_size);

bool
aot_emit_aot_file_buf_ex(aot_comp_context_t comp_ctx, aot_comp_data_t comp_data,
                         aot_obj_data_t obj_data, uint8_t *aot_file_buf,
                         uint32_t aot_file_size);

bool
aot_emit_llvm_file(aot_comp_context_t comp_ctx, const char *file_name);

bool
aot_emit_object_file(aot_comp_context_t comp_ctx, const char *file_name);

bool
aot_emit_aot_file(aot_comp_context_t comp_ctx, aot_comp_data_t comp_data,
                  const char *file_name);

void
aot_destroy_aot_file(uint8_t *aot_file);

char *
aot_get_last_error(void);

uint32_t
aot_get_plt_table_size(void);

#ifdef __cplusplus
}
#endif

#endif /* end of _AOT_EXPORT_H */
