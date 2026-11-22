/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _GC_OBJECT_H_
#define _GC_OBJECT_H_

#include "gc_type.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Object header of a WASM object, as the address of allocated memory
 * must be 8-byte aligned, the lowest 3 bits are zero, we use them to
 * mark the object:
 *   bits[0] is 1: the object is an externref object
 *   bits[1] is 1: the object is an anyref object
 *   bits[2] is 1: the object has extra information
 *   if both bits[0] and bits[1] are 0, then this object header must
 *   be a pointer of a WASMRttType, denotes that the object is a
 *   struct object, or an array object, or a function object
 */
typedef uintptr_t WASMObjectHeader;

#define WASM_OBJ_HEADER_MASK (~((uintptr_t)7))

#define WASM_OBJ_EXTERNREF_OBJ_FLAG (((uintptr_t)1) << 0)

#define WASM_OBJ_ANYREF_OBJ_FLAG (((uintptr_t)1) << 1)

#define WASM_OBJ_EXTRA_INFO_FLAG (((uintptr_t)1) << 2)

/* Representation of WASM objects */
typedef struct WASMObject {
    WASMObjectHeader header;
} WASMObject, *WASMObjectRef;

/* Representation of WASM rtt types */
typedef struct WASMRttType {
    /* type_flag must be WASM_TYPE_FUNC/STRUCT/ARRAY to
       denote an object of func, struct or array */
    uint32 type_flag;
    uint32 inherit_depth;
    WASMType *defined_type;
    WASMType *root_type;
} WASMRttType, *WASMRttTypeRef;

/* Representation of WASM externref objects */
typedef struct WASMExternrefObject {
    /* bits[0] must be 1, denotes an externref object */
    WASMObjectHeader header;
    /* an object of WASMAnyrefObjectRef which encapsulates the external
       object passed from host, or other internal objects passed to
       opcode extern.externalize */
    WASMObjectRef internal_obj;
} WASMExternrefObject, *WASMExternrefObjectRef;

/* Representation of WASM anyref objects which encapsulate the
   external object passed from host */
typedef struct WASMAnyrefObject {
    /* bits[1] must be 1, denotes an anyref object */
    WASMObjectHeader header;
    const void *host_obj;
} WASMAnyrefObject, *WASMAnyrefObjectRef;

/**
 * Representation of WASM i31 objects, the lowest bit is 1:
 * for a pointer of WASMObjectRef, if the lowest bit is 1, then it is an
 * i31 object and bits[1..31] stores the actual i31 value, otherwise
 * it is a normal object of rtt/externref/struct/array/func */
typedef uintptr_t WASMI31ObjectRef;

/* Representation of WASM struct objects */
typedef struct WASMStructObject {
    /* Must be pointer of WASMRttObject of struct type */
    WASMObjectHeader header;
    uint8 field_data[1];
} WASMStructObject, *WASMStructObjectRef;

/* Representation of WASM array objects */
typedef struct WASMArrayObject {
    /* Must be pointer of WASMRttObject of array type */
    WASMObjectHeader header;
    /* (<array length> << 2) | <array element size>,
     * elem_count = length >> 2
     * elem_size = 2 ^ (length & 0x3)
     */
    uint32 length;
    uint8 elem_data[1];
} WASMArrayObject, *WASMArrayObjectRef;

#define WASM_ARRAY_LENGTH_SHIFT 2
#define WASM_ARRAY_ELEM_SIZE_MASK 3

/* Representation of WASM function objects */
typedef struct WASMFuncObject {
    /* must be pointer of WASMRttObject of func type */
    WASMObjectHeader header;
    uint32 func_idx_bound;
} WASMFuncObject, *WASMFuncObjectRef;

/* Representation of WASM stringref objects */
typedef struct WASMStringrefObject {
    WASMObjectHeader header;
    const void *str_obj;
} WASMStringrefObject, *WASMStringrefObjectRef;

typedef struct WASMStringviewWTF8Object {
    WASMObjectHeader header;
    const void *str_obj;
} WASMStringviewWTF8Object, *WASMStringviewWTF8ObjectRef;

typedef struct WASMStringviewWTF16Object {
    WASMObjectHeader header;
    const void *str_obj;
} WASMStringviewWTF16Object, *WASMStringviewWTF16ObjectRef;

typedef struct WASMStringviewIterObject {
    WASMObjectHeader header;
    const void *str_obj;
    int32 pos;
} WASMStringviewIterObject, *WASMStringviewIterObjectRef;

struct WASMExecEnv;

inline static WASMObjectHeader
wasm_object_header(const WASMObjectRef obj)
{
    return (obj->header & WASM_OBJ_HEADER_MASK);
}

WASMRttTypeRef
wasm_rtt_type_new(WASMType *defined_type, uint32 defined_type_idx,
                  WASMRttType **rtt_types, uint32 rtt_type_count,
                  korp_mutex *rtt_type_lock);

inline static WASMType *
wasm_rtt_type_get_defined_type(const WASMRttTypeRef rtt_type)
{
    return rtt_type->defined_type;
}

WASMStructObjectRef
wasm_struct_obj_new_internal(void *heap_handle, WASMRttTypeRef rtt_type);

WASMStructObjectRef
wasm_struct_obj_new(struct WASMExecEnv *exec_env, WASMRttTypeRef rtt_type);

void
wasm_struct_obj_set_field(WASMStructObjectRef struct_obj, uint32 field_idx,
                          const WASMValue *value);

void
wasm_struct_obj_get_field(const WASMStructObjectRef struct_obj,
                          uint32 field_idx, bool sign_extend, WASMValue *value);

/**
 * Return the field count of the WASM struct object.
 *
 * @param struct_obj the WASM struct object
 *
 * @return the field count of the WASM struct object
 */
uint32
wasm_struct_obj_get_field_count(const WASMStructObjectRef struct_obj);

WASMArrayObjectRef
wasm_array_obj_new_internal(void *heap_handle, WASMRttTypeRef rtt_type,
                            uint32 length, WASMValue *init_value);

WASMArrayObjectRef
wasm_array_obj_new(struct WASMExecEnv *exec_env, WASMRttTypeRef rtt_type,
                   uint32 length, WASMValue *init_value);

void
wasm_array_obj_set_elem(WASMArrayObjectRef array_obj, uint32 elem_idx,
                        const WASMValue *value);

void
wasm_array_obj_get_elem(const WASMArrayObjectRef array_obj, uint32 elem_idx,
                        bool sign_extend, WASMValue *value);

void
wasm_array_obj_fill(const WASMArrayObjectRef array_obj, uint32 elem_idx,
                    uint32 len, WASMValue *value);

void
wasm_array_obj_copy(WASMArrayObjectRef dst_obj, uint32 dst_idx,
                    WASMArrayObjectRef src_obj, uint32 src_idx, uint32 len);

/**
 * Return the logarithm of the size of array element.
 *
 * @param array the WASM array object
 *
 * @return log(size of the array element)
 */
inline static uint32
wasm_array_obj_elem_size_log(const WASMArrayObjectRef array_obj)
{
    return (array_obj->length & WASM_ARRAY_ELEM_SIZE_MASK);
}

/**
 * Return the length of the array.
 *
 * @param array_obj the WASM array object
 *
 * @return the length of the array
 */
uint32
wasm_array_obj_length(const WASMArrayObjectRef array_obj);

/**
 * Return the address of the first element of an array object.
 *
 * @param array_obj the WASM array object
 *
 * @return the address of the first element of the array object
 */
void *
wasm_array_obj_first_elem_addr(const WASMArrayObjectRef array_obj);

/**
 * Return the address of the i-th element of an array object.
 *
 * @param array_obj the WASM array object
 * @param index the index of the element
 *
 * @return the address of the i-th element of the array object
 */
void *
wasm_array_obj_elem_addr(const WASMArrayObjectRef array_obj, uint32 elem_idx);

WASMFuncObjectRef
wasm_func_obj_new_internal(void *heap_handle, WASMRttTypeRef rtt_type,
                           uint32 func_idx_bound);

WASMFuncObjectRef
wasm_func_obj_new(struct WASMExecEnv *exec_env, WASMRttTypeRef rtt_type,
                  uint32 func_idx_bound);

uint32
wasm_func_obj_get_func_idx_bound(const WASMFuncObjectRef func_obj);

WASMFuncType *
wasm_func_obj_get_func_type(const WASMFuncObjectRef func_obj);

WASMExternrefObjectRef
wasm_externref_obj_new(struct WASMExecEnv *exec_env, const void *host_obj);

WASMAnyrefObjectRef
wasm_anyref_obj_new(struct WASMExecEnv *exec_env, const void *host_obj);

/* Implementation of opcode extern.internalize */
WASMObjectRef
wasm_externref_obj_to_internal_obj(const WASMExternrefObjectRef externref_obj);

/* Implementation of opcode extern.externalize */
WASMExternrefObjectRef
wasm_internal_obj_to_externref_obj(struct WASMExecEnv *exec_env,
                                   const WASMObjectRef internal_obj);

const void *
wasm_anyref_obj_get_value(const WASMAnyrefObjectRef anyref_obj);

const void *
wasm_externref_obj_get_value(const WASMExternrefObjectRef externref_obj);

WASMI31ObjectRef
wasm_i31_obj_new(uint32 i31_value);

uint32
wasm_i31_obj_get_value(WASMI31ObjectRef i31_obj, bool sign_extend);

bool
wasm_obj_is_i31_obj(WASMObjectRef obj);

bool
wasm_obj_is_externref_obj(WASMObjectRef obj);

bool
wasm_obj_is_anyref_obj(WASMObjectRef obj);

bool
wasm_obj_is_i31_externref_or_anyref_obj(WASMObjectRef obj);

bool
wasm_obj_is_struct_obj(WASMObjectRef obj);

bool
wasm_obj_is_array_obj(WASMObjectRef obj);

bool
wasm_obj_is_func_obj(WASMObjectRef obj);

bool
wasm_obj_is_internal_obj(WASMObjectRef obj);

bool
wasm_obj_is_eq_obj(WASMObjectRef obj);

inline static bool
wasm_obj_is_null_obj(WASMObjectRef obj)
{
    return obj == NULL_REF ? true : false;
}

inline static bool
wasm_obj_is_created_from_heap(WASMObjectRef obj)
{
    if (obj == NULL || (((uintptr_t)obj) & 1))
        /* null object or i31 object */
        return false;
    return true;
}

bool
wasm_obj_is_instance_of(WASMObjectRef obj, uint32 type_idx, WASMType **types,
                        uint32 type_count);

bool
wasm_obj_is_type_of(WASMObjectRef obj, int32 heap_type);

bool
wasm_obj_equal(WASMObjectRef obj1, WASMObjectRef obj2);

bool
wasm_object_get_ref_list(WASMObjectRef obj, bool *p_is_compact_mode,
                         uint32 *p_ref_num, uint16 **p_ref_list,
                         uint32 *p_ref_start_offset);

#if WASM_ENABLE_STRINGREF != 0
WASMStringrefObjectRef
wasm_stringref_obj_new(struct WASMExecEnv *exec_env, const void *str_obj);

WASMStringviewWTF8ObjectRef
wasm_stringview_wtf8_obj_new(struct WASMExecEnv *exec_env, const void *str_obj);

WASMStringviewWTF16ObjectRef
wasm_stringview_wtf16_obj_new(struct WASMExecEnv *exec_env,
                              const void *str_obj);

WASMStringviewIterObjectRef
wasm_stringview_iter_obj_new(struct WASMExecEnv *exec_env, const void *str_obj,
                             int32 pos);

const void *
wasm_stringref_obj_get_value(WASMStringrefObjectRef stringref_obj);

const void *
wasm_stringview_wtf8_obj_get_value(
    WASMStringviewWTF8ObjectRef stringview_wtf8_obj);

const void *
wasm_stringview_wtf16_obj_get_value(
    WASMStringviewWTF16ObjectRef stringview_wtf16_obj);

const void *
wasm_stringview_iter_obj_get_value(
    WASMStringviewIterObjectRef stringview_iter_obj);

int32
wasm_stringview_iter_obj_get_pos(
    WASMStringviewIterObjectRef stringview_iter_obj);

void
wasm_stringview_iter_obj_update_pos(
    WASMStringviewIterObjectRef stringview_iter_obj, int32 pos);

bool
wasm_obj_is_stringref_obj(WASMObjectRef obj);

bool
wasm_obj_is_stringview_wtf8_obj(WASMObjectRef obj);

bool
wasm_obj_is_stringview_wtf16_obj(WASMObjectRef obj);
#endif /* end of WASM_ENABLE_STRINGREF != 0 */

#ifdef __cplusplus
} /* end of extern "C" */
#endif

#endif /* end of _GC_OBJECT_H_ */
