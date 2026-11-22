/*
 * Copyright (C) 2019 Intel Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 */

#include "gc_type.h"

void
wasm_dump_value_type(uint8 type, const WASMRefType *ref_type)
{
    switch (type) {
        case VALUE_TYPE_I32:
            os_printf("i32");
            break;
        case VALUE_TYPE_I64:
            os_printf("i64");
            break;
        case VALUE_TYPE_F32:
            os_printf("f32");
            break;
        case VALUE_TYPE_F64:
            os_printf("f64");
            break;
        case VALUE_TYPE_V128:
            os_printf("v128");
            break;
        case PACKED_TYPE_I8:
            os_printf("i8");
            break;
        case PACKED_TYPE_I16:
            os_printf("i16");
            break;
        case REF_TYPE_FUNCREF:
            os_printf("funcref");
            break;
        case REF_TYPE_EXTERNREF:
            os_printf("externref");
            break;
        case REF_TYPE_ANYREF:
            os_printf("anyref");
            break;
        case REF_TYPE_EQREF:
            os_printf("eqref");
            break;
        case REF_TYPE_HT_NULLABLE:
        case REF_TYPE_HT_NON_NULLABLE:
        {
            os_printf("(ref ");
            if (ref_type->ref_ht_common.nullable)
                os_printf("null ");
            if (wasm_is_refheaptype_common(&ref_type->ref_ht_common)) {
                switch (ref_type->ref_ht_common.heap_type) {
                    case HEAP_TYPE_FUNC:
                        os_printf("func");
                        break;
                    case HEAP_TYPE_EXTERN:
                        os_printf("extern");
                        break;
                    case HEAP_TYPE_ANY:
                        os_printf("any");
                        break;
                    case HEAP_TYPE_EQ:
                        os_printf("eq");
                        break;
                    case HEAP_TYPE_I31:
                        os_printf("i31");
                        break;
                    case HEAP_TYPE_STRUCT:
                        os_printf("struct");
                        break;
                    case HEAP_TYPE_ARRAY:
                        os_printf("array");
                        break;
                    case HEAP_TYPE_NONE:
                        os_printf("none");
                        break;
                    case HEAP_TYPE_NOFUNC:
                        os_printf("nofunc");
                        break;
                    case HEAP_TYPE_NOEXTERN:
                        os_printf("noextern");
                        break;
                    default:
                        bh_assert(0);
                        break;
                }
            }
            else if (wasm_is_refheaptype_typeidx(&ref_type->ref_ht_common)) {
                os_printf("%" PRId32, ref_type->ref_ht_typeidx.type_idx);
            }
            else {
                bh_assert(0);
            }
            os_printf(")");
            break;
        }
        case REF_TYPE_I31REF:
            os_printf("i31ref");
            break;
        case REF_TYPE_STRUCTREF:
            os_printf("structref");
            break;
        case REF_TYPE_ARRAYREF:
            os_printf("arrayref");
            break;
        case REF_TYPE_NULLREF:
            os_printf("nullref");
            break;
        case REF_TYPE_NULLFUNCREF:
            os_printf("nullfuncref");
            break;
        case REF_TYPE_NULLEXTERNREF:
            os_printf("nullexternref");
            break;
        default:
            bh_assert(0);
    }
}

void
wasm_dump_func_type(const WASMFuncType *type)
{
    uint32 i, j = 0;
    const WASMRefType *ref_type = NULL;

    if (type->base_type.parent_type_idx != (uint32)-1) {
        if (!type->base_type.is_sub_final)
            os_printf("sub ");
        else
            os_printf("sub final ");
        os_printf("%" PRIu32 " ", type->base_type.parent_type_idx);
    }

    os_printf("func [");

    for (i = 0; i < type->param_count; i++) {
        if (wasm_is_type_multi_byte_type(type->types[i])) {
            bh_assert(j < type->ref_type_map_count);
            bh_assert(i == type->ref_type_maps[j].index);
            ref_type = type->ref_type_maps[j++].ref_type;
        }
        else
            ref_type = NULL;
        wasm_dump_value_type(type->types[i], ref_type);
        if (i < (uint32)type->param_count - 1)
            os_printf(" ");
    }

    os_printf("] -> [");

    for (; i < (uint32)(type->param_count + type->result_count); i++) {
        if (wasm_is_type_multi_byte_type(type->types[i])) {
            bh_assert(j < type->ref_type_map_count);
            bh_assert(i == type->ref_type_maps[j].index);
            ref_type = type->ref_type_maps[j++].ref_type;
        }
        else
            ref_type = NULL;
        wasm_dump_value_type(type->types[i], ref_type);
        if (i < (uint32)type->param_count + type->result_count - 1)
            os_printf(" ");
    }

    os_printf("]\n");
}

void
wasm_dump_struct_type(const WASMStructType *type)
{
    uint32 i, j = 0;
    const WASMRefType *ref_type = NULL;

    if (type->base_type.parent_type_idx != (uint32)-1) {
        if (!type->base_type.is_sub_final)
            os_printf("sub ");
        else
            os_printf("sub final ");
        os_printf("%" PRIu32 " ", type->base_type.parent_type_idx);
    }

    os_printf("struct");

    for (i = 0; i < type->field_count; i++) {
        os_printf(" (field ");
        if (type->fields[i].field_flags & 1)
            os_printf("(mut ");
        if (wasm_is_type_multi_byte_type(type->fields[i].field_type)) {
            bh_assert(j < type->ref_type_map_count);
            bh_assert(i == type->ref_type_maps[j].index);
            ref_type = type->ref_type_maps[j++].ref_type;
        }
        else
            ref_type = NULL;
        wasm_dump_value_type(type->fields[i].field_type, ref_type);
        if (type->fields[i].field_flags & 1)
            os_printf(")");
        os_printf(")");
    }

    os_printf("\n");
}

void
wasm_dump_array_type(const WASMArrayType *type)
{
    if (type->base_type.parent_type_idx != (uint32)-1) {
        if (!type->base_type.is_sub_final)
            os_printf("sub ");
        else
            os_printf("sub final ");
        os_printf("%" PRIu32 " ", type->base_type.parent_type_idx);
    }

    os_printf("array ");

    if (type->elem_flags & 1)
        os_printf("(mut ");
    wasm_dump_value_type(type->elem_type, type->elem_ref_type);
    if (type->elem_flags & 1)
        os_printf(")");
    os_printf("\n");
}

bool
wasm_value_types_is_subtype_of(const uint8 *types1,
                               const WASMRefTypeMap *ref_type_maps1,
                               const uint8 *types2,
                               const WASMRefTypeMap *ref_type_maps2,
                               uint32 value_type_count,
                               const WASMTypePtr *types, uint32 type_count)
{
    uint32 i;
    WASMRefType *ref_type1, *ref_type2;

    for (i = 0; i < value_type_count; i++) {
        ref_type1 = ref_type2 = NULL;
        if (wasm_is_type_multi_byte_type(types1[i])) {
            ref_type1 = ref_type_maps1->ref_type;
            ref_type_maps1++;
        }
        if (wasm_is_type_multi_byte_type(types2[i])) {
            ref_type2 = ref_type_maps2->ref_type;
            ref_type_maps2++;
        }
        if (!wasm_reftype_is_subtype_of(types1[i], ref_type1, types2[i],
                                        ref_type2, types, type_count)) {
            return false;
        }
    }
    return true;
}

static bool
rec_ref_type_equal(const WASMRefType *ref_type1, const WASMRefType *ref_type2,
                   uint32 rec_begin_type_idx1, uint32 rec_begin_type_idx2,
                   uint32 rec_count, const WASMTypePtr *types,
                   uint32 type_count)
{
    uint32 type_idx1, type_idx2;

    if (!wasm_is_refheaptype_typeidx(&ref_type1->ref_ht_common)
        || !wasm_is_refheaptype_typeidx(&ref_type2->ref_ht_common))
        return ref_type1->ref_ht_common.heap_type
                       == ref_type2->ref_ht_common.heap_type
                   ? true
                   : false;

    /* Now both ref types are type of (ref type_idx) */
    type_idx1 = ref_type1->ref_ht_typeidx.type_idx;
    type_idx2 = ref_type2->ref_ht_typeidx.type_idx;

    if (type_idx1 >= rec_begin_type_idx1
        && type_idx1 < rec_begin_type_idx1 + rec_count) {
        /* The converted iso-recursive types should be the same */
        bool ret = (type_idx2 >= rec_begin_type_idx2
                    && type_idx2 < rec_begin_type_idx2 + rec_count
                    && type_idx1 - rec_begin_type_idx1
                           == type_idx2 - rec_begin_type_idx2)
                       ? true
                       : false;
        return ret;
    }
    else if (type_idx2 >= rec_begin_type_idx2
             && type_idx2 < rec_begin_type_idx2 + rec_count) {
        /* The converted iso-recursive types should be the same */
        bool ret = (type_idx1 >= rec_begin_type_idx1
                    && type_idx1 < rec_begin_type_idx1 + rec_count
                    && type_idx1 - rec_begin_type_idx1
                           == type_idx2 - rec_begin_type_idx2)
                       ? true
                       : false;
        return ret;
    }

    return types[type_idx1] == types[type_idx2] ? true : false;
}

bool
wasm_func_type_equal(const WASMFuncType *type1, const WASMFuncType *type2,
                     const WASMTypePtr *types, uint32 type_count)
{
    uint32 i, j = 0;

    if (type1 == type2)
        return true;

    if (type1->param_count != type2->param_count
        || type1->result_count != type2->result_count
        || type1->ref_type_map_count != type2->ref_type_map_count)
        return false;

    for (i = 0; i < (uint32)(type1->param_count + type1->result_count); i++) {
        if (type1->types[i] != type2->types[i])
            return false;

        if (wasm_is_type_multi_byte_type(type1->types[i])) {
            const WASMRefType *ref_type1, *ref_type2;

            bh_assert(j < type1->ref_type_map_count);
            bh_assert(i == type1->ref_type_maps[j].index
                      && i == type2->ref_type_maps[j].index);

            ref_type1 = type1->ref_type_maps[j].ref_type;
            ref_type2 = type2->ref_type_maps[j].ref_type;

            if (!rec_ref_type_equal(
                    ref_type1, ref_type2, type1->base_type.rec_begin_type_idx,
                    type2->base_type.rec_begin_type_idx,
                    type1->base_type.rec_count, types, type_count))
                return false;

            j++;
        }
    }

    return true;
}

bool
wasm_struct_type_equal(const WASMStructType *type1, const WASMStructType *type2,
                       const WASMTypePtr *types, uint32 type_count)
{
    uint32 i, j = 0;

    if (type1 == type2)
        return true;

    if (type1->field_count != type2->field_count
        || type1->ref_type_map_count != type2->ref_type_map_count)
        return false;

    for (i = 0; i < type1->field_count; i++) {
        if (type1->fields[i].field_type != type2->fields[i].field_type
            || type1->fields[i].field_flags != type2->fields[i].field_flags)
            return false;

        if (wasm_is_type_multi_byte_type(type1->fields[i].field_type)) {
            const WASMRefType *ref_type1, *ref_type2;

            bh_assert(j < type1->ref_type_map_count);
            bh_assert(i == type1->ref_type_maps[j].index
                      && i == type2->ref_type_maps[j].index);

            ref_type1 = type1->ref_type_maps[j].ref_type;
            ref_type2 = type2->ref_type_maps[j].ref_type;

            if (!rec_ref_type_equal(
                    ref_type1, ref_type2, type1->base_type.rec_begin_type_idx,
                    type2->base_type.rec_begin_type_idx,
                    type1->base_type.rec_count, types, type_count))
                return false;

            j++;
        }
    }

    return true;
}

bool
wasm_array_type_equal(const WASMArrayType *type1, const WASMArrayType *type2,
                      const WASMTypePtr *types, uint32 type_count)
{
    if (type1 == type2)
        return true;

    if (type1->elem_flags != type2->elem_flags)
        return false;

    if (type1->elem_type != type2->elem_type)
        return false;

    if (!wasm_is_type_multi_byte_type(type1->elem_type))
        return true;

    return rec_ref_type_equal(type1->elem_ref_type, type2->elem_ref_type,
                              type1->base_type.rec_begin_type_idx,
                              type2->base_type.rec_begin_type_idx,
                              type1->base_type.rec_count, types, type_count);
}

bool
wasm_type_equal(const WASMType *type1, const WASMType *type2,
                const WASMTypePtr *types, uint32 type_count)
{
    uint32 rec_begin_type_idx1 = type1->rec_begin_type_idx;
    uint32 rec_begin_type_idx2 = type2->rec_begin_type_idx;
    uint32 parent_type_idx1, parent_type_idx2, rec_count;

    if (type1 == type2)
        return true;

    if (!(type1->type_flag == type2->type_flag
          && type1->is_sub_final == type2->is_sub_final
          && type1->rec_count == type2->rec_count
          && type1->rec_idx == type2->rec_idx))
        return false;

    rec_count = type1->rec_count;

    parent_type_idx1 = type1->parent_type_idx;
    parent_type_idx2 = type2->parent_type_idx;

    if (parent_type_idx1 >= rec_begin_type_idx1
        && parent_type_idx1 < rec_begin_type_idx1 + rec_count) {
        /* The converted iso-recursive types should be the same */
        if (!(parent_type_idx2 >= rec_begin_type_idx2
              && parent_type_idx2 < rec_begin_type_idx2 + rec_count
              && parent_type_idx1 - rec_begin_type_idx1
                     == parent_type_idx2 - rec_begin_type_idx2)) {
            return false;
        }
    }
    else if (parent_type_idx2 >= rec_begin_type_idx2
             && parent_type_idx2 < rec_begin_type_idx2 + rec_count) {
        /* The converted iso-recursive types should be the same */
        if (!(parent_type_idx1 >= rec_begin_type_idx1
              && parent_type_idx1 < rec_begin_type_idx1 + rec_count
              && parent_type_idx1 - rec_begin_type_idx1
                     == parent_type_idx2 - rec_begin_type_idx2)) {
            return false;
        }
    }
    else if (type1->parent_type != type2->parent_type) {
        /* The parent types should be same since they have been
           normalized and equivalence types with different type
           indexes are referring to a same WASMType */
        return false;
    }

    if (wasm_type_is_func_type(type1))
        return wasm_func_type_equal((WASMFuncType *)type1,
                                    (WASMFuncType *)type2, types, type_count);
    else if (wasm_type_is_struct_type(type1))
        return wasm_struct_type_equal((WASMStructType *)type1,
                                      (WASMStructType *)type2, types,
                                      type_count);
    else if (wasm_type_is_array_type(type1))
        return wasm_array_type_equal((WASMArrayType *)type1,
                                     (WASMArrayType *)type2, types, type_count);

    bh_assert(0);
    return false;
}

bool
wasm_func_type_is_subtype_of(const WASMFuncType *type1,
                             const WASMFuncType *type2,
                             const WASMTypePtr *types, uint32 type_count)
{
    const WASMRefType *ref_type1 = NULL, *ref_type2 = NULL;
    uint32 i, j1 = 0, j2 = 0;

    if (type1 == type2)
        return true;

    if (type1->param_count != type2->param_count
        || type1->result_count != type2->result_count)
        return false;

    for (i = 0; i < type1->param_count; i++) {
        if (wasm_is_type_multi_byte_type(type1->types[i])) {
            bh_assert(j1 < type1->ref_type_map_count);
            ref_type1 = type1->ref_type_maps[j1++].ref_type;
        }
        if (wasm_is_type_multi_byte_type(type2->types[i])) {
            bh_assert(j2 < type2->ref_type_map_count);
            ref_type2 = type2->ref_type_maps[j2++].ref_type;
        }
        if (!wasm_reftype_is_subtype_of(type2->types[i], ref_type2,
                                        type1->types[i], ref_type1, types,
                                        type_count)) {
            return false;
        }
    }

    for (; i < (uint32)(type1->param_count + type1->result_count); i++) {
        if (wasm_is_type_multi_byte_type(type1->types[i])) {
            bh_assert(j1 < type1->ref_type_map_count);
            ref_type1 = type1->ref_type_maps[j1++].ref_type;
        }
        if (wasm_is_type_multi_byte_type(type2->types[i])) {
            bh_assert(j2 < type2->ref_type_map_count);
            ref_type2 = type2->ref_type_maps[j2++].ref_type;
        }
        if (!wasm_reftype_is_subtype_of(type1->types[i], ref_type1,
                                        type2->types[i], ref_type2, types,
                                        type_count)) {
            return false;
        }
    }

    return true;
}

bool
wasm_func_type_result_is_subtype_of(const WASMFuncType *type1,
                                    const WASMFuncType *type2,
                                    const WASMTypePtr *types, uint32 type_count)
{
    const WASMRefType *ref_type1 = NULL, *ref_type2 = NULL;
    const WASMRefTypeMap *ref_type_map1, *ref_type_map2;
    uint32 i;

    if (type1 == type2)
        return true;

    if (type1->result_count != type2->result_count)
        return false;

    ref_type_map1 = type1->result_ref_type_maps;
    ref_type_map2 = type2->result_ref_type_maps;

    for (i = 0; i < type1->result_count; i++) {
        ref_type1 = ref_type2 = NULL;
        if (wasm_is_type_multi_byte_type(
                type1->types[type1->param_count + i])) {
            bh_assert(ref_type_map1
                      && ref_type_map1->index == type1->param_count + i);
            ref_type1 = ref_type_map1->ref_type;
            ref_type_map1++;
        }
        if (wasm_is_type_multi_byte_type(
                type2->types[type2->param_count + i])) {
            bh_assert(ref_type_map2
                      && ref_type_map2->index == type1->param_count + i);
            ref_type2 = ref_type_map2->ref_type;
            ref_type_map2++;
        }
        if (!wasm_reftype_is_subtype_of(type1->types[type1->param_count + i],
                                        ref_type1,
                                        type2->types[type2->param_count + i],
                                        ref_type2, types, type_count)) {
            return false;
        }
    }
    return true;
}

bool
wasm_struct_type_is_subtype_of(const WASMStructType *type1,
                               const WASMStructType *type2,
                               const WASMTypePtr *types, uint32 type_count)
{
    const WASMRefType *ref_type1 = NULL, *ref_type2 = NULL;
    uint32 i, j1 = 0, j2 = 0;

    /**
     * A structure type is a supertype of another structure type if
     *   its field list is a prefix of the other (width subtyping).
     * A structure type also is a supertype of another structure type
     *   if they have the same fields and for each field type:
     *     The field is mutable in both types and the storage types
     *       are the same.
     *     The field is immutable in both types and their storage types
     *       are in (covariant) subtype relation (depth subtyping).
     */

    if (type1 == type2)
        return true;

    if (type1->field_count > type2->field_count) {
        /* Check whether type1's field list is a prefix of type2 */
        for (i = 0; i < type2->field_count; i++) {
            if (type1->fields[i].field_flags != type2->fields[i].field_flags)
                return false;
            if (wasm_is_type_multi_byte_type(type1->fields[i].field_type)) {
                bh_assert(j1 < type1->ref_type_map_count);
                ref_type1 = type1->ref_type_maps[j1++].ref_type;
            }
            if (wasm_is_type_multi_byte_type(type2->fields[i].field_type)) {
                bh_assert(j2 < type2->ref_type_map_count);
                ref_type2 = type2->ref_type_maps[j2++].ref_type;
            }
            if (!wasm_reftype_is_subtype_of(type1->fields[i].field_type,
                                            ref_type1,
                                            type2->fields[i].field_type,
                                            ref_type2, types, type_count)) {
                return false;
            }
        }
        return true;
    }
    else if (type1->field_count == type2->field_count) {
        /* Check each field's flag and type */
        for (i = 0; i < type1->field_count; i++) {
            if (type1->fields[i].field_flags != type2->fields[i].field_flags)
                return false;

            if (type1->fields[i].field_flags & 1) {
                /* The field is mutable in both types: the storage types
                   must be the same */
                if (type1->fields[i].field_type != type2->fields[i].field_type)
                    return false;
                if (wasm_is_type_multi_byte_type(type1->fields[i].field_type)) {
                    bh_assert(j1 < type1->ref_type_map_count);
                    bh_assert(j2 < type2->ref_type_map_count);
                    ref_type1 = type1->ref_type_maps[j1++].ref_type;
                    ref_type2 = type2->ref_type_maps[j2++].ref_type;
                    if (!wasm_reftype_equal(ref_type1->ref_type, ref_type1,
                                            ref_type2->ref_type, ref_type2,
                                            types, type_count))
                        return false;
                }
            }
            else {
                /* The field is immutable in both types: their storage types
                   must be in (covariant) subtype relation (depth subtyping) */
                if (wasm_is_type_multi_byte_type(type1->fields[i].field_type)) {
                    bh_assert(j1 < type1->ref_type_map_count);
                    ref_type1 = type1->ref_type_maps[j1++].ref_type;
                }
                if (wasm_is_type_multi_byte_type(type2->fields[i].field_type)) {
                    bh_assert(j2 < type2->ref_type_map_count);
                    ref_type2 = type2->ref_type_maps[j2++].ref_type;
                }
                if (!wasm_reftype_is_subtype_of(type1->fields[i].field_type,
                                                ref_type1,
                                                type2->fields[i].field_type,
                                                ref_type2, types, type_count))
                    return false;
            }
        }
        return true;
    }

    return false;
}

bool
wasm_array_type_is_subtype_of(const WASMArrayType *type1,
                              const WASMArrayType *type2,
                              const WASMTypePtr *types, uint32 type_count)
{
    /**
     * An array type is a supertype of another array type if:
     *   Both element types are mutable and the storage types are the same.
     *   Both element types are immutable and their storage types are in
     *     (covariant) subtype relation (depth subtyping).
     */

    if (type1->elem_flags != type2->elem_flags)
        return false;

    if (type1->elem_flags & 1) {
        /* The elem is mutable in both types: the storage types
           must be the same */
        return wasm_reftype_equal(type1->elem_type, type1->elem_ref_type,
                                  type2->elem_type, type2->elem_ref_type, types,
                                  type_count);
    }
    else {
        /* The elem is immutable in both types: their storage types
           must be in (covariant) subtype relation (depth subtyping) */
        return wasm_reftype_is_subtype_of(
            type1->elem_type, type1->elem_ref_type, type2->elem_type,
            type2->elem_ref_type, types, type_count);
    }
    return false;
}

bool
wasm_type_is_subtype_of(const WASMType *type1, const WASMType *type2,
                        const WASMTypePtr *types, uint32 type_count)
{
    if (type1 == type2)
        return true;

    if (type1->type_flag != type2->type_flag)
        return false;

    if (wasm_type_is_func_type(type1))
        return wasm_func_type_is_subtype_of(
            (WASMFuncType *)type1, (WASMFuncType *)type2, types, type_count);
    else if (wasm_type_is_struct_type(type1))
        return wasm_struct_type_is_subtype_of((WASMStructType *)type1,
                                              (WASMStructType *)type2, types,
                                              type_count);
    else if (wasm_type_is_array_type(type1))
        return wasm_array_type_is_subtype_of(
            (WASMArrayType *)type1, (WASMArrayType *)type2, types, type_count);

    bh_assert(0);
    return false;
}

uint32
wasm_reftype_size(uint8 type)
{
    if (type == VALUE_TYPE_I32 || type == VALUE_TYPE_F32)
        return 4;
    else if (type == VALUE_TYPE_I64 || type == VALUE_TYPE_F64)
        return 8;
    else if ((type >= (uint8)REF_TYPE_ARRAYREF
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
        return sizeof(uintptr_t);
    else if (type == PACKED_TYPE_I8)
        return 1;
    else if (type == PACKED_TYPE_I16)
        return 2;
    else if (type == VALUE_TYPE_V128)
        return 16;
    else {
        bh_assert(0);
        return 0;
    }

    return 0;
}

uint32
wasm_reftype_struct_size(const WASMRefType *ref_type)
{
    bh_assert(wasm_is_reftype_htref_nullable(ref_type->ref_type)
              || wasm_is_reftype_htref_non_nullable(ref_type->ref_type));
    bh_assert(wasm_is_refheaptype_typeidx(&ref_type->ref_ht_common)
              || wasm_is_refheaptype_common(&ref_type->ref_ht_common));

    return (uint32)sizeof(RefHeapType_Common);
}

bool
wasm_refheaptype_equal(const RefHeapType_Common *ref_heap_type1,
                       const RefHeapType_Common *ref_heap_type2,
                       const WASMTypePtr *types, uint32 type_count)
{
    if (ref_heap_type1 == ref_heap_type2)
        return true;

    if (ref_heap_type1->ref_type != ref_heap_type2->ref_type)
        return false;

    if (ref_heap_type1->heap_type != ref_heap_type2->heap_type) {
        if (wasm_is_refheaptype_typeidx(ref_heap_type1)
            && wasm_is_refheaptype_typeidx(ref_heap_type2)) {
            if (ref_heap_type1->heap_type == ref_heap_type2->heap_type)
                return true;
            else
                /* the type_count may be 0 when called from reftype_equal */
                return ((uint32)ref_heap_type1->heap_type < type_count
                        && (uint32)ref_heap_type2->heap_type < type_count
                        && types[ref_heap_type1->heap_type]
                               == types[ref_heap_type2->heap_type])
                           ? true
                           : false;
        }
        return false;
    }

    /* No need to check extra info for common types and (type i)
       as their heap_types are the same */
    return true;
}

bool
wasm_reftype_equal(uint8 type1, const WASMRefType *reftype1, uint8 type2,
                   const WASMRefType *reftype2, const WASMTypePtr *types,
                   uint32 type_count)
{
    /* For (ref null func/extern/any/eq/i31/struct/array/none/nofunc/noextern),
       they are same as funcref/externref/anyref/eqref/i31ref/structref/arayref/
       nullref/nullfuncref/nullexternref, and have been converted into to the
       related one-byte type when loading, so here we don't consider the
       situations again:
         one is (ref null func/extern/any/eq/i31/struct/array/..),
         the other is
       funcref/externref/anyref/eqref/i31ref/structref/arrayref/.. */
    if (type1 != type2)
        return false;

    if (!wasm_is_type_multi_byte_type(type1))
        /* one byte type */
        return true;

    bh_assert(type1 == (uint8)REF_TYPE_HT_NULLABLE
              || type1 == (uint8)REF_TYPE_HT_NON_NULLABLE);

    /* (ref null ht) or (ref ht) */
    return wasm_refheaptype_equal((RefHeapType_Common *)reftype1,
                                  (RefHeapType_Common *)reftype2, types,
                                  type_count);
}

inline static bool
wasm_is_reftype_supers_of_eq(uint8 type)
{
    return (type == REF_TYPE_EQREF || type == REF_TYPE_ANYREF) ? true : false;
}

inline static bool
wasm_is_reftype_supers_of_i31(uint8 type)
{
    return (type == REF_TYPE_I31REF || wasm_is_reftype_supers_of_eq(type))
               ? true
               : false;
}

inline static bool
wasm_is_reftype_supers_of_struct(uint8 type)
{
    return (type == REF_TYPE_STRUCTREF || wasm_is_reftype_supers_of_eq(type))
               ? true
               : false;
}

inline static bool
wasm_is_reftype_supers_of_array(uint8 type)
{
    return (type == REF_TYPE_ARRAYREF || wasm_is_reftype_supers_of_eq(type))
               ? true
               : false;
}

inline static bool
wasm_is_reftype_supers_of_func(uint8 type)
{
    return (type == REF_TYPE_FUNCREF) ? true : false;
}

#if WASM_ENABLE_STRINGREF != 0
inline static bool
wasm_is_reftype_supers_of_string(uint8 type)
{
    return (type == REF_TYPE_STRINGREF || type == REF_TYPE_ANYREF) ? true
                                                                   : false;
}
#endif

inline static bool
wasm_is_reftype_supers_of_none(uint8 type, const WASMRefType *ref_type,
                               const WASMTypePtr *types, uint32 type_count)
{
    if (type == REF_TYPE_NULLREF || type == REF_TYPE_I31REF
        || type == REF_TYPE_STRUCTREF || type == REF_TYPE_ARRAYREF
        || wasm_is_reftype_supers_of_eq(type)
#if WASM_ENABLE_STRINGREF != 0
        || type == REF_TYPE_STRINGREF
#endif
    )
        return true;

    if (type == REF_TYPE_HT_NULLABLE && ref_type != NULL
        && wasm_is_refheaptype_typeidx(&ref_type->ref_ht_common)
        && (types[ref_type->ref_ht_typeidx.type_idx]->type_flag
                == WASM_TYPE_STRUCT
            || types[ref_type->ref_ht_typeidx.type_idx]->type_flag
                   == WASM_TYPE_ARRAY))
        return true;

    return false;
}

inline static bool
wasm_is_reftype_supers_of_nofunc(uint8 type, const WASMRefType *ref_type,
                                 const WASMTypePtr *types, uint32 type_count)
{
    if (type == REF_TYPE_NULLFUNCREF || type == REF_TYPE_FUNCREF)
        return true;

    if (type == REF_TYPE_HT_NULLABLE && ref_type != NULL
        && wasm_is_refheaptype_typeidx(&ref_type->ref_ht_common)
        && (types[ref_type->ref_ht_typeidx.type_idx]->type_flag
            == WASM_TYPE_FUNC))
        return true;

    return false;
}

inline static bool
wasm_is_reftype_supers_of_noextern(uint8 type)
{
    return (type == REF_TYPE_NULLEXTERNREF || type == REF_TYPE_EXTERNREF)
               ? true
               : false;
}

/* Whether type1 is one of super types of type2 */
static bool
wasm_type_is_supers_of(const WASMType *type1, const WASMType *type2)
{
    uint32 i, inherit_depth_diff;

    if (type1 == type2)
        return true;

    if (!(type1->root_type == type2->root_type
          && type1->inherit_depth < type2->inherit_depth))
        return false;

    inherit_depth_diff = type2->inherit_depth - type1->inherit_depth;
    for (i = 0; i < inherit_depth_diff; i++) {
        type2 = type2->parent_type;
        if (type2 == type1)
            return true;
    }

    return false;
}

bool
wasm_func_type_is_super_of(const WASMFuncType *type1, const WASMFuncType *type2)
{
    return wasm_type_is_supers_of((const WASMType *)type1,
                                  (const WASMType *)type2);
}

bool
wasm_reftype_is_subtype_of(uint8 type1, const WASMRefType *ref_type1,
                           uint8 type2, const WASMRefType *ref_type2,
                           const WASMTypePtr *types, uint32 type_count)
{
    if (type1 >= PACKED_TYPE_I16 && type1 <= VALUE_TYPE_I32) {
        /* Primitive types (I32/I64/F32/F64/V128/I8/I16) are not
           subtypes of each other */
        return type1 == type2 ? true : false;
    }

    /**
     * Check subtype relationship of two ref types, the ref type hierarchy can
     * be described as:
     *
     * anyref -> eqref
     *            |-> i31ref
     *            |-> structref -> (ref null $t) -> (ref $t), $t is struct
     *            |-> arrayref -> (ref null $t) -> (ref $t), $t is array
     *
     * funcref -> (ref null $t) -> (ref $t), $t is func
     * externref
     */

    if (type1 == REF_TYPE_ANYREF) {
        /* any <: any */
        return type2 == REF_TYPE_ANYREF ? true : false;
    }
    else if (type1 == REF_TYPE_FUNCREF) {
        /* func <: func */
        return type2 == REF_TYPE_FUNCREF ? true : false;
    }
    else if (type1 == REF_TYPE_EXTERNREF) {
        /* extern <: extern */
        return type2 == REF_TYPE_EXTERNREF ? true : false;
    }
    else if (type1 == REF_TYPE_EQREF) {
        /* eq <: [eq, any] */
        return wasm_is_reftype_supers_of_eq(type2);
    }
    else if (type1 == REF_TYPE_I31REF) {
        /* i31 <: [i31, eq, any] */
        return wasm_is_reftype_supers_of_i31(type2);
    }
    else if (type1 == REF_TYPE_STRUCTREF) {
        /* struct <: [struct, eq, any] */
        return wasm_is_reftype_supers_of_struct(type2);
    }
    else if (type1 == REF_TYPE_ARRAYREF) {
        /* array <: [array, eq, any] */
        return wasm_is_reftype_supers_of_array(type2);
    }
    else if (type1 == REF_TYPE_NULLREF) {
        return wasm_is_reftype_supers_of_none(type2, ref_type2, types,
                                              type_count);
    }
    else if (type1 == REF_TYPE_NULLFUNCREF) {
        return wasm_is_reftype_supers_of_nofunc(type2, ref_type2, types,
                                                type_count);
    }
    else if (type1 == REF_TYPE_NULLEXTERNREF) {
        return wasm_is_reftype_supers_of_noextern(type2);
    }
#if WASM_ENABLE_STRINGREF != 0
    else if (type1 == REF_TYPE_STRINGREF) {
        return wasm_is_reftype_supers_of_string(type2);
    }
    else if (type1 == REF_TYPE_STRINGVIEWWTF8) {
        return type2 == REF_TYPE_STRINGVIEWWTF8 ? true : false;
    }
    else if (type1 == REF_TYPE_STRINGVIEWWTF16) {
        return type2 == REF_TYPE_STRINGVIEWWTF16 ? true : false;
    }
    else if (type1 == REF_TYPE_STRINGVIEWITER) {
        return type2 == REF_TYPE_STRINGVIEWITER ? true : false;
    }
#endif
    else if (type1 == REF_TYPE_HT_NULLABLE) {
        if (wasm_is_refheaptype_typeidx(&ref_type1->ref_ht_common)) {
            bh_assert((uint32)ref_type1->ref_ht_typeidx.type_idx < type_count);
            /* reftype1 is (ref null $t) */
            if (type2 == REF_TYPE_HT_NULLABLE && ref_type2 != NULL
                && wasm_is_refheaptype_typeidx(&ref_type2->ref_ht_common)) {
                bh_assert((uint32)ref_type2->ref_ht_typeidx.type_idx
                          < type_count);
                return wasm_type_is_supers_of(
                    types[ref_type2->ref_ht_typeidx.type_idx],
                    types[ref_type1->ref_ht_typeidx.type_idx]);
            }
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == WASM_TYPE_STRUCT)
                return wasm_is_reftype_supers_of_struct(type2);
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == WASM_TYPE_ARRAY)
                return wasm_is_reftype_supers_of_array(type2);
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == WASM_TYPE_FUNC)
                return wasm_is_reftype_supers_of_func(type2);
#if WASM_ENABLE_STRINGREF != 0
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == WASM_TYPE_STRINGREF)
                return wasm_is_reftype_supers_of_string(type2);
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == WASM_TYPE_STRINGVIEWWTF8) {
                return type2 == REF_TYPE_STRINGVIEWWTF8 ? true : false;
            }
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == WASM_TYPE_STRINGVIEWWTF16) {
                return type2 == REF_TYPE_STRINGVIEWWTF16 ? true : false;
            }
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == WASM_TYPE_STRINGVIEWITER) {
                return type2 == REF_TYPE_STRINGVIEWITER ? true : false;
            }
#endif
            else
                return false;
        }
        else {
            /* (ref null func/extern/any/eq/i31/struct/array/..) have been
               converted into
               funcref/externref/anyref/eqref/i31ref/structref/arrayref/..
               when loading */
            bh_assert(0);
        }
    }
    else if (type1 == REF_TYPE_HT_NON_NULLABLE) {
        bh_assert(ref_type1);
        if (wasm_is_refheaptype_typeidx(&ref_type1->ref_ht_common)) {
            bh_assert((uint32)ref_type1->ref_ht_typeidx.type_idx < type_count);
            /* reftype1 is (ref $t) */
            if ((type2 == REF_TYPE_HT_NULLABLE
                 || type2 == REF_TYPE_HT_NON_NULLABLE)
                && ref_type2 != NULL
                && wasm_is_refheaptype_typeidx(&ref_type2->ref_ht_common)) {
                bh_assert((uint32)ref_type2->ref_ht_typeidx.type_idx
                          < type_count);
                return wasm_type_is_supers_of(
                    types[ref_type2->ref_ht_typeidx.type_idx],
                    types[ref_type1->ref_ht_typeidx.type_idx]);
            }
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == WASM_TYPE_STRUCT) {
                /* the super type is (ref null struct) or (ref struct) */
                if (type2 == REF_TYPE_HT_NULLABLE
                    || type2 == REF_TYPE_HT_NON_NULLABLE) {
                    bh_assert(ref_type2);
                    uint8 ref_type =
                        (uint8)(ref_type2->ref_ht_common.heap_type
                                + REF_TYPE_FUNCREF - HEAP_TYPE_FUNC);
                    return wasm_is_reftype_supers_of_struct(ref_type);
                }
                else
                    /* the super type is structref or anyref */
                    return wasm_is_reftype_supers_of_struct(type2);
            }
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == WASM_TYPE_ARRAY) {
                /* the super type is (ref null array) or (ref array) */
                if (type2 == REF_TYPE_HT_NULLABLE
                    || type2 == REF_TYPE_HT_NON_NULLABLE) {
                    bh_assert(ref_type2);
                    uint8 ref_type =
                        (uint8)(ref_type2->ref_ht_common.heap_type
                                + REF_TYPE_FUNCREF - HEAP_TYPE_FUNC);
                    return wasm_is_reftype_supers_of_array(ref_type);
                }
                else
                    /* the super type is arrayref, eqref or anyref */
                    return wasm_is_reftype_supers_of_array(type2);
            }
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == WASM_TYPE_FUNC) {
                /* the super type is (ref null func) or (ref func) */
                if (type2 == REF_TYPE_HT_NULLABLE
                    || type2 == REF_TYPE_HT_NON_NULLABLE) {
                    bh_assert(ref_type2);
                    uint8 ref_type =
                        (uint8)(ref_type2->ref_ht_common.heap_type
                                + REF_TYPE_FUNCREF - HEAP_TYPE_FUNC);
                    return wasm_is_reftype_supers_of_func(ref_type);
                }
                else
                    /* the super type is funcref */
                    return wasm_is_reftype_supers_of_func(type2);
            }
            else if (types[ref_type1->ref_ht_typeidx.type_idx]->type_flag
                     == REF_TYPE_I31REF) {
                /* the super type is (ref null i31) or (ref i31) */
                if (type2 == REF_TYPE_HT_NULLABLE
                    || type2 == REF_TYPE_HT_NON_NULLABLE) {
                    bh_assert(ref_type2);
                    uint8 ref_type =
                        (uint8)(ref_type2->ref_ht_common.heap_type
                                + REF_TYPE_FUNCREF - HEAP_TYPE_FUNC);
                    return wasm_is_reftype_supers_of_i31(ref_type);
                }
                else
                    /* the super type is i31ref, eqref or anyref */
                    return wasm_is_reftype_supers_of_i31(type2);
            }
            else {
                return false;
            }
        }
        else if (wasm_is_refheaptype_common(&ref_type1->ref_ht_common)) {
            /* reftype1 is (ref func/extern/any/eq/i31/struct/array/..) */
            if (wasm_reftype_equal(type1, ref_type1, type2, ref_type2, types,
                                   type_count))
                return true;
            else {
                int32 heap_type = ref_type1->ref_ht_common.heap_type;
                // We don't care whether type2 is nullable or not. So
                // we normalize it into its related one-byte type.
                if (type2 == REF_TYPE_HT_NULLABLE
                    || type2 == REF_TYPE_HT_NON_NULLABLE) {
                    bh_assert(ref_type2);
                    type2 = (uint8)(ref_type2->ref_ht_common.heap_type
                                    + REF_TYPE_FUNCREF - HEAP_TYPE_FUNC);
                }
                if (heap_type == HEAP_TYPE_ANY) {
                    /* (ref any) <: anyref */
                    return type2 == REF_TYPE_ANYREF ? true : false;
                }
                else if (heap_type == HEAP_TYPE_EXTERN) {
                    /* (ref extern) <: externref */
                    return type2 == REF_TYPE_EXTERNREF ? true : false;
                }
                else if (heap_type == HEAP_TYPE_EQ) {
                    /* (ref eq) <: [eqref, anyref] */
                    return wasm_is_reftype_supers_of_eq(type2);
                }
                else if (heap_type == HEAP_TYPE_I31) {
                    /* (ref i31) <: [i31ref, eqref, anyref] */
                    return wasm_is_reftype_supers_of_i31(type2);
                }
                else if (heap_type == HEAP_TYPE_STRUCT) {
                    /* (ref struct) <: [structref, eqref, anyref] */
                    return wasm_is_reftype_supers_of_struct(type2);
                }
                else if (heap_type == HEAP_TYPE_ARRAY) {
                    /* (ref array) <: [arrayref, eqref, anyref] */
                    return wasm_is_reftype_supers_of_array(type2);
                }
                else if (heap_type == HEAP_TYPE_FUNC) {
                    /* (ref func) <: [funcref] */
                    return wasm_is_reftype_supers_of_func(type2);
                }
#if WASM_ENABLE_STRINGREF != 0
                else if (heap_type == HEAP_TYPE_STRINGREF) {
                    return wasm_is_reftype_supers_of_string(type2);
                }
                else if (heap_type == HEAP_TYPE_STRINGVIEWWTF8) {
                    return type2 == REF_TYPE_STRINGVIEWWTF8 ? true : false;
                }
                else if (heap_type == HEAP_TYPE_STRINGVIEWWTF16) {
                    return type2 == REF_TYPE_STRINGVIEWWTF16 ? true : false;
                }
                else if (heap_type == HEAP_TYPE_STRINGVIEWITER) {
                    return type2 == REF_TYPE_STRINGVIEWITER ? true : false;
                }
#endif
                else if (heap_type == HEAP_TYPE_NONE) {
                    return wasm_is_reftype_supers_of_none(type2, NULL, types,
                                                          type_count);
                }
                else if (heap_type == HEAP_TYPE_NOEXTERN) {
                    return wasm_is_reftype_supers_of_noextern(type2);
                }
                else if (heap_type == HEAP_TYPE_NOFUNC) {
                    return wasm_is_reftype_supers_of_nofunc(type2, NULL, types,
                                                            type_count);
                }
                else {
                    bh_assert(0);
                }
            }
        }
        else {
            /* unknown type detected */
            LOG_ERROR("unknown sub type 0x%02x", type1);
            bh_assert(0);
        }
    }
    else {
        bh_assert(0);
    }

    return false;
}

static uint32
reftype_hash(const void *key)
{
    WASMRefType *reftype = (WASMRefType *)key;

    switch (reftype->ref_type) {
        case (uint8)REF_TYPE_HT_NULLABLE:
        case (uint8)REF_TYPE_HT_NON_NULLABLE:
        {
            RefHeapType_Common *ref_heap_type = (RefHeapType_Common *)reftype;

            if (wasm_is_refheaptype_common(ref_heap_type)
                /* type indexes of defined type are same */
                || wasm_is_refheaptype_typeidx(ref_heap_type)) {
                return (uint32)reftype->ref_type
                       ^ (uint32)ref_heap_type->heap_type;
            }

            break;
        }

        default:
            break;
    }

    bh_assert(0);
    return 0;
}

static bool
reftype_equal(void *type1, void *type2)
{
    WASMRefType *reftype1 = (WASMRefType *)type1;
    WASMRefType *reftype2 = (WASMRefType *)type2;

    return wasm_reftype_equal(reftype1->ref_type, reftype1, reftype2->ref_type,
                              reftype2, NULL, 0);
}

WASMRefType *
wasm_reftype_dup(const WASMRefType *ref_type)
{
    if (wasm_is_reftype_htref_nullable(ref_type->ref_type)
        || wasm_is_reftype_htref_non_nullable(ref_type->ref_type)) {
        if (wasm_is_refheaptype_common(&ref_type->ref_ht_common)
            || wasm_is_refheaptype_typeidx(&ref_type->ref_ht_common)) {
            RefHeapType_Common *ht_common;
            if (!(ht_common = wasm_runtime_malloc(sizeof(RefHeapType_Common))))
                return NULL;

            ht_common->ref_type = ref_type->ref_ht_common.ref_type;
            ht_common->nullable = ref_type->ref_ht_common.nullable;
            ht_common->heap_type = ref_type->ref_ht_common.heap_type;
            return (WASMRefType *)ht_common;
        }
    }

    bh_assert(0);
    return NULL;
}

void
wasm_set_refheaptype_typeidx(RefHeapType_TypeIdx *ref_ht_typeidx, bool nullable,
                             int32 type_idx)
{
    ref_ht_typeidx->ref_type =
        nullable ? REF_TYPE_HT_NULLABLE : REF_TYPE_HT_NON_NULLABLE;
    ref_ht_typeidx->nullable = nullable;
    ref_ht_typeidx->type_idx = type_idx;
}

void
wasm_set_refheaptype_common(RefHeapType_Common *ref_ht_common, bool nullable,
                            int32 heap_type)
{
    ref_ht_common->ref_type =
        nullable ? REF_TYPE_HT_NULLABLE : REF_TYPE_HT_NON_NULLABLE;
    ref_ht_common->nullable = nullable;
    ref_ht_common->heap_type = heap_type;
}

WASMRefType *
wasm_reftype_map_find(WASMRefTypeMap *ref_type_maps, uint32 ref_type_map_count,
                      uint32 index_to_find)
{
    int low = 0, mid;
    int high = (int32)ref_type_map_count - 1;
    uint32 index;

    while (low <= high) {
        mid = (low + high) / 2;
        index = ref_type_maps[mid].index;
        if (index_to_find == index) {
            return ref_type_maps[mid].ref_type;
        }
        else if (index_to_find < index)
            high = mid - 1;
        else
            low = mid + 1;
    }

    return NULL;
}

HashMap *
wasm_reftype_set_create(uint32 size)
{
    HashMap *ref_type_set = bh_hash_map_create(
        size, false, reftype_hash, reftype_equal, NULL, wasm_runtime_free);

    return ref_type_set;
}

WASMRefType *
wasm_reftype_set_insert(HashMap *ref_type_set, const WASMRefType *ref_type)
{
    WASMRefType *ref_type_ret;

    if ((ref_type_ret = bh_hash_map_find(ref_type_set, (void *)ref_type)))
        return ref_type_ret;

    if (!(ref_type_ret = wasm_reftype_dup(ref_type)))
        return NULL;

    if (!bh_hash_map_insert(ref_type_set, ref_type_ret, ref_type_ret)) {
        wasm_runtime_free(ref_type_ret);
        return NULL;
    }

    return ref_type_ret;
}
