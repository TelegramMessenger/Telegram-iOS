/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */
#ifndef _WASM_LOADER_H
#define _WASM_LOADER_H

#include "wasm.h"
#include "bh_hashmap.h"
#include "../common/wasm_runtime_common.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Load a WASM module from a specified byte buffer.
 *
 * @param buf the byte buffer which contains the WASM binary data
 * @param size the size of the buffer
 * @param error_buf output of the exception info
 * @param error_buf_size the size of the exception string
 *
 * @return return module loaded, NULL if failed
 */
WASMModule *
wasm_loader_load(uint8 *buf, uint32 size,
#if WASM_ENABLE_MULTI_MODULE != 0
                 bool main_module,
#endif
                 const LoadArgs *args, char *error_buf, uint32 error_buf_size);

/**
 * Load a WASM module from a specified WASM section list.
 *
 * @param section_list the section list which contains each section data
 * @param error_buf output of the exception info
 * @param error_buf_size the size of the exception string
 *
 * @return return WASM module loaded, NULL if failed
 */
WASMModule *
wasm_loader_load_from_sections(WASMSection *section_list, char *error_buf,
                               uint32 error_buf_size);

/**
 * Unload a WASM module.
 *
 * @param module the module to be unloaded
 */
void
wasm_loader_unload(WASMModule *module);

/**
 * Find address of related else opcode and end opcode of opcode block/loop/if
 * according to the start address of opcode.
 *
 * @param module the module to find
 * @param start_addr the next address of opcode block/loop/if
 * @param code_end_addr the end address of function code block
 * @param block_type the type of block, 0/1/2 denotes block/loop/if
 * @param p_else_addr returns the else addr if found
 * @param p_end_addr returns the end addr if found
 * @param error_buf returns the error log for this function
 * @param error_buf_size returns the error log string length
 *
 * @return true if success, false otherwise
 */

bool
wasm_loader_find_block_addr(WASMExecEnv *exec_env, BlockAddr *block_addr_cache,
                            const uint8 *start_addr, const uint8 *code_end_addr,
                            uint8 block_type, uint8 **p_else_addr,
                            uint8 **p_end_addr);

#ifdef __cplusplus
}
#endif

#endif /* end of _WASM_LOADER_H */
