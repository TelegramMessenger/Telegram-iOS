/*
** 2006 June 7
**
** The author disclaims copyright to this source code.  In place of
** a legal notice, here is a blessing:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
**
*************************************************************************
** This header file defines the SQLite interface for use by
** shared libraries that want to be imported as extensions into
** an SQLite instance.  Shared libraries that intend to be loaded
** as extensions by SQLite should #include this file instead of 
** sqlite3.h.
*/
#ifndef SQLITE3EXT_H
#define SQLITE3EXT_H
#include "sqlite3.h"

/*
** The following structure holds pointers to all of the SQLite API
** routines.
**
** WARNING:  In order to maintain backwards compatibility, add new
** interfaces to the end of this structure only.  If you insert new
** interfaces in the middle of this structure, then older different
** versions of SQLite will not be able to load each other's shared
** libraries!
*/
struct tdsqlite3_api_routines {
  void * (*aggregate_context)(tdsqlite3_context*,int nBytes);
  int  (*aggregate_count)(tdsqlite3_context*);
  int  (*bind_blob)(tdsqlite3_stmt*,int,const void*,int n,void(*)(void*));
  int  (*bind_double)(tdsqlite3_stmt*,int,double);
  int  (*bind_int)(tdsqlite3_stmt*,int,int);
  int  (*bind_int64)(tdsqlite3_stmt*,int,sqlite_int64);
  int  (*bind_null)(tdsqlite3_stmt*,int);
  int  (*bind_parameter_count)(tdsqlite3_stmt*);
  int  (*bind_parameter_index)(tdsqlite3_stmt*,const char*zName);
  const char * (*bind_parameter_name)(tdsqlite3_stmt*,int);
  int  (*bind_text)(tdsqlite3_stmt*,int,const char*,int n,void(*)(void*));
  int  (*bind_text16)(tdsqlite3_stmt*,int,const void*,int,void(*)(void*));
  int  (*bind_value)(tdsqlite3_stmt*,int,const tdsqlite3_value*);
  int  (*busy_handler)(tdsqlite3*,int(*)(void*,int),void*);
  int  (*busy_timeout)(tdsqlite3*,int ms);
  int  (*changes)(tdsqlite3*);
  int  (*close)(tdsqlite3*);
  int  (*collation_needed)(tdsqlite3*,void*,void(*)(void*,tdsqlite3*,
                           int eTextRep,const char*));
  int  (*collation_needed16)(tdsqlite3*,void*,void(*)(void*,tdsqlite3*,
                             int eTextRep,const void*));
  const void * (*column_blob)(tdsqlite3_stmt*,int iCol);
  int  (*column_bytes)(tdsqlite3_stmt*,int iCol);
  int  (*column_bytes16)(tdsqlite3_stmt*,int iCol);
  int  (*column_count)(tdsqlite3_stmt*pStmt);
  const char * (*column_database_name)(tdsqlite3_stmt*,int);
  const void * (*column_database_name16)(tdsqlite3_stmt*,int);
  const char * (*column_decltype)(tdsqlite3_stmt*,int i);
  const void * (*column_decltype16)(tdsqlite3_stmt*,int);
  double  (*column_double)(tdsqlite3_stmt*,int iCol);
  int  (*column_int)(tdsqlite3_stmt*,int iCol);
  sqlite_int64  (*column_int64)(tdsqlite3_stmt*,int iCol);
  const char * (*column_name)(tdsqlite3_stmt*,int);
  const void * (*column_name16)(tdsqlite3_stmt*,int);
  const char * (*column_origin_name)(tdsqlite3_stmt*,int);
  const void * (*column_origin_name16)(tdsqlite3_stmt*,int);
  const char * (*column_table_name)(tdsqlite3_stmt*,int);
  const void * (*column_table_name16)(tdsqlite3_stmt*,int);
  const unsigned char * (*column_text)(tdsqlite3_stmt*,int iCol);
  const void * (*column_text16)(tdsqlite3_stmt*,int iCol);
  int  (*column_type)(tdsqlite3_stmt*,int iCol);
  tdsqlite3_value* (*column_value)(tdsqlite3_stmt*,int iCol);
  void * (*commit_hook)(tdsqlite3*,int(*)(void*),void*);
  int  (*complete)(const char*sql);
  int  (*complete16)(const void*sql);
  int  (*create_collation)(tdsqlite3*,const char*,int,void*,
                           int(*)(void*,int,const void*,int,const void*));
  int  (*create_collation16)(tdsqlite3*,const void*,int,void*,
                             int(*)(void*,int,const void*,int,const void*));
  int  (*create_function)(tdsqlite3*,const char*,int,int,void*,
                          void (*xFunc)(tdsqlite3_context*,int,tdsqlite3_value**),
                          void (*xStep)(tdsqlite3_context*,int,tdsqlite3_value**),
                          void (*xFinal)(tdsqlite3_context*));
  int  (*create_function16)(tdsqlite3*,const void*,int,int,void*,
                            void (*xFunc)(tdsqlite3_context*,int,tdsqlite3_value**),
                            void (*xStep)(tdsqlite3_context*,int,tdsqlite3_value**),
                            void (*xFinal)(tdsqlite3_context*));
  int (*create_module)(tdsqlite3*,const char*,const tdsqlite3_module*,void*);
  int  (*data_count)(tdsqlite3_stmt*pStmt);
  tdsqlite3 * (*db_handle)(tdsqlite3_stmt*);
  int (*declare_vtab)(tdsqlite3*,const char*);
  int  (*enable_shared_cache)(int);
  int  (*errcode)(tdsqlite3*db);
  const char * (*errmsg)(tdsqlite3*);
  const void * (*errmsg16)(tdsqlite3*);
  int  (*exec)(tdsqlite3*,const char*,tdsqlite3_callback,void*,char**);
  int  (*expired)(tdsqlite3_stmt*);
  int  (*finalize)(tdsqlite3_stmt*pStmt);
  void  (*free)(void*);
  void  (*free_table)(char**result);
  int  (*get_autocommit)(tdsqlite3*);
  void * (*get_auxdata)(tdsqlite3_context*,int);
  int  (*get_table)(tdsqlite3*,const char*,char***,int*,int*,char**);
  int  (*global_recover)(void);
  void  (*interruptx)(tdsqlite3*);
  sqlite_int64  (*last_insert_rowid)(tdsqlite3*);
  const char * (*libversion)(void);
  int  (*libversion_number)(void);
  void *(*malloc)(int);
  char * (*mprintf)(const char*,...);
  int  (*open)(const char*,tdsqlite3**);
  int  (*open16)(const void*,tdsqlite3**);
  int  (*prepare)(tdsqlite3*,const char*,int,tdsqlite3_stmt**,const char**);
  int  (*prepare16)(tdsqlite3*,const void*,int,tdsqlite3_stmt**,const void**);
  void * (*profile)(tdsqlite3*,void(*)(void*,const char*,sqlite_uint64),void*);
  void  (*progress_handler)(tdsqlite3*,int,int(*)(void*),void*);
  void *(*realloc)(void*,int);
  int  (*reset)(tdsqlite3_stmt*pStmt);
  void  (*result_blob)(tdsqlite3_context*,const void*,int,void(*)(void*));
  void  (*result_double)(tdsqlite3_context*,double);
  void  (*result_error)(tdsqlite3_context*,const char*,int);
  void  (*result_error16)(tdsqlite3_context*,const void*,int);
  void  (*result_int)(tdsqlite3_context*,int);
  void  (*result_int64)(tdsqlite3_context*,sqlite_int64);
  void  (*result_null)(tdsqlite3_context*);
  void  (*result_text)(tdsqlite3_context*,const char*,int,void(*)(void*));
  void  (*result_text16)(tdsqlite3_context*,const void*,int,void(*)(void*));
  void  (*result_text16be)(tdsqlite3_context*,const void*,int,void(*)(void*));
  void  (*result_text16le)(tdsqlite3_context*,const void*,int,void(*)(void*));
  void  (*result_value)(tdsqlite3_context*,tdsqlite3_value*);
  void * (*rollback_hook)(tdsqlite3*,void(*)(void*),void*);
  int  (*set_authorizer)(tdsqlite3*,int(*)(void*,int,const char*,const char*,
                         const char*,const char*),void*);
  void  (*set_auxdata)(tdsqlite3_context*,int,void*,void (*)(void*));
  char * (*xsnprintf)(int,char*,const char*,...);
  int  (*step)(tdsqlite3_stmt*);
  int  (*table_column_metadata)(tdsqlite3*,const char*,const char*,const char*,
                                char const**,char const**,int*,int*,int*);
  void  (*thread_cleanup)(void);
  int  (*total_changes)(tdsqlite3*);
  void * (*trace)(tdsqlite3*,void(*xTrace)(void*,const char*),void*);
  int  (*transfer_bindings)(tdsqlite3_stmt*,tdsqlite3_stmt*);
  void * (*update_hook)(tdsqlite3*,void(*)(void*,int ,char const*,char const*,
                                         sqlite_int64),void*);
  void * (*user_data)(tdsqlite3_context*);
  const void * (*value_blob)(tdsqlite3_value*);
  int  (*value_bytes)(tdsqlite3_value*);
  int  (*value_bytes16)(tdsqlite3_value*);
  double  (*value_double)(tdsqlite3_value*);
  int  (*value_int)(tdsqlite3_value*);
  sqlite_int64  (*value_int64)(tdsqlite3_value*);
  int  (*value_numeric_type)(tdsqlite3_value*);
  const unsigned char * (*value_text)(tdsqlite3_value*);
  const void * (*value_text16)(tdsqlite3_value*);
  const void * (*value_text16be)(tdsqlite3_value*);
  const void * (*value_text16le)(tdsqlite3_value*);
  int  (*value_type)(tdsqlite3_value*);
  char *(*vmprintf)(const char*,va_list);
  /* Added ??? */
  int (*overload_function)(tdsqlite3*, const char *zFuncName, int nArg);
  /* Added by 3.3.13 */
  int (*prepare_v2)(tdsqlite3*,const char*,int,tdsqlite3_stmt**,const char**);
  int (*prepare16_v2)(tdsqlite3*,const void*,int,tdsqlite3_stmt**,const void**);
  int (*clear_bindings)(tdsqlite3_stmt*);
  /* Added by 3.4.1 */
  int (*create_module_v2)(tdsqlite3*,const char*,const tdsqlite3_module*,void*,
                          void (*xDestroy)(void *));
  /* Added by 3.5.0 */
  int (*bind_zeroblob)(tdsqlite3_stmt*,int,int);
  int (*blob_bytes)(tdsqlite3_blob*);
  int (*blob_close)(tdsqlite3_blob*);
  int (*blob_open)(tdsqlite3*,const char*,const char*,const char*,tdsqlite3_int64,
                   int,tdsqlite3_blob**);
  int (*blob_read)(tdsqlite3_blob*,void*,int,int);
  int (*blob_write)(tdsqlite3_blob*,const void*,int,int);
  int (*create_collation_v2)(tdsqlite3*,const char*,int,void*,
                             int(*)(void*,int,const void*,int,const void*),
                             void(*)(void*));
  int (*file_control)(tdsqlite3*,const char*,int,void*);
  tdsqlite3_int64 (*memory_highwater)(int);
  tdsqlite3_int64 (*memory_used)(void);
  tdsqlite3_mutex *(*mutex_alloc)(int);
  void (*mutex_enter)(tdsqlite3_mutex*);
  void (*mutex_free)(tdsqlite3_mutex*);
  void (*mutex_leave)(tdsqlite3_mutex*);
  int (*mutex_try)(tdsqlite3_mutex*);
  int (*open_v2)(const char*,tdsqlite3**,int,const char*);
  int (*release_memory)(int);
  void (*result_error_nomem)(tdsqlite3_context*);
  void (*result_error_toobig)(tdsqlite3_context*);
  int (*sleep)(int);
  void (*soft_heap_limit)(int);
  tdsqlite3_vfs *(*vfs_find)(const char*);
  int (*vfs_register)(tdsqlite3_vfs*,int);
  int (*vfs_unregister)(tdsqlite3_vfs*);
  int (*xthreadsafe)(void);
  void (*result_zeroblob)(tdsqlite3_context*,int);
  void (*result_error_code)(tdsqlite3_context*,int);
  int (*test_control)(int, ...);
  void (*randomness)(int,void*);
  tdsqlite3 *(*context_db_handle)(tdsqlite3_context*);
  int (*extended_result_codes)(tdsqlite3*,int);
  int (*limit)(tdsqlite3*,int,int);
  tdsqlite3_stmt *(*next_stmt)(tdsqlite3*,tdsqlite3_stmt*);
  const char *(*sql)(tdsqlite3_stmt*);
  int (*status)(int,int*,int*,int);
  int (*backup_finish)(tdsqlite3_backup*);
  tdsqlite3_backup *(*backup_init)(tdsqlite3*,const char*,tdsqlite3*,const char*);
  int (*backup_pagecount)(tdsqlite3_backup*);
  int (*backup_remaining)(tdsqlite3_backup*);
  int (*backup_step)(tdsqlite3_backup*,int);
  const char *(*compileoption_get)(int);
  int (*compileoption_used)(const char*);
  int (*create_function_v2)(tdsqlite3*,const char*,int,int,void*,
                            void (*xFunc)(tdsqlite3_context*,int,tdsqlite3_value**),
                            void (*xStep)(tdsqlite3_context*,int,tdsqlite3_value**),
                            void (*xFinal)(tdsqlite3_context*),
                            void(*xDestroy)(void*));
  int (*db_config)(tdsqlite3*,int,...);
  tdsqlite3_mutex *(*db_mutex)(tdsqlite3*);
  int (*db_status)(tdsqlite3*,int,int*,int*,int);
  int (*extended_errcode)(tdsqlite3*);
  void (*log)(int,const char*,...);
  tdsqlite3_int64 (*soft_heap_limit64)(tdsqlite3_int64);
  const char *(*sourceid)(void);
  int (*stmt_status)(tdsqlite3_stmt*,int,int);
  int (*strnicmp)(const char*,const char*,int);
  int (*unlock_notify)(tdsqlite3*,void(*)(void**,int),void*);
  int (*wal_autocheckpoint)(tdsqlite3*,int);
  int (*wal_checkpoint)(tdsqlite3*,const char*);
  void *(*wal_hook)(tdsqlite3*,int(*)(void*,tdsqlite3*,const char*,int),void*);
  int (*blob_reopen)(tdsqlite3_blob*,tdsqlite3_int64);
  int (*vtab_config)(tdsqlite3*,int op,...);
  int (*vtab_on_conflict)(tdsqlite3*);
  /* Version 3.7.16 and later */
  int (*close_v2)(tdsqlite3*);
  const char *(*db_filename)(tdsqlite3*,const char*);
  int (*db_readonly)(tdsqlite3*,const char*);
  int (*db_release_memory)(tdsqlite3*);
  const char *(*errstr)(int);
  int (*stmt_busy)(tdsqlite3_stmt*);
  int (*stmt_readonly)(tdsqlite3_stmt*);
  int (*stricmp)(const char*,const char*);
  int (*uri_boolean)(const char*,const char*,int);
  tdsqlite3_int64 (*uri_int64)(const char*,const char*,tdsqlite3_int64);
  const char *(*uri_parameter)(const char*,const char*);
  char *(*xvsnprintf)(int,char*,const char*,va_list);
  int (*wal_checkpoint_v2)(tdsqlite3*,const char*,int,int*,int*);
  /* Version 3.8.7 and later */
  int (*auto_extension)(void(*)(void));
  int (*bind_blob64)(tdsqlite3_stmt*,int,const void*,tdsqlite3_uint64,
                     void(*)(void*));
  int (*bind_text64)(tdsqlite3_stmt*,int,const char*,tdsqlite3_uint64,
                      void(*)(void*),unsigned char);
  int (*cancel_auto_extension)(void(*)(void));
  int (*load_extension)(tdsqlite3*,const char*,const char*,char**);
  void *(*malloc64)(tdsqlite3_uint64);
  tdsqlite3_uint64 (*msize)(void*);
  void *(*realloc64)(void*,tdsqlite3_uint64);
  void (*reset_auto_extension)(void);
  void (*result_blob64)(tdsqlite3_context*,const void*,tdsqlite3_uint64,
                        void(*)(void*));
  void (*result_text64)(tdsqlite3_context*,const char*,tdsqlite3_uint64,
                         void(*)(void*), unsigned char);
  int (*strglob)(const char*,const char*);
  /* Version 3.8.11 and later */
  tdsqlite3_value *(*value_dup)(const tdsqlite3_value*);
  void (*value_free)(tdsqlite3_value*);
  int (*result_zeroblob64)(tdsqlite3_context*,tdsqlite3_uint64);
  int (*bind_zeroblob64)(tdsqlite3_stmt*, int, tdsqlite3_uint64);
  /* Version 3.9.0 and later */
  unsigned int (*value_subtype)(tdsqlite3_value*);
  void (*result_subtype)(tdsqlite3_context*,unsigned int);
  /* Version 3.10.0 and later */
  int (*status64)(int,tdsqlite3_int64*,tdsqlite3_int64*,int);
  int (*strlike)(const char*,const char*,unsigned int);
  int (*db_cacheflush)(tdsqlite3*);
  /* Version 3.12.0 and later */
  int (*system_errno)(tdsqlite3*);
  /* Version 3.14.0 and later */
  int (*trace_v2)(tdsqlite3*,unsigned,int(*)(unsigned,void*,void*,void*),void*);
  char *(*expanded_sql)(tdsqlite3_stmt*);
  /* Version 3.18.0 and later */
  void (*set_last_insert_rowid)(tdsqlite3*,tdsqlite3_int64);
  /* Version 3.20.0 and later */
  int (*prepare_v3)(tdsqlite3*,const char*,int,unsigned int,
                    tdsqlite3_stmt**,const char**);
  int (*prepare16_v3)(tdsqlite3*,const void*,int,unsigned int,
                      tdsqlite3_stmt**,const void**);
  int (*bind_pointer)(tdsqlite3_stmt*,int,void*,const char*,void(*)(void*));
  void (*result_pointer)(tdsqlite3_context*,void*,const char*,void(*)(void*));
  void *(*value_pointer)(tdsqlite3_value*,const char*);
  int (*vtab_nochange)(tdsqlite3_context*);
  int (*value_nochange)(tdsqlite3_value*);
  const char *(*vtab_collation)(tdsqlite3_index_info*,int);
  /* Version 3.24.0 and later */
  int (*keyword_count)(void);
  int (*keyword_name)(int,const char**,int*);
  int (*keyword_check)(const char*,int);
  tdsqlite3_str *(*str_new)(tdsqlite3*);
  char *(*str_finish)(tdsqlite3_str*);
  void (*str_appendf)(tdsqlite3_str*, const char *zFormat, ...);
  void (*str_vappendf)(tdsqlite3_str*, const char *zFormat, va_list);
  void (*str_append)(tdsqlite3_str*, const char *zIn, int N);
  void (*str_appendall)(tdsqlite3_str*, const char *zIn);
  void (*str_appendchar)(tdsqlite3_str*, int N, char C);
  void (*str_reset)(tdsqlite3_str*);
  int (*str_errcode)(tdsqlite3_str*);
  int (*str_length)(tdsqlite3_str*);
  char *(*str_value)(tdsqlite3_str*);
  /* Version 3.25.0 and later */
  int (*create_window_function)(tdsqlite3*,const char*,int,int,void*,
                            void (*xStep)(tdsqlite3_context*,int,tdsqlite3_value**),
                            void (*xFinal)(tdsqlite3_context*),
                            void (*xValue)(tdsqlite3_context*),
                            void (*xInv)(tdsqlite3_context*,int,tdsqlite3_value**),
                            void(*xDestroy)(void*));
  /* Version 3.26.0 and later */
  const char *(*normalized_sql)(tdsqlite3_stmt*);
  /* Version 3.28.0 and later */
  int (*stmt_isexplain)(tdsqlite3_stmt*);
  int (*value_frombind)(tdsqlite3_value*);
  /* Version 3.30.0 and later */
  int (*drop_modules)(tdsqlite3*,const char**);
  /* Version 3.31.0 and later */
  tdsqlite3_int64 (*hard_heap_limit64)(tdsqlite3_int64);
  const char *(*uri_key)(const char*,int);
  const char *(*filename_database)(const char*);
  const char *(*filename_journal)(const char*);
  const char *(*filename_wal)(const char*);
};

/*
** This is the function signature used for all extension entry points.  It
** is also defined in the file "loadext.c".
*/
typedef int (*tdsqlite3_loadext_entry)(
  tdsqlite3 *db,                       /* Handle to the database. */
  char **pzErrMsg,                   /* Used to set error string on failure. */
  const tdsqlite3_api_routines *pThunk /* Extension API function pointers. */
);

/*
** The following macros redefine the API routines so that they are
** redirected through the global tdsqlite3_api structure.
**
** This header file is also used by the loadext.c source file
** (part of the main SQLite library - not an extension) so that
** it can get access to the tdsqlite3_api_routines structure
** definition.  But the main library does not want to redefine
** the API.  So the redefinition macros are only valid if the
** SQLITE_CORE macros is undefined.
*/
#if !defined(SQLITE_CORE) && !defined(SQLITE_OMIT_LOAD_EXTENSION)
#define tdsqlite3_aggregate_context      tdsqlite3_api->aggregate_context
#ifndef SQLITE_OMIT_DEPRECATED
#define tdsqlite3_aggregate_count        tdsqlite3_api->aggregate_count
#endif
#define tdsqlite3_bind_blob              tdsqlite3_api->bind_blob
#define tdsqlite3_bind_double            tdsqlite3_api->bind_double
#define tdsqlite3_bind_int               tdsqlite3_api->bind_int
#define tdsqlite3_bind_int64             tdsqlite3_api->bind_int64
#define tdsqlite3_bind_null              tdsqlite3_api->bind_null
#define tdsqlite3_bind_parameter_count   tdsqlite3_api->bind_parameter_count
#define tdsqlite3_bind_parameter_index   tdsqlite3_api->bind_parameter_index
#define tdsqlite3_bind_parameter_name    tdsqlite3_api->bind_parameter_name
#define tdsqlite3_bind_text              tdsqlite3_api->bind_text
#define tdsqlite3_bind_text16            tdsqlite3_api->bind_text16
#define tdsqlite3_bind_value             tdsqlite3_api->bind_value
#define tdsqlite3_busy_handler           tdsqlite3_api->busy_handler
#define tdsqlite3_busy_timeout           tdsqlite3_api->busy_timeout
#define tdsqlite3_changes                tdsqlite3_api->changes
#define tdsqlite3_close                  tdsqlite3_api->close
#define tdsqlite3_collation_needed       tdsqlite3_api->collation_needed
#define tdsqlite3_collation_needed16     tdsqlite3_api->collation_needed16
#define tdsqlite3_column_blob            tdsqlite3_api->column_blob
#define tdsqlite3_column_bytes           tdsqlite3_api->column_bytes
#define tdsqlite3_column_bytes16         tdsqlite3_api->column_bytes16
#define tdsqlite3_column_count           tdsqlite3_api->column_count
#define tdsqlite3_column_database_name   tdsqlite3_api->column_database_name
#define tdsqlite3_column_database_name16 tdsqlite3_api->column_database_name16
#define tdsqlite3_column_decltype        tdsqlite3_api->column_decltype
#define tdsqlite3_column_decltype16      tdsqlite3_api->column_decltype16
#define tdsqlite3_column_double          tdsqlite3_api->column_double
#define tdsqlite3_column_int             tdsqlite3_api->column_int
#define tdsqlite3_column_int64           tdsqlite3_api->column_int64
#define tdsqlite3_column_name            tdsqlite3_api->column_name
#define tdsqlite3_column_name16          tdsqlite3_api->column_name16
#define tdsqlite3_column_origin_name     tdsqlite3_api->column_origin_name
#define tdsqlite3_column_origin_name16   tdsqlite3_api->column_origin_name16
#define tdsqlite3_column_table_name      tdsqlite3_api->column_table_name
#define tdsqlite3_column_table_name16    tdsqlite3_api->column_table_name16
#define tdsqlite3_column_text            tdsqlite3_api->column_text
#define tdsqlite3_column_text16          tdsqlite3_api->column_text16
#define tdsqlite3_column_type            tdsqlite3_api->column_type
#define tdsqlite3_column_value           tdsqlite3_api->column_value
#define tdsqlite3_commit_hook            tdsqlite3_api->commit_hook
#define tdsqlite3_complete               tdsqlite3_api->complete
#define tdsqlite3_complete16             tdsqlite3_api->complete16
#define tdsqlite3_create_collation       tdsqlite3_api->create_collation
#define tdsqlite3_create_collation16     tdsqlite3_api->create_collation16
#define tdsqlite3_create_function        tdsqlite3_api->create_function
#define tdsqlite3_create_function16      tdsqlite3_api->create_function16
#define tdsqlite3_create_module          tdsqlite3_api->create_module
#define tdsqlite3_create_module_v2       tdsqlite3_api->create_module_v2
#define tdsqlite3_data_count             tdsqlite3_api->data_count
#define tdsqlite3_db_handle              tdsqlite3_api->db_handle
#define tdsqlite3_declare_vtab           tdsqlite3_api->declare_vtab
#define tdsqlite3_enable_shared_cache    tdsqlite3_api->enable_shared_cache
#define tdsqlite3_errcode                tdsqlite3_api->errcode
#define tdsqlite3_errmsg                 tdsqlite3_api->errmsg
#define tdsqlite3_errmsg16               tdsqlite3_api->errmsg16
#define tdsqlite3_exec                   tdsqlite3_api->exec
#ifndef SQLITE_OMIT_DEPRECATED
#define tdsqlite3_expired                tdsqlite3_api->expired
#endif
#define tdsqlite3_finalize               tdsqlite3_api->finalize
#define tdsqlite3_free                   tdsqlite3_api->free
#define tdsqlite3_free_table             tdsqlite3_api->free_table
#define tdsqlite3_get_autocommit         tdsqlite3_api->get_autocommit
#define tdsqlite3_get_auxdata            tdsqlite3_api->get_auxdata
#define tdsqlite3_get_table              tdsqlite3_api->get_table
#ifndef SQLITE_OMIT_DEPRECATED
#define tdsqlite3_global_recover         tdsqlite3_api->global_recover
#endif
#define tdsqlite3_interrupt              tdsqlite3_api->interruptx
#define tdsqlite3_last_insert_rowid      tdsqlite3_api->last_insert_rowid
#define tdsqlite3_libversion             tdsqlite3_api->libversion
#define tdsqlite3_libversion_number      tdsqlite3_api->libversion_number
#define tdsqlite3_malloc                 tdsqlite3_api->malloc
#define tdsqlite3_mprintf                tdsqlite3_api->mprintf
#define tdsqlite3_open                   tdsqlite3_api->open
#define tdsqlite3_open16                 tdsqlite3_api->open16
#define tdsqlite3_prepare                tdsqlite3_api->prepare
#define tdsqlite3_prepare16              tdsqlite3_api->prepare16
#define tdsqlite3_prepare_v2             tdsqlite3_api->prepare_v2
#define tdsqlite3_prepare16_v2           tdsqlite3_api->prepare16_v2
#define tdsqlite3_profile                tdsqlite3_api->profile
#define tdsqlite3_progress_handler       tdsqlite3_api->progress_handler
#define tdsqlite3_realloc                tdsqlite3_api->realloc
#define tdsqlite3_reset                  tdsqlite3_api->reset
#define tdsqlite3_result_blob            tdsqlite3_api->result_blob
#define tdsqlite3_result_double          tdsqlite3_api->result_double
#define tdsqlite3_result_error           tdsqlite3_api->result_error
#define tdsqlite3_result_error16         tdsqlite3_api->result_error16
#define tdsqlite3_result_int             tdsqlite3_api->result_int
#define tdsqlite3_result_int64           tdsqlite3_api->result_int64
#define tdsqlite3_result_null            tdsqlite3_api->result_null
#define tdsqlite3_result_text            tdsqlite3_api->result_text
#define tdsqlite3_result_text16          tdsqlite3_api->result_text16
#define tdsqlite3_result_text16be        tdsqlite3_api->result_text16be
#define tdsqlite3_result_text16le        tdsqlite3_api->result_text16le
#define tdsqlite3_result_value           tdsqlite3_api->result_value
#define tdsqlite3_rollback_hook          tdsqlite3_api->rollback_hook
#define tdsqlite3_set_authorizer         tdsqlite3_api->set_authorizer
#define tdsqlite3_set_auxdata            tdsqlite3_api->set_auxdata
#define tdsqlite3_snprintf               tdsqlite3_api->xsnprintf
#define tdsqlite3_step                   tdsqlite3_api->step
#define tdsqlite3_table_column_metadata  tdsqlite3_api->table_column_metadata
#define tdsqlite3_thread_cleanup         tdsqlite3_api->thread_cleanup
#define tdsqlite3_total_changes          tdsqlite3_api->total_changes
#define tdsqlite3_trace                  tdsqlite3_api->trace
#ifndef SQLITE_OMIT_DEPRECATED
#define tdsqlite3_transfer_bindings      tdsqlite3_api->transfer_bindings
#endif
#define tdsqlite3_update_hook            tdsqlite3_api->update_hook
#define tdsqlite3_user_data              tdsqlite3_api->user_data
#define tdsqlite3_value_blob             tdsqlite3_api->value_blob
#define tdsqlite3_value_bytes            tdsqlite3_api->value_bytes
#define tdsqlite3_value_bytes16          tdsqlite3_api->value_bytes16
#define tdsqlite3_value_double           tdsqlite3_api->value_double
#define tdsqlite3_value_int              tdsqlite3_api->value_int
#define tdsqlite3_value_int64            tdsqlite3_api->value_int64
#define tdsqlite3_value_numeric_type     tdsqlite3_api->value_numeric_type
#define tdsqlite3_value_text             tdsqlite3_api->value_text
#define tdsqlite3_value_text16           tdsqlite3_api->value_text16
#define tdsqlite3_value_text16be         tdsqlite3_api->value_text16be
#define tdsqlite3_value_text16le         tdsqlite3_api->value_text16le
#define tdsqlite3_value_type             tdsqlite3_api->value_type
#define tdsqlite3_vmprintf               tdsqlite3_api->vmprintf
#define tdsqlite3_vsnprintf              tdsqlite3_api->xvsnprintf
#define tdsqlite3_overload_function      tdsqlite3_api->overload_function
#define tdsqlite3_prepare_v2             tdsqlite3_api->prepare_v2
#define tdsqlite3_prepare16_v2           tdsqlite3_api->prepare16_v2
#define tdsqlite3_clear_bindings         tdsqlite3_api->clear_bindings
#define tdsqlite3_bind_zeroblob          tdsqlite3_api->bind_zeroblob
#define tdsqlite3_blob_bytes             tdsqlite3_api->blob_bytes
#define tdsqlite3_blob_close             tdsqlite3_api->blob_close
#define tdsqlite3_blob_open              tdsqlite3_api->blob_open
#define tdsqlite3_blob_read              tdsqlite3_api->blob_read
#define tdsqlite3_blob_write             tdsqlite3_api->blob_write
#define tdsqlite3_create_collation_v2    tdsqlite3_api->create_collation_v2
#define tdsqlite3_file_control           tdsqlite3_api->file_control
#define tdsqlite3_memory_highwater       tdsqlite3_api->memory_highwater
#define tdsqlite3_memory_used            tdsqlite3_api->memory_used
#define tdsqlite3_mutex_alloc            tdsqlite3_api->mutex_alloc
#define tdsqlite3_mutex_enter            tdsqlite3_api->mutex_enter
#define tdsqlite3_mutex_free             tdsqlite3_api->mutex_free
#define tdsqlite3_mutex_leave            tdsqlite3_api->mutex_leave
#define tdsqlite3_mutex_try              tdsqlite3_api->mutex_try
#define tdsqlite3_open_v2                tdsqlite3_api->open_v2
#define tdsqlite3_release_memory         tdsqlite3_api->release_memory
#define tdsqlite3_result_error_nomem     tdsqlite3_api->result_error_nomem
#define tdsqlite3_result_error_toobig    tdsqlite3_api->result_error_toobig
#define tdsqlite3_sleep                  tdsqlite3_api->sleep
#define tdsqlite3_soft_heap_limit        tdsqlite3_api->soft_heap_limit
#define tdsqlite3_vfs_find               tdsqlite3_api->vfs_find
#define tdsqlite3_vfs_register           tdsqlite3_api->vfs_register
#define tdsqlite3_vfs_unregister         tdsqlite3_api->vfs_unregister
#define tdsqlite3_threadsafe             tdsqlite3_api->xthreadsafe
#define tdsqlite3_result_zeroblob        tdsqlite3_api->result_zeroblob
#define tdsqlite3_result_error_code      tdsqlite3_api->result_error_code
#define tdsqlite3_test_control           tdsqlite3_api->test_control
#define tdsqlite3_randomness             tdsqlite3_api->randomness
#define tdsqlite3_context_db_handle      tdsqlite3_api->context_db_handle
#define tdsqlite3_extended_result_codes  tdsqlite3_api->extended_result_codes
#define tdsqlite3_limit                  tdsqlite3_api->limit
#define tdsqlite3_next_stmt              tdsqlite3_api->next_stmt
#define tdsqlite3_sql                    tdsqlite3_api->sql
#define tdsqlite3_status                 tdsqlite3_api->status
#define tdsqlite3_backup_finish          tdsqlite3_api->backup_finish
#define tdsqlite3_backup_init            tdsqlite3_api->backup_init
#define tdsqlite3_backup_pagecount       tdsqlite3_api->backup_pagecount
#define tdsqlite3_backup_remaining       tdsqlite3_api->backup_remaining
#define tdsqlite3_backup_step            tdsqlite3_api->backup_step
#define tdsqlite3_compileoption_get      tdsqlite3_api->compileoption_get
#define tdsqlite3_compileoption_used     tdsqlite3_api->compileoption_used
#define tdsqlite3_create_function_v2     tdsqlite3_api->create_function_v2
#define tdsqlite3_db_config              tdsqlite3_api->db_config
#define tdsqlite3_db_mutex               tdsqlite3_api->db_mutex
#define tdsqlite3_db_status              tdsqlite3_api->db_status
#define tdsqlite3_extended_errcode       tdsqlite3_api->extended_errcode
#define tdsqlite3_log                    tdsqlite3_api->log
#define tdsqlite3_soft_heap_limit64      tdsqlite3_api->soft_heap_limit64
#define tdsqlite3_sourceid               tdsqlite3_api->sourceid
#define tdsqlite3_stmt_status            tdsqlite3_api->stmt_status
#define tdsqlite3_strnicmp               tdsqlite3_api->strnicmp
#define tdsqlite3_unlock_notify          tdsqlite3_api->unlock_notify
#define tdsqlite3_wal_autocheckpoint     tdsqlite3_api->wal_autocheckpoint
#define tdsqlite3_wal_checkpoint         tdsqlite3_api->wal_checkpoint
#define tdsqlite3_wal_hook               tdsqlite3_api->wal_hook
#define tdsqlite3_blob_reopen            tdsqlite3_api->blob_reopen
#define tdsqlite3_vtab_config            tdsqlite3_api->vtab_config
#define tdsqlite3_vtab_on_conflict       tdsqlite3_api->vtab_on_conflict
/* Version 3.7.16 and later */
#define tdsqlite3_close_v2               tdsqlite3_api->close_v2
#define tdsqlite3_db_filename            tdsqlite3_api->db_filename
#define tdsqlite3_db_readonly            tdsqlite3_api->db_readonly
#define tdsqlite3_db_release_memory      tdsqlite3_api->db_release_memory
#define tdsqlite3_errstr                 tdsqlite3_api->errstr
#define tdsqlite3_stmt_busy              tdsqlite3_api->stmt_busy
#define tdsqlite3_stmt_readonly          tdsqlite3_api->stmt_readonly
#define tdsqlite3_stricmp                tdsqlite3_api->stricmp
#define tdsqlite3_uri_boolean            tdsqlite3_api->uri_boolean
#define tdsqlite3_uri_int64              tdsqlite3_api->uri_int64
#define tdsqlite3_uri_parameter          tdsqlite3_api->uri_parameter
#define tdsqlite3_uri_vsnprintf          tdsqlite3_api->xvsnprintf
#define tdsqlite3_wal_checkpoint_v2      tdsqlite3_api->wal_checkpoint_v2
/* Version 3.8.7 and later */
#define tdsqlite3_auto_extension         tdsqlite3_api->auto_extension
#define tdsqlite3_bind_blob64            tdsqlite3_api->bind_blob64
#define tdsqlite3_bind_text64            tdsqlite3_api->bind_text64
#define tdsqlite3_cancel_auto_extension  tdsqlite3_api->cancel_auto_extension
#define tdsqlite3_load_extension         tdsqlite3_api->load_extension
#define tdsqlite3_malloc64               tdsqlite3_api->malloc64
#define tdsqlite3_msize                  tdsqlite3_api->msize
#define tdsqlite3_realloc64              tdsqlite3_api->realloc64
#define tdsqlite3_reset_auto_extension   tdsqlite3_api->reset_auto_extension
#define tdsqlite3_result_blob64          tdsqlite3_api->result_blob64
#define tdsqlite3_result_text64          tdsqlite3_api->result_text64
#define tdsqlite3_strglob                tdsqlite3_api->strglob
/* Version 3.8.11 and later */
#define tdsqlite3_value_dup              tdsqlite3_api->value_dup
#define tdsqlite3_value_free             tdsqlite3_api->value_free
#define tdsqlite3_result_zeroblob64      tdsqlite3_api->result_zeroblob64
#define tdsqlite3_bind_zeroblob64        tdsqlite3_api->bind_zeroblob64
/* Version 3.9.0 and later */
#define tdsqlite3_value_subtype          tdsqlite3_api->value_subtype
#define tdsqlite3_result_subtype         tdsqlite3_api->result_subtype
/* Version 3.10.0 and later */
#define tdsqlite3_status64               tdsqlite3_api->status64
#define tdsqlite3_strlike                tdsqlite3_api->strlike
#define tdsqlite3_db_cacheflush          tdsqlite3_api->db_cacheflush
/* Version 3.12.0 and later */
#define tdsqlite3_system_errno           tdsqlite3_api->system_errno
/* Version 3.14.0 and later */
#define tdsqlite3_trace_v2               tdsqlite3_api->trace_v2
#define tdsqlite3_expanded_sql           tdsqlite3_api->expanded_sql
/* Version 3.18.0 and later */
#define tdsqlite3_set_last_insert_rowid  tdsqlite3_api->set_last_insert_rowid
/* Version 3.20.0 and later */
#define tdsqlite3_prepare_v3             tdsqlite3_api->prepare_v3
#define tdsqlite3_prepare16_v3           tdsqlite3_api->prepare16_v3
#define tdsqlite3_bind_pointer           tdsqlite3_api->bind_pointer
#define tdsqlite3_result_pointer         tdsqlite3_api->result_pointer
#define tdsqlite3_value_pointer          tdsqlite3_api->value_pointer
/* Version 3.22.0 and later */
#define tdsqlite3_vtab_nochange          tdsqlite3_api->vtab_nochange
#define tdsqlite3_value_nochange         tdsqlite3_api->value_nochange
#define tdsqlite3_vtab_collation         tdsqlite3_api->vtab_collation
/* Version 3.24.0 and later */
#define tdsqlite3_keyword_count          tdsqlite3_api->keyword_count
#define tdsqlite3_keyword_name           tdsqlite3_api->keyword_name
#define tdsqlite3_keyword_check          tdsqlite3_api->keyword_check
#define tdsqlite3_str_new                tdsqlite3_api->str_new
#define tdsqlite3_str_finish             tdsqlite3_api->str_finish
#define tdsqlite3_str_appendf            tdsqlite3_api->str_appendf
#define tdsqlite3_str_vappendf           tdsqlite3_api->str_vappendf
#define tdsqlite3_str_append             tdsqlite3_api->str_append
#define tdsqlite3_str_appendall          tdsqlite3_api->str_appendall
#define tdsqlite3_str_appendchar         tdsqlite3_api->str_appendchar
#define tdsqlite3_str_reset              tdsqlite3_api->str_reset
#define tdsqlite3_str_errcode            tdsqlite3_api->str_errcode
#define tdsqlite3_str_length             tdsqlite3_api->str_length
#define tdsqlite3_str_value              tdsqlite3_api->str_value
/* Version 3.25.0 and later */
#define tdsqlite3_create_window_function tdsqlite3_api->create_window_function
/* Version 3.26.0 and later */
#define tdsqlite3_normalized_sql         tdsqlite3_api->normalized_sql
/* Version 3.28.0 and later */
#define tdsqlite3_stmt_isexplain         tdsqlite3_api->isexplain
#define tdsqlite3_value_frombind         tdsqlite3_api->frombind
/* Version 3.30.0 and later */
#define tdsqlite3_drop_modules           tdsqlite3_api->drop_modules
/* Version 3.31.0 andn later */
#define tdsqlite3_hard_heap_limit64      tdsqlite3_api->hard_heap_limit64
#define tdsqlite3_uri_key                tdsqlite3_api->uri_key
#define tdsqlite3_filename_database      tdsqlite3_api->filename_database
#define tdsqlite3_filename_journal       tdsqlite3_api->filename_journal
#define tdsqlite3_filename_wal           tdsqlite3_api->filename_wal
#endif /* !defined(SQLITE_CORE) && !defined(SQLITE_OMIT_LOAD_EXTENSION) */

#if !defined(SQLITE_CORE) && !defined(SQLITE_OMIT_LOAD_EXTENSION)
  /* This case when the file really is being compiled as a loadable 
  ** extension */
# define SQLITE_EXTENSION_INIT1     const tdsqlite3_api_routines *tdsqlite3_api=0;
# define SQLITE_EXTENSION_INIT2(v)  tdsqlite3_api=v;
# define SQLITE_EXTENSION_INIT3     \
    extern const tdsqlite3_api_routines *tdsqlite3_api;
#else
  /* This case when the file is being statically linked into the 
  ** application */
# define SQLITE_EXTENSION_INIT1     /*no-op*/
# define SQLITE_EXTENSION_INIT2(v)  (void)v; /* unused parameter */
# define SQLITE_EXTENSION_INIT3     /*no-op*/
#endif

#endif /* SQLITE3EXT_H */
