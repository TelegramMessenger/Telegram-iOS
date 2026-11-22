/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#ifndef _GC_TYPE_H_
#define _GC_TYPE_H_

#include "../interpreter/wasm.h"

#ifdef __cplusplus
extern "C" {
#endif

void
wasm_dump_value_type(uint8 type, const WASMRefType *ref_type);

void
wasm_dump_func_type(const WASMFuncType *type);

void
wasm_dump_struct_type(const WASMStructType *type);

void
wasm_dump_array_type(const WASMArrayType *type);

/* Whether a group of value types is subtype of
   another group of value types */
bool
wasm_value_types_is_subtype_of(const uint8 *types1,
                               const WASMRefTypeMap *ref_type_maps1,
                               const uint8 *types2,
                               const WASMRefTypeMap *ref_type_maps2,
                               uint32 value_type_count,
                               const WASMTypePtr *types, uint32 type_count);

/* Operations of function type */

/* Whether two function types are equal */
bool
wasm_func_type_equal(const WASMFuncType *type1, const WASMFuncType *type2,
                     const WASMTypePtr *types, uint32 type_count);

/* Whether func type1 is subtype of func type2 */
bool
wasm_func_type_is_subtype_of(const WASMFuncType *type1,
                             const WASMFuncType *type2,
                             const WASMTypePtr *types, uint32 type_count);

/* Whether func type1 is one of super types of func type2,
   used for the func type check in call_indirect/call_ref opcodes */
bool
wasm_func_type_is_super_of(const WASMFuncType *type1,
                           const WASMFuncType *type2);

/* Whether func type1's result types are subtype of
   func type2's result types */
bool
wasm_func_type_result_is_subtype_of(const WASMFuncType *type,
                                    const WASMFuncType *type2,
                                    const WASMTypePtr *types,
                                    uint32 type_count);

/* Operations of struct type */

/* Whether two struct types are equal */
bool
wasm_struct_type_equal(const WASMStructType *type1, const WASMStructType *type2,
                       const WASMTypePtr *types, uint32 type_count);

/* Whether struct type1 is subtype of struct type2 */
bool
wasm_struct_type_is_subtype_of(const WASMStructType *type1,
                               const WASMStructType *type2,
                               const WASMTypePtr *types, uint32 type_count);

/* Operations of array type */

/* Whether two array types are equal */
bool
wasm_array_type_equal(const WASMArrayType *type1, const WASMArrayType *type2,
                      const WASMTypePtr *types, uint32 type_count);

/* Whether array type1 is subtype of array type2 */
bool
wasm_array_type_is_subtype_of(const WASMArrayType *type1,
                              const WASMArrayType *type2,
                              const WASMTypePtr *types, uint32 type_count);

/* Operations of wasm type */

/* Whether a wasm type is a function type */
inline static bool
wasm_type_is_func_type(const WASMType *type)
{
    return type->type_flag == WASM_TYPE_FUNC ? true : false;
}

/* Whether a wasm type is a struct type */
inline static bool
wasm_type_is_struct_type(const WASMType *type)
{
    return type->type_flag == WASM_TYPE_STRUCT ? true : false;
}

/* Whether a wasm type is an array type */
inline static bool
wasm_type_is_array_type(const WASMType *type)
{
    return type->type_flag == WASM_TYPE_ARRAY ? true : false;
}

/* Whether two wasm types are equal */
bool
wasm_type_equal(const WASMType *type1, const WASMType *type2,
                const WASMTypePtr *types, uint32 type_count);

/* Whether wasm type1 is subtype of wasm type2 */
bool
wasm_type_is_subtype_of(const WASMType *type1, const WASMType *type2,
                        const WASMTypePtr *types, uint32 type_count);

/* Operations of reference type */

/* Whether a value type is a reference type */
inline static bool
wasm_is_type_reftype(uint8 type)
{
    return ((type >= (uint8)REF_TYPE_ARRAYREF
             && type <= (uint8)REF_TYPE_NULLFUNCREF)
            || (type >= (uint8)REF_TYPE_HT_NULLABLE
                && type <= (uint8)REF_TYPE_HT_NON_NULLABLE)
#if WASM_ENABLE_STRINGREF != 0
            || (type >= (uint8)REF_TYPE_STRINGVIEWWTF8
                && type <= (uint8)REF_TYPE_STRINGREF)
            || (type >= (uint8)REF_TYPE_STRINGVIEWITER
                && type <= (uint8)REF_TYPE_STRINGVIEWWTF16)
#endif
                )
               ? true
               : false;
}

/* Whether a negative value is a valid heap type */
inline static bool
wasm_is_valid_heap_type(int32 heap_type)
{
    return ((heap_type <= HEAP_TYPE_NOFUNC && heap_type >= HEAP_TYPE_ARRAY)
#if WASM_ENABLE_STRINGREF != 0
            || heap_type == HEAP_TYPE_STRINGREF
            || heap_type == HEAP_TYPE_STRINGVIEWWTF8
            || heap_type == HEAP_TYPE_STRINGVIEWWTF16
            || heap_type == HEAP_TYPE_STRINGVIEWITER
#endif
            )
               ? true
               : false;
}

/* Whether a value type is multi-byte type, or, requires ref type map
   to retrieve extra info */
inline static bool
wasm_is_type_multi_byte_type(uint8 type)
{
    return (type == (uint8)REF_TYPE_HT_NULLABLE
            || type == (uint8)REF_TYPE_HT_NON_NULLABLE)
               ? true
               : false;
}

/* Whether a reference type is a funcref type */
inline static bool
wasm_is_reftype_funcref(uint8 type)
{
    return type == (uint8)REF_TYPE_FUNCREF ? true : false;
}

/* Whether a reference type is an externref type */
inline static bool
wasm_is_reftype_externref(uint8 type)
{
    return type == (uint8)REF_TYPE_EXTERNREF ? true : false;
}

/* Whether a reference type is an anyref type */
inline static bool
wasm_is_reftype_anyref(uint8 type)
{
    return type == (uint8)REF_TYPE_ANYREF ? true : false;
}

/* Whether a reference type is an eqref type */
inline static bool
wasm_is_reftype_eqref(uint8 type)
{
    return type == (uint8)REF_TYPE_EQREF ? true : false;
}

/* Whether a reference type is a (ref null ht) type */
inline static bool
wasm_is_reftype_htref_nullable(uint8 type)
{
    return type == (uint8)REF_TYPE_HT_NULLABLE ? true : false;
}

/* Whether a reference type is a (ref ht) type */
inline static bool
wasm_is_reftype_htref_non_nullable(uint8 type)
{
    return type == (uint8)REF_TYPE_HT_NON_NULLABLE ? true : false;
}

/* Whether a reference type is an i31ref type */
inline static bool
wasm_is_reftype_i31ref(uint8 type)
{
    return type == (uint8)REF_TYPE_I31REF ? true : false;
}

/* Whether a reference type is a structref type */
inline static bool
wasm_is_reftype_structref(uint8 type)
{
    return type == (uint8)REF_TYPE_STRUCTREF ? true : false;
}

/* Whether a reference type is an arrayref type */
inline static bool
wasm_is_reftype_arrayref(uint8 type)
{
    return type == (uint8)REF_TYPE_ARRAYREF ? true : false;
}

/* Whether a reference type is a nullref type */
inline static bool
wasm_is_reftype_nullref(uint8 type)
{
    return type == (uint8)REF_TYPE_NULLREF ? true : false;
}

/* Whether a reference type is a nullfuncref type */
inline static bool
wasm_is_reftype_nullfuncref(uint8 type)
{
    return type == (uint8)REF_TYPE_NULLFUNCREF ? true : false;
}

/* Whether a reference type is a nullexternref type */
inline static bool
wasm_is_reftype_nullexternref(uint8 type)
{
    return type == (uint8)REF_TYPE_NULLEXTERNREF ? true : false;
}

/* Return the size of a reference type */
uint32
wasm_reftype_size(uint8 type);

/* Return the actual WASMRefType struct size required of a reference type */
uint32
wasm_reftype_struct_size(const WASMRefType *ref_type);

/* Operations of ref heap type */

/* Whether a ref heap type is (type i), i : typeidx, >= 0 */
inline static bool
wasm_is_refheaptype_typeidx(const RefHeapType_Common *ref_heap_type)
{
    return ref_heap_type->heap_type >= 0 ? true : false;
}

/* Whether a ref heap type is a common type: func/any/eq/i31/data,
   not (type i) or (rtt n i) or (rtt i) */
inline static bool
wasm_is_refheaptype_common(const RefHeapType_Common *ref_heap_type)
{
    return ((ref_heap_type->heap_type >= (int32)HEAP_TYPE_ARRAY
             && ref_heap_type->heap_type <= (int32)HEAP_TYPE_NONE)
#if WASM_ENABLE_STRINGREF != 0
            || (ref_heap_type->heap_type >= (int32)HEAP_TYPE_STRINGVIEWITER
                && ref_heap_type->heap_type <= (int32)HEAP_TYPE_I31)
#endif
                )
               ? true
               : false;
}

/* Whether a ref heap type is a func type */
inline static bool
wasm_is_refheaptype_func(const RefHeapType_Common *ref_heap_type)
{
    return ref_heap_type->heap_type == (int32)HEAP_TYPE_FUNC ? true : false;
}

/* Whether a ref heap type is an any type */
inline static bool
wasm_is_refheaptype_any(const RefHeapType_Common *ref_heap_type)
{
    return ref_heap_type->heap_type == (int32)HEAP_TYPE_ANY ? true : false;
}

/* Whether a ref heap type is an eq type */
inline static bool
wasm_is_refheaptype_eq(const RefHeapType_Common *ref_heap_type)
{
    return ref_heap_type->heap_type == (int32)HEAP_TYPE_EQ ? true : false;
}

/* Whether a ref heap type is an i31 type */
inline static bool
wasm_is_refheaptype_i31(const RefHeapType_Common *ref_heap_type)
{
    return ref_heap_type->heap_type == (int32)HEAP_TYPE_I31 ? true : false;
}

/* Whether a ref heap type is an array type */
inline static bool
wasm_is_refheaptype_array(const RefHeapType_Common *ref_heap_type)
{
    return ref_heap_type->heap_type == (int32)HEAP_TYPE_ARRAY ? true : false;
}

#if WASM_ENABLE_STRINGREF != 0
inline static bool
wasm_is_refheaptype_stringrefs(const RefHeapType_Common *ref_heap_type)
{
    return ref_heap_type->heap_type <= (int32)HEAP_TYPE_STRINGREF
                   && ref_heap_type->heap_type >= HEAP_TYPE_STRINGVIEWITER
               ? true
               : false;
}
#endif

/* Whether two ref heap types are equal */
bool
wasm_refheaptype_equal(const RefHeapType_Common *ref_heap_type1,
                       const RefHeapType_Common *ref_heap_type2,
                       const WASMTypePtr *types, uint32 type_count);

/* Whether two ref types are equal */
bool
wasm_reftype_equal(uint8 type1, const WASMRefType *reftype1, uint8 type2,
                   const WASMRefType *reftype2, const WASMTypePtr *types,
                   uint32 type_count);

/* Whether ref type1 is subtype of ref type2 */
bool
wasm_reftype_is_subtype_of(uint8 type1, const WASMRefType *reftype1,
                           uint8 type2, const WASMRefType *reftype2,
                           const WASMTypePtr *types, uint32 type_count);

/* Returns a new reference type which is a duplication of ref_type,
   the caller should use wasm_runtime_free() to free the new ref type */
WASMRefType *
wasm_reftype_dup(const WASMRefType *ref_type);

/* Set fields of RefHeapType_TypeIdx */
void
wasm_set_refheaptype_typeidx(RefHeapType_TypeIdx *ref_ht_typeidx, bool nullable,
                             int32 type_idx);

/* Set fields of RefHeapType_Common */
void
wasm_set_refheaptype_common(RefHeapType_Common *ref_ht_common, bool nullable,
                            int32 heap_type);

/* Find the related reftype in reftype map array with index */
WASMRefType *
wasm_reftype_map_find(WASMRefTypeMap *ref_type_maps, uint32 ref_type_map_count,
                      uint32 index_to_find);

/* Create a new hash set of reference type */
HashMap *
wasm_reftype_set_create(uint32 size);

/* Insert a reference type into the hash set */
WASMRefType *
wasm_reftype_set_insert(HashMap *ref_type_set, const WASMRefType *ref_type);

#ifdef __cplusplus
} /* end of extern "C" */
#endif

#endif /* end of _GC_TYPE_H_ */
