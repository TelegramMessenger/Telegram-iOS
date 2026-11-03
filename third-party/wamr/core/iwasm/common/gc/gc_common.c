/*
 * Copyright (C) 2019 Intel Corporation.  All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "../wasm_runtime_common.h"
#include "gc_export.h"
#if WASM_ENABLE_INTERP != 0
#include "../interpreter/wasm_runtime.h"
#endif
#if WASM_ENABLE_AOT != 0
#include "../aot/aot_runtime.h"
#endif

static bool
wasm_ref_type_normalize(wasm_ref_type_t *ref_type)
{
    wasm_value_type_t value_type = ref_type->value_type;
    int32 heap_type = ref_type->heap_type;

    if (!((value_type >= VALUE_TYPE_I16 && value_type <= VALUE_TYPE_I32)
          || ((value_type >= (uint8)REF_TYPE_ARRAYREF
               && value_type <= (uint8)REF_TYPE_NULLFUNCREF)
              || (value_type >= (uint8)REF_TYPE_HT_NULLABLE
                  && value_type <= (uint8)REF_TYPE_HT_NON_NULLABLE)
#if WASM_ENABLE_STRINGREF != 0
              || (value_type >= (uint8)REF_TYPE_STRINGVIEWWTF8
                  && value_type <= (uint8)REF_TYPE_STRINGREF)
              || (value_type >= (uint8)REF_TYPE_STRINGVIEWITER
                  && value_type <= (uint8)REF_TYPE_STRINGVIEWWTF16)
#endif
                  ))) {
        return false;
    }
    if (value_type == VALUE_TYPE_HT_NULLABLE_REF
        || value_type == VALUE_TYPE_HT_NON_NULLABLE_REF) {
        if (heap_type < 0 && !wasm_is_valid_heap_type(heap_type)) {
            return false;
        }
    }

    if (value_type != REF_TYPE_HT_NULLABLE) {
        ref_type->nullable = false;
    }
    else {
        if (wasm_is_valid_heap_type(heap_type)) {
            ref_type->value_type =
#if WASM_ENABLE_STRINGREF != 0
                (uint8)(REF_TYPE_STRINGVIEWITER + heap_type
                        - HEAP_TYPE_STRINGVIEWITER);
#else
                (uint8)(REF_TYPE_ARRAYREF + heap_type - HEAP_TYPE_ARRAY);
#endif
            ref_type->nullable = false;
            ref_type->heap_type = 0;
        }
        else {
            ref_type->nullable = true;
        }
    }

    return true;
}

uint32
wasm_get_defined_type_count(WASMModuleCommon *const module)
{
    uint32 type_count = 0;

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;
        type_count = wasm_module->type_count;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;
        type_count = aot_module->type_count;
    }
#endif

    return type_count;
}

WASMType *
wasm_get_defined_type(WASMModuleCommon *const module, uint32 index)
{
    WASMType *type = NULL;

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;

        bh_assert(index < wasm_module->type_count);
        type = wasm_module->types[index];
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;

        bh_assert(index < aot_module->type_count);
        type = aot_module->types[index];
    }
#endif

    return type;
}

WASMType *
wasm_obj_get_defined_type(const WASMObjectRef obj)
{
    if ((!wasm_obj_is_struct_obj(obj)) && (!wasm_obj_is_array_obj(obj))
        && (!wasm_obj_is_func_obj(obj))) {
        bh_assert(false);
    }

    return ((WASMRttTypeRef)(obj->header))->defined_type;
}

int32
wasm_obj_get_defined_type_idx(WASMModuleCommon *const module,
                              const WASMObjectRef obj)
{
    WASMType *type = wasm_obj_get_defined_type(obj);
    uint32 i, type_idx = (uint32)-1;

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;
        uint32 type_count = wasm_module->type_count;

        for (i = 0; i < type_count; i++) {
            if (wasm_module->types[i] == type) {
                type_idx = i;
                break;
            }
        }
        bh_assert(type_idx < type_count);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;
        uint32 type_count = aot_module->type_count;

        for (i = 0; i < type_count; i++) {
            if (aot_module->types[i] == type) {
                type_idx = i;
                break;
            }
        }
        bh_assert(type_idx < type_count);
    }
#endif

    return type_idx;
}

bool
wasm_defined_type_is_func_type(WASMType *const def_type)
{
    return wasm_type_is_func_type(def_type);
}

bool
wasm_defined_type_is_struct_type(WASMType *const def_type)
{
    return wasm_type_is_struct_type(def_type);
}

bool
wasm_defined_type_is_array_type(WASMType *const def_type)
{
    return wasm_type_is_array_type(def_type);
}

wasm_ref_type_t
wasm_func_type_get_param_type(WASMFuncType *const func_type, uint32 param_idx)
{
    wasm_ref_type_t ref_type = { 0 };

    bh_assert(param_idx < func_type->param_count);

    ref_type.value_type = func_type->types[param_idx];

    if (wasm_is_type_multi_byte_type(func_type->types[param_idx])) {
        WASMRefType *param_ref_type = wasm_reftype_map_find(
            func_type->ref_type_maps, func_type->ref_type_map_count, param_idx);
        bh_assert(param_ref_type);
        ref_type.nullable = param_ref_type->ref_ht_common.nullable;
        ref_type.heap_type = param_ref_type->ref_ht_common.heap_type;
    }

    return ref_type;
}

wasm_ref_type_t
wasm_func_type_get_result_type(WASMFuncType *const func_type, uint32 result_idx)
{
    wasm_ref_type_t ref_type = { 0 };
    uint32 result_idx_with_param;

    result_idx_with_param = func_type->param_count + result_idx;
    bh_assert(result_idx < func_type->result_count);

    ref_type.value_type = func_type->types[result_idx_with_param];

    if (wasm_is_type_multi_byte_type(func_type->types[result_idx_with_param])) {
        WASMRefType *result_ref_type = wasm_reftype_map_find(
            func_type->ref_type_maps, func_type->ref_type_map_count,
            result_idx_with_param);
        bh_assert(result_ref_type);
        ref_type.nullable = result_ref_type->ref_ht_common.nullable;
        ref_type.heap_type = result_ref_type->ref_ht_common.heap_type;
    }

    return ref_type;
}

uint32
wasm_struct_type_get_field_count(WASMStructType *const struct_type)
{
    bh_assert(struct_type->base_type.type_flag == WASM_TYPE_STRUCT);
    return struct_type->field_count;
}

wasm_ref_type_t
wasm_struct_type_get_field_type(WASMStructType *const struct_type,
                                uint32 field_idx, bool *p_is_mutable)
{
    wasm_ref_type_t ref_type = { 0 };
    WASMStructFieldType field;

    bh_assert(struct_type->base_type.type_flag == WASM_TYPE_STRUCT);
    bh_assert(field_idx < struct_type->field_count);

    field = struct_type->fields[field_idx];
    ref_type.value_type = field.field_type;

    if (wasm_is_type_multi_byte_type(field.field_type)) {
        WASMRefType *field_ref_type =
            wasm_reftype_map_find(struct_type->ref_type_maps,
                                  struct_type->ref_type_map_count, field_idx);
        bh_assert(field_ref_type);
        ref_type.nullable = field_ref_type->ref_ht_common.nullable;
        ref_type.heap_type = field_ref_type->ref_ht_common.heap_type;
    }

    if (p_is_mutable) {
        *p_is_mutable = field.field_flags & 1;
    }

    return ref_type;
}

wasm_ref_type_t
wasm_array_type_get_elem_type(WASMArrayType *const array_type,
                              bool *p_is_mutable)
{
    wasm_ref_type_t ref_type = { 0 };

    ref_type.value_type = array_type->elem_type;

    if (wasm_is_type_multi_byte_type(array_type->elem_type)) {
        WASMRefType *elem_ref_type = array_type->elem_ref_type;
        ref_type.nullable = elem_ref_type->ref_ht_common.nullable;
        ref_type.heap_type = elem_ref_type->ref_ht_common.heap_type;
    }

    if (p_is_mutable) {
        *p_is_mutable = array_type->elem_flags & 1;
    }

    return ref_type;
}

bool
wasm_defined_type_equal(WASMType *const def_type1, WASMType *const def_type2,
                        WASMModuleCommon *const module)
{
    WASMTypePtr *types = NULL;
    uint32 type_count = 0;

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;

        types = wasm_module->types;
        type_count = wasm_module->type_count;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;

        types = aot_module->types;
        type_count = aot_module->type_count;
    }
#endif

    bh_assert(types);

    return wasm_type_equal(def_type1, def_type2, types, type_count);
}

bool
wasm_defined_type_is_subtype_of(WASMType *const def_type1,
                                WASMType *const def_type2,
                                WASMModuleCommon *const module)
{
    WASMTypePtr *types = NULL;
    uint32 type_count = 0;

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;

        types = wasm_module->types;
        type_count = wasm_module->type_count;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;

        types = aot_module->types;
        type_count = aot_module->type_count;
    }
#endif

    bh_assert(types);

    return wasm_type_is_subtype_of(def_type1, def_type2, types, type_count);
}

void
wasm_ref_type_set_type_idx(wasm_ref_type_t *ref_type, bool nullable,
                           int32 type_idx)
{
    bh_assert(type_idx >= 0);
    ref_type->value_type =
        nullable ? VALUE_TYPE_HT_NULLABLE_REF : VALUE_TYPE_HT_NON_NULLABLE_REF;
    ref_type->nullable = nullable;
    ref_type->heap_type = type_idx;
}

void
wasm_ref_type_set_heap_type(wasm_ref_type_t *ref_type, bool nullable,
                            int32 heap_type)
{
    bool ret;

    bh_assert(heap_type <= HEAP_TYPE_FUNC && heap_type >= HEAP_TYPE_NONE);
    ref_type->value_type =
        nullable ? VALUE_TYPE_HT_NULLABLE_REF : VALUE_TYPE_HT_NON_NULLABLE_REF;
    ref_type->nullable = nullable;
    ref_type->heap_type = heap_type;
    ret = wasm_ref_type_normalize(ref_type);
    bh_assert(ret);
    (void)ret;
}

bool
wasm_ref_type_equal(const wasm_ref_type_t *ref_type1,
                    const wasm_ref_type_t *ref_type2,
                    WASMModuleCommon *const module)
{
    wasm_ref_type_t ref_type1_norm = { 0 };
    wasm_ref_type_t ref_type2_norm = { 0 };
    uint32 type_count = 0;
    WASMTypePtr *types = NULL;
    uint8 type1;
    uint8 type2;

    bh_memcpy_s(&ref_type1_norm, (uint32)sizeof(wasm_ref_type_t), ref_type1,
                (uint32)sizeof(wasm_ref_type_t));
    bh_memcpy_s(&ref_type2_norm, (uint32)sizeof(wasm_ref_type_t), ref_type2,
                (uint32)sizeof(wasm_ref_type_t));
    if (!wasm_ref_type_normalize(&ref_type1_norm)) {
        return false;
    }
    if (!wasm_ref_type_normalize(&ref_type2_norm)) {
        return false;
    }
    type1 = ref_type1_norm.value_type;
    type2 = ref_type2_norm.value_type;

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        types = ((WASMModule *)module)->types;
        type_count = wasm_get_defined_type_count(module);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        types = ((AOTModule *)module)->types;
        type_count = wasm_get_defined_type_count(module);
    }
#endif

    return wasm_reftype_equal(type1, (WASMRefType *)&ref_type1_norm, type2,
                              (WASMRefType *)&ref_type2_norm, types,
                              type_count);
}

bool
wasm_ref_type_is_subtype_of(const wasm_ref_type_t *ref_type1,
                            const wasm_ref_type_t *ref_type2,
                            WASMModuleCommon *const module)
{
    wasm_ref_type_t ref_type1_norm = { 0 };
    wasm_ref_type_t ref_type2_norm = { 0 };
    uint8 type1;
    uint8 type2;
    WASMTypePtr *types = NULL;
    uint32 type_count = 0;

    bh_memcpy_s(&ref_type1_norm, (uint32)sizeof(wasm_ref_type_t), ref_type1,
                (uint32)sizeof(wasm_ref_type_t));
    bh_memcpy_s(&ref_type2_norm, (uint32)sizeof(wasm_ref_type_t), ref_type2,
                (uint32)sizeof(wasm_ref_type_t));
    if (!wasm_ref_type_normalize(&ref_type1_norm)) {
        return false;
    }
    if (!wasm_ref_type_normalize(&ref_type2_norm)) {
        return false;
    }
    type1 = ref_type1_norm.value_type;
    type2 = ref_type2_norm.value_type;

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        types = ((WASMModule *)module)->types;
        type_count = wasm_get_defined_type_count(module);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        types = ((AOTModule *)module)->types;
        type_count = wasm_get_defined_type_count(module);
    }
#endif

    bh_assert(types);

    return wasm_reftype_is_subtype_of(type1, (WASMRefType *)&ref_type1_norm,
                                      type2, (WASMRefType *)&ref_type2_norm,
                                      types, type_count);
}

WASMStructObjectRef
wasm_struct_obj_new_with_typeidx(WASMExecEnv *exec_env, uint32 type_idx)
{
    WASMStructObjectRef struct_obj;
    WASMModuleInstanceCommon *module_inst =
        wasm_runtime_get_module_inst(exec_env);
    WASMType *type = NULL;
    WASMRttTypeRef rtt_type = NULL;

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModule *module = ((WASMModuleInstance *)module_inst)->module;

        bh_assert(type_idx < module->type_count);
        type = module->types[type_idx];
        bh_assert(wasm_defined_type_is_struct_type(type));
        rtt_type =
            wasm_rtt_type_new(type, type_idx, module->rtt_types,
                              module->type_count, &module->rtt_type_lock);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModule *module =
            (AOTModule *)((AOTModuleInstance *)module_inst)->module;

        bh_assert(type_idx < module->type_count);
        type = module->types[type_idx];
        bh_assert(wasm_defined_type_is_struct_type(type));
        rtt_type =
            wasm_rtt_type_new(type, type_idx, module->rtt_types,
                              module->type_count, &module->rtt_type_lock);
    }
#endif

    if (!rtt_type) {
        return NULL;
    }
    struct_obj = wasm_struct_obj_new(exec_env, rtt_type);

    return struct_obj;
}

WASMStructObjectRef
wasm_struct_obj_new_with_type(WASMExecEnv *exec_env, WASMStructType *type)
{
    WASMStructObjectRef struct_obj;
    WASMModuleInstanceCommon *module_inst =
        wasm_runtime_get_module_inst(exec_env);
    WASMRttTypeRef rtt_type = NULL;
    uint32 i = 0;
    uint32 type_count = 0;

    bh_assert(type->base_type.type_flag == WASM_TYPE_STRUCT);

#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode) {
        WASMModule *module = ((WASMModuleInstance *)module_inst)->module;

        type_count = module->type_count;

        for (i = 0; i < type_count; i++) {
            if (module->types[i] == (WASMType *)type) {
                break;
            }
        }
        bh_assert(i < type_count);
        rtt_type =
            wasm_rtt_type_new((WASMType *)type, i, module->rtt_types,
                              module->type_count, &module->rtt_type_lock);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModule *module =
            (AOTModule *)((AOTModuleInstance *)module_inst)->module;

        type_count = module->type_count;

        for (i = 0; i < type_count; i++) {
            if (module->types[i] == (AOTType *)type) {
                break;
            }
        }
        bh_assert(i < type_count);
        rtt_type =
            wasm_rtt_type_new((AOTType *)type, i, module->rtt_types,
                              module->type_count, &module->rtt_type_lock);
    }
#endif

    if (!rtt_type) {
        return NULL;
    }
    struct_obj = wasm_struct_obj_new(exec_env, rtt_type);

    return struct_obj;
}

WASMArrayObjectRef
wasm_array_obj_new_with_typeidx(WASMExecEnv *exec_env, uint32 type_idx,
                                uint32 length, wasm_value_t *init_value)
{
    WASMArrayObjectRef array_obj;
    WASMModuleCommon *module = wasm_exec_env_get_module(exec_env);
    WASMType *defined_type = wasm_get_defined_type(module, type_idx);
    WASMRttTypeRef rtt_type = NULL;

    bh_assert(wasm_defined_type_is_array_type(defined_type));

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;

        rtt_type = wasm_rtt_type_new(
            defined_type, type_idx, wasm_module->rtt_types,
            wasm_module->type_count, &wasm_module->rtt_type_lock);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;

        rtt_type = wasm_rtt_type_new(
            defined_type, type_idx, aot_module->rtt_types,
            aot_module->type_count, &aot_module->rtt_type_lock);
    }
#endif

    if (!rtt_type) {
        return NULL;
    }
    array_obj = wasm_array_obj_new(exec_env, rtt_type, length, init_value);

    return array_obj;
}

WASMArrayObjectRef
wasm_array_obj_new_with_type(WASMExecEnv *exec_env, WASMArrayType *type,
                             uint32 length, wasm_value_t *init_value)
{
    WASMArrayObjectRef array_obj;
    uint32 i, type_count, type_idx = 0;
    WASMModuleCommon *module = wasm_exec_env_get_module(exec_env);

    bh_assert(type->base_type.type_flag == WASM_TYPE_ARRAY);

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;

        type_count = wasm_module->type_count;
        for (i = 0; i < type_count; i++) {
            if (wasm_module->types[i] == (WASMType *)type) {
                break;
            }
        }
        bh_assert(i < wasm_module->type_count);

        type_idx = i;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;

        type_count = aot_module->type_count;
        for (i = 0; i < type_count; i++) {
            if (aot_module->types[i] == (AOTType *)type) {
                break;
            }
        }
        bh_assert(i < aot_module->type_count);

        type_idx = i;
    }
#endif

    array_obj =
        wasm_array_obj_new_with_typeidx(exec_env, type_idx, length, init_value);

    return array_obj;
}

WASMFuncObjectRef
wasm_func_obj_new_with_typeidx(WASMExecEnv *exec_env, uint32 type_idx,
                               uint32 func_idx_bound)
{
    WASMFuncObjectRef func_obj;
    WASMRttTypeRef rtt_type = NULL;
    WASMModuleCommon *module = wasm_exec_env_get_module(exec_env);
    WASMType *defined_type = wasm_get_defined_type(module, type_idx);

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;

        rtt_type = wasm_rtt_type_new(
            defined_type, type_idx, wasm_module->rtt_types,
            wasm_module->type_count, &wasm_module->rtt_type_lock);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;

        rtt_type = wasm_rtt_type_new(
            defined_type, type_idx, aot_module->rtt_types,
            aot_module->type_count, &aot_module->rtt_type_lock);
    }
#endif

    if (!rtt_type) {
        return NULL;
    }
    func_obj = wasm_func_obj_new(exec_env, rtt_type, func_idx_bound);

    return func_obj;
}

WASMFuncObjectRef
wasm_func_obj_new_with_type(WASMExecEnv *exec_env, WASMFuncType *type,
                            uint32 func_idx_bound)
{
    WASMFuncObjectRef func_obj;
    uint32 i, type_count, type_idx = 0;
    WASMModuleCommon *module = wasm_exec_env_get_module(exec_env);

    bh_assert(type->base_type.type_flag == WASM_TYPE_FUNC);

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;

        type_count = wasm_module->type_count;
        for (i = 0; i < type_count; i++) {
            if (wasm_module->types[i] == (WASMType *)type) {
                break;
            }
        }
        bh_assert(i < wasm_module->type_count);

        type_idx = i;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;

        type_count = aot_module->type_count;
        for (i = 0; i < type_count; i++) {
            if (aot_module->types[i] == (AOTType *)type) {
                break;
            }
        }
        bh_assert(i < aot_module->type_count);

        type_idx = i;
    }
#endif

    func_obj =
        wasm_func_obj_new_with_typeidx(exec_env, type_idx, func_idx_bound);

    return func_obj;
}

bool
wasm_runtime_call_func_ref(WASMExecEnv *exec_env,
                           const WASMFuncObjectRef func_obj, uint32 argc,
                           uint32 argv[])
{
    WASMFunctionInstanceCommon *func_inst = NULL;
    uint32 func_idx = wasm_func_obj_get_func_idx_bound(func_obj);
#if WASM_ENABLE_AOT != 0
    AOTFunctionInstance aot_func_inst = { 0 };
#endif

#if WASM_ENABLE_INTERP != 0
    if (exec_env->module_inst->module_type == Wasm_Module_Bytecode) {
        WASMFunctionInstance *wasm_func_inst;
        WASMModuleInstance *module_inst =
            (WASMModuleInstance *)exec_env->module_inst;

        bh_assert(func_idx < module_inst->module->import_function_count
                                 + module_inst->module->function_count);
        wasm_func_inst = module_inst->e->functions + func_idx;
        func_inst = (WASMFunctionInstanceCommon *)wasm_func_inst;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (exec_env->module_inst->module_type == Wasm_Module_AoT) {
        uint32 func_type_idx;
        AOTModuleInstance *module_inst =
            (AOTModuleInstance *)exec_env->module_inst;
        AOTModule *module = (AOTModule *)module_inst->module;
        (void)module_inst;

        bh_assert(func_idx < module->import_func_count + module->func_count);

        aot_func_inst.func_name = "";
        aot_func_inst.func_index = func_idx;
        aot_func_inst.is_import_func = false;
        func_type_idx =
            module->func_type_indexes[func_idx - module->import_func_count];
        aot_func_inst.u.func.func_type =
            (AOTFuncType *)module->types[func_type_idx];
        aot_func_inst.u.func.func_ptr =
            module->func_ptrs[func_idx - module->import_func_count];

        func_inst = (WASMFunctionInstanceCommon *)(&aot_func_inst);
    }
#endif

    bh_assert(func_inst);
    return wasm_runtime_call_wasm(exec_env, func_inst, argc, argv);
}

bool
wasm_runtime_call_func_ref_a(WASMExecEnv *exec_env,
                             const WASMFuncObjectRef func_obj,
                             uint32 num_results, wasm_val_t results[],
                             uint32 num_args, wasm_val_t *args)
{
    /* TODO */
    return false;
}

bool
wasm_runtime_call_func_ref_v(wasm_exec_env_t exec_env,
                             const WASMFuncObjectRef func_obj,
                             uint32 num_results, wasm_val_t results[],
                             uint32 num_args, ...)
{
    /* TODO */
    return false;
}

bool
wasm_obj_is_instance_of_defined_type(WASMObjectRef obj, WASMType *defined_type,
                                     WASMModuleCommon *const module)
{
    WASMType **types = NULL;
    uint32 type_count = 0;
    uint32 type_idx = 0;

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;

        type_count = wasm_module->type_count;
        types = wasm_module->types;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;

        type_count = aot_module->type_count;
        types = (WASMType **)aot_module->types;
    }
#endif

    for (type_idx = 0; type_idx < type_count; type_idx++) {
        if (types[type_idx] == defined_type) {
            break;
        }
    }
    bh_assert(type_idx < type_count);

    return wasm_obj_is_instance_of(obj, type_idx, types, type_count);
}

bool
wasm_obj_is_instance_of_type_idx(WASMObjectRef obj, uint32 type_idx,
                                 WASMModuleCommon *const module)
{
    WASMType **types = NULL;
    uint32 type_count = 0;

#if WASM_ENABLE_INTERP != 0
    if (module->module_type == Wasm_Module_Bytecode) {
        WASMModule *wasm_module = (WASMModule *)module;

        types = wasm_module->types;
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (module->module_type == Wasm_Module_AoT) {
        AOTModule *aot_module = (AOTModule *)module;

        types = (WASMType **)aot_module->types;
    }
#endif

    bh_assert(types);

    return wasm_obj_is_instance_of(obj, type_idx, types, type_count);
}

bool
wasm_obj_is_instance_of_ref_type(const WASMObjectRef obj,
                                 const wasm_ref_type_t *ref_type)
{
    int32 heap_type = ref_type->heap_type;
    return wasm_obj_is_type_of(obj, heap_type);
}

void
wasm_runtime_push_local_obj_ref(WASMExecEnv *exec_env, WASMLocalObjectRef *ref)
{
    ref->val = NULL;
    ref->prev = exec_env->cur_local_object_ref;
    exec_env->cur_local_object_ref = ref;
}

WASMLocalObjectRef *
wasm_runtime_pop_local_obj_ref(WASMExecEnv *exec_env)
{
    WASMLocalObjectRef *local_ref = exec_env->cur_local_object_ref;
    exec_env->cur_local_object_ref = exec_env->cur_local_object_ref->prev;
    return local_ref;
}

void
wasm_runtime_pop_local_obj_refs(WASMExecEnv *exec_env, uint32 n)
{
    bh_assert(n > 0);

    do {
        exec_env->cur_local_object_ref = exec_env->cur_local_object_ref->prev;
    } while (--n > 0);
}

WASMLocalObjectRef *
wasm_runtime_get_cur_local_obj_ref(WASMExecEnv *exec_env)
{
    WASMLocalObjectRef *local_ref = exec_env->cur_local_object_ref;

    bh_assert(local_ref);
    return local_ref;
}

void
wasm_runtime_gc_prepare(WASMExecEnv *exec_env)
{
#if 0
    /* TODO: implement wasm_runtime_gc_prepare for multi-thread */
    exec_env->is_gc_reclaiming = false;
    wasm_thread_suspend_all();
    exec_env->is_gc_reclaim = 1;
    exec_env->requesting_suspend = 0;
#endif
}

void
wasm_runtime_gc_finalize(WASMExecEnv *exec_env)
{
#if 0
    /* TODO: implement wasm_runtime_gc_finalize for multi-thread */
    wasm_thread_resume_all();
    exec_env->doing_gc_reclaim = 0;
#endif
}

bool
wasm_runtime_get_wasm_object_ref_list(WASMObjectRef obj,
                                      bool *p_is_compact_mode,
                                      uint32 *p_ref_num, uint16 **p_ref_list,
                                      uint32 *p_ref_start_offset)
{
    return wasm_object_get_ref_list(obj, p_is_compact_mode, p_ref_num,
                                    p_ref_list, p_ref_start_offset);
}

bool
wasm_runtime_traverse_gc_rootset(WASMExecEnv *exec_env, void *heap)
{
#if WASM_ENABLE_INTERP != 0
    if (exec_env->module_inst->module_type == Wasm_Module_Bytecode) {
        return wasm_traverse_gc_rootset(exec_env, heap);
    }
#endif
#if WASM_ENABLE_AOT != 0
    if (exec_env->module_inst->module_type == Wasm_Module_AoT) {
        return aot_traverse_gc_rootset(exec_env, heap);
    }
#endif
    return false;
}

void
wasm_runtime_set_gc_heap_handle(WASMModuleInstanceCommon *module_inst,
                                void *gc_heap_handle)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        ((WASMModuleInstance *)module_inst)->e->common.gc_heap_handle =
            gc_heap_handle;
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstanceExtra *e =
            (AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e;
        e->common.gc_heap_handle = gc_heap_handle;
    }
#endif
}

void *
wasm_runtime_get_gc_heap_handle(WASMModuleInstanceCommon *module_inst)
{
#if WASM_ENABLE_INTERP != 0
    if (module_inst->module_type == Wasm_Module_Bytecode)
        return ((WASMModuleInstance *)module_inst)->e->common.gc_heap_handle;
#endif
#if WASM_ENABLE_AOT != 0
    if (module_inst->module_type == Wasm_Module_AoT) {
        AOTModuleInstanceExtra *e =
            (AOTModuleInstanceExtra *)((AOTModuleInstance *)module_inst)->e;
        return e->common.gc_heap_handle;
    }
#endif
    return NULL;
}

bool
wasm_runtime_get_wasm_object_extra_info_flag(WASMObjectRef obj)
{
    return obj->header & WASM_OBJ_EXTRA_INFO_FLAG;
}

void
wasm_runtime_set_wasm_object_extra_info_flag(WASMObjectRef obj, bool set)
{
    if (set) {
        obj->header |= WASM_OBJ_EXTRA_INFO_FLAG;
    }
    else {
        obj->header &= ~WASM_OBJ_EXTRA_INFO_FLAG;
    }
}
