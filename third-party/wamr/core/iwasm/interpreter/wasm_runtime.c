/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "wasm_runtime.h"
#include "wasm.h"
#include "wasm_loader.h"
#include "wasm_interp.h"
#include "bh_common.h"
#include "bh_log.h"
#include "mem_alloc.h"
#include "../common/wasm_runtime_common.h"
#include "../common/wasm_memory.h"
#if WASM_ENABLE_GC != 0
#include "../common/gc/gc_object.h"
#endif
#if WASM_ENABLE_SHARED_MEMORY != 0
#include "../common/wasm_shared_memory.h"
#endif
#if WASM_ENABLE_THREAD_MGR != 0
#include "../libraries/thread-mgr/thread_manager.h"
#endif
#if WASM_ENABLE_DEBUG_INTERP != 0
#include "../libraries/debug-engine/debug_engine.h"
#endif
#if WASM_ENABLE_FAST_JIT != 0
#include "../fast-jit/jit_compiler.h"
#endif
#if WASM_ENABLE_JIT != 0
#include "../aot/aot_runtime.h"
#endif

static void
set_error_buf(char *error_buf, uint32 error_buf_size, const char *string)
{
    if (error_buf != NULL) {
        snprintf(error_buf, error_buf_size,
                 "WASM module instantiate failed: %s", string);
    }
}

static void
set_error_buf_v(char *error_buf, uint32 error_buf_size, const char *format, ...)
{
    va_list args;
    char buf[128];

    if (error_buf != NULL) {
        va_start(args, format);
        vsnprintf(buf, sizeof(buf), format, args);
        va_end(args);
        snprintf(error_buf, error_buf_size,
                 "WASM module instantiate failed: %s", buf);
    }
}

WASMModule *
wasm_load(uint8 *buf, uint32 size,
#if WASM_ENABLE_MULTI_MODULE != 0
          bool main_module,
#endif
          const LoadArgs *name, char *error_buf, uint32 error_buf_size)
{
    return wasm_loader_load(buf, size,
#if WASM_ENABLE_MULTI_MODULE != 0
                            main_module,
#endif
                            name, error_buf, error_buf_size);
}

WASMModule *
wasm_load_from_sections(WASMSection *section_list, char *error_buf,
                        uint32 error_buf_size)
{
    return wasm_loader_load_from_sections(section_list, error_buf,
                                          error_buf_size);
}

void
wasm_unload(WASMModule *module)
{
    wasm_loader_unload(module);
}

bool
wasm_resolve_symbols(WASMModule *module)
{
    bool ret = true;
    uint32 idx;
    for (idx = 0; idx < module->import_function_count; ++idx) {
        WASMFunctionImport *import = &module->import_functions[idx].u.function;
        bool linked = import->func_ptr_linked;
#if WASM_ENABLE_MULTI_MODULE != 0
        if (import->import_func_linked) {
            linked = true;
        }
#endif
        if (!linked && !wasm_resolve_import_func(module, import)) {
            ret = false;
        }
    }
    return ret;
}

#if WASM_ENABLE_MULTI_MODULE != 0
static WASMFunction *
wasm_resolve_function(const char *module_name, const char *function_name,
                      const WASMFuncType *expected_function_type,
                      char *error_buf, uint32 error_buf_size)
{
    WASMModuleCommon *module_reg;
    WASMFunction *function = NULL;
    WASMExport *export = NULL;
    WASMModule *module = NULL;
    WASMFuncType *target_function_type = NULL;

    module_reg = wasm_runtime_find_module_registered(module_name);
    if (!module_reg || module_reg->module_type != Wasm_Module_Bytecode) {
        LOG_DEBUG("can not find a module named %s for function %s", module_name,
                  function_name);
        set_error_buf(error_buf, error_buf_size, "unknown import");
        return NULL;
    }

    module = (WASMModule *)module_reg;
    export = loader_find_export((WASMModuleCommon *)module, module_name,
                                function_name, EXPORT_KIND_FUNC, error_buf,
                                error_buf_size);
    if (!export) {
        return NULL;
    }

    /* resolve function type and function */
    if (export->index < module->import_function_count) {
        target_function_type =
            module->import_functions[export->index].u.function.func_type;
        function = module->import_functions[export->index]
                       .u.function.import_func_linked;
    }
    else {
        target_function_type =
            module->functions[export->index - module->import_function_count]
                ->func_type;
        function =
            module->functions[export->index - module->import_function_count];
    }

    /* check function type */
    if (!wasm_type_equal((WASMType *)expected_function_type,
                         (WASMType *)target_function_type, module->types,
                         module->type_count)) {
        LOG_DEBUG("%s.%s failed the type check", module_name, function_name);
        set_error_buf(error_buf, error_buf_size, "incompatible import type");
        return NULL;
    }

    return function;
}
#endif

bool
wasm_resolve_import_func(const WASMModule *module, WASMFunctionImport *function)
{
#if WASM_ENABLE_MULTI_MODULE != 0
    char error_buf[128];
    WASMModule *sub_module = NULL;
#endif
    function->func_ptr_linked = wasm_native_resolve_symbol(
        function->module_name, function->field_name, function->func_type,
        &function->signature, &function->attachment, &function->call_conv_raw);

    if (function->func_ptr_linked) {
        return true;
    }

#if WASM_ENABLE_MULTI_MODULE != 0
    if (!wasm_runtime_is_built_in_module(function->module_name)) {
        sub_module = (WASMModule *)wasm_runtime_load_depended_module(
            (WASMModuleCommon *)module, function->module_name, error_buf,
            sizeof(error_buf));
        if (!sub_module) {
            LOG_WARNING("failed to load sub module: %s", error_buf);
            return false;
        }
    }
    function->import_func_linked = wasm_resolve_function(
        function->module_name, function->field_name, function->func_type,
        error_buf, sizeof(error_buf));

    if (function->import_func_linked) {
        function->import_module = sub_module;
        return true;
    }
    else {
        LOG_WARNING("failed to link function (%s, %s): %s",
                    function->module_name, function->field_name, error_buf);
    }
#endif

    return false;
}

static void *
runtime_malloc(uint64 size, char *error_buf, uint32 error_buf_size)
{
    void *mem;

    if (size >= UINT32_MAX || !(mem = wasm_runtime_malloc((uint32)size))) {
        set_error_buf(error_buf, error_buf_size, "allocate memory failed");
        return NULL;
    }

    memset(mem, 0, (uint32)size);
    return mem;
}

#if WASM_ENABLE_MULTI_MODULE != 0
static WASMModuleInstance *
get_sub_module_inst(const WASMModuleInstance *parent_module_inst,
                    const WASMModule *sub_module)
{
    bh_list *sub_module_inst_list = parent_module_inst->e->sub_module_inst_list;
    WASMSubModInstNode *node = bh_list_first_elem(sub_module_inst_list);

    while (node && sub_module != node->module_inst->module) {
        node = bh_list_elem_next(node);
    }
    return node ? node->module_inst : NULL;
}
#endif

/**
 * Destroy memory instances.
 */
static void
memories_deinstantiate(WASMModuleInstance *module_inst,
                       WASMMemoryInstance **memories, uint32 count)
{
    uint32 i;
    if (memories) {
        for (i = 0; i < count; i++) {
            if (memories[i]) {
#if WASM_ENABLE_MULTI_MODULE != 0
                WASMModule *module = module_inst->module;
                if (i < module->import_memory_count
                    && module->import_memories[i].u.memory.import_module) {
                    continue;
                }
#endif
#if WASM_ENABLE_SHARED_MEMORY != 0
                if (shared_memory_is_shared(memories[i])) {
                    uint32 ref_count = shared_memory_dec_reference(memories[i]);
                    /* if the reference count is not zero,
                        don't free the memory */
                    if (ref_count > 0)
                        continue;
                }
#endif
                if (memories[i]->heap_handle) {
                    mem_allocator_destroy(memories[i]->heap_handle);
                    wasm_runtime_free(memories[i]->heap_handle);
                    memories[i]->heap_handle = NULL;
                }
                if (memories[i]->memory_data) {
                    wasm_deallocate_linear_memory(memories[i]);
                }
            }
        }
        wasm_runtime_free(memories);
    }
    (void)module_inst;
}

static WASMMemoryInstance *
memory_instantiate(WASMModuleInstance *module_inst, WASMModuleInstance *parent,
                   WASMMemoryInstance *memory, uint32 memory_idx,
                   uint32 num_bytes_per_page, uint32 init_page_count,
                   uint32 max_page_count, uint32 heap_size, uint32 flags,
                   char *error_buf, uint32 error_buf_size)
{
    WASMModule *module = module_inst->module;
    uint32 inc_page_count, global_idx, default_max_page;
    uint32 bytes_of_last_page, bytes_to_page_end;
    uint64 aux_heap_base,
        heap_offset = (uint64)num_bytes_per_page * init_page_count;
    uint64 memory_data_size, max_memory_data_size;
    uint8 *global_addr;

    bool is_shared_memory = false;
#if WASM_ENABLE_SHARED_MEMORY != 0
    is_shared_memory = flags & SHARED_MEMORY_FLAG ? true : false;

    /* shared memory */
    if (is_shared_memory && parent != NULL) {
        bh_assert(parent->memory_count > memory_idx);
        memory = parent->memories[memory_idx];
        shared_memory_inc_reference(memory);
        return memory;
    }
#else
    (void)parent;
    (void)memory_idx;
    (void)flags;
#endif /* end of WASM_ENABLE_SHARED_MEMORY */

#if WASM_ENABLE_MEMORY64 != 0
    if (flags & MEMORY64_FLAG) {
        memory->is_memory64 = 1;
    }
#endif
    default_max_page =
        memory->is_memory64 ? DEFAULT_MEM64_MAX_PAGES : DEFAULT_MAX_PAGES;

    /* The app heap should be in the default memory */
    if (memory_idx == 0) {
        if (heap_size > 0 && module_inst->module->malloc_function != (uint32)-1
            && module_inst->module->free_function != (uint32)-1) {
            /* Disable app heap, use malloc/free function exported
               by wasm app to allocate/free memory instead */
            heap_size = 0;
        }

        /* If initial memory is the largest size allowed, disallowing insert
         * host managed heap */
        if (heap_size > 0
            && heap_offset == GET_MAX_LINEAR_MEMORY_SIZE(memory->is_memory64)) {
            set_error_buf(error_buf, error_buf_size,
                          "failed to insert app heap into linear memory, "
                          "try using `--heap-size=0` option");
            return NULL;
        }

        if (init_page_count == max_page_count && init_page_count == 1) {
            /* If only one page and at most one page, we just append
               the app heap to the end of linear memory, enlarge the
               num_bytes_per_page, and don't change the page count */
            heap_offset = num_bytes_per_page;
            num_bytes_per_page += heap_size;
            if (num_bytes_per_page < heap_size) {
                set_error_buf(error_buf, error_buf_size,
                              "failed to insert app heap into linear memory, "
                              "try using `--heap-size=0` option");
                return NULL;
            }
        }
        else if (heap_size > 0) {
            if (init_page_count == max_page_count && init_page_count == 0) {
                /* If the memory data size is always 0, we resize it to
                   one page for app heap */
                num_bytes_per_page = heap_size;
                heap_offset = 0;
                inc_page_count = 1;
            }
            else if (module->aux_heap_base_global_index != (uint32)-1
                     && module->aux_heap_base
                            < (uint64)num_bytes_per_page * init_page_count) {
                /* Insert app heap before __heap_base */
                aux_heap_base = module->aux_heap_base;
                bytes_of_last_page = aux_heap_base % num_bytes_per_page;
                if (bytes_of_last_page == 0)
                    bytes_of_last_page = num_bytes_per_page;
                bytes_to_page_end = num_bytes_per_page - bytes_of_last_page;
                inc_page_count =
                    (heap_size - bytes_to_page_end + num_bytes_per_page - 1)
                    / num_bytes_per_page;
                heap_offset = aux_heap_base;
                aux_heap_base += heap_size;

                bytes_of_last_page = aux_heap_base % num_bytes_per_page;
                if (bytes_of_last_page == 0)
                    bytes_of_last_page = num_bytes_per_page;
                bytes_to_page_end = num_bytes_per_page - bytes_of_last_page;
                if (bytes_to_page_end < 1 * BH_KB) {
                    aux_heap_base += 1 * BH_KB;
                    inc_page_count++;
                }

                /* Adjust __heap_base global value */
                global_idx = module->aux_heap_base_global_index;
                bh_assert(module_inst->e->globals
                          && global_idx < module_inst->e->global_count);
                global_addr = module_inst->global_data
                              + module_inst->e->globals[global_idx].data_offset;
#if WASM_ENABLE_MEMORY64 != 0
                if (memory->is_memory64) {
                    /* For memory64, the global value should be i64 */
                    *(uint64 *)global_addr = aux_heap_base;
                }
                else
#endif
                {
                    /* For memory32, the global value should be i32 */
                    *(uint32 *)global_addr = (uint32)aux_heap_base;
                }
                LOG_VERBOSE("Reset __heap_base global to %" PRIu64,
                            aux_heap_base);
            }
            else {
                /* Insert app heap before new page */
                inc_page_count =
                    (heap_size + num_bytes_per_page - 1) / num_bytes_per_page;
                heap_offset = (uint64)num_bytes_per_page * init_page_count;
                heap_size = (uint64)num_bytes_per_page * inc_page_count;
                if (heap_size > 0)
                    heap_size -= 1 * BH_KB;
            }
            init_page_count += inc_page_count;
            max_page_count += inc_page_count;
            if (init_page_count > default_max_page) {
                set_error_buf(error_buf, error_buf_size,
                              "failed to insert app heap into linear memory, "
                              "try using `--heap-size=0` option");
                return NULL;
            }

            if (max_page_count > default_max_page)
                max_page_count = default_max_page;
        }
    }

    LOG_VERBOSE("Memory instantiate:");
    LOG_VERBOSE("  page bytes: %u, init pages: %u, max pages: %u",
                num_bytes_per_page, init_page_count, max_page_count);
    if (memory_idx == 0)
        LOG_VERBOSE("  heap offset: %" PRIu64 ", heap size: %u\n", heap_offset,
                    heap_size);

    max_memory_data_size = (uint64)num_bytes_per_page * max_page_count;
    bh_assert(max_memory_data_size
              <= GET_MAX_LINEAR_MEMORY_SIZE(memory->is_memory64));
    (void)max_memory_data_size;

    bh_assert(memory != NULL);

    if (wasm_allocate_linear_memory(&memory->memory_data, is_shared_memory,
                                    memory->is_memory64, num_bytes_per_page,
                                    init_page_count, max_page_count,
                                    &memory_data_size)
        != BHT_OK) {
        set_error_buf(error_buf, error_buf_size,
                      "allocate linear memory failed");
        return NULL;
    }

    memory->module_type = Wasm_Module_Bytecode;
    memory->num_bytes_per_page = num_bytes_per_page;
    memory->cur_page_count = init_page_count;
    memory->max_page_count = max_page_count;
    memory->memory_data_size = memory_data_size;

    if (memory_idx == 0) {
        memory->heap_data = memory->memory_data + heap_offset;
        memory->heap_data_end = memory->heap_data + heap_size;
        memory->memory_data_end = memory->memory_data + memory_data_size;
    }

    /* Initialize heap */
    if (memory_idx == 0 && heap_size > 0) {
        uint32 heap_struct_size = mem_allocator_get_heap_struct_size();

        if (!(memory->heap_handle = runtime_malloc(
                  (uint64)heap_struct_size, error_buf, error_buf_size))) {
            goto fail1;
        }
        if (!mem_allocator_create_with_struct_and_pool(
                memory->heap_handle, heap_struct_size, memory->heap_data,
                heap_size)) {
            set_error_buf(error_buf, error_buf_size, "init app heap failed");
            goto fail2;
        }
    }

    if (memory_data_size > 0) {
        wasm_runtime_set_mem_bound_check_bytes(memory, memory_data_size);
    }

#if WASM_ENABLE_SHARED_MEMORY != 0
    if (is_shared_memory) {
        memory->is_shared_memory = 1;
        memory->ref_count = 1;
    }
#endif

    LOG_VERBOSE("Memory instantiate success.");
    return memory;

fail2:
    if (memory_idx == 0 && heap_size > 0)
        wasm_runtime_free(memory->heap_handle);
fail1:
    if (memory->memory_data)
        wasm_deallocate_linear_memory(memory);

    return NULL;
}

/**
 * Instantiate memories in a module.
 */
static WASMMemoryInstance **
memories_instantiate(const WASMModule *module, WASMModuleInstance *module_inst,
                     WASMModuleInstance *parent, uint32 heap_size,
                     uint32 max_memory_pages, char *error_buf,
                     uint32 error_buf_size)
{
    WASMImport *import;
    uint32 mem_index = 0, i,
           memory_count = module->import_memory_count + module->memory_count;
    uint64 total_size;
    WASMMemoryInstance **memories, *memory;

    total_size = sizeof(WASMMemoryInstance *) * (uint64)memory_count;

    if (!(memories = runtime_malloc(total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    memory = module_inst->global_table_data.memory_instances;

    /* instantiate memories from import section */
    import = module->import_memories;
    for (i = 0; i < module->import_memory_count; i++, import++, memory++) {
        uint32 num_bytes_per_page =
            import->u.memory.mem_type.num_bytes_per_page;
        uint32 init_page_count = import->u.memory.mem_type.init_page_count;
        uint32 max_page_count = wasm_runtime_get_max_mem(
            max_memory_pages, import->u.memory.mem_type.init_page_count,
            import->u.memory.mem_type.max_page_count);
        uint32 flags = import->u.memory.mem_type.flags;
        uint32 actual_heap_size = heap_size;

#if WASM_ENABLE_MULTI_MODULE != 0
        if (import->u.memory.import_module != NULL) {
            WASMModuleInstance *module_inst_linked;

            if (!(module_inst_linked = get_sub_module_inst(
                      module_inst, import->u.memory.import_module))) {
                set_error_buf(error_buf, error_buf_size, "unknown memory");
                memories_deinstantiate(module_inst, memories, memory_count);
                return NULL;
            }

            if (!(memories[mem_index++] = wasm_lookup_memory(
                      module_inst_linked, import->u.memory.field_name))) {
                set_error_buf(error_buf, error_buf_size, "unknown memory");
                memories_deinstantiate(module_inst, memories, memory_count);
                return NULL;
            }
        }
        else
#endif
        {
            if (!(memories[mem_index] = memory_instantiate(
                      module_inst, parent, memory, mem_index,
                      num_bytes_per_page, init_page_count, max_page_count,
                      actual_heap_size, flags, error_buf, error_buf_size))) {
                memories_deinstantiate(module_inst, memories, memory_count);
                return NULL;
            }
            mem_index++;
        }
    }

    /* instantiate memories from memory section */
    for (i = 0; i < module->memory_count; i++, memory++) {
        uint32 max_page_count = wasm_runtime_get_max_mem(
            max_memory_pages, module->memories[i].init_page_count,
            module->memories[i].max_page_count);
        if (!(memories[mem_index] = memory_instantiate(
                  module_inst, parent, memory, mem_index,
                  module->memories[i].num_bytes_per_page,
                  module->memories[i].init_page_count, max_page_count,
                  heap_size, module->memories[i].flags, error_buf,
                  error_buf_size))) {
            memories_deinstantiate(module_inst, memories, memory_count);
            return NULL;
        }
        mem_index++;
    }

    bh_assert(mem_index == memory_count);
    (void)module_inst;
    return memories;
}

/**
 * Destroy table instances.
 */
static void
tables_deinstantiate(WASMModuleInstance *module_inst)
{
    if (module_inst->tables) {
        wasm_runtime_free(module_inst->tables);
    }
#if WASM_ENABLE_MULTI_MODULE != 0
    if (module_inst->e->table_insts_linked) {
        wasm_runtime_free(module_inst->e->table_insts_linked);
    }
#endif
}

/**
 * Instantiate tables in a module.
 */
static WASMTableInstance **
tables_instantiate(const WASMModule *module, WASMModuleInstance *module_inst,
                   WASMTableInstance *first_table, char *error_buf,
                   uint32 error_buf_size)
{
    WASMImport *import;
    uint32 table_index = 0, i;
    uint32 table_count = module->import_table_count + module->table_count;
    uint64 total_size = (uint64)sizeof(WASMTableInstance *) * table_count;
    WASMTableInstance **tables, *table = first_table;
#if WASM_ENABLE_MULTI_MODULE != 0
    uint64 total_size_of_tables_linked =
        (uint64)sizeof(WASMTableInstance *) * module->import_table_count;
    WASMTableInstance **table_linked = NULL;
#endif

    if (!(tables = runtime_malloc(total_size, error_buf, error_buf_size))) {
        return NULL;
    }

#if WASM_ENABLE_MULTI_MODULE != 0
    if (module->import_table_count > 0
        && !(module_inst->e->table_insts_linked = table_linked = runtime_malloc(
                 total_size_of_tables_linked, error_buf, error_buf_size))) {
        goto fail;
    }
#endif

    /* instantiate tables from import section */
    import = module->import_tables;
    for (i = 0; i < module->import_table_count; i++, import++) {
        uint32 max_size_fixed = 0;
#if WASM_ENABLE_MULTI_MODULE != 0
        WASMTableInstance *table_inst_linked = NULL;
        WASMModuleInstance *module_inst_linked = NULL;

        if (import->u.table.import_module) {
            if (!(module_inst_linked = get_sub_module_inst(
                      module_inst, import->u.table.import_module))) {
                set_error_buf(error_buf, error_buf_size, "unknown table");
                goto fail;
            }

            if (!(table_inst_linked = wasm_lookup_table(
                      module_inst_linked, import->u.table.field_name))) {
                set_error_buf(error_buf, error_buf_size, "unknown table");
                goto fail;
            }

            total_size = offsetof(WASMTableInstance, elems);
        }
        else
#endif
        {
            /* in order to save memory, alloc resource as few as possible */
            max_size_fixed = import->u.table.table_type.possible_grow
                                 ? import->u.table.table_type.max_size
                                 : import->u.table.table_type.init_size;

            /* it is a built-in table, every module has its own */
            total_size = offsetof(WASMTableInstance, elems);
            /* store function indexes for non-gc, object pointers for gc */
            total_size += (uint64)sizeof(table_elem_type_t) * max_size_fixed;
        }

        tables[table_index++] = table;

#if WASM_ENABLE_GC == 0
        /* Set all elements to -1 to mark them as uninitialized elements */
        memset(table, -1, (uint32)total_size);
#else
        /* For GC, all elements have already been set to NULL_REF (0) as
           uninitialized elements */
#endif

        table->is_table64 = import->u.table.table_type.flags & TABLE64_FLAG;

#if WASM_ENABLE_MULTI_MODULE != 0
        *table_linked = table_inst_linked;
        if (table_inst_linked != NULL) {
            table->elem_type = table_inst_linked->elem_type;
#if WASM_ENABLE_GC != 0
            table->elem_ref_type = table_inst_linked->elem_ref_type;
#endif
            table->cur_size = table_inst_linked->cur_size;
            table->max_size = table_inst_linked->max_size;
        }
        else
#endif
        {
            table->elem_type = import->u.table.table_type.elem_type;
#if WASM_ENABLE_GC != 0
            table->elem_ref_type.elem_ref_type =
                import->u.table.table_type.elem_ref_type;
#endif
            table->cur_size = import->u.table.table_type.init_size;
            table->max_size = max_size_fixed;
        }

        table = (WASMTableInstance *)((uint8 *)table + (uint32)total_size);
#if WASM_ENABLE_MULTI_MODULE != 0
        table_linked++;
#endif
    }

    /* instantiate tables from table section */
    for (i = 0; i < module->table_count; i++) {
        uint32 max_size_fixed = 0;

        total_size = offsetof(WASMTableInstance, elems);
#if WASM_ENABLE_MULTI_MODULE != 0
        /* in case, a module which imports this table will grow it */
        max_size_fixed = module->tables[i].table_type.max_size;
#else
        max_size_fixed = module->tables[i].table_type.possible_grow
                             ? module->tables[i].table_type.max_size
                             : module->tables[i].table_type.init_size;
#endif
#if WASM_ENABLE_GC == 0
        /* Store function indexes */
        total_size += sizeof(uintptr_t) * (uint64)max_size_fixed;
#else
        /* Store object pointers */
        total_size += sizeof(uintptr_t) * (uint64)max_size_fixed;
#endif

        tables[table_index++] = table;

#if WASM_ENABLE_GC == 0
        /* Set all elements to -1 to mark them as uninitialized elements */
        memset(table, -1, (uint32)total_size);
#else
        /* For GC, all elements have already been set to NULL_REF (0) as
           uninitialized elements */
#endif
        table->is_table64 = module->tables[i].table_type.flags & TABLE64_FLAG;
        table->elem_type = module->tables[i].table_type.elem_type;
#if WASM_ENABLE_GC != 0
        table->elem_ref_type.elem_ref_type =
            module->tables[i].table_type.elem_ref_type;
#endif
        table->cur_size = module->tables[i].table_type.init_size;
        table->max_size = max_size_fixed;

        table = (WASMTableInstance *)((uint8 *)table + (uint32)total_size);
    }

    bh_assert(table_index == table_count);
    (void)module_inst;
    return tables;
#if WASM_ENABLE_MULTI_MODULE != 0
fail:
    wasm_runtime_free(tables);
    return NULL;
#endif
}

/**
 * Destroy function instances.
 */
static void
functions_deinstantiate(WASMFunctionInstance *functions)
{
    if (functions) {
        wasm_runtime_free(functions);
    }
}

/**
 * Instantiate functions in a module.
 */
static WASMFunctionInstance *
functions_instantiate(const WASMModule *module, WASMModuleInstance *module_inst,
                      char *error_buf, uint32 error_buf_size)
{
    WASMImport *import;
    uint32 i,
        function_count = module->import_function_count + module->function_count;
    uint64 total_size = sizeof(WASMFunctionInstance) * (uint64)function_count;
    WASMFunctionInstance *functions, *function;

    if (!(functions = runtime_malloc(total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    total_size = sizeof(void *) * (uint64)module->import_function_count;
    if (total_size > 0
        && !(module_inst->import_func_ptrs =
                 runtime_malloc(total_size, error_buf, error_buf_size))) {
        wasm_runtime_free(functions);
        return NULL;
    }

    /* instantiate functions from import section */
    function = functions;
    import = module->import_functions;
    for (i = 0; i < module->import_function_count; i++, import++) {
        function->is_import_func = true;

#if WASM_ENABLE_MULTI_MODULE != 0
        if (import->u.function.import_module) {
            function->import_module_inst = get_sub_module_inst(
                module_inst, import->u.function.import_module);

            if (function->import_module_inst) {
                function->import_func_inst =
                    wasm_lookup_function(function->import_module_inst,
                                         import->u.function.field_name);
            }
        }
#endif /* WASM_ENABLE_MULTI_MODULE */
        function->u.func_import = &import->u.function;
        function->param_cell_num = import->u.function.func_type->param_cell_num;
        function->ret_cell_num = import->u.function.func_type->ret_cell_num;
        function->param_count =
            (uint16)function->u.func_import->func_type->param_count;
        function->param_types = function->u.func_import->func_type->types;
        function->local_cell_num = 0;
        function->local_count = 0;
        function->local_types = NULL;

        /* Copy the function pointer to current instance */
        module_inst->import_func_ptrs[i] =
            function->u.func_import->func_ptr_linked;

        function++;
    }

    /* instantiate functions from function section */
    for (i = 0; i < module->function_count; i++) {
        function->is_import_func = false;
        function->u.func = module->functions[i];

        function->param_cell_num = function->u.func->param_cell_num;
        function->ret_cell_num = function->u.func->ret_cell_num;
        function->local_cell_num = function->u.func->local_cell_num;

        function->param_count =
            (uint16)function->u.func->func_type->param_count;
        function->local_count = (uint16)function->u.func->local_count;
        function->param_types = function->u.func->func_type->types;
        function->local_types = function->u.func->local_types;

        function->local_offsets = function->u.func->local_offsets;

#if WASM_ENABLE_FAST_INTERP != 0
        function->const_cell_num = function->u.func->const_cell_num;
#endif

        function++;
    }
    bh_assert((uint32)(function - functions) == function_count);

#if WASM_ENABLE_FAST_JIT != 0
    module_inst->fast_jit_func_ptrs = module->fast_jit_func_ptrs;
#endif

    return functions;
}

#if WASM_ENABLE_TAGS != 0
/**
 * Destroy tags instances.
 */
static void
tags_deinstantiate(WASMTagInstance *tags, void **import_tag_ptrs)
{
    if (tags) {
        wasm_runtime_free(tags);
    }
    if (import_tag_ptrs) {
        wasm_runtime_free(import_tag_ptrs);
    }
}

/**
 * Instantiate tags in a module.
 */
static WASMTagInstance *
tags_instantiate(const WASMModule *module, WASMModuleInstance *module_inst,
                 char *error_buf, uint32 error_buf_size)
{
    WASMImport *import;
    uint32 i, tag_count = module->import_tag_count + module->tag_count;
    uint64 total_size = sizeof(WASMTagInstance) * (uint64)tag_count;
    WASMTagInstance *tags, *tag;

    if (!(tags = runtime_malloc(total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    total_size = sizeof(void *) * (uint64)module->import_tag_count;
    if (total_size > 0
        && !(module_inst->e->import_tag_ptrs =
                 runtime_malloc(total_size, error_buf, error_buf_size))) {
        wasm_runtime_free(tags);
        return NULL;
    }

    /* instantiate tags from import section */
    tag = tags;
    import = module->import_tags;
    for (i = 0; i < module->import_tag_count; i++, import++) {
        tag->is_import_tag = true;
        tag->u.tag_import = &import->u.tag;
        tag->type = import->u.tag.type;
        tag->attribute = import->u.tag.attribute;
#if WASM_ENABLE_MULTI_MODULE != 0
        if (import->u.tag.import_module) {
            if (!(tag->import_module_inst = get_sub_module_inst(
                      module_inst, import->u.tag.import_module))) {
                set_error_buf(error_buf, error_buf_size, "unknown tag");
                goto fail;
            }

            if (!(tag->import_tag_inst =
                      wasm_lookup_tag(tag->import_module_inst,
                                      import->u.tag.field_name, NULL))) {
                set_error_buf(error_buf, error_buf_size, "unknown tag");
                goto fail;
            }

            /* Copy the imported tag to current instance */
            module_inst->e->import_tag_ptrs[i] =
                tag->u.tag_import->import_tag_linked;
        }
#endif
        tag++;
    }

    /* instantiate tags from tag section */
    for (i = 0; i < module->tag_count; i++) {
        tag->is_import_tag = false;
        tag->type = module->tags[i]->type;
        tag->u.tag = module->tags[i];

#if WASM_ENABLE_FAST_INTERP != 0
        /* tag->const_cell_num = function->u.func->const_cell_num; */
#endif
        tag++;
    }
    bh_assert((uint32)(tag - tags) == tag_count);

    return tags;

#if WASM_ENABLE_MULTI_MODULE != 0
fail:
    tags_deinstantiate(tags, module_inst->e->import_tag_ptrs);
    /* clean up */
    module_inst->e->import_tag_ptrs = NULL;
    return NULL;
#endif
}
#endif /* end of WASM_ENABLE_TAGS != 0 */

/**
 * Destroy global instances.
 */
static void
globals_deinstantiate(WASMGlobalInstance *globals)
{
    if (globals)
        wasm_runtime_free(globals);
}

static bool
check_global_init_expr(const WASMModule *module, uint32 global_index,
                       char *error_buf, uint32 error_buf_size)
{
    if (global_index >= module->import_global_count + module->global_count) {
        set_error_buf_v(error_buf, error_buf_size, "unknown global %d",
                        global_index);
        return false;
    }

#if WASM_ENABLE_GC == 0
    /**
     * Currently, constant expressions occurring as initializers of
     * globals are further constrained in that contained global.get
     * instructions are only allowed to refer to imported globals.
     *
     * And initializer expression cannot reference a mutable global.
     */
    if (global_index >= module->import_global_count
        || (module->import_globals + global_index)->u.global.type.is_mutable) {
        set_error_buf(error_buf, error_buf_size,
                      "constant expression required");
        return false;
    }
#endif

    return true;
}

#if WASM_ENABLE_GC != 0
/* Instantiate struct global variable recursively */
static WASMStructObjectRef
instantiate_struct_global_recursive(WASMModule *module,
                                    WASMModuleInstance *module_inst,
                                    uint32 type_idx, uint8 flag,
                                    WASMStructNewInitValues *init_values,
                                    char *error_buf, uint32 error_buf_size)
{
    WASMRttType *rtt_type;
    WASMStructObjectRef struct_obj;
    WASMStructType *struct_type;

    struct_type = (WASMStructType *)module->types[type_idx];

    if (!(rtt_type = wasm_rtt_type_new((WASMType *)struct_type, type_idx,
                                       module->rtt_types, module->type_count,
                                       &module->rtt_type_lock))) {
        set_error_buf(error_buf, error_buf_size, "create rtt object failed");
        return NULL;
    }

    if (!(struct_obj = wasm_struct_obj_new_internal(
              module_inst->e->common.gc_heap_handle, rtt_type))) {
        set_error_buf(error_buf, error_buf_size, "create struct object failed");
        return NULL;
    }

    if (flag == INIT_EXPR_TYPE_STRUCT_NEW) {
        uint32 field_idx;
        WASMRefTypeMap *ref_type_map = struct_type->ref_type_maps;

        bh_assert(init_values->count == struct_type->field_count);

        for (field_idx = 0; field_idx < init_values->count; field_idx++) {
            uint8 field_type = struct_type->fields[field_idx].field_type;
            WASMRefType *field_ref_type = NULL;
            if (wasm_is_type_multi_byte_type(field_type)) {
                field_ref_type = ref_type_map->ref_type;
            }

            if (wasm_reftype_is_subtype_of(field_type, field_ref_type,
                                           REF_TYPE_STRUCTREF, NULL,
                                           module->types, module->type_count)
                || wasm_reftype_is_subtype_of(field_type, field_ref_type,
                                              REF_TYPE_ARRAYREF, NULL,
                                              module->types, module->type_count)
                || wasm_reftype_is_subtype_of(
                    field_type, field_ref_type, REF_TYPE_FUNCREF, NULL,
                    module->types, module->type_count)) {
                WASMType *wasm_type;
                int32 heap_type =
                    ref_type_map->ref_type->ref_ht_common.heap_type;
                WASMValue *wasm_value = &init_values->fields[field_idx];
                WASMValue field_value = { 0 };

                bh_assert(heap_type >= 0);
                wasm_type = module->types[heap_type];

                bh_assert(wasm_type->type_flag == WASM_TYPE_STRUCT
                          || wasm_type->type_flag == WASM_TYPE_ARRAY
                          || wasm_type->type_flag == WASM_TYPE_FUNC);

                if (wasm_type->type_flag == WASM_TYPE_STRUCT) {
                    WASMStructNewInitValues *init_values1 =
                        (WASMStructNewInitValues *)wasm_value->data;
                    WASMStructObjectRef field =
                        instantiate_struct_global_recursive(
                            module, module_inst, heap_type,
                            init_values1 ? INIT_EXPR_TYPE_STRUCT_NEW
                                         : INIT_EXPR_TYPE_STRUCT_NEW_DEFAULT,
                            init_values1, error_buf, error_buf_size);
                    field_value.gc_obj = (WASMObjectRef)field;
                    wasm_struct_obj_set_field(struct_obj, field_idx,
                                              &field_value);
                }
                else if (wasm_type->type_flag == WASM_TYPE_ARRAY) {
                    /* struct object's field is an array obj */
                    set_error_buf(error_buf, error_buf_size,
                                  "array as a field in struct object is "
                                  "not supported in constant init expr");
                    return NULL;
                }
                else if (wasm_type->type_flag == WASM_TYPE_FUNC) {
                    WASMFuncObjectRef func_obj = NULL;
                    /* UINT32_MAX indicates that it is a null reference */
                    if (wasm_value->u32 != UINT32_MAX) {
                        if (!(func_obj = wasm_create_func_obj(
                                  module_inst, wasm_value->u32, false,
                                  error_buf, error_buf_size))) {
                            return NULL;
                        }
                    }
                    field_value.gc_obj = (WASMObjectRef)func_obj;
                    wasm_struct_obj_set_field(struct_obj, field_idx,
                                              &field_value);
                }
            }
            else {
                wasm_struct_obj_set_field(struct_obj, field_idx,
                                          &init_values->fields[field_idx]);
            }
            if (wasm_is_type_multi_byte_type(field_type)) {
                ref_type_map++;
            }
        }
    }

    return struct_obj;
}

static WASMArrayObjectRef
instantiate_array_global_recursive(WASMModule *module,
                                   WASMModuleInstance *module_inst,
                                   uint32 type_idx, uint8 flag, uint32 len,
                                   WASMValue *array_init_value,
                                   WASMArrayNewInitValues *init_values,
                                   char *error_buf, uint32 error_buf_size)
{
    WASMRttType *rtt_type;
    WASMArrayObjectRef array_obj;
    WASMArrayType *array_type;

    array_type = (WASMArrayType *)module->types[type_idx];

    if (!(rtt_type = wasm_rtt_type_new((WASMType *)array_type, type_idx,
                                       module->rtt_types, module->type_count,
                                       &module->rtt_type_lock))) {
        set_error_buf(error_buf, error_buf_size, "create rtt object failed");
        return NULL;
    }

    if (!(array_obj =
              wasm_array_obj_new_internal(module_inst->e->common.gc_heap_handle,
                                          rtt_type, len, array_init_value))) {
        set_error_buf(error_buf, error_buf_size, "create array object failed");
        return NULL;
    }

    if (flag == INIT_EXPR_TYPE_ARRAY_NEW_FIXED) {
        uint32 elem_idx;
        uint8 elem_type = array_type->elem_type;
        WASMRefType *elem_ref_type = array_type->elem_ref_type;

        bh_assert(init_values);

        if (wasm_reftype_is_subtype_of(elem_type, elem_ref_type,
                                       REF_TYPE_STRUCTREF, NULL, module->types,
                                       module->type_count)
            || wasm_reftype_is_subtype_of(elem_type, elem_ref_type,
                                          REF_TYPE_ARRAYREF, NULL,
                                          module->types, module->type_count)
            || wasm_reftype_is_subtype_of(elem_type, elem_ref_type,
                                          REF_TYPE_FUNCREF, NULL, module->types,
                                          module->type_count)) {
            /* TODO */
        }

        for (elem_idx = 0; elem_idx < len; elem_idx++) {
            wasm_array_obj_set_elem(array_obj, elem_idx,
                                    &init_values->elem_data[elem_idx]);
        }
    }

    return array_obj;
}
#endif

static bool
get_init_value_recursive(WASMModule *module, InitializerExpression *expr,
                         WASMGlobalInstance *globals, WASMValue *value,
                         char *error_buf, uint32 error_buf_size)
{
    uint8 flag = expr->init_expr_type;
    switch (flag) {
        case INIT_EXPR_TYPE_GET_GLOBAL:
        {
            if (!check_global_init_expr(module, expr->u.unary.v.global_index,
                                        error_buf, error_buf_size)) {
                goto fail;
            }

            *value = globals[expr->u.unary.v.global_index].initial_value;
            break;
        }
        case INIT_EXPR_TYPE_I32_CONST:
        case INIT_EXPR_TYPE_I64_CONST:
        {
            *value = expr->u.unary.v;
            break;
        }
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
        case INIT_EXPR_TYPE_I32_ADD:
        case INIT_EXPR_TYPE_I32_SUB:
        case INIT_EXPR_TYPE_I32_MUL:
        case INIT_EXPR_TYPE_I64_ADD:
        case INIT_EXPR_TYPE_I64_SUB:
        case INIT_EXPR_TYPE_I64_MUL:
        {
            WASMValue l_value, r_value;
            if (!expr->u.binary.l_expr || !expr->u.binary.r_expr) {
                goto fail;
            }
            if (!get_init_value_recursive(module, expr->u.binary.l_expr,
                                          globals, &l_value, error_buf,
                                          error_buf_size)) {
                goto fail;
            }
            if (!get_init_value_recursive(module, expr->u.binary.r_expr,
                                          globals, &r_value, error_buf,
                                          error_buf_size)) {
                goto fail;
            }

            if (flag == INIT_EXPR_TYPE_I32_ADD) {
                value->i32 = l_value.i32 + r_value.i32;
            }
            else if (flag == INIT_EXPR_TYPE_I32_SUB) {
                value->i32 = l_value.i32 - r_value.i32;
            }
            else if (flag == INIT_EXPR_TYPE_I32_MUL) {
                value->i32 = l_value.i32 * r_value.i32;
            }
            else if (flag == INIT_EXPR_TYPE_I64_ADD) {
                value->i64 = l_value.i64 + r_value.i64;
            }
            else if (flag == INIT_EXPR_TYPE_I64_SUB) {
                value->i64 = l_value.i64 - r_value.i64;
            }
            else if (flag == INIT_EXPR_TYPE_I64_MUL) {
                value->i64 = l_value.i64 * r_value.i64;
            }
            break;
        }
#endif /* end of WASM_ENABLE_EXTENDED_CONST_EXPR != 0 */
        default:
            goto fail;
    }
    return true;
fail:
    return false;
}

/**
 * Instantiate globals in a module.
 */
static WASMGlobalInstance *
globals_instantiate(WASMModule *module, WASMModuleInstance *module_inst,
                    char *error_buf, uint32 error_buf_size)
{
    WASMImport *import;
    uint32 global_data_offset = 0;
    uint32 i, global_count = module->import_global_count + module->global_count;
    uint64 total_size = sizeof(WASMGlobalInstance) * (uint64)global_count;
    WASMGlobalInstance *globals, *global;

    if (!(globals = runtime_malloc(total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    /* instantiate globals from import section */
    global = globals;
    import = module->import_globals;
    for (i = 0; i < module->import_global_count; i++, import++) {
        WASMGlobalImport *global_import = &import->u.global;
        global->type = global_import->type.val_type;
        global->is_mutable = global_import->type.is_mutable;
#if WASM_ENABLE_GC != 0
        global->ref_type = global_import->ref_type;
#endif
#if WASM_ENABLE_MULTI_MODULE != 0
        if (global_import->import_module) {
            if (!(global->import_module_inst = get_sub_module_inst(
                      module_inst, global_import->import_module))) {
                set_error_buf(error_buf, error_buf_size, "unknown global");
                goto fail;
            }

            if (!(global->import_global_inst = wasm_lookup_global(
                      global->import_module_inst, global_import->field_name))) {
                set_error_buf(error_buf, error_buf_size, "unknown global");
                goto fail;
            }

            /* The linked global instance has been initialized, we
               just need to copy the value. */
            global->initial_value =
                global_import->import_global_linked->init_expr.u.unary.v;
        }
        else
#endif
        {
            /* native globals share their initial_values in one module */
            bh_memcpy_s(&(global->initial_value), sizeof(WASMValue),
                        &(global_import->global_data_linked),
                        sizeof(WASMValue));
        }
#if WASM_ENABLE_FAST_JIT != 0
        bh_assert(global_data_offset == global_import->data_offset);
#endif
        global->data_offset = global_data_offset;
        global_data_offset += wasm_value_type_size(global->type);

        global++;
    }

    /* instantiate globals from global section */
    for (i = 0; i < module->global_count; i++) {
        InitializerExpression *init_expr = &(module->globals[i].init_expr);
        uint8 flag = init_expr->init_expr_type;

        global->type = module->globals[i].type.val_type;
        global->is_mutable = module->globals[i].type.is_mutable;
#if WASM_ENABLE_FAST_JIT != 0
        bh_assert(global_data_offset == module->globals[i].data_offset);
#endif
        global->data_offset = global_data_offset;
        global_data_offset += wasm_value_type_size(global->type);
#if WASM_ENABLE_GC != 0
        global->ref_type = module->globals[i].ref_type;
#endif

        switch (flag) {
            case INIT_EXPR_TYPE_I32_CONST:
            case INIT_EXPR_TYPE_I64_CONST:
            case INIT_EXPR_TYPE_GET_GLOBAL:
#if WASM_ENABLE_EXTENDED_CONST_EXPR != 0
            case INIT_EXPR_TYPE_I32_ADD:
            case INIT_EXPR_TYPE_I32_SUB:
            case INIT_EXPR_TYPE_I32_MUL:
            case INIT_EXPR_TYPE_I64_ADD:
            case INIT_EXPR_TYPE_I64_SUB:
            case INIT_EXPR_TYPE_I64_MUL:
#endif
            {
                if (!get_init_value_recursive(module, init_expr, globals,
                                              &global->initial_value, error_buf,
                                              error_buf_size)) {
                    goto fail;
                }
                break;
            }
#if WASM_ENABLE_GC != 0
            case INIT_EXPR_TYPE_STRUCT_NEW:
            case INIT_EXPR_TYPE_STRUCT_NEW_DEFAULT:
            {
                WASMStructObjectRef struct_obj;
                WASMStructNewInitValues *init_values = NULL;
                uint32 type_idx;

                if (flag == INIT_EXPR_TYPE_STRUCT_NEW) {
                    init_values =
                        (WASMStructNewInitValues *)init_expr->u.unary.v.data;
                    type_idx = init_values->type_idx;
                }
                else {
                    type_idx = init_expr->u.unary.v.type_index;
                }

                struct_obj = instantiate_struct_global_recursive(
                    module, module_inst, type_idx, flag, init_values, error_buf,
                    error_buf_size);
                if (!struct_obj) {
                    goto fail;
                }

                global->initial_value.gc_obj = (void *)struct_obj;
                break;
            }
            case INIT_EXPR_TYPE_ARRAY_NEW:
            case INIT_EXPR_TYPE_ARRAY_NEW_DEFAULT:
            case INIT_EXPR_TYPE_ARRAY_NEW_FIXED:
            {
                WASMArrayObjectRef array_obj;
                WASMArrayNewInitValues *init_values = NULL;
                WASMValue *array_init_value = NULL, empty_value = { 0 };
                uint32 type_idx, len;

                if (flag == INIT_EXPR_TYPE_ARRAY_NEW_DEFAULT) {
                    type_idx =
                        init_expr->u.unary.v.array_new_default.type_index;
                    len = init_expr->u.unary.v.array_new_default.length;
                    array_init_value = &empty_value;
                }
                else {
                    init_values =
                        (WASMArrayNewInitValues *)init_expr->u.unary.v.data;
                    type_idx = init_values->type_idx;
                    len = init_values->length;

                    if (flag == INIT_EXPR_TYPE_ARRAY_NEW) {
                        array_init_value = init_values->elem_data;
                    }
                }

                array_obj = instantiate_array_global_recursive(
                    module, module_inst, type_idx, flag, len, array_init_value,
                    init_values, error_buf, error_buf_size);

                global->initial_value.gc_obj = (void *)array_obj;
                break;
            }
            case INIT_EXPR_TYPE_I31_NEW:
            {
                global->initial_value.gc_obj =
                    (wasm_obj_t)wasm_i31_obj_new(init_expr->u.unary.v.i32);
                break;
            }
#endif /* end of WASM_ENABLE_GC != 0 */
            default:
                global->initial_value = init_expr->u.unary.v;
                break;
        }

        global++;
    }

    bh_assert((uint32)(global - globals) == global_count);
    bh_assert(global_data_offset == module->global_data_size);
    (void)module_inst;
    return globals;
fail:
    wasm_runtime_free(globals);
    return NULL;
}

/**
 * Return export function count in module export section.
 */
static uint32
get_export_count(const WASMModule *module, uint8 kind)
{
    WASMExport *export = module->exports;
    uint32 count = 0, i;

    for (i = 0; i < module->export_count; i++, export ++)
        if (export->kind == kind)
            count++;

    return count;
}

/**
 * Destroy export function instances.
 */
static void
export_functions_deinstantiate(WASMExportFuncInstance *functions)
{
    if (functions)
        wasm_runtime_free(functions);
}

static int
cmp_export_func_inst(const void *a, const void *b)
{
    const WASMExportFuncInstance *export_func1 =
        (const WASMExportFuncInstance *)a;
    const WASMExportFuncInstance *export_func2 =
        (const WASMExportFuncInstance *)b;

    return strcmp(export_func1->name, export_func2->name);
}

/**
 * Instantiate export functions in a module.
 */
static WASMExportFuncInstance *
export_functions_instantiate(const WASMModule *module,
                             WASMModuleInstance *module_inst,
                             uint32 export_func_count, char *error_buf,
                             uint32 error_buf_size)
{
    WASMExportFuncInstance *export_funcs, *export_func;
    WASMExport *export = module->exports;
    uint32 i;
    uint64 total_size =
        sizeof(WASMExportFuncInstance) * (uint64)export_func_count;

    if (!(export_func = export_funcs =
              runtime_malloc(total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    for (i = 0; i < module->export_count; i++, export ++)
        if (export->kind == EXPORT_KIND_FUNC) {
            export_func->name = export->name;
            export_func->function = &module_inst->e->functions[export->index];
            export_func++;
        }

    bh_assert((uint32)(export_func - export_funcs) == export_func_count);

    qsort(export_funcs, export_func_count, sizeof(WASMExportFuncInstance),
          cmp_export_func_inst);
    return export_funcs;
}

#if WASM_ENABLE_TAGS != 0
/**
 * Destroy export function instances.
 */
static void
export_tags_deinstantiate(WASMExportTagInstance *tags)
{
    if (tags)
        wasm_runtime_free(tags);
}

/**
 * Instantiate export functions in a module.
 */
static WASMExportTagInstance *
export_tags_instantiate(const WASMModule *module,
                        WASMModuleInstance *module_inst,
                        uint32 export_tag_count, char *error_buf,
                        uint32 error_buf_size)
{
    WASMExportTagInstance *export_tags, *export_tag;
    WASMExport *export = module->exports;
    uint32 i;
    uint64 total_size =
        sizeof(WASMExportTagInstance) * (uint64)export_tag_count;

    if (!(export_tag = export_tags =
              runtime_malloc(total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    for (i = 0; i < module->export_count; i++, export ++)
        if (export->kind == EXPORT_KIND_TAG) {
            export_tag->name = export->name;

            bh_assert(module_inst->e->tags);

            export_tag->tag = &module_inst->e->tags[export->index];
            export_tag++;
        }

    bh_assert((uint32)(export_tag - export_tags) == export_tag_count);
    return export_tags;
}
#endif /* end of WASM_ENABLE_TAGS != 0 */

#if WASM_ENABLE_MULTI_MEMORY != 0
static void
export_memories_deinstantiate(WASMExportMemInstance *memories)
{
    if (memories)
        wasm_runtime_free(memories);
}

static WASMExportMemInstance *
export_memories_instantiate(const WASMModule *module,
                            WASMModuleInstance *module_inst,
                            uint32 export_mem_count, char *error_buf,
                            uint32 error_buf_size)
{
    WASMExportMemInstance *export_memories, *export_memory;
    WASMExport *export = module->exports;
    uint32 i;
    uint64 total_size =
        sizeof(WASMExportMemInstance) * (uint64)export_mem_count;

    if (!(export_memory = export_memories =
              runtime_malloc(total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    for (i = 0; i < module->export_count; i++, export ++)
        if (export->kind == EXPORT_KIND_MEMORY) {
            export_memory->name = export->name;
            export_memory->memory = module_inst->memories[export->index];
            export_memory++;
        }

    bh_assert((uint32)(export_memory - export_memories) == export_mem_count);
    return export_memories;
}
#endif /* end of if WASM_ENABLE_MULTI_MEMORY != 0 */

#if WASM_ENABLE_MULTI_MODULE != 0
static void
export_globals_deinstantiate(WASMExportGlobInstance *globals)
{
    if (globals)
        wasm_runtime_free(globals);
}

static WASMExportGlobInstance *
export_globals_instantiate(const WASMModule *module,
                           WASMModuleInstance *module_inst,
                           uint32 export_glob_count, char *error_buf,
                           uint32 error_buf_size)
{
    WASMExportGlobInstance *export_globals, *export_global;
    WASMExport *export = module->exports;
    uint32 i;
    uint64 total_size =
        sizeof(WASMExportGlobInstance) * (uint64)export_glob_count;

    if (!(export_global = export_globals =
              runtime_malloc(total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    for (i = 0; i < module->export_count; i++, export ++)
        if (export->kind == EXPORT_KIND_GLOBAL) {
            export_global->name = export->name;
            export_global->global = &module_inst->e->globals[export->index];
            export_global++;
        }

    bh_assert((uint32)(export_global - export_globals) == export_glob_count);
    return export_globals;
}

#endif /* end of if WASM_ENABLE_MULTI_MODULE != 0 */

static WASMFunctionInstance *
lookup_post_instantiate_func(WASMModuleInstance *module_inst,
                             const char *func_name)
{
    WASMFunctionInstance *func;
    WASMFuncType *func_type;

    if (!(func = wasm_lookup_function(module_inst, func_name)))
        /* Not found */
        return NULL;

    func_type = func->u.func->func_type;
    if (!(func_type->param_count == 0 && func_type->result_count == 0))
        /* Not a valid function type, ignore it */
        return NULL;

    return func;
}

static bool
execute_post_instantiate_functions(WASMModuleInstance *module_inst,
                                   bool is_sub_inst, WASMExecEnv *exec_env_main)
{
    WASMFunctionInstance *start_func = module_inst->e->start_function;
    WASMFunctionInstance *initialize_func = NULL;
    WASMFunctionInstance *post_inst_func = NULL;
    WASMFunctionInstance *call_ctors_func = NULL;
#if WASM_ENABLE_LIBC_WASI != 0
    WASMModule *module = module_inst->module;
#endif
    WASMModuleInstanceCommon *module_inst_main = NULL;
#ifdef OS_ENABLE_HW_BOUND_CHECK
    WASMExecEnv *exec_env_tls = wasm_runtime_get_exec_env_tls();
#endif
    WASMExecEnv *exec_env = NULL, *exec_env_created = NULL;
    bool ret = false;

#if WASM_ENABLE_LIBC_WASI != 0
    /*
     * WASI reactor instances may assume that _initialize will be called by
     * the environment at most once, and that none of their other exports
     * are accessed before that call.
     */
    if (!is_sub_inst && module->import_wasi_api) {
        initialize_func =
            lookup_post_instantiate_func(module_inst, "_initialize");
    }
#endif

    /* Execute possible "__post_instantiate" function if wasm app is
       compiled by emsdk's early version */
    if (!is_sub_inst) {
        post_inst_func =
            lookup_post_instantiate_func(module_inst, "__post_instantiate");
    }

#if WASM_ENABLE_BULK_MEMORY != 0
    /* Only execute the memory init function for main instance since
       the data segments will be dropped once initialized */
    if (!is_sub_inst
#if WASM_ENABLE_LIBC_WASI != 0
        && !module->import_wasi_api
#endif
    ) {
        call_ctors_func =
            lookup_post_instantiate_func(module_inst, "__wasm_call_ctors");
    }
#endif

    if (!start_func && !initialize_func && !post_inst_func
        && !call_ctors_func) {
        /* No post instantiation functions to call */
        return true;
    }

    if (is_sub_inst) {
        bh_assert(exec_env_main);
#ifdef OS_ENABLE_HW_BOUND_CHECK
        /* May come from pthread_create_wrapper, thread_spawn_wrapper and
           wasm_cluster_spawn_exec_env. If it comes from the former two,
           the exec_env_tls must be not NULL and equal to exec_env_main,
           else if it comes from the last one, it may be NULL. */
        if (exec_env_tls)
            bh_assert(exec_env_tls == exec_env_main);
#endif
        exec_env = exec_env_main;

        /* Temporarily replace parent exec_env's module inst to current
           module inst to avoid checking failure when calling the
           wasm functions, and ensure that the exec_env's module inst
           is the correct one. */
        module_inst_main = exec_env_main->module_inst;
        wasm_exec_env_set_module_inst(exec_env,
                                      (WASMModuleInstanceCommon *)module_inst);
    }
    else {
        /* Try using the existing exec_env */
#ifdef OS_ENABLE_HW_BOUND_CHECK
        exec_env = exec_env_tls;
#endif
#if WASM_ENABLE_THREAD_MGR != 0
        if (!exec_env)
            exec_env = wasm_clusters_search_exec_env(
                (WASMModuleInstanceCommon *)module_inst);
#endif
        if (!exec_env) {
            if (!(exec_env = exec_env_created = wasm_exec_env_create(
                      (WASMModuleInstanceCommon *)module_inst,
                      module_inst->default_wasm_stack_size))) {
                wasm_set_exception(module_inst, "allocate memory failed");
                return false;
            }
        }
        else {
            /* Temporarily replace exec_env's module inst with current
               module inst to ensure that the exec_env's module inst
               is the correct one. */
            module_inst_main = exec_env->module_inst;
            wasm_exec_env_set_module_inst(
                exec_env, (WASMModuleInstanceCommon *)module_inst);
        }
    }

    /* Execute start function for both main instance and sub instance */
    if (start_func && !wasm_call_function(exec_env, start_func, 0, NULL)) {
        goto fail;
    }

#if WASM_ENABLE_LIBC_WASI != 0
    if (initialize_func
        && !wasm_call_function(exec_env, initialize_func, 0, NULL)) {
        goto fail;
    }
#else
    (void)initialize_func;
#endif

    if (post_inst_func
        && !wasm_call_function(exec_env, post_inst_func, 0, NULL)) {
        goto fail;
    }

    if (call_ctors_func
        && !wasm_call_function(exec_env, call_ctors_func, 0, NULL)) {
        goto fail;
    }

    ret = true;

fail:
    if (is_sub_inst) {
        /* Restore the parent exec_env's module inst */
        wasm_exec_env_restore_module_inst(exec_env_main, module_inst_main);
    }
    else {
        if (module_inst_main)
            /* Restore the existing exec_env's module inst */
            wasm_exec_env_restore_module_inst(exec_env, module_inst_main);
        if (exec_env_created)
            wasm_exec_env_destroy(exec_env_created);
    }

    return ret;
}

static bool
execute_malloc_function(WASMModuleInstance *module_inst, WASMExecEnv *exec_env,
                        WASMFunctionInstance *malloc_func,
                        WASMFunctionInstance *retain_func, uint64 size,
                        uint64 *p_result)
{
#ifdef OS_ENABLE_HW_BOUND_CHECK
    WASMExecEnv *exec_env_tls = wasm_runtime_get_exec_env_tls();
#endif
    WASMExecEnv *exec_env_created = NULL;
    WASMModuleInstanceCommon *module_inst_old = NULL;
    union {
        uint32 u32[3];
        uint64 u64;
    } argv;
    uint32 argc;
    bool ret;
#if WASM_ENABLE_MEMORY64 != 0
    bool is_memory64 = module_inst->memories[0]->is_memory64;
    if (is_memory64) {
        argc = 2;
        PUT_I64_TO_ADDR(&argv.u64, size);
    }
    else
#endif
    {
        argc = 1;
        argv.u32[0] = (uint32)size;
    }

    /* if __retain is exported, then this module is compiled by
        assemblyscript, the memory should be managed by as's runtime,
        in this case we need to call the retain function after malloc
        the memory */
    if (retain_func) {
        /* the malloc function from assemblyscript is:
            function __new(size: usize, id: u32)
            id = 0 means this is an ArrayBuffer object */
        argv.u32[argc] = 0;
        argc++;
    }

    if (exec_env) {
#ifdef OS_ENABLE_HW_BOUND_CHECK
        if (exec_env_tls) {
            bh_assert(exec_env_tls == exec_env);
        }
#endif
        bh_assert(exec_env->module_inst
                  == (WASMModuleInstanceCommon *)module_inst);
    }
    else {
        /* Try using the existing exec_env */
#ifdef OS_ENABLE_HW_BOUND_CHECK
        exec_env = exec_env_tls;
#endif
#if WASM_ENABLE_THREAD_MGR != 0
        if (!exec_env)
            exec_env = wasm_clusters_search_exec_env(
                (WASMModuleInstanceCommon *)module_inst);
#endif
        if (!exec_env) {
            if (!(exec_env = exec_env_created = wasm_exec_env_create(
                      (WASMModuleInstanceCommon *)module_inst,
                      module_inst->default_wasm_stack_size))) {
                wasm_set_exception(module_inst, "allocate memory failed");
                return false;
            }
        }
        else {
            /* Temporarily replace exec_env's module inst with current
               module inst to ensure that the exec_env's module inst
               is the correct one. */
            module_inst_old = exec_env->module_inst;
            wasm_exec_env_set_module_inst(
                exec_env, (WASMModuleInstanceCommon *)module_inst);
        }
    }

    ret = wasm_call_function(exec_env, malloc_func, argc, argv.u32);

    if (retain_func && ret)
        ret = wasm_call_function(exec_env, retain_func, 1, argv.u32);

    if (module_inst_old)
        /* Restore the existing exec_env's module inst */
        wasm_exec_env_restore_module_inst(exec_env, module_inst_old);

    if (exec_env_created)
        wasm_exec_env_destroy(exec_env_created);

    if (ret) {
#if WASM_ENABLE_MEMORY64 != 0
        if (is_memory64)
            *p_result = argv.u64;
        else
#endif
        {
            *p_result = argv.u32[0];
        }
    }
    return ret;
}

static bool
execute_free_function(WASMModuleInstance *module_inst, WASMExecEnv *exec_env,
                      WASMFunctionInstance *free_func, uint64 offset)
{
#ifdef OS_ENABLE_HW_BOUND_CHECK
    WASMExecEnv *exec_env_tls = wasm_runtime_get_exec_env_tls();
#endif
    WASMExecEnv *exec_env_created = NULL;
    WASMModuleInstanceCommon *module_inst_old = NULL;
    union {
        uint32 u32[2];
        uint64 u64;
    } argv;
    uint32 argc;
    bool ret;

#if WASM_ENABLE_MEMORY64 != 0
    if (module_inst->memories[0]->is_memory64) {
        PUT_I64_TO_ADDR(&argv.u64, offset);
        argc = 2;
    }
    else
#endif
    {
        argv.u32[0] = (uint32)offset;
        argc = 1;
    }

    if (exec_env) {
#ifdef OS_ENABLE_HW_BOUND_CHECK
        if (exec_env_tls) {
            bh_assert(exec_env_tls == exec_env);
        }
#endif
        bh_assert(exec_env->module_inst
                  == (WASMModuleInstanceCommon *)module_inst);
    }
    else {
        /* Try using the existing exec_env */
#ifdef OS_ENABLE_HW_BOUND_CHECK
        exec_env = exec_env_tls;
#endif
#if WASM_ENABLE_THREAD_MGR != 0
        if (!exec_env)
            exec_env = wasm_clusters_search_exec_env(
                (WASMModuleInstanceCommon *)module_inst);
#endif
        if (!exec_env) {
            if (!(exec_env = exec_env_created = wasm_exec_env_create(
                      (WASMModuleInstanceCommon *)module_inst,
                      module_inst->default_wasm_stack_size))) {
                wasm_set_exception(module_inst, "allocate memory failed");
                return false;
            }
        }
        else {
            /* Temporarily replace exec_env's module inst with current
               module inst to ensure that the exec_env's module inst
               is the correct one. */
            module_inst_old = exec_env->module_inst;
            wasm_exec_env_set_module_inst(
                exec_env, (WASMModuleInstanceCommon *)module_inst);
        }
    }

    ret = wasm_call_function(exec_env, free_func, argc, argv.u32);

    if (module_inst_old)
        /* Restore the existing exec_env's module inst */
        wasm_exec_env_restore_module_inst(exec_env, module_inst_old);

    if (exec_env_created)
        wasm_exec_env_destroy(exec_env_created);

    return ret;
}

static bool
check_linked_symbol(WASMModuleInstance *module_inst, char *error_buf,
                    uint32 error_buf_size)
{
    WASMModule *module = module_inst->module;
    uint32 i;

    for (i = 0; i < module->import_function_count; i++) {
        WASMFunctionImport *func =
            &((module->import_functions + i)->u.function);
        if (!func->func_ptr_linked
#if WASM_ENABLE_MULTI_MODULE != 0
            && !func->import_func_linked
#endif
        ) {
            LOG_WARNING("warning: failed to link import function (%s, %s)",
                        func->module_name, func->field_name);
        }
    }

    for (i = 0; i < module->import_global_count; i++) {
        WASMGlobalImport *global = &((module->import_globals + i)->u.global);

        if (!global->is_linked) {
#if WASM_ENABLE_SPEC_TEST != 0
            set_error_buf(error_buf, error_buf_size,
                          "unknown import or incompatible import type");
            return false;
#else
            set_error_buf_v(error_buf, error_buf_size,
                            "failed to link import global (%s, %s)",
                            global->module_name, global->field_name);
            return false;
#endif /* WASM_ENABLE_SPEC_TEST != 0 */
        }
    }

    for (i = 0; i < module->import_table_count; i++) {
        WASMTableImport *table = &((module->import_tables + i)->u.table);

        if (!wasm_runtime_is_built_in_module(table->module_name)
#if WASM_ENABLE_MULTI_MODULE != 0
            && !table->import_table_linked
#endif
        ) {
            set_error_buf_v(error_buf, error_buf_size,
                            "failed to link import table (%s, %s)",
                            table->module_name, table->field_name);
            return false;
        }
    }

    for (i = 0; i < module->import_memory_count; i++) {
        WASMMemoryImport *memory = &((module->import_memories + i)->u.memory);

        if (!wasm_runtime_is_built_in_module(memory->module_name)
#if WASM_ENABLE_MULTI_MODULE != 0
            && !memory->import_memory_linked
#endif
        ) {
            set_error_buf_v(error_buf, error_buf_size,
                            "failed to link import memory (%s, %s)",
                            memory->module_name, memory->field_name);
            return false;
        }
    }

#if WASM_ENABLE_MULTI_MODULE != 0
#if WASM_ENABLE_TAGS != 0
    for (i = 0; i < module->import_tag_count; i++) {
        WASMTagImport *tag = &((module->import_tags + i)->u.tag);

        if (!tag->import_tag_linked) {
            set_error_buf_v(error_buf, error_buf_size,
                            "failed to link import tag (%s, %s)",
                            tag->module_name, tag->field_name);
            return false;
        }
    }
#endif /* WASM_ENABLE_TAGS != 0 */
#endif

    return true;
}

#if WASM_ENABLE_JIT != 0
static bool
init_func_ptrs(WASMModuleInstance *module_inst, WASMModule *module,
               char *error_buf, uint32 error_buf_size)
{
    uint32 i;
    void **func_ptrs;
    uint64 total_size = (uint64)sizeof(void *) * module_inst->e->function_count;

    /* Allocate memory */
    if (!(func_ptrs = module_inst->func_ptrs =
              runtime_malloc(total_size, error_buf, error_buf_size))) {
        return false;
    }

    /* Set import function pointers */
    for (i = 0; i < module->import_function_count; i++, func_ptrs++) {
        WASMFunctionImport *import_func =
            &module->import_functions[i].u.function;
        /* TODO: handle multi module */
        *func_ptrs = import_func->func_ptr_linked;
    }

    /* The defined function pointers will be set in
       wasm_runtime_set_running_mode, no need to set them here */
    return true;
}
#endif /* end of WASM_ENABLE_JIT != 0 */

#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0
static uint32
get_smallest_type_idx(WASMModule *module, WASMFuncType *func_type)
{
    uint32 i;

    for (i = 0; i < module->type_count; i++) {
        if (func_type == (WASMFuncType *)module->types[i])
            return i;
    }

    bh_assert(0);
    return -1;
}

static bool
init_func_type_indexes(WASMModuleInstance *module_inst, char *error_buf,
                       uint32 error_buf_size)
{
    uint32 i;
    uint64 total_size = (uint64)sizeof(uint32) * module_inst->e->function_count;

    /* Allocate memory */
    if (!(module_inst->func_type_indexes =
              runtime_malloc(total_size, error_buf, error_buf_size))) {
        return false;
    }

    for (i = 0; i < module_inst->e->function_count; i++) {
        WASMFunctionInstance *func_inst = module_inst->e->functions + i;
        WASMFuncType *func_type = func_inst->is_import_func
                                      ? func_inst->u.func_import->func_type
                                      : func_inst->u.func->func_type;
        module_inst->func_type_indexes[i] =
            get_smallest_type_idx(module_inst->module, func_type);
    }

    return true;
}
#endif /* end of WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 */

#if WASM_ENABLE_GC != 0
void *
wasm_create_func_obj(WASMModuleInstance *module_inst, uint32 func_idx,
                     bool throw_exce, char *error_buf, uint32 error_buf_size)
{
    WASMModule *module = module_inst->module;
    WASMRttTypeRef rtt_type;
    WASMFuncObjectRef func_obj;
    WASMFuncType *func_type;
    uint32 type_idx;

    if (throw_exce) {
        error_buf = module_inst->cur_exception;
        error_buf_size = sizeof(module_inst->cur_exception);
    }

    if (func_idx >= module->import_function_count + module->function_count) {
        set_error_buf_v(error_buf, error_buf_size, "unknown function %d",
                        func_idx);
        return NULL;
    }

    if (func_idx < module->import_function_count) {
        func_type = module->import_functions[func_idx].u.function.func_type;
        type_idx = module->import_functions[func_idx].u.function.type_idx;
    }
    else {
        func_type = module->functions[func_idx - module->import_function_count]
                        ->func_type;
        type_idx = module->functions[func_idx - module->import_function_count]
                       ->type_idx;
    }

    if (!(rtt_type = wasm_rtt_type_new((WASMType *)func_type, type_idx,
                                       module->rtt_types, module->type_count,
                                       &module->rtt_type_lock))) {
        set_error_buf(error_buf, error_buf_size, "create rtt object failed");
        return NULL;
    }

    if (!(func_obj = wasm_func_obj_new_internal(
              module_inst->e->common.gc_heap_handle, rtt_type, func_idx))) {
        set_error_buf(error_buf, error_buf_size, "create func object failed");
        return NULL;
    }

    return func_obj;
}

static bool
wasm_global_traverse_gc_rootset(WASMModuleInstance *module_inst, void *heap)
{
    WASMGlobalInstance *global = module_inst->e->globals;
    WASMGlobalInstance *global_end = global + module_inst->e->global_count;
    uint8 *global_data = module_inst->global_data;
    WASMObjectRef gc_obj;

    while (global < global_end) {
        if (wasm_is_type_reftype(global->type)) {
            gc_obj = GET_REF_FROM_ADDR(
                (uint32 *)(global_data + global->data_offset));
            if (wasm_obj_is_created_from_heap(gc_obj)) {
                if (0 != mem_allocator_add_root((mem_allocator_t)heap, gc_obj))
                    return false;
            }
        }
        global++;
    }
    return true;
}

static bool
wasm_table_traverse_gc_rootset(WASMModuleInstance *module_inst, void *heap)
{
    WASMTableInstance **tables = module_inst->tables, *table;
    uint32 table_count = module_inst->table_count, i, j;
    WASMObjectRef gc_obj, *table_elems;

    for (i = 0; i < table_count; i++) {
        table = tables[i];
        table_elems = (WASMObjectRef *)table->elems;
        for (j = 0; j < table->cur_size; j++) {
            gc_obj = table_elems[j];
            if (wasm_obj_is_created_from_heap(gc_obj)) {
                if (0 != mem_allocator_add_root((mem_allocator_t)heap, gc_obj))
                    return false;
            }
        }
    }

    return true;
}

static bool
local_object_refs_traverse_gc_rootset(WASMExecEnv *exec_env, void *heap)
{
    WASMLocalObjectRef *r;
    WASMObjectRef gc_obj;

    for (r = exec_env->cur_local_object_ref; r; r = r->prev) {
        gc_obj = r->val;
        if (wasm_obj_is_created_from_heap(gc_obj)) {
            if (0 != mem_allocator_add_root((mem_allocator_t)heap, gc_obj))
                return false;
        }
    }
    return true;
}

bool
wasm_traverse_gc_rootset(WASMExecEnv *exec_env, void *heap)
{
    WASMModuleInstance *module_inst =
        (WASMModuleInstance *)exec_env->module_inst;
    bool ret;

    ret = wasm_global_traverse_gc_rootset(module_inst, heap);
    if (!ret)
        return ret;

    ret = wasm_table_traverse_gc_rootset(module_inst, heap);
    if (!ret)
        return ret;

    ret = local_object_refs_traverse_gc_rootset(exec_env, heap);
    if (!ret)
        return ret;

    return wasm_interp_traverse_gc_rootset(exec_env, heap);
}
#endif /* end of WASM_ENABLE_GC != 0 */

static bool
set_running_mode(WASMModuleInstance *module_inst, RunningMode running_mode,
                 bool first_time_set)
{
    WASMModule *module = module_inst->module;

    if (running_mode == Mode_Default) {
#if WASM_ENABLE_FAST_JIT == 0 && WASM_ENABLE_JIT == 0
        running_mode = Mode_Interp;
#elif WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT == 0
        running_mode = Mode_Fast_JIT;
#elif WASM_ENABLE_FAST_JIT == 0 && WASM_ENABLE_JIT != 0
        running_mode = Mode_LLVM_JIT;
#else /* WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 */
#if WASM_ENABLE_LAZY_JIT == 0
        running_mode = Mode_LLVM_JIT;
#else
        running_mode = Mode_Multi_Tier_JIT;
#endif
#endif
    }

    if (!wasm_runtime_is_running_mode_supported(running_mode))
        return false;

#if !(WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
      && WASM_ENABLE_LAZY_JIT != 0) /* No possible multi-tier JIT */
    (void)first_time_set;
    module_inst->e->running_mode = running_mode;

    if (running_mode == Mode_Interp) {
        /* Do nothing for Mode_Interp */
    }
    else if (running_mode == Mode_Fast_JIT) {
        /* Do nothing for Mode_Fast_JIT since
           module_inst->fast_jit_func_ptrs is same as
           module->fast_jit_func_ptrs */
    }
#if WASM_ENABLE_JIT != 0
    else if (running_mode == Mode_LLVM_JIT) {
        /* Set defined function pointers */
        bh_memcpy_s(module_inst->func_ptrs + module->import_function_count,
                    sizeof(void *) * module->function_count, module->func_ptrs,
                    sizeof(void *) * module->function_count);
    }
#endif
    else {
        bh_assert(0);
    }
#else /* Possible multi-tier JIT */
    os_mutex_lock(&module->instance_list_lock);

    module_inst->e->running_mode = running_mode;

    if (running_mode == Mode_Interp) {
        /* Do nothing for Mode_Interp */
    }
#if WASM_ENABLE_FAST_JIT != 0
    else if (running_mode == Mode_Fast_JIT) {
        JitGlobals *jit_globals = jit_compiler_get_jit_globals();
        uint32 i;

        /* Allocate memory for fast_jit_func_ptrs if needed */
        if (!module_inst->fast_jit_func_ptrs
            || module_inst->fast_jit_func_ptrs == module->fast_jit_func_ptrs) {
            uint64 total_size = (uint64)sizeof(void *) * module->function_count;
            if (!(module_inst->fast_jit_func_ptrs =
                      runtime_malloc(total_size, NULL, 0))) {
                os_mutex_unlock(&module->instance_list_lock);
                return false;
            }
        }

        for (i = 0; i < module->function_count; i++) {
            if (module->functions[i]->fast_jit_jitted_code) {
                /* current fast jit function has been compiled */
                module_inst->fast_jit_func_ptrs[i] =
                    module->functions[i]->fast_jit_jitted_code;
            }
            else {
                module_inst->fast_jit_func_ptrs[i] =
                    jit_globals->compile_fast_jit_and_then_call;
            }
        }
    }
#endif
#if WASM_ENABLE_JIT != 0
    else if (running_mode == Mode_LLVM_JIT) {
        void **llvm_jit_func_ptrs;
        uint32 i;

        /* Notify backend threads to start llvm jit compilation */
        module->enable_llvm_jit_compilation = true;

        /* Wait until llvm jit finishes initialization */
        os_mutex_lock(&module->tierup_wait_lock);
        while (!module->llvm_jit_inited) {
            os_cond_reltimedwait(&module->tierup_wait_cond,
                                 &module->tierup_wait_lock, 10000);
            if (module->orcjit_stop_compiling) {
                /* init_llvm_jit_functions_stage2 failed */
                os_mutex_unlock(&module->tierup_wait_lock);
                os_mutex_unlock(&module->instance_list_lock);
                return false;
            }
        }
        os_mutex_unlock(&module->tierup_wait_lock);

        llvm_jit_func_ptrs =
            module_inst->func_ptrs + module->import_function_count;
        for (i = 0; i < module->function_count; i++) {
            llvm_jit_func_ptrs[i] = module->functions[i]->llvm_jit_func_ptr;
        }
    }
#endif
    else if (running_mode == Mode_Multi_Tier_JIT) {
        /* Notify backend threads to start llvm jit compilation */
        module->enable_llvm_jit_compilation = true;

        /* Free fast_jit_func_ptrs if it is allocated before */
        if (module_inst->fast_jit_func_ptrs
            && module_inst->fast_jit_func_ptrs != module->fast_jit_func_ptrs) {
            wasm_runtime_free(module_inst->fast_jit_func_ptrs);
        }
        module_inst->fast_jit_func_ptrs = module->fast_jit_func_ptrs;

        /* Copy all llvm jit func ptrs from the module */
        bh_memcpy_s(module_inst->func_ptrs + module->import_function_count,
                    sizeof(void *) * module->function_count, module->func_ptrs,
                    sizeof(void *) * module->function_count);
    }
    else {
        bh_assert(0);
    }

    /* Add module instance into module's instance list if not added */
    if (first_time_set) {
        bool found = false;
        WASMModuleInstance *node = module->instance_list;

        while (node) {
            if (node == module_inst) {
                found = true;
                break;
            }
            node = node->e->next;
        }

        if (!found) {
            module_inst->e->next = module->instance_list;
            module->instance_list = module_inst;
        }
    }

    os_mutex_unlock(&module->instance_list_lock);
#endif /* end of !(WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
                   && WASM_ENABLE_LAZY_JIT != 0) */

    (void)module;
    return true;
}

bool
wasm_set_running_mode(WASMModuleInstance *module_inst, RunningMode running_mode)
{
    return set_running_mode(module_inst, running_mode, false);
}

/**
 * Instantiate module
 */
WASMModuleInstance *
wasm_instantiate(WASMModule *module, WASMModuleInstance *parent,
                 WASMExecEnv *exec_env_main, uint32 stack_size,
                 uint32 heap_size, uint32 max_memory_pages, char *error_buf,
                 uint32 error_buf_size)
{
    WASMModuleInstance *module_inst;
    WASMGlobalInstance *globals = NULL, *global;
    WASMTableInstance *first_table;
    uint32 global_count, i;
    uint32 length, extra_info_offset;
    mem_offset_t base_offset;
    uint32 module_inst_struct_size =
        offsetof(WASMModuleInstance, global_table_data.bytes);
    uint64 module_inst_mem_inst_size;
    uint64 total_size, table_size = 0;
    uint8 *global_data, *global_data_end;
#if WASM_ENABLE_MULTI_MODULE != 0
    bool ret = false;
#endif
    const bool is_sub_inst = parent != NULL;

    if (!module)
        return NULL;

    /* Check the heap size */
    heap_size = align_uint(heap_size, 8);
    if (heap_size > APP_HEAP_SIZE_MAX)
        heap_size = APP_HEAP_SIZE_MAX;

    module_inst_mem_inst_size =
        sizeof(WASMMemoryInstance)
        * ((uint64)module->import_memory_count + module->memory_count);

#if WASM_ENABLE_JIT != 0
    /* If the module doesn't have memory, reserve one mem_info space
       with empty content to align with llvm jit compiler */
    if (module_inst_mem_inst_size == 0)
        module_inst_mem_inst_size = (uint64)sizeof(WASMMemoryInstance);
#endif

    /* Size of module inst, memory instances and global data */
    total_size = (uint64)module_inst_struct_size + module_inst_mem_inst_size
                 + module->global_data_size;

    /* Calculate the size of table data */
    for (i = 0; i < module->import_table_count; i++) {
        WASMTableImport *import_table = &module->import_tables[i].u.table;
        table_size += offsetof(WASMTableInstance, elems);
#if WASM_ENABLE_MULTI_MODULE != 0
        table_size += (uint64)sizeof(table_elem_type_t)
                      * import_table->table_type.max_size;
#else
        table_size += (uint64)sizeof(table_elem_type_t)
                      * (import_table->table_type.possible_grow
                             ? import_table->table_type.max_size
                             : import_table->table_type.init_size);
#endif
    }
    for (i = 0; i < module->table_count; i++) {
        WASMTable *table = module->tables + i;
        table_size += offsetof(WASMTableInstance, elems);
#if WASM_ENABLE_MULTI_MODULE != 0
        table_size +=
            (uint64)sizeof(table_elem_type_t) * table->table_type.max_size;
#else
        table_size +=
            (uint64)sizeof(table_elem_type_t)
            * (table->table_type.possible_grow ? table->table_type.max_size
                                               : table->table_type.init_size);
#endif
    }
    total_size += table_size;

    /* The offset of WASMModuleInstanceExtra, make it 8-byte aligned */
    total_size = (total_size + 7LL) & ~7LL;
    extra_info_offset = (uint32)total_size;
    total_size += sizeof(WASMModuleInstanceExtra);

    /* Allocate the memory for module instance with memory instances,
       global data, table data appended at the end */
    if (!(module_inst =
              runtime_malloc(total_size, error_buf, error_buf_size))) {
        return NULL;
    }

    module_inst->module_type = Wasm_Module_Bytecode;
    module_inst->module = module;
    module_inst->e =
        (WASMModuleInstanceExtra *)((uint8 *)module_inst + extra_info_offset);

#if WASM_ENABLE_MULTI_MODULE != 0
    module_inst->e->sub_module_inst_list =
        &module_inst->e->sub_module_inst_list_head;
    ret = wasm_runtime_sub_module_instantiate(
        (WASMModuleCommon *)module, (WASMModuleInstanceCommon *)module_inst,
        stack_size, heap_size, max_memory_pages, error_buf, error_buf_size);
    if (!ret) {
        LOG_DEBUG("build a sub module list failed");
        goto fail;
    }
#endif

#if WASM_ENABLE_BULK_MEMORY != 0
    if (module->data_seg_count > 0) {
        module_inst->e->common.data_dropped =
            bh_bitmap_new(0, module->data_seg_count);
        if (module_inst->e->common.data_dropped == NULL) {
            LOG_DEBUG("failed to allocate bitmaps");
            set_error_buf(error_buf, error_buf_size,
                          "failed to allocate bitmaps");
            goto fail;
        }
        for (i = 0; i < module->data_seg_count; i++) {
            if (!module->data_segments[i]->is_passive)
                bh_bitmap_set_bit(module_inst->e->common.data_dropped, i);
        }
    }
#endif
#if WASM_ENABLE_REF_TYPES != 0
    if (module->table_seg_count > 0) {
        module_inst->e->common.elem_dropped =
            bh_bitmap_new(0, module->table_seg_count);
        if (module_inst->e->common.elem_dropped == NULL) {
            LOG_DEBUG("failed to allocate bitmaps");
            set_error_buf(error_buf, error_buf_size,
                          "failed to allocate bitmaps");
            goto fail;
        }
        for (i = 0; i < module->table_seg_count; i++) {
            if (wasm_elem_is_active(module->table_segments[i].mode)
                || wasm_elem_is_declarative(module->table_segments[i].mode))
                bh_bitmap_set_bit(module_inst->e->common.elem_dropped, i);
        }
    }
#endif

#if WASM_ENABLE_GC != 0
    if (!is_sub_inst) {
        uint32 gc_heap_size = wasm_runtime_get_gc_heap_size_default();

        if (gc_heap_size < GC_HEAP_SIZE_MIN)
            gc_heap_size = GC_HEAP_SIZE_MIN;
        if (gc_heap_size > GC_HEAP_SIZE_MAX)
            gc_heap_size = GC_HEAP_SIZE_MAX;

        module_inst->e->common.gc_heap_pool =
            runtime_malloc(gc_heap_size, error_buf, error_buf_size);
        if (!module_inst->e->common.gc_heap_pool)
            goto fail;

        module_inst->e->common.gc_heap_handle = mem_allocator_create(
            module_inst->e->common.gc_heap_pool, gc_heap_size);
        if (!module_inst->e->common.gc_heap_handle)
            goto fail;
    }
#endif

#if WASM_ENABLE_DUMP_CALL_STACK != 0
    if (!(module_inst->frames = runtime_malloc((uint64)sizeof(Vector),
                                               error_buf, error_buf_size))) {
        goto fail;
    }
#endif

    /* Instantiate global firstly to get the mutable data size */
    global_count = module->import_global_count + module->global_count;
    if (global_count
        && !(globals = globals_instantiate(module, module_inst, error_buf,
                                           error_buf_size))) {
        goto fail;
    }
    module_inst->e->global_count = global_count;
    module_inst->e->globals = globals;
    module_inst->global_data = (uint8 *)module_inst + module_inst_struct_size
                               + module_inst_mem_inst_size;
    module_inst->global_data_size = module->global_data_size;
    first_table = (WASMTableInstance *)(module_inst->global_data
                                        + module->global_data_size);

    module_inst->memory_count =
        module->import_memory_count + module->memory_count;
    module_inst->table_count = module->import_table_count + module->table_count;
    module_inst->e->function_count =
        module->import_function_count + module->function_count;
#if WASM_ENABLE_TAGS != 0
    module_inst->e->tag_count = module->import_tag_count + module->tag_count;
#endif

    /* export */
    module_inst->export_func_count = get_export_count(module, EXPORT_KIND_FUNC);
#if WASM_ENABLE_MULTI_MEMORY != 0
    module_inst->export_memory_count =
        get_export_count(module, EXPORT_KIND_MEMORY);
#endif
#if WASM_ENABLE_MULTI_MODULE != 0
    module_inst->export_table_count =
        get_export_count(module, EXPORT_KIND_TABLE);
#if WASM_ENABLE_TAGS != 0
    module_inst->e->export_tag_count =
        get_export_count(module, EXPORT_KIND_TAG);
#endif
    module_inst->export_global_count =
        get_export_count(module, EXPORT_KIND_GLOBAL);
#endif

    /* Instantiate memories/tables/functions/tags */
    if ((module_inst->memory_count > 0
         && !(module_inst->memories = memories_instantiate(
                  module, module_inst, parent, heap_size, max_memory_pages,
                  error_buf, error_buf_size)))
        || (module_inst->table_count > 0
            && !(module_inst->tables =
                     tables_instantiate(module, module_inst, first_table,
                                        error_buf, error_buf_size)))
        || (module_inst->e->function_count > 0
            && !(module_inst->e->functions = functions_instantiate(
                     module, module_inst, error_buf, error_buf_size)))
        || (module_inst->export_func_count > 0
            && !(module_inst->export_functions = export_functions_instantiate(
                     module, module_inst, module_inst->export_func_count,
                     error_buf, error_buf_size)))
#if WASM_ENABLE_TAGS != 0
        || (module_inst->e->tag_count > 0
            && !(module_inst->e->tags = tags_instantiate(
                     module, module_inst, error_buf, error_buf_size)))
        || (module_inst->e->export_tag_count > 0
            && !(module_inst->e->export_tags = export_tags_instantiate(
                     module, module_inst, module_inst->e->export_tag_count,
                     error_buf, error_buf_size)))
#endif
#if WASM_ENABLE_MULTI_MODULE != 0
        || (module_inst->export_global_count > 0
            && !(module_inst->export_globals = export_globals_instantiate(
                     module, module_inst, module_inst->export_global_count,
                     error_buf, error_buf_size)))
#endif
#if WASM_ENABLE_MULTI_MEMORY != 0
        || (module_inst->export_memory_count > 0
            && !(module_inst->export_memories = export_memories_instantiate(
                     module, module_inst, module_inst->export_memory_count,
                     error_buf, error_buf_size)))
#endif
#if WASM_ENABLE_JIT != 0
        || (module_inst->e->function_count > 0
            && !init_func_ptrs(module_inst, module, error_buf, error_buf_size))
#endif
#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0
        || (module_inst->e->function_count > 0
            && !init_func_type_indexes(module_inst, error_buf, error_buf_size))
#endif
    ) {
        goto fail;
    }
    if (global_count > 0) {
        /* Initialize the global data */
        global_data = module_inst->global_data;
        global_data_end = global_data + module->global_data_size;
        global = globals;
        for (i = 0; i < global_count; i++, global++) {
            switch (global->type) {
                case VALUE_TYPE_I32:
                case VALUE_TYPE_F32:
#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
                case VALUE_TYPE_FUNCREF:
                case VALUE_TYPE_EXTERNREF:
#endif
                    *(int32 *)global_data = global->initial_value.i32;
                    global_data += sizeof(int32);
                    break;
                case VALUE_TYPE_I64:
                case VALUE_TYPE_F64:
                    bh_memcpy_s(global_data,
                                (uint32)(global_data_end - global_data),
                                &global->initial_value.i64, sizeof(int64));
                    global_data += sizeof(int64);
                    break;
#if WASM_ENABLE_SIMD != 0
                case VALUE_TYPE_V128:
                    bh_memcpy_s(global_data, (uint32)sizeof(V128),
                                &global->initial_value.v128, sizeof(V128));
                    global_data += sizeof(V128);
                    break;
#endif
#if WASM_ENABLE_GC != 0
                case VALUE_TYPE_EXTERNREF:
                    /* the initial value should be a null reference */
                    bh_assert(global->initial_value.gc_obj == NULL_REF);
                    STORE_PTR((void **)global_data, NULL_REF);
                    global_data += sizeof(void *);
                    break;
#endif
                default:
                {
#if WASM_ENABLE_GC != 0
                    InitializerExpression *global_init = NULL;
                    bh_assert(wasm_is_type_reftype(global->type));

                    if (i >= module->import_global_count) {
                        global_init =
                            &module->globals[i - module->import_global_count]
                                 .init_expr;
                    }

                    if (global->type == REF_TYPE_NULLFUNCREF
                        || global->type == REF_TYPE_NULLEXTERNREF
                        || global->type == REF_TYPE_NULLREF) {
                        STORE_PTR((void **)global_data, NULL_REF);
                        global_data += sizeof(void *);
                        break;
                    }

                    /* We can't create funcref obj during global instantiation
                     * since the functions are not instantiated yet, so we need
                     * to defer the initialization here */
                    if (global_init
                        && (global_init->init_expr_type
                            == INIT_EXPR_TYPE_FUNCREF_CONST)
                        && wasm_reftype_is_subtype_of(
                            global->type, global->ref_type, REF_TYPE_FUNCREF,
                            NULL, module_inst->module->types,
                            module_inst->module->type_count)) {
                        WASMFuncObjectRef func_obj = NULL;
                        /* UINT32_MAX indicates that it is a null reference */
                        if ((uint32)global->initial_value.i32 != UINT32_MAX) {
                            if (!(func_obj = wasm_create_func_obj(
                                      module_inst, global->initial_value.i32,
                                      false, error_buf, error_buf_size)))
                                goto fail;
                        }
                        STORE_PTR((void **)global_data, func_obj);
                        global_data += sizeof(void *);
                        /* Also update the initial_value since other globals may
                         * refer to this */
                        global->initial_value.gc_obj = (wasm_obj_t)func_obj;
                        break;
                    }
                    else {
                        STORE_PTR((void **)global_data,
                                  global->initial_value.gc_obj);
                        global_data += sizeof(void *);
                        break;
                    }
#endif
                    bh_assert(0);
                    break;
                }
            }
        }
        bh_assert(global_data == global_data_end);
    }

    if (!check_linked_symbol(module_inst, error_buf, error_buf_size)) {
        goto fail;
    }

    /* Initialize the memory data with data segment section */
    for (i = 0; i < module->data_seg_count; i++) {
        WASMMemoryInstance *memory = NULL;
        uint8 *memory_data = NULL;
        uint64 memory_size = 0;
        WASMDataSeg *data_seg = module->data_segments[i];
        WASMValue offset_value;

#if WASM_ENABLE_BULK_MEMORY != 0
        if (data_seg->is_passive)
            continue;
#endif
        if (is_sub_inst)
            /* Ignore setting memory init data if the memory has been
               initialized */
            continue;

        /* has check it in loader */
        memory = module_inst->memories[data_seg->memory_index];
        bh_assert(memory);

        memory_data = memory->memory_data;
        memory_size =
            (uint64)memory->num_bytes_per_page * memory->cur_page_count;
        bh_assert(memory_data || memory_size == 0);

        uint8 offset_flag = data_seg->base_offset.init_expr_type;
        bh_assert(offset_flag == INIT_EXPR_TYPE_GET_GLOBAL
                  || (memory->is_memory64 ? is_valid_i64_offset(offset_flag)
                                          : is_valid_i32_offset(offset_flag)));

        if (!get_init_value_recursive(module, &data_seg->base_offset, globals,
                                      &offset_value, error_buf,
                                      error_buf_size)) {
            goto fail;
        }

        if (offset_flag == INIT_EXPR_TYPE_GET_GLOBAL) {
            if (!globals
                || globals[data_seg->base_offset.u.unary.v.global_index].type
                       != (memory->is_memory64 ? VALUE_TYPE_I64
                                               : VALUE_TYPE_I32)) {
                set_error_buf(error_buf, error_buf_size,
                              "data segment does not fit");
                goto fail;
            }
        }

#if WASM_ENABLE_MEMORY64 != 0
        if (memory->is_memory64) {
            base_offset = (uint64)offset_value.i64;
        }
        else
#endif
        {
            base_offset = (uint32)offset_value.i32;
        }
        /* check offset */
        if (base_offset > memory_size) {
#if WASM_ENABLE_MEMORY64 != 0
            LOG_DEBUG("base_offset(%" PRIu64 ") > memory_size(%" PRIu64 ")",
                      base_offset, memory_size);
#else
            LOG_DEBUG("base_offset(%u) > memory_size(%" PRIu64 ")", base_offset,
                      memory_size);
#endif
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds memory access");
#else
            set_error_buf(error_buf, error_buf_size,
                          "data segment does not fit");
#endif
            goto fail;
        }

        /* check offset + length(could be zero) */
        length = data_seg->data_length;
        if ((uint64)base_offset + length > memory_size) {
#if WASM_ENABLE_MEMORY64 != 0
            LOG_DEBUG("base_offset(%" PRIu64
                      ") + length(%d) > memory_size(%" PRIu64 ")",
                      base_offset, length, memory_size);
#else
            LOG_DEBUG("base_offset(%u) + length(%d) > memory_size(%" PRIu64 ")",
                      base_offset, length, memory_size);
#endif
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds memory access");
#else
            set_error_buf(error_buf, error_buf_size,
                          "data segment does not fit");
#endif
            goto fail;
        }

        if (memory_data) {
            bh_memcpy_s(memory_data + base_offset,
                        (uint32)(memory_size - base_offset), data_seg->data,
                        length);
        }
    }

#if WASM_ENABLE_JIT != 0 && WASM_ENABLE_SHARED_HEAP != 0
#if UINTPTR_MAX == UINT64_MAX
    module_inst->e->shared_heap_start_off.u64 = UINT64_MAX;
#else
    module_inst->e->shared_heap_start_off.u32[0] = UINT32_MAX;
#endif
    module_inst->e->shared_heap = NULL;
#endif

#if WASM_ENABLE_GC != 0
    /* Initialize the table data with init expr */
    for (i = 0; i < module->table_count; i++) {
        WASMTable *table = module->tables + i;
        WASMTableInstance *table_inst = module_inst->tables[i];
        table_elem_type_t *table_data;
        uint32 j;

        if (table->init_expr.init_expr_type == 0) {
            /* No table initializer */
            continue;
        }

        table_data = table_inst->elems;

        bh_assert(
            table->init_expr.init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL
            || table->init_expr.init_expr_type == INIT_EXPR_TYPE_FUNCREF_CONST
            || table->init_expr.init_expr_type == INIT_EXPR_TYPE_REFNULL_CONST);

        if (table->init_expr.init_expr_type == INIT_EXPR_TYPE_GET_GLOBAL) {
            if (!check_global_init_expr(module,
                                        table->init_expr.u.unary.v.global_index,
                                        error_buf, error_buf_size)) {
                goto fail;
            }

            table->init_expr.u.unary.v.gc_obj =
                globals[table->init_expr.u.unary.v.global_index]
                    .initial_value.gc_obj;
        }
        else if (table->init_expr.init_expr_type
                 == INIT_EXPR_TYPE_FUNCREF_CONST) {
            uint32 func_idx = table->init_expr.u.unary.v.ref_index;
            if (func_idx != UINT32_MAX) {
                if (!(table->init_expr.u.unary.v.gc_obj =
                          wasm_create_func_obj(module_inst, func_idx, false,
                                               error_buf, error_buf_size)))
                    goto fail;
            }
            else {
                table->init_expr.u.unary.v.gc_obj = NULL_REF;
            }
        }
        else if (table->init_expr.init_expr_type
                 == INIT_EXPR_TYPE_REFNULL_CONST) {
            table->init_expr.u.unary.v.gc_obj = NULL_REF;
        }

        LOG_DEBUG("Init table [%d] elements from [%d] to [%d] as: %p", i, 0,
                  table_inst->cur_size,
                  (void *)table->init_expr.u.unary.v.gc_obj);
        for (j = 0; j < table_inst->cur_size; j++) {
            *(table_data + j) = table->init_expr.u.unary.v.gc_obj;
        }
    }
#endif /* end of WASM_ENABLE_GC != 0 */

    /* Initialize the table data with table segment section */
    for (i = 0; module_inst->table_count > 0 && i < module->table_seg_count;
         i++) {
        WASMTableSeg *table_seg = module->table_segments + i;
        /* has check it in loader */
        WASMTableInstance *table = module_inst->tables[table_seg->table_index];
        table_elem_type_t *table_data;
        WASMValue offset_value;
        uint32 j;
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
        uint8 tbl_elem_type;
        uint32 tbl_init_size, tbl_max_size;
#endif
#if WASM_ENABLE_GC != 0
        WASMRefType *tbl_elem_ref_type;
#endif

        bh_assert(table);

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
        (void)wasm_runtime_get_table_inst_elem_type(
            (WASMModuleInstanceCommon *)module_inst, table_seg->table_index,
            &tbl_elem_type,
#if WASM_ENABLE_GC != 0
            &tbl_elem_ref_type,
#endif
            &tbl_init_size, &tbl_max_size);

#if WASM_ENABLE_GC == 0
        if (tbl_elem_type != VALUE_TYPE_FUNCREF
            && tbl_elem_type != VALUE_TYPE_EXTERNREF) {
            set_error_buf(error_buf, error_buf_size,
                          "type mismatch: elements segment does not fit");
            goto fail;
        }
#elif WASM_ENABLE_GC != 0
        if (!wasm_elem_is_declarative(table_seg->mode)
            && !wasm_reftype_is_subtype_of(
                table_seg->elem_type, table_seg->elem_ref_type,
                table->elem_type, table->elem_ref_type.elem_ref_type,
                module->types, module->type_count)) {
            set_error_buf(error_buf, error_buf_size,
                          "type mismatch: elements segment does not fit");
            goto fail;
        }
#endif
        (void)tbl_init_size;
        (void)tbl_max_size;
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */

        table_data = table->elems;
#if WASM_ENABLE_MULTI_MODULE != 0
        if (table_seg->table_index < module->import_table_count
            && module_inst->e->table_insts_linked[table_seg->table_index]) {
            table_data =
                module_inst->e->table_insts_linked[table_seg->table_index]
                    ->elems;
        }
#endif
        bh_assert(table_data);

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
        if (!wasm_elem_is_active(table_seg->mode))
            continue;
#endif

        uint8 offset_flag = table_seg->base_offset.init_expr_type;
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
        bh_assert(offset_flag == INIT_EXPR_TYPE_GET_GLOBAL
                  || offset_flag == INIT_EXPR_TYPE_FUNCREF_CONST
                  || offset_flag == INIT_EXPR_TYPE_REFNULL_CONST
                  || is_valid_i32_offset(offset_flag));
#else
        bh_assert(offset_flag == INIT_EXPR_TYPE_GET_GLOBAL
                  || is_valid_i32_offset(offset_flag));
#endif

        if (!get_init_value_recursive(module, &table_seg->base_offset, globals,
                                      &offset_value, error_buf,
                                      error_buf_size)) {
            goto fail;
        }

        if (offset_flag == INIT_EXPR_TYPE_GET_GLOBAL) {
            if (!globals
                || globals[table_seg->base_offset.u.unary.v.global_index].type
                       != VALUE_TYPE_I32) {
                set_error_buf(error_buf, error_buf_size,
                              "type mismatch: elements segment does not fit");
                goto fail;
            }
        }

        /* check offset since length might negative */
        if ((uint32)offset_value.i32 > table->cur_size) {
            LOG_DEBUG("base_offset(%d) > table->cur_size(%d)", offset_value.i32,
                      table->cur_size);
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds table access");
#else
            set_error_buf(error_buf, error_buf_size,
                          "type mismatch: elements segment does not fit");
#endif
            goto fail;
        }

        /* check offset + length(could be zero) */
        length = table_seg->value_count;
        if ((uint32)offset_value.i32 + length > table->cur_size) {
            LOG_DEBUG("base_offset(%d) + length(%d)> table->cur_size(%d)",
                      offset_value.i32, length, table->cur_size);
#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
            set_error_buf(error_buf, error_buf_size,
                          "out of bounds table access");
#else
            set_error_buf(error_buf, error_buf_size,
                          "type mismatch: elements segment does not fit");
#endif
            goto fail;
        }

        for (j = 0; j < length; j++) {
            InitializerExpression *init_expr = &table_seg->init_values[j];
            uint8 flag = init_expr->init_expr_type;
            void *ref = NULL;

            /* const and get global init values should be resolved during
             * loading */
            bh_assert((flag == INIT_EXPR_TYPE_GET_GLOBAL)
                      || (flag == INIT_EXPR_TYPE_REFNULL_CONST)
                      || ((flag >= INIT_EXPR_TYPE_FUNCREF_CONST)
                          && (flag <= INIT_EXPR_TYPE_EXTERN_CONVERT_ANY)));

            switch (flag) {
                case INIT_EXPR_TYPE_REFNULL_CONST:
                    ref = NULL;
                    break;
                case INIT_EXPR_TYPE_FUNCREF_CONST:
                {
#if WASM_ENABLE_GC == 0
                    ref = (void *)(uintptr_t)init_expr->u.unary.v.ref_index;
#else
                    WASMFuncObjectRef func_obj;
                    uint32 func_idx = init_expr->u.unary.v.ref_index;
                    /* UINT32_MAX indicates that it is a null reference */
                    if (func_idx != UINT32_MAX) {
                        if (!(func_obj = wasm_create_func_obj(
                                  module_inst, func_idx, false, error_buf,
                                  error_buf_size))) {
                            goto fail;
                        }
                        ref = func_obj;
                    }
                    else {
                        ref = NULL_REF;
                    }
#endif /* end of WASM_ENABLE_GC != 0 */
                    break;
                }
#if WASM_ENABLE_GC != 0
                case INIT_EXPR_TYPE_GET_GLOBAL:
                {
                    if (!check_global_init_expr(
                            module, init_expr->u.unary.v.global_index,
                            error_buf, error_buf_size)) {
                        goto fail;
                    }

                    ref = globals[init_expr->u.unary.v.global_index]
                              .initial_value.gc_obj;
                    break;
                }
                case INIT_EXPR_TYPE_STRUCT_NEW:
                case INIT_EXPR_TYPE_STRUCT_NEW_DEFAULT:
                {
                    WASMRttType *rtt_type;
                    WASMStructObjectRef struct_obj;
                    WASMStructType *struct_type;
                    WASMStructNewInitValues *init_values = NULL;
                    uint32 type_idx;

                    if (flag == INIT_EXPR_TYPE_STRUCT_NEW) {
                        init_values = (WASMStructNewInitValues *)
                                          init_expr->u.unary.v.data;
                        type_idx = init_values->type_idx;
                    }
                    else {
                        type_idx = init_expr->u.unary.v.type_index;
                    }

                    struct_type = (WASMStructType *)module->types[type_idx];

                    if (!(rtt_type = wasm_rtt_type_new(
                              (WASMType *)struct_type, type_idx,
                              module->rtt_types, module->type_count,
                              &module->rtt_type_lock))) {
                        set_error_buf(error_buf, error_buf_size,
                                      "create rtt object failed");
                        goto fail;
                    }

                    if (!(struct_obj = wasm_struct_obj_new_internal(
                              module_inst->e->common.gc_heap_handle,
                              rtt_type))) {
                        set_error_buf(error_buf, error_buf_size,
                                      "create struct object failed");
                        goto fail;
                    }

                    if (flag == INIT_EXPR_TYPE_STRUCT_NEW) {
                        uint32 field_idx;

                        bh_assert(init_values->count
                                  == struct_type->field_count);

                        for (field_idx = 0; field_idx < init_values->count;
                             field_idx++) {
                            wasm_struct_obj_set_field(
                                struct_obj, field_idx,
                                &init_values->fields[field_idx]);
                        }
                    }

                    ref = struct_obj;
                    break;
                }
                case INIT_EXPR_TYPE_ARRAY_NEW:
                case INIT_EXPR_TYPE_ARRAY_NEW_DEFAULT:
                case INIT_EXPR_TYPE_ARRAY_NEW_FIXED:
                {
                    WASMRttType *rtt_type;
                    WASMArrayObjectRef array_obj;
                    WASMArrayType *array_type;
                    WASMArrayNewInitValues *init_values = NULL;
                    WASMValue *arr_init_val = NULL, empty_val = { 0 };
                    uint32 type_idx, len;

                    if (flag == INIT_EXPR_TYPE_ARRAY_NEW_DEFAULT) {
                        type_idx =
                            init_expr->u.unary.v.array_new_default.type_index;
                        len = init_expr->u.unary.v.array_new_default.length;
                        arr_init_val = &empty_val;
                    }
                    else {
                        init_values =
                            (WASMArrayNewInitValues *)init_expr->u.unary.v.data;
                        type_idx = init_values->type_idx;
                        len = init_values->length;

                        if (flag == INIT_EXPR_TYPE_ARRAY_NEW_FIXED) {
                            arr_init_val = init_values->elem_data;
                        }
                    }

                    array_type = (WASMArrayType *)module->types[type_idx];

                    if (!(rtt_type = wasm_rtt_type_new(
                              (WASMType *)array_type, type_idx,
                              module->rtt_types, module->type_count,
                              &module->rtt_type_lock))) {
                        set_error_buf(error_buf, error_buf_size,
                                      "create rtt object failed");
                        goto fail;
                    }

                    if (!(array_obj = wasm_array_obj_new_internal(
                              module_inst->e->common.gc_heap_handle, rtt_type,
                              len, arr_init_val))) {
                        set_error_buf(error_buf, error_buf_size,
                                      "create array object failed");
                        goto fail;
                    }

                    if (flag == INIT_EXPR_TYPE_ARRAY_NEW_FIXED) {
                        uint32 elem_idx;

                        bh_assert(init_values);

                        for (elem_idx = 0; elem_idx < len; elem_idx++) {
                            wasm_array_obj_set_elem(
                                array_obj, elem_idx,
                                &init_values->elem_data[elem_idx]);
                        }
                    }

                    ref = array_obj;

                    break;
                }
                case INIT_EXPR_TYPE_I31_NEW:
                {
                    ref =
                        (wasm_obj_t)wasm_i31_obj_new(init_expr->u.unary.v.i32);
                    break;
                }
#endif /* end of WASM_ENABLE_GC != 0 */
            }

            *(table_data + offset_value.i32 + j) = (table_elem_type_t)ref;
        }
    }

    /* Initialize the thread related data */
    if (stack_size == 0)
        stack_size = DEFAULT_WASM_STACK_SIZE;

    module_inst->default_wasm_stack_size = stack_size;

    if (module->malloc_function != (uint32)-1) {
        module_inst->e->malloc_function =
            &module_inst->e->functions[module->malloc_function];
    }

    if (module->free_function != (uint32)-1) {
        module_inst->e->free_function =
            &module_inst->e->functions[module->free_function];
    }

    if (module->retain_function != (uint32)-1) {
        module_inst->e->retain_function =
            &module_inst->e->functions[module->retain_function];
    }

#if WASM_ENABLE_LIBC_WASI != 0
    /* The sub-instance will get the wasi_ctx from main-instance */
    if (!is_sub_inst) {
        if (!wasm_runtime_init_wasi(
                (WASMModuleInstanceCommon *)module_inst,
                module->wasi_args.dir_list, module->wasi_args.dir_count,
                module->wasi_args.map_dir_list, module->wasi_args.map_dir_count,
                module->wasi_args.env, module->wasi_args.env_count,
                module->wasi_args.addr_pool, module->wasi_args.addr_count,
                module->wasi_args.ns_lookup_pool,
                module->wasi_args.ns_lookup_count, module->wasi_args.argv,
                module->wasi_args.argc, module->wasi_args.stdio[0],
                module->wasi_args.stdio[1], module->wasi_args.stdio[2],
                error_buf, error_buf_size)) {
            goto fail;
        }
    }
#endif

#if WASM_ENABLE_DEBUG_INTERP != 0
    if (!is_sub_inst) {
        /* Add module instance into module's instance list */
        os_mutex_lock(&module->instance_list_lock);
        if (module->instance_list) {
            LOG_WARNING(
                "warning: multiple instances referencing to the same module "
                "may cause unexpected behaviour during debugging");
        }
        module_inst->e->next = module->instance_list;
        module->instance_list = module_inst;
        os_mutex_unlock(&module->instance_list_lock);
    }
#endif

    /* Set running mode before executing wasm functions */
    if (!set_running_mode(module_inst, wasm_runtime_get_default_running_mode(),
                          true)) {
        set_error_buf(error_buf, error_buf_size,
                      "set instance running mode failed");
        goto fail;
    }

    if (module->start_function != (uint32)-1) {
        /* TODO: fix start function can be import function issue */
        if (module->start_function >= module->import_function_count)
            module_inst->e->start_function =
                &module_inst->e->functions[module->start_function];
    }

    if (!execute_post_instantiate_functions(module_inst, is_sub_inst,
                                            exec_env_main)) {
        set_error_buf(error_buf, error_buf_size, module_inst->cur_exception);
        goto fail;
    }

#if WASM_ENABLE_MEMORY_TRACING != 0
    wasm_runtime_dump_module_inst_mem_consumption(
        (WASMModuleInstanceCommon *)module_inst);
#endif

    (void)global_data_end;
    return module_inst;

fail:
    wasm_deinstantiate(module_inst, false);
    return NULL;
}

#if WASM_ENABLE_DUMP_CALL_STACK != 0
static void
destroy_c_api_frames(Vector *frames)
{
    WASMCApiFrame frame = { 0 };
    uint32 i, total_frames, ret;

    total_frames = (uint32)bh_vector_size(frames);

    for (i = 0; i < total_frames; i++) {
        ret = bh_vector_get(frames, i, &frame);
        bh_assert(ret);

        if (frame.lp)
            wasm_runtime_free(frame.lp);
    }

    ret = bh_vector_destroy(frames);
    bh_assert(ret);
    (void)ret;
}
#endif

void
wasm_deinstantiate(WASMModuleInstance *module_inst, bool is_sub_inst)
{
    if (!module_inst)
        return;

    if (module_inst->exec_env_singleton) {
        /* wasm_exec_env_destroy will call
           wasm_cluster_wait_for_all_except_self to wait for other
           threads, so as to destroy their exec_envs and module
           instances first, and avoid accessing the shared resources
           of current module instance after it is deinstantiated. */
        wasm_exec_env_destroy(module_inst->exec_env_singleton);
    }

#if WASM_ENABLE_DEBUG_INTERP != 0                         \
    || (WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
        && WASM_ENABLE_LAZY_JIT != 0)
    /* Remove instance from module's instance list before freeing
       func_ptrs and fast_jit_func_ptrs of the instance, to avoid
       accessing the freed memory in the jit backend compilation
       threads */
    {
        WASMModule *module = module_inst->module;
        WASMModuleInstance *instance_prev = NULL, *instance;
        os_mutex_lock(&module->instance_list_lock);

        instance = module->instance_list;
        while (instance) {
            if (instance == module_inst) {
                if (!instance_prev)
                    module->instance_list = instance->e->next;
                else
                    instance_prev->e->next = instance->e->next;
                break;
            }
            instance_prev = instance;
            instance = instance->e->next;
        }

        os_mutex_unlock(&module->instance_list_lock);
    }
#endif

#if WASM_ENABLE_JIT != 0
    if (module_inst->func_ptrs)
        wasm_runtime_free(module_inst->func_ptrs);
#endif

#if WASM_ENABLE_FAST_JIT != 0 && WASM_ENABLE_JIT != 0 \
    && WASM_ENABLE_LAZY_JIT != 0
    if (module_inst->fast_jit_func_ptrs
        && module_inst->fast_jit_func_ptrs
               != module_inst->module->fast_jit_func_ptrs)
        wasm_runtime_free(module_inst->fast_jit_func_ptrs);
#endif

#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0
    if (module_inst->func_type_indexes)
        wasm_runtime_free(module_inst->func_type_indexes);
#endif

#if WASM_ENABLE_MULTI_MODULE != 0
    wasm_runtime_sub_module_deinstantiate(
        (WASMModuleInstanceCommon *)module_inst);
#endif

    if (module_inst->memory_count > 0)
        memories_deinstantiate(module_inst, module_inst->memories,
                               module_inst->memory_count);

    if (module_inst->import_func_ptrs) {
        wasm_runtime_free(module_inst->import_func_ptrs);
    }

    tables_deinstantiate(module_inst);
    functions_deinstantiate(module_inst->e->functions);
#if WASM_ENABLE_TAGS != 0
    tags_deinstantiate(module_inst->e->tags, module_inst->e->import_tag_ptrs);
#endif
    globals_deinstantiate(module_inst->e->globals);
    export_functions_deinstantiate(module_inst->export_functions);
#if WASM_ENABLE_TAGS != 0
    export_tags_deinstantiate(module_inst->e->export_tags);
#endif

#if WASM_ENABLE_MULTI_MODULE != 0
    export_globals_deinstantiate(module_inst->export_globals);
#endif

#if WASM_ENABLE_MULTI_MEMORY != 0
    export_memories_deinstantiate(module_inst->export_memories);
#endif

#if WASM_ENABLE_GC == 0 && WASM_ENABLE_REF_TYPES != 0
    wasm_externref_cleanup((WASMModuleInstanceCommon *)module_inst);
#endif

#if WASM_ENABLE_GC != 0
    if (!is_sub_inst) {
        if (module_inst->e->common.gc_heap_handle)
            mem_allocator_destroy(module_inst->e->common.gc_heap_handle);
        if (module_inst->e->common.gc_heap_pool)
            wasm_runtime_free(module_inst->e->common.gc_heap_pool);
    }
#endif

#if WASM_ENABLE_DUMP_CALL_STACK != 0
    if (module_inst->frames) {
        destroy_c_api_frames(module_inst->frames);
        wasm_runtime_free(module_inst->frames);
        module_inst->frames = NULL;
    }
#endif

    if (module_inst->c_api_func_imports)
        wasm_runtime_free(module_inst->c_api_func_imports);

    if (!is_sub_inst) {
        wasm_native_call_context_dtors((WASMModuleInstanceCommon *)module_inst);
    }

#if WASM_ENABLE_BULK_MEMORY != 0
    bh_bitmap_delete(module_inst->e->common.data_dropped);
#endif
#if WASM_ENABLE_REF_TYPES != 0
    bh_bitmap_delete(module_inst->e->common.elem_dropped);
#endif

    wasm_runtime_free(module_inst);
}

WASMFunctionInstance *
wasm_lookup_function(const WASMModuleInstance *module_inst, const char *name)
{
    WASMExportFuncInstance key = { .name = (char *)name };
    WASMExportFuncInstance *export_func_inst;

    if (!module_inst->export_functions)
        return NULL;

    export_func_inst = bsearch(
        &key, module_inst->export_functions, module_inst->export_func_count,
        sizeof(WASMExportFuncInstance), cmp_export_func_inst);

    if (!export_func_inst)
        return NULL;

    return export_func_inst->function;
}

WASMMemoryInstance *
wasm_lookup_memory(const WASMModuleInstance *module_inst, const char *name)
{
#if WASM_ENABLE_MULTI_MEMORY != 0
    uint32 i;
    for (i = 0; i < module_inst->export_memory_count; i++)
        if (!strcmp(module_inst->export_memories[i].name, name))
            return module_inst->export_memories[i].memory;
    return NULL;
#else
    (void)module_inst->export_memories;
    if (!module_inst->memories)
        return NULL;
    return module_inst->memories[0];
#endif
}

#if WASM_ENABLE_MULTI_MODULE != 0
WASMGlobalInstance *
wasm_lookup_global(const WASMModuleInstance *module_inst, const char *name)
{
    uint32 i;
    for (i = 0; i < module_inst->export_global_count; i++)
        if (!strcmp(module_inst->export_globals[i].name, name))
            return module_inst->export_globals[i].global;
    return NULL;
}

WASMTableInstance *
wasm_lookup_table(const WASMModuleInstance *module_inst, const char *name)
{
    /**
     * using a strong assumption that one module instance only has
     * one table instance
     */
    (void)module_inst->export_tables;
    return module_inst->tables[0];
}

#if WASM_ENABLE_TAGS != 0
WASMTagInstance *
wasm_lookup_tag(const WASMModuleInstance *module_inst, const char *name,
                const char *signature)
{
    uint32 i;
    for (i = 0; i < module_inst->e->export_tag_count; i++)
        if (!strcmp(module_inst->e->export_tags[i].name, name))
            return module_inst->e->export_tags[i].tag;
    (void)signature;
    return NULL;
}
#endif

#endif

#ifdef OS_ENABLE_HW_BOUND_CHECK
static void
call_wasm_with_hw_bound_check(WASMModuleInstance *module_inst,
                              WASMExecEnv *exec_env,
                              WASMFunctionInstance *function, unsigned argc,
                              uint32 argv[])
{
    WASMExecEnv *exec_env_tls = wasm_runtime_get_exec_env_tls();
    WASMJmpBuf jmpbuf_node = { 0 }, *jmpbuf_node_pop;
    WASMRuntimeFrame *prev_frame = wasm_exec_env_get_cur_frame(exec_env);
    uint8 *prev_top = exec_env->wasm_stack.top;
#ifdef BH_PLATFORM_WINDOWS
    int result;
    bool has_exception;
    char exception[EXCEPTION_BUF_LEN];
#endif
    bool ret = true;

    if (!exec_env_tls) {
        if (!os_thread_signal_inited()) {
            wasm_set_exception(module_inst, "thread signal env not inited");
            return;
        }

        /* Set thread handle and stack boundary if they haven't been set */
        wasm_exec_env_set_thread_info(exec_env);

        wasm_runtime_set_exec_env_tls(exec_env);
    }
    else {
        if (exec_env_tls != exec_env) {
            wasm_set_exception(module_inst, "invalid exec env");
            return;
        }
    }

    /* Check native stack overflow firstly to ensure we have enough
       native stack to run the following codes before actually calling
       the aot function in invokeNative function. */
    if (!wasm_runtime_detect_native_stack_overflow(exec_env)) {
        return;
    }

    wasm_exec_env_push_jmpbuf(exec_env, &jmpbuf_node);

    if (os_setjmp(jmpbuf_node.jmpbuf) == 0) {
#ifndef BH_PLATFORM_WINDOWS
        wasm_interp_call_wasm(module_inst, exec_env, function, argc, argv);
#else
        __try {
            wasm_interp_call_wasm(module_inst, exec_env, function, argc, argv);
        } __except (wasm_copy_exception(module_inst, NULL)
                        ? EXCEPTION_EXECUTE_HANDLER
                        : EXCEPTION_CONTINUE_SEARCH) {
            /* Exception was thrown in wasm_exception_handler */
            ret = false;
        }
        has_exception = wasm_copy_exception(module_inst, exception);
        if (has_exception && strstr(exception, "native stack overflow")) {
            /* After a stack overflow, the stack was left
               in a damaged state, let the CRT repair it */
            result = _resetstkoflw();
            bh_assert(result != 0);
        }
#endif
    }
    else {
        /* Exception has been set in signal handler before calling longjmp */
        ret = false;
    }

    /* Note: can't check wasm_get_exception(module_inst) here, there may be
     * exception which is not caught by hardware (e.g. uninitialized elements),
     * then the stack-frame is already freed inside wasm_interp_call_wasm */
    if (!ret) {
#if WASM_ENABLE_DUMP_CALL_STACK != 0
        if (wasm_interp_create_call_stack(exec_env)) {
            wasm_interp_dump_call_stack(exec_env, true, NULL, 0);
        }
#endif
        /* Restore operand frames */
        wasm_exec_env_set_cur_frame(exec_env, prev_frame);
        exec_env->wasm_stack.top = prev_top;
    }

    jmpbuf_node_pop = wasm_exec_env_pop_jmpbuf(exec_env);
    bh_assert(&jmpbuf_node == jmpbuf_node_pop);
    if (!exec_env->jmpbuf_stack_top) {
        wasm_runtime_set_exec_env_tls(NULL);
    }
    if (!ret) {
        os_sigreturn();
        os_signal_unmask();
    }
    (void)jmpbuf_node_pop;
}
#define interp_call_wasm call_wasm_with_hw_bound_check
#else
#define interp_call_wasm wasm_interp_call_wasm
#endif

bool
wasm_call_function(WASMExecEnv *exec_env, WASMFunctionInstance *function,
                   unsigned argc, uint32 argv[])
{
    WASMModuleInstance *module_inst =
        (WASMModuleInstance *)exec_env->module_inst;

#ifndef OS_ENABLE_HW_BOUND_CHECK
    /* Set thread handle and stack boundary */
    wasm_exec_env_set_thread_info(exec_env);
#else
    /* Set thread info in call_wasm_with_hw_bound_check when
       hw bound check is enabled */
#endif

    /* Set exec env, so it can be later retrieved from instance */
    module_inst->cur_exec_env = exec_env;

    interp_call_wasm(module_inst, exec_env, function, argc, argv);
    return !wasm_copy_exception(module_inst, NULL);
}

#if WASM_ENABLE_PERF_PROFILING != 0 || WASM_ENABLE_DUMP_CALL_STACK != 0
/* look for the function name */
static char *
get_func_name_from_index(const WASMModuleInstance *inst, uint32 func_index)
{
    char *func_name = NULL;
    WASMFunctionInstance *func_inst = inst->e->functions + func_index;

    if (func_inst->is_import_func) {
        func_name = func_inst->u.func_import->field_name;
    }
    else {
#if WASM_ENABLE_CUSTOM_NAME_SECTION != 0
        func_name = func_inst->u.func->field_name;
#endif
        /* if custom name section is not generated,
            search symbols from export table */
        if (!func_name) {
            unsigned j;
            for (j = 0; j < inst->export_func_count; j++) {
                WASMExportFuncInstance *export_func =
                    inst->export_functions + j;
                if (export_func->function == func_inst) {
                    func_name = export_func->name;
                    break;
                }
            }
        }
    }

    return func_name;
}
#endif /*WASM_ENABLE_PERF_PROFILING != 0 || WASM_ENABLE_DUMP_CALL_STACK != 0*/

#if WASM_ENABLE_PERF_PROFILING != 0
void
wasm_dump_perf_profiling(const WASMModuleInstance *module_inst)
{
    WASMFunctionInstance *func_inst;
    char *func_name;
    uint32 i;

    os_printf("Performance profiler data:\n");
    for (i = 0; i < module_inst->e->function_count; i++) {
        func_inst = module_inst->e->functions + i;

        if (func_inst->total_exec_cnt == 0)
            continue;

        func_name = get_func_name_from_index(module_inst, i);
        if (func_name)
            os_printf(
                "  func %s, execution time: %.3f ms, execution count: %" PRIu32
                " times, children execution time: %.3f ms\n",
                func_name, func_inst->total_exec_time / 1000.0f,
                func_inst->total_exec_cnt,
                func_inst->children_exec_time / 1000.0f);
        else
            os_printf("  func %" PRIu32
                      ", execution time: %.3f ms, execution count: %" PRIu32
                      " times, children execution time: %.3f ms\n",
                      i, func_inst->total_exec_time / 1000.0f,
                      func_inst->total_exec_cnt,
                      func_inst->children_exec_time / 1000.0f);
    }
}

double
wasm_summarize_wasm_execute_time(const WASMModuleInstance *inst)
{
    double ret = 0;

    unsigned i;
    for (i = 0; i < inst->e->function_count; i++) {
        WASMFunctionInstance *func = inst->e->functions + i;
        ret += (func->total_exec_time - func->children_exec_time) / 1000.0f;
    }

    return ret;
}

double
wasm_get_wasm_func_exec_time(const WASMModuleInstance *inst,
                             const char *func_name)
{
    unsigned i;
    for (i = 0; i < inst->e->function_count; i++) {
        char *name_in_wasm = get_func_name_from_index(inst, i);
        if (name_in_wasm && strcmp(name_in_wasm, func_name) == 0) {
            WASMFunctionInstance *func = inst->e->functions + i;
            return (func->total_exec_time - func->children_exec_time) / 1000.0f;
        }
    }

    return -1.0;
}
#endif /*WASM_ENABLE_PERF_PROFILING != 0*/

uint64
wasm_module_malloc_internal(WASMModuleInstance *module_inst,
                            WASMExecEnv *exec_env, uint64 size,
                            void **p_native_addr)
{
    WASMMemoryInstance *memory = wasm_get_default_memory(module_inst);
    uint8 *addr = NULL;
    uint64 offset = 0;

    /* TODO: Memory64 size check based on memory idx type */
    bh_assert(size <= UINT32_MAX);

    if (!memory) {
        wasm_set_exception(module_inst, "uninitialized memory");
        return 0;
    }

    if (memory->heap_handle) {
        addr = mem_allocator_malloc(memory->heap_handle, (uint32)size);
    }
    else if (module_inst->e->malloc_function && module_inst->e->free_function) {
        if (!execute_malloc_function(
                module_inst, exec_env, module_inst->e->malloc_function,
                module_inst->e->retain_function, size, &offset)) {
            return 0;
        }
        /* If we use app's malloc function,
           the default memory may be changed while memory growing */
        memory = wasm_get_default_memory(module_inst);
        addr = offset ? memory->memory_data + offset : NULL;
    }

    if (!addr) {
        if (memory->heap_handle
            && mem_allocator_is_heap_corrupted(memory->heap_handle)) {
            wasm_runtime_show_app_heap_corrupted_prompt();
            wasm_set_exception(module_inst, "app heap corrupted");
        }
        else {
            LOG_WARNING("warning: allocate %" PRIu64 " bytes memory failed",
                        size);
        }
        return 0;
    }
    if (p_native_addr)
        *p_native_addr = addr;

    return (uint64)(addr - memory->memory_data);
}

uint64
wasm_module_realloc_internal(WASMModuleInstance *module_inst,
                             WASMExecEnv *exec_env, uint64 ptr, uint64 size,
                             void **p_native_addr)
{
    WASMMemoryInstance *memory = wasm_get_default_memory(module_inst);
    uint8 *addr = NULL;

    /* TODO: Memory64 ptr and size check based on memory idx type */
    bh_assert(ptr <= UINT32_MAX);
    bh_assert(size <= UINT32_MAX);

    if (!memory) {
        wasm_set_exception(module_inst, "uninitialized memory");
        return 0;
    }

    if (memory->heap_handle) {
        addr = mem_allocator_realloc(
            memory->heap_handle,
            (uint32)ptr ? memory->memory_data + (uint32)ptr : NULL,
            (uint32)size);
    }

    /* Only support realloc in WAMR's app heap */
    (void)exec_env;

    if (!addr) {
        if (memory->heap_handle
            && mem_allocator_is_heap_corrupted(memory->heap_handle)) {
            wasm_set_exception(module_inst, "app heap corrupted");
        }
        else {
            wasm_set_exception(module_inst, "out of memory");
        }
        return 0;
    }
    if (p_native_addr)
        *p_native_addr = addr;

    return (uint64)(addr - memory->memory_data);
}

void
wasm_module_free_internal(WASMModuleInstance *module_inst,
                          WASMExecEnv *exec_env, uint64 ptr)
{
    WASMMemoryInstance *memory = wasm_get_default_memory(module_inst);

    /* TODO: Memory64 ptr and size check based on memory idx type */
    bh_assert(ptr <= UINT32_MAX);

    if (!memory) {
        return;
    }

    if (ptr) {
        uint8 *addr = memory->memory_data + (uint32)ptr;
        uint8 *memory_data_end;

        /* memory->memory_data_end may be changed in memory grow */
        SHARED_MEMORY_LOCK(memory);
        memory_data_end = memory->memory_data_end;
        SHARED_MEMORY_UNLOCK(memory);

        if (memory->heap_handle && memory->heap_data <= addr
            && addr < memory->heap_data_end) {
            mem_allocator_free(memory->heap_handle, addr);
        }
        else if (module_inst->e->malloc_function
                 && module_inst->e->free_function && memory->memory_data <= addr
                 && addr < memory_data_end) {
            execute_free_function(module_inst, exec_env,
                                  module_inst->e->free_function, ptr);
        }
    }
}

uint64
wasm_module_malloc(WASMModuleInstance *module_inst, uint64 size,
                   void **p_native_addr)
{
    return wasm_module_malloc_internal(module_inst, NULL, size, p_native_addr);
}

uint64
wasm_module_realloc(WASMModuleInstance *module_inst, uint64 ptr, uint64 size,
                    void **p_native_addr)
{
    return wasm_module_realloc_internal(module_inst, NULL, ptr, size,
                                        p_native_addr);
}

void
wasm_module_free(WASMModuleInstance *module_inst, uint64 ptr)
{
    wasm_module_free_internal(module_inst, NULL, ptr);
}

uint64
wasm_module_dup_data(WASMModuleInstance *module_inst, const char *src,
                     uint64 size)
{
    char *buffer;
    uint64 buffer_offset;

    /* TODO: Memory64 size check based on memory idx type */
    bh_assert(size <= UINT32_MAX);

    buffer_offset = wasm_module_malloc(module_inst, size, (void **)&buffer);

    if (buffer_offset != 0) {
        buffer = wasm_runtime_addr_app_to_native(
            (WASMModuleInstanceCommon *)module_inst, buffer_offset);
        bh_memcpy_s(buffer, (uint32)size, src, (uint32)size);
    }
    return buffer_offset;
}

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
bool
wasm_enlarge_table(WASMModuleInstance *module_inst, uint32 table_idx,
                   uint32 inc_size, table_elem_type_t init_val)
{
    uint32 total_size, i;
    table_elem_type_t *new_table_data_start;
    WASMTableInstance *table_inst;

    if (!inc_size) {
        return true;
    }

    bh_assert(table_idx < module_inst->table_count);
    table_inst = wasm_get_table_inst(module_inst, table_idx);
    if (!table_inst) {
        return false;
    }

    if (inc_size > UINT32_MAX - table_inst->cur_size) {
        return false;
    }

    total_size = table_inst->cur_size + inc_size;
    if (total_size > table_inst->max_size) {
        return false;
    }

    /* fill in */
    new_table_data_start = table_inst->elems + table_inst->cur_size;
    for (i = 0; i < inc_size; ++i) {
        new_table_data_start[i] = init_val;
    }

    table_inst->cur_size = total_size;
    return true;
}
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */

static bool
call_indirect(WASMExecEnv *exec_env, uint32 tbl_idx, uint32 tbl_elem_idx,
              uint32 argc, uint32 argv[], bool check_type_idx, uint32 type_idx)
{
    WASMModuleInstance *module_inst = NULL;
    WASMTableInstance *table_inst = NULL;
    table_elem_type_t tbl_elem_val = NULL_REF;
    uint32 func_idx = 0;
    WASMFunctionInstance *func_inst = NULL;

    module_inst = (WASMModuleInstance *)exec_env->module_inst;
    bh_assert(module_inst);

    table_inst = module_inst->tables[tbl_idx];
    if (!table_inst) {
        wasm_set_exception(module_inst, "unknown table");
        goto got_exception;
    }

    if (tbl_elem_idx >= table_inst->cur_size) {
        wasm_set_exception(module_inst, "undefined element");
        goto got_exception;
    }

    tbl_elem_val = ((table_elem_type_t *)table_inst->elems)[tbl_elem_idx];
    if (tbl_elem_val == NULL_REF) {
        wasm_set_exception(module_inst, "uninitialized element");
        goto got_exception;
    }

#if WASM_ENABLE_GC == 0
    func_idx = (uint32)tbl_elem_val;
#else
    func_idx =
        wasm_func_obj_get_func_idx_bound((WASMFuncObjectRef)tbl_elem_val);
#endif

    /**
     * we insist to call functions owned by the module itself
     **/
    if (func_idx >= module_inst->e->function_count) {
        wasm_set_exception(module_inst, "unknown function");
        goto got_exception;
    }

    func_inst = module_inst->e->functions + func_idx;

    if (check_type_idx) {
        WASMType *cur_type = module_inst->module->types[type_idx];
        WASMType *cur_func_type;

        if (func_inst->is_import_func)
            cur_func_type = (WASMType *)func_inst->u.func_import->func_type;
        else
            cur_func_type = (WASMType *)func_inst->u.func->func_type;

        if (cur_type != cur_func_type) {
            wasm_set_exception(module_inst, "indirect call type mismatch");
            goto got_exception;
        }
    }

    interp_call_wasm(module_inst, exec_env, func_inst, argc, argv);

    return !wasm_copy_exception(module_inst, NULL);

got_exception:
    return false;
}

bool
wasm_call_indirect(WASMExecEnv *exec_env, uint32 tbl_idx, uint32 elem_idx,
                   uint32 argc, uint32 argv[])
{
    return call_indirect(exec_env, tbl_idx, elem_idx, argc, argv, false, 0);
}

#if WASM_ENABLE_THREAD_MGR != 0
bool
wasm_set_aux_stack(WASMExecEnv *exec_env, uint64 start_offset, uint32 size)
{
    WASMModuleInstance *module_inst =
        (WASMModuleInstance *)exec_env->module_inst;
    uint32 stack_top_idx = module_inst->module->aux_stack_top_global_index;

#if WASM_ENABLE_HEAP_AUX_STACK_ALLOCATION == 0
    /* Check the aux stack space */
    uint64 data_end = module_inst->module->aux_data_end;
    uint64 stack_bottom = module_inst->module->aux_stack_bottom;
    bool is_stack_before_data = stack_bottom < data_end ? true : false;
    if ((is_stack_before_data && (size > start_offset))
        || ((!is_stack_before_data) && (start_offset - data_end < size)))
        return false;
#endif

    if (stack_top_idx != (uint32)-1) {
        /* The aux stack top is a wasm global,
            set the initial value for the global */
        uint8 *global_addr =
            module_inst->global_data
            + module_inst->e->globals[stack_top_idx].data_offset;
        *(int32 *)global_addr = (uint32)start_offset;
        /* The aux stack boundary is a constant value,
            set the value to exec_env */
        exec_env->aux_stack_boundary = (uintptr_t)start_offset - size;
        exec_env->aux_stack_bottom = (uintptr_t)start_offset;
        return true;
    }

    return false;
}

bool
wasm_get_aux_stack(WASMExecEnv *exec_env, uint64 *start_offset, uint32 *size)
{
    WASMModuleInstance *module_inst =
        (WASMModuleInstance *)exec_env->module_inst;

    /* The aux stack information is resolved in loader
        and store in module */
    uint64 stack_bottom = module_inst->module->aux_stack_bottom;
    uint32 total_aux_stack_size = module_inst->module->aux_stack_size;

    if (stack_bottom != 0 && total_aux_stack_size != 0) {
        if (start_offset)
            *start_offset = stack_bottom;
        if (size)
            *size = total_aux_stack_size;
        return true;
    }
    return false;
}
#endif

#if (WASM_ENABLE_MEMORY_PROFILING != 0) || (WASM_ENABLE_MEMORY_TRACING != 0)
void
wasm_get_module_mem_consumption(const WASMModule *module,
                                WASMModuleMemConsumption *mem_conspn)
{
    uint32 i, size;

    memset(mem_conspn, 0, sizeof(*mem_conspn));

    mem_conspn->module_struct_size = sizeof(WASMModule);

    mem_conspn->types_size = sizeof(WASMFuncType *) * module->type_count;
    for (i = 0; i < module->type_count; i++) {
        WASMFuncType *type = module->types[i];
        size = offsetof(WASMFuncType, types)
               + sizeof(uint8) * (type->param_count + type->result_count);
        mem_conspn->types_size += size;
    }

    mem_conspn->imports_size = sizeof(WASMImport) * module->import_count;

    mem_conspn->functions_size =
        sizeof(WASMFunction *) * module->function_count;
    for (i = 0; i < module->function_count; i++) {
        WASMFunction *func = module->functions[i];
        WASMFuncType *type = func->func_type;
        size = sizeof(WASMFunction) + func->local_count
               + sizeof(uint16) * (type->param_count + func->local_count);
#if WASM_ENABLE_FAST_INTERP != 0
        size +=
            func->code_compiled_size + sizeof(uint32) * func->const_cell_num;
#endif
        mem_conspn->functions_size += size;
    }

    mem_conspn->tables_size = sizeof(WASMTable) * module->table_count;
    mem_conspn->memories_size = sizeof(WASMMemory) * module->memory_count;
    mem_conspn->globals_size = sizeof(WASMGlobal) * module->global_count;
    mem_conspn->exports_size = sizeof(WASMExport) * module->export_count;

    mem_conspn->table_segs_size =
        sizeof(WASMTableSeg) * module->table_seg_count;
    for (i = 0; i < module->table_seg_count; i++) {
        WASMTableSeg *table_seg = &module->table_segments[i];
        mem_conspn->tables_size +=
            sizeof(InitializerExpression *) * table_seg->value_count;
    }

    mem_conspn->data_segs_size = sizeof(WASMDataSeg *) * module->data_seg_count;
    for (i = 0; i < module->data_seg_count; i++) {
        mem_conspn->data_segs_size += sizeof(WASMDataSeg);
    }

    if (module->const_str_list) {
        StringNode *node = module->const_str_list, *node_next;
        while (node) {
            node_next = node->next;
            mem_conspn->const_strs_size +=
                sizeof(StringNode) + strlen(node->str) + 1;
            node = node_next;
        }
    }

    mem_conspn->total_size += mem_conspn->module_struct_size;
    mem_conspn->total_size += mem_conspn->types_size;
    mem_conspn->total_size += mem_conspn->imports_size;
    mem_conspn->total_size += mem_conspn->functions_size;
    mem_conspn->total_size += mem_conspn->tables_size;
    mem_conspn->total_size += mem_conspn->memories_size;
    mem_conspn->total_size += mem_conspn->globals_size;
    mem_conspn->total_size += mem_conspn->exports_size;
    mem_conspn->total_size += mem_conspn->table_segs_size;
    mem_conspn->total_size += mem_conspn->data_segs_size;
    mem_conspn->total_size += mem_conspn->const_strs_size;
}

void
wasm_get_module_inst_mem_consumption(const WASMModuleInstance *module_inst,
                                     WASMModuleInstMemConsumption *mem_conspn)
{
    uint32 i;
    uint64 size;

    memset(mem_conspn, 0, sizeof(*mem_conspn));

    mem_conspn->module_inst_struct_size = (uint8 *)module_inst->e
                                          - (uint8 *)module_inst
                                          + sizeof(WASMModuleInstanceExtra);

    mem_conspn->memories_size =
        sizeof(WASMMemoryInstance *) * module_inst->memory_count;
    for (i = 0; i < module_inst->memory_count; i++) {
        WASMMemoryInstance *memory = module_inst->memories[i];
        size = (uint64)memory->num_bytes_per_page * memory->cur_page_count;
        mem_conspn->memories_size += size;
        mem_conspn->app_heap_size += memory->heap_data_end - memory->heap_data;
        /* size of app heap structure */
        mem_conspn->memories_size += mem_allocator_get_heap_struct_size();
        /* Module instance structures have been appended into the end of
           module instance */
    }

    mem_conspn->tables_size =
        sizeof(WASMTableInstance *) * module_inst->table_count;
    /* Table instance structures and table elements have been appended into
       the end of module instance */

    mem_conspn->functions_size =
        sizeof(WASMFunctionInstance) * module_inst->e->function_count;

    mem_conspn->globals_size =
        sizeof(WASMGlobalInstance) * module_inst->e->global_count;
    /* Global data has been appended into the end of module instance */

    mem_conspn->exports_size =
        sizeof(WASMExportFuncInstance) * module_inst->export_func_count;

    mem_conspn->total_size += mem_conspn->module_inst_struct_size;
    mem_conspn->total_size += mem_conspn->memories_size;
    mem_conspn->total_size += mem_conspn->functions_size;
    mem_conspn->total_size += mem_conspn->tables_size;
    mem_conspn->total_size += mem_conspn->globals_size;
    mem_conspn->total_size += mem_conspn->exports_size;
}
#endif /* end of (WASM_ENABLE_MEMORY_PROFILING != 0) \
                 || (WASM_ENABLE_MEMORY_TRACING != 0) */

#if WASM_ENABLE_COPY_CALL_STACK != 0
uint32
wasm_interp_copy_callstack(WASMExecEnv *exec_env, WASMCApiFrame *buffer,
                           uint32 length, uint32 skip_n, char *error_buf,
                           uint32_t error_buf_size)
{
    /*
     * Note for devs: please refrain from such modifications inside of
     * wasm_interp_copy_callstack
     * - any allocations/freeing memory
     * - dereferencing any pointers other than: exec_env, exec_env->module_inst,
     * exec_env->module_inst->module, pointers between stack's bottom and
     * top_boundary For more details check wasm_copy_callstack in
     * wasm_export.h
     */
    WASMModuleInstance *module_inst =
        (WASMModuleInstance *)wasm_exec_env_get_module_inst(exec_env);
    WASMInterpFrame *cur_frame = wasm_exec_env_get_cur_frame(exec_env);
    uint8 *top_boundary = exec_env->wasm_stack.top_boundary;
    uint8 *bottom = exec_env->wasm_stack.bottom;
    uint32 count = 0;

    WASMCApiFrame record_frame;
    while (cur_frame && (uint8_t *)cur_frame >= bottom
           && (uint8_t *)cur_frame + sizeof(WASMInterpFrame) <= top_boundary
           && count < (skip_n + length)) {
        if (!cur_frame->function) {
            cur_frame = cur_frame->prev_frame;
            continue;
        }
        if (count < skip_n) {
            ++count;
            cur_frame = cur_frame->prev_frame;
            continue;
        }
        record_frame.instance = module_inst;
        record_frame.module_offset = 0;
        // It's safe to dereference module_inst->e because "e" is asigned only
        // once in wasm_instantiate
        record_frame.func_index =
            (uint32)(cur_frame->function - module_inst->e->functions);
        buffer[count - skip_n] = record_frame;
        cur_frame = cur_frame->prev_frame;
        ++count;
    }
    return count >= skip_n ? count - skip_n : 0;
}
#endif // WASM_ENABLE_COPY_CALL_STACK

#if WASM_ENABLE_DUMP_CALL_STACK != 0
bool
wasm_interp_create_call_stack(struct WASMExecEnv *exec_env)
{
    WASMModuleInstance *module_inst =
        (WASMModuleInstance *)wasm_exec_env_get_module_inst(exec_env);
    WASMModule *module = module_inst->module;
    WASMInterpFrame *first_frame,
        *cur_frame = wasm_exec_env_get_cur_frame(exec_env);
    uint32 n = 0;

    /* count frames includes a function */
    first_frame = cur_frame;
    while (cur_frame) {
        if (cur_frame->function) {
            n++;
        }
        cur_frame = cur_frame->prev_frame;
    }

    /* release previous stack frames and create new ones */
    destroy_c_api_frames(module_inst->frames);
    if (!bh_vector_init(module_inst->frames, n, sizeof(WASMCApiFrame), false)) {
        return false;
    }

    cur_frame = first_frame;
    n = 0;

    while (cur_frame) {
        WASMCApiFrame frame = { 0 };
        WASMFunctionInstance *func_inst = cur_frame->function;
        const char *func_name = NULL;
        const uint8 *func_code_base = NULL;
        uint32 max_local_cell_num, max_stack_cell_num;
        uint32 all_cell_num, lp_size;

        if (!func_inst) {
            cur_frame = cur_frame->prev_frame;
            continue;
        }

        /* place holder, will overwrite it in wasm_c_api */
        frame.instance = module_inst;
        frame.module_offset = 0;
        frame.func_index = (uint32)(func_inst - module_inst->e->functions);

        func_code_base = wasm_get_func_code(func_inst);
        if (!cur_frame->ip || !func_code_base) {
            frame.func_offset = 0;
        }
        else {
#if WASM_ENABLE_FAST_INTERP == 0
            frame.func_offset = (uint32)(cur_frame->ip - module->load_addr);
#else
            frame.func_offset = (uint32)(cur_frame->ip - func_code_base);
#endif
        }

        func_name = get_func_name_from_index(module_inst, frame.func_index);
        frame.func_name_wp = func_name;

        if (frame.func_index >= module->import_function_count) {
            uint32 wasm_func_idx =
                frame.func_index - module->import_function_count;
            max_local_cell_num =
                module->functions[wasm_func_idx]->param_cell_num
                + module->functions[wasm_func_idx]->local_cell_num;
            max_stack_cell_num =
                module->functions[wasm_func_idx]->max_stack_cell_num;
            all_cell_num = max_local_cell_num + max_stack_cell_num;
#if WASM_ENABLE_FAST_INTERP != 0
            all_cell_num += module->functions[wasm_func_idx]->const_cell_num;
#endif
        }
        else {
            WASMFuncType *func_type =
                module->import_functions[frame.func_index].u.function.func_type;
            max_local_cell_num =
                func_type->param_cell_num > 2 ? func_type->param_cell_num : 2;
            max_stack_cell_num = 0;
            all_cell_num = max_local_cell_num + max_stack_cell_num;
        }

#if WASM_ENABLE_GC == 0
        lp_size = all_cell_num * 4;
#else
        lp_size = align_uint(all_cell_num * 5, 4);
#endif
        if (lp_size > 0) {
            if (!(frame.lp = wasm_runtime_malloc(lp_size))) {
                destroy_c_api_frames(module_inst->frames);
                return false;
            }
            bh_memcpy_s(frame.lp, lp_size, cur_frame->lp, lp_size);

#if WASM_ENABLE_GC != 0
#if WASM_ENABLE_FAST_INTERP == 0
            frame.sp = frame.lp + (cur_frame->sp - cur_frame->lp);
#else
            /* for fast-interp, let frame sp point to the end of the frame */
            frame.sp = frame.lp + all_cell_num;
#endif
            frame.frame_ref = (uint8 *)frame.lp
                              + (wasm_interp_get_frame_ref(cur_frame)
                                 - (uint8 *)cur_frame->lp);
#endif
        }

        if (!bh_vector_append(module_inst->frames, &frame)) {
            if (frame.lp)
                wasm_runtime_free(frame.lp);
            destroy_c_api_frames(module_inst->frames);
            return false;
        }

        cur_frame = cur_frame->prev_frame;
        n++;
    }

    return true;
}

#define PRINT_OR_DUMP()                                                   \
    do {                                                                  \
        total_len +=                                                      \
            wasm_runtime_dump_line_buf_impl(line_buf, print, &buf, &len); \
        if ((!print) && buf && (len == 0)) {                              \
            exception_unlock(module_inst);                                \
            return total_len;                                             \
        }                                                                 \
    } while (0)

uint32
wasm_interp_dump_call_stack(struct WASMExecEnv *exec_env, bool print, char *buf,
                            uint32 len)
{
    WASMModuleInstance *module_inst =
        (WASMModuleInstance *)wasm_exec_env_get_module_inst(exec_env);
    uint32 n = 0, total_len = 0, total_frames;
    /* reserve 256 bytes for line buffer, any line longer than 256 bytes
     * will be truncated */
    char line_buf[256];

    if (!module_inst->frames) {
        return 0;
    }

    total_frames = (uint32)bh_vector_size(module_inst->frames);
    if (total_frames == 0) {
        return 0;
    }

    exception_lock(module_inst);
    snprintf(line_buf, sizeof(line_buf), "\n");
    PRINT_OR_DUMP();

    while (n < total_frames) {
        WASMCApiFrame frame = { 0 };
        uint32 line_length, i;

        if (!bh_vector_get(module_inst->frames, n, &frame)) {
            exception_unlock(module_inst);
            return 0;
        }

#if WASM_ENABLE_FAST_JIT != 0
        /* Fast JIT doesn't support committing ip (instruction pointer) yet */
        if (module_inst->e->running_mode == Mode_Fast_JIT
            || module_inst->e->running_mode == Mode_Multi_Tier_JIT) {
            /* function name not exported, print number instead */
            if (frame.func_name_wp == NULL) {
                line_length = snprintf(line_buf, sizeof(line_buf),
                                       "#%02" PRIu32 " $f%" PRIu32 "\n", n,
                                       frame.func_index);
            }
            else {
                line_length =
                    snprintf(line_buf, sizeof(line_buf), "#%02" PRIu32 " %s\n",
                             n, frame.func_name_wp);
            }
        }
        else
#endif
        {
            /* function name not exported, print number instead */
            if (frame.func_name_wp == NULL) {
                line_length =
                    snprintf(line_buf, sizeof(line_buf),
                             "#%02" PRIu32 ": 0x%04x - $f%" PRIu32 "\n", n,
                             frame.func_offset, frame.func_index);
            }
            else {
                line_length = snprintf(line_buf, sizeof(line_buf),
                                       "#%02" PRIu32 ": 0x%04x - %s\n", n,
                                       frame.func_offset, frame.func_name_wp);
            }
        }

        if (line_length >= sizeof(line_buf)) {
            uint32 line_buffer_len = sizeof(line_buf);
            /* If line too long, ensure the last character is '\n' */
            for (i = line_buffer_len - 5; i < line_buffer_len - 2; i++) {
                line_buf[i] = '.';
            }
            line_buf[line_buffer_len - 2] = '\n';
        }

        PRINT_OR_DUMP();

        n++;
    }
    snprintf(line_buf, sizeof(line_buf), "\n");
    PRINT_OR_DUMP();
    exception_unlock(module_inst);

    return total_len + 1;
}
#endif /* end of WASM_ENABLE_DUMP_CALL_STACK */

#if WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
    || WASM_ENABLE_WAMR_COMPILER != 0
void
jit_set_exception_with_id(WASMModuleInstance *module_inst, uint32 id)
{
    if (id != EXCE_ALREADY_THROWN)
        wasm_set_exception_with_id(module_inst, id);
#ifdef OS_ENABLE_HW_BOUND_CHECK
    wasm_runtime_access_exce_check_guard_page();
#endif
}

bool
jit_check_app_addr_and_convert(WASMModuleInstance *module_inst, bool is_str,
                               uint64 app_buf_addr, uint64 app_buf_size,
                               void **p_native_addr)
{
    bool ret = wasm_check_app_addr_and_convert(
        module_inst, is_str, app_buf_addr, app_buf_size, p_native_addr);

#ifdef OS_ENABLE_HW_BOUND_CHECK
    if (!ret)
        wasm_runtime_access_exce_check_guard_page();
#endif

    return ret;
}
#endif /* end of WASM_ENABLE_FAST_JIT != 0 || WASM_ENABLE_JIT != 0 \
          || WASM_ENABLE_WAMR_COMPILER != 0 */

#if WASM_ENABLE_FAST_JIT != 0
bool
fast_jit_call_indirect(WASMExecEnv *exec_env, uint32 tbl_idx, uint32 elem_idx,
                       uint32 type_idx, uint32 argc, uint32 *argv)
{
    return call_indirect(exec_env, tbl_idx, elem_idx, argc, argv, true,
                         type_idx);
}
#endif /* end of WASM_ENABLE_FAST_JIT != 0 */

#if WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0

bool
llvm_jit_call_indirect(WASMExecEnv *exec_env, uint32 tbl_idx, uint32 elem_idx,
                       uint32 argc, uint32 *argv)
{
    bool ret;

    bh_assert(exec_env->module_inst->module_type == Wasm_Module_Bytecode);

    ret = call_indirect(exec_env, tbl_idx, elem_idx, argc, argv, false, 0);
#ifdef OS_ENABLE_HW_BOUND_CHECK
    if (!ret)
        wasm_runtime_access_exce_check_guard_page();
#endif
    return ret;
}

bool
llvm_jit_invoke_native(WASMExecEnv *exec_env, uint32 func_idx, uint32 argc,
                       uint32 *argv)
{
    WASMModuleInstance *module_inst;
    WASMModule *module;
    uint32 *func_type_indexes;
    uint32 func_type_idx;
    WASMFuncType *func_type;
    void *func_ptr;
    WASMFunctionImport *import_func;
    CApiFuncImport *c_api_func_import = NULL;
    const char *signature;
    void *attachment;
    char buf[96];
    bool ret = false;

    bh_assert(exec_env->module_inst->module_type == Wasm_Module_Bytecode);

    module_inst = (WASMModuleInstance *)wasm_runtime_get_module_inst(exec_env);
    module = module_inst->module;
    func_type_indexes = module_inst->func_type_indexes;
    func_type_idx = func_type_indexes[func_idx];
    func_type = (WASMFuncType *)module->types[func_type_idx];
    func_ptr = module_inst->func_ptrs[func_idx];

    bh_assert(func_idx < module->import_function_count);

    import_func = &module->import_functions[func_idx].u.function;
    if (import_func->call_conv_wasm_c_api) {
        if (module_inst->c_api_func_imports) {
            c_api_func_import = module_inst->c_api_func_imports + func_idx;
            func_ptr = c_api_func_import->func_ptr_linked;
        }
        else {
            c_api_func_import = NULL;
            func_ptr = NULL;
        }
    }

    if (!func_ptr) {
        snprintf(buf, sizeof(buf),
                 "failed to call unlinked import function (%s, %s)",
                 import_func->module_name, import_func->field_name);
        wasm_set_exception(module_inst, buf);
        goto fail;
    }

    attachment = import_func->attachment;
    if (import_func->call_conv_wasm_c_api) {
        ret = wasm_runtime_invoke_c_api_native(
            (WASMModuleInstanceCommon *)module_inst, func_ptr, func_type, argc,
            argv, c_api_func_import->with_env_arg, c_api_func_import->env_arg);
    }
    else if (!import_func->call_conv_raw) {
        signature = import_func->signature;
        ret =
            wasm_runtime_invoke_native(exec_env, func_ptr, func_type, signature,
                                       attachment, argv, argc, argv);
    }
    else {
        signature = import_func->signature;
        ret = wasm_runtime_invoke_native_raw(exec_env, func_ptr, func_type,
                                             signature, attachment, argv, argc,
                                             argv);
    }

fail:
#ifdef OS_ENABLE_HW_BOUND_CHECK
    if (!ret)
        wasm_runtime_access_exce_check_guard_page();
#endif
    return ret;
}

#if WASM_ENABLE_BULK_MEMORY != 0
bool
llvm_jit_memory_init(WASMModuleInstance *module_inst, uint32 seg_index,
                     uint32 offset, uint32 len, size_t dst)
{
    WASMMemoryInstance *memory_inst;
    WASMModule *module;
    uint8 *data;
    uint8 *maddr;
    uint64 seg_len;

    bh_assert(module_inst->module_type == Wasm_Module_Bytecode);

    memory_inst = wasm_get_default_memory(module_inst);

    if (bh_bitmap_get_bit(module_inst->e->common.data_dropped, seg_index)) {
        seg_len = 0;
        data = NULL;
    }
    else {
        module = module_inst->module;
        seg_len = module->data_segments[seg_index]->data_length;
        data = module->data_segments[seg_index]->data;
    }

    if (!wasm_runtime_validate_app_addr((WASMModuleInstanceCommon *)module_inst,
                                        (uint64)dst, (uint64)len))
        return false;

    if ((uint64)offset + (uint64)len > seg_len) {
        wasm_set_exception(module_inst, "out of bounds memory access");
        return false;
    }

    maddr = wasm_runtime_addr_app_to_native(
        (WASMModuleInstanceCommon *)module_inst, (uint64)dst);

    SHARED_MEMORY_LOCK(memory_inst);
    bh_memcpy_s(maddr, CLAMP_U64_TO_U32(memory_inst->memory_data_size - dst),
                data + offset, len);
    SHARED_MEMORY_UNLOCK(memory_inst);
    return true;
}

bool
llvm_jit_data_drop(WASMModuleInstance *module_inst, uint32 seg_index)
{
    bh_assert(module_inst->module_type == Wasm_Module_Bytecode);

    bh_bitmap_set_bit(module_inst->e->common.data_dropped, seg_index);
    /* Currently we can't free the dropped data segment
       as they are stored in wasm bytecode */
    return true;
}
#endif /* end of WASM_ENABLE_BULK_MEMORY != 0 */

#if WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0
void
llvm_jit_drop_table_seg(WASMModuleInstance *module_inst, uint32 tbl_seg_idx)
{
    bh_assert(module_inst->module_type == Wasm_Module_Bytecode);
    bh_bitmap_set_bit(module_inst->e->common.elem_dropped, tbl_seg_idx);
}

void
llvm_jit_table_init(WASMModuleInstance *module_inst, uint32 tbl_idx,
                    uint32 tbl_seg_idx, uint32 length, uint32 src_offset,
                    uint32 dst_offset)
{
    WASMTableInstance *tbl_inst;
    WASMTableSeg *tbl_seg;
    table_elem_type_t *table_elems;
    InitializerExpression *tbl_seg_init_values = NULL, *init_values;
    uint32 i, tbl_seg_len = 0;
#if WASM_ENABLE_GC != 0
    void *func_obj;
#endif

    bh_assert(module_inst->module_type == Wasm_Module_Bytecode);

    tbl_inst = wasm_get_table_inst(module_inst, tbl_idx);
    tbl_seg = module_inst->module->table_segments + tbl_seg_idx;

    bh_assert(tbl_inst);
    bh_assert(tbl_seg);

    if (!bh_bitmap_get_bit(module_inst->e->common.elem_dropped, tbl_seg_idx)) {
        /* table segment isn't dropped */
        tbl_seg_init_values = tbl_seg->init_values;
        tbl_seg_len = tbl_seg->value_count;
    }

    if (offset_len_out_of_bounds(src_offset, length, tbl_seg_len)
        || offset_len_out_of_bounds(dst_offset, length, tbl_inst->cur_size)) {
        jit_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    if (!length) {
        return;
    }

    table_elems = tbl_inst->elems + dst_offset;
    init_values = tbl_seg_init_values + src_offset;

    for (i = 0; i < length; i++) {
#if WASM_ENABLE_GC != 0
        /* UINT32_MAX indicates that it is a null ref */
        if (init_values[i].u.unary.v.ref_index != UINT32_MAX) {
            if (!(func_obj = wasm_create_func_obj(
                      module_inst, init_values[i].u.unary.v.ref_index, true,
                      NULL, 0))) {
                wasm_set_exception(module_inst, "null function reference");
                return;
            }
            table_elems[i] = func_obj;
        }
        else {
            table_elems[i] = NULL_REF;
        }
#else
        table_elems[i] = init_values[i].u.unary.v.ref_index;
#endif
    }
}

void
llvm_jit_table_copy(WASMModuleInstance *module_inst, uint32 src_tbl_idx,
                    uint32 dst_tbl_idx, uint32 length, uint32 src_offset,
                    uint32 dst_offset)
{
    WASMTableInstance *src_tbl_inst;
    WASMTableInstance *dst_tbl_inst;

    bh_assert(module_inst->module_type == Wasm_Module_Bytecode);

    src_tbl_inst = wasm_get_table_inst(module_inst, src_tbl_idx);
    dst_tbl_inst = wasm_get_table_inst(module_inst, dst_tbl_idx);
    bh_assert(src_tbl_inst);
    bh_assert(dst_tbl_inst);

    if (offset_len_out_of_bounds(dst_offset, length, dst_tbl_inst->cur_size)
        || offset_len_out_of_bounds(src_offset, length,
                                    src_tbl_inst->cur_size)) {
        jit_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    /* if src_offset >= dst_offset, copy from front to back */
    /* if src_offset < dst_offset, copy from back to front */
    /* merge all together */
    bh_memmove_s((uint8 *)dst_tbl_inst + offsetof(WASMTableInstance, elems)
                     + sizeof(table_elem_type_t) * dst_offset,
                 (uint32)sizeof(table_elem_type_t)
                     * (dst_tbl_inst->cur_size - dst_offset),
                 (uint8 *)src_tbl_inst + offsetof(WASMTableInstance, elems)
                     + sizeof(table_elem_type_t) * src_offset,
                 (uint32)sizeof(table_elem_type_t) * length);
}

void
llvm_jit_table_fill(WASMModuleInstance *module_inst, uint32 tbl_idx,
                    uint32 length, uintptr_t val, uint32 data_offset)
{
    WASMTableInstance *tbl_inst;

    bh_assert(module_inst->module_type == Wasm_Module_Bytecode);

    tbl_inst = wasm_get_table_inst(module_inst, tbl_idx);
    bh_assert(tbl_inst);

    if (offset_len_out_of_bounds(data_offset, length, tbl_inst->cur_size)) {
        jit_set_exception_with_id(module_inst, EXCE_OUT_OF_BOUNDS_TABLE_ACCESS);
        return;
    }

    for (; length != 0; data_offset++, length--) {
        tbl_inst->elems[data_offset] = (table_elem_type_t)val;
    }
}

uint32
llvm_jit_table_grow(WASMModuleInstance *module_inst, uint32 tbl_idx,
                    uint32 inc_size, uintptr_t init_val)
{
    WASMTableInstance *tbl_inst;
    uint32 i, orig_size, total_size;

    bh_assert(module_inst->module_type == Wasm_Module_Bytecode);

    tbl_inst = wasm_get_table_inst(module_inst, tbl_idx);
    if (!tbl_inst) {
        return (uint32)-1;
    }

    orig_size = tbl_inst->cur_size;

    if (!inc_size) {
        return orig_size;
    }

    if (tbl_inst->cur_size > UINT32_MAX - inc_size) { /* integer overflow */
#if WASM_ENABLE_SPEC_TEST == 0
        LOG_WARNING("table grow (%" PRIu32 "-> %" PRIu32
                    ") failed because of integer overflow",
                    tbl_inst->cur_size, inc_size);
#endif
        return (uint32)-1;
    }

    total_size = tbl_inst->cur_size + inc_size;
    if (total_size > tbl_inst->max_size) {
#if WASM_ENABLE_SPEC_TEST == 0
        LOG_WARNING("table grow (%" PRIu32 "-> %" PRIu32
                    ") failed because of over max size",
                    tbl_inst->cur_size, inc_size);
#endif
        return (uint32)-1;
    }

    /* fill in */
    for (i = 0; i < inc_size; ++i) {
        tbl_inst->elems[tbl_inst->cur_size + i] = (table_elem_type_t)init_val;
    }

    tbl_inst->cur_size = total_size;
    return orig_size;
}
#endif /* end of WASM_ENABLE_REF_TYPES != 0 || WASM_ENABLE_GC != 0 */

#if WASM_ENABLE_GC != 0
void *
llvm_jit_create_func_obj(WASMModuleInstance *module_inst, uint32 func_idx,
                         bool throw_exce, char *error_buf,
                         uint32 error_buf_size)
{
    bh_assert(module_inst->module_type == Wasm_Module_Bytecode);

    return wasm_create_func_obj(module_inst, func_idx, throw_exce, error_buf,
                                error_buf_size);
}

bool
llvm_jit_obj_is_instance_of(WASMModuleInstance *module_inst,
                            WASMObjectRef gc_obj, uint32 type_index)
{
    WASMModule *module = module_inst->module;
    WASMType **types = module->types;
    uint32 type_count = module->type_count;

    return wasm_obj_is_instance_of(gc_obj, type_index, types, type_count);
}

bool
llvm_jit_func_type_is_super_of(WASMModuleInstance *module_inst,
                               uint32 type_idx1, uint32 type_idx2)
{
    WASMModule *module = module_inst->module;
    WASMType **types = module->types;

    if (type_idx1 == type_idx2)
        return true;

    bh_assert(types[type_idx1]->type_flag == WASM_TYPE_FUNC);
    bh_assert(types[type_idx2]->type_flag == WASM_TYPE_FUNC);
    return wasm_func_type_is_super_of((WASMFuncType *)types[type_idx1],
                                      (WASMFuncType *)types[type_idx2]);
}

WASMRttTypeRef
llvm_jit_rtt_type_new(WASMModuleInstance *module_inst, uint32 type_index)
{
    WASMModule *module = module_inst->module;
    WASMType *defined_type = module->types[type_index];
    WASMRttType **rtt_types = module->rtt_types;
    uint32 rtt_type_count = module->type_count;
    korp_mutex *rtt_type_lock = &module->rtt_type_lock;

    return wasm_rtt_type_new(defined_type, type_index, rtt_types,
                             rtt_type_count, rtt_type_lock);
}

bool
llvm_array_init_with_data(WASMModuleInstance *module_inst, uint32 seg_index,
                          uint32 data_seg_offset, WASMArrayObjectRef array_obj,
                          uint32 elem_size, uint32 array_len)
{
    WASMModule *wasm_module = module_inst->module;
    WASMDataSeg *data_seg;
    uint8 *array_elem_base;
    uint64 total_size;

    data_seg = wasm_module->data_segments[seg_index];
    total_size = (int64)elem_size * array_len;

    if (data_seg_offset >= data_seg->data_length
        || total_size > data_seg->data_length - data_seg_offset) {
        wasm_set_exception(module_inst, "out of bounds memory access");
        return false;
    }

    array_elem_base = (uint8 *)wasm_array_obj_first_elem_addr(array_obj);
    bh_memcpy_s(array_elem_base, (uint32)total_size,
                data_seg->data + data_seg_offset, (uint32)total_size);

    return true;
}
#endif /* end of WASM_ENABLE_GC != 0  */

#endif /* end of WASM_ENABLE_JIT != 0 || WASM_ENABLE_WAMR_COMPILER != 0 */

#if WASM_ENABLE_LIBC_WASI != 0 && WASM_ENABLE_MULTI_MODULE != 0
void
wasm_propagate_wasi_args(WASMModule *module)
{
    if (!module->import_count)
        return;

    bh_assert(&module->import_module_list_head);

    WASMRegisteredModule *node =
        bh_list_first_elem(&module->import_module_list_head);
    while (node) {
        WASIArguments *wasi_args_impt_mod =
            &((WASMModule *)(node->module))->wasi_args;
        bh_assert(wasi_args_impt_mod);

        bh_memcpy_s(wasi_args_impt_mod, sizeof(WASIArguments),
                    &module->wasi_args, sizeof(WASIArguments));
        node = bh_list_elem_next(node);
    }
}
#endif

bool
wasm_check_utf8_str(const uint8 *str, uint32 len)
{
    /* The valid ranges are taken from page 125, below link
       https://www.unicode.org/versions/Unicode9.0.0/ch03.pdf */
    const uint8 *p = str, *p_end = str + len;
    uint8 chr;

    while (p < p_end) {
        chr = *p;

        if (chr == 0) {
            LOG_WARNING(
                "LIMITATION: a string which contains '\\00' is unsupported");
            return false;
        }
        else if (chr < 0x80) {
            p++;
        }
        else if (chr >= 0xC2 && chr <= 0xDF && p + 1 < p_end) {
            if (p[1] < 0x80 || p[1] > 0xBF) {
                return false;
            }
            p += 2;
        }
        else if (chr >= 0xE0 && chr <= 0xEF && p + 2 < p_end) {
            if (chr == 0xE0) {
                if (p[1] < 0xA0 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF) {
                    return false;
                }
            }
            else if (chr == 0xED) {
                if (p[1] < 0x80 || p[1] > 0x9F || p[2] < 0x80 || p[2] > 0xBF) {
                    return false;
                }
            }
            else { /* chr >= 0xE1 && chr <= 0xEF */
                if (p[1] < 0x80 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF) {
                    return false;
                }
            }
            p += 3;
        }
        else if (chr >= 0xF0 && chr <= 0xF4 && p + 3 < p_end) {
            if (chr == 0xF0) {
                if (p[1] < 0x90 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF
                    || p[3] < 0x80 || p[3] > 0xBF) {
                    return false;
                }
            }
            else if (chr <= 0xF3) { /* and also chr >= 0xF1 */
                if (p[1] < 0x80 || p[1] > 0xBF || p[2] < 0x80 || p[2] > 0xBF
                    || p[3] < 0x80 || p[3] > 0xBF) {
                    return false;
                }
            }
            else { /* chr == 0xF4 */
                if (p[1] < 0x80 || p[1] > 0x8F || p[2] < 0x80 || p[2] > 0xBF
                    || p[3] < 0x80 || p[3] > 0xBF) {
                    return false;
                }
            }
            p += 4;
        }
        else {
            return false;
        }
    }
    return (p == p_end);
}

char *
wasm_const_str_list_insert(const uint8 *str, uint32 len, WASMModule *module,
                           bool is_load_from_file_buf, char *error_buf,
                           uint32 error_buf_size)
{
    StringNode *node, *node_next;

    if (!wasm_check_utf8_str(str, len)) {
        set_error_buf(error_buf, error_buf_size, "invalid UTF-8 encoding");
        return NULL;
    }

    if (len == 0) {
        return "";
    }
    else if (is_load_from_file_buf) {
        /* As the file buffer can be referred to after loading, we use
           the previous byte of leb encoded size to adjust the string:
           move string 1 byte backward and then append '\0' */
        char *c_str = (char *)str - 1;
        bh_memmove_s(c_str, len + 1, c_str + 1, len);
        c_str[len] = '\0';
        return c_str;
    }

    /* Search const str list */
    node = module->const_str_list;
    while (node) {
        node_next = node->next;
        if (strlen(node->str) == len && !memcmp(node->str, str, len))
            break;
        node = node_next;
    }

    if (node) {
        return node->str;
    }

    if (!(node = runtime_malloc(sizeof(StringNode) + len + 1, error_buf,
                                error_buf_size))) {
        return NULL;
    }

    node->str = ((char *)node) + sizeof(StringNode);
    bh_memcpy_s(node->str, len + 1, str, len);
    node->str[len] = '\0';

    if (!module->const_str_list) {
        /* set as head */
        module->const_str_list = node;
        node->next = NULL;
    }
    else {
        /* insert it */
        node->next = module->const_str_list;
        module->const_str_list = node;
    }

    return node->str;
}

bool
wasm_set_module_name(WASMModule *module, const char *name, char *error_buf,
                     uint32_t error_buf_size)
{
    if (!name)
        return false;

    module->name =
        wasm_const_str_list_insert((const uint8 *)name, (uint32)strlen(name),
                                   module, false, error_buf, error_buf_size);
    return module->name != NULL;
}

const char *
wasm_get_module_name(WASMModule *module)
{
    return module->name;
}
