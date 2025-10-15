//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#ifdef TD_PORT_WINDOWS

namespace td {

#if !WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP | WINAPI_PARTITION_SYSTEM)
inline HMODULE GetKernelModule() {
  static const auto kernel_module = []() -> HMODULE {
    MEMORY_BASIC_INFORMATION mbi;
    if (VirtualQuery(VirtualQuery, &mbi, sizeof(MEMORY_BASIC_INFORMATION))) {
      return reinterpret_cast<HMODULE>(mbi.AllocationBase);
    }
    return nullptr;
  }();
  return kernel_module;
}

inline HMODULE LoadLibrary(LPCTSTR lpFileName) {
  using pLoadLibrary = HMODULE(WINAPI *)(_In_ LPCTSTR);
  static const auto proc_load_library =
      reinterpret_cast<pLoadLibrary>(GetProcAddress(GetKernelModule(), "LoadLibraryW"));
  return proc_load_library(lpFileName);
}

inline HMODULE GetFromAppModule() {
  static const HMODULE from_app_module = LoadLibrary(L"api-ms-win-core-file-fromapp-l1-1-0.dll");
  return from_app_module;
}
#endif

template <int num, class T>
T *get_from_app_function(const char *name, T *original_func) {
#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP | WINAPI_PARTITION_SYSTEM)
  return original_func;
#else
  static T *func = [name, original_func]() -> T * {
    auto func_pointer = GetProcAddress(GetFromAppModule(), name);
    if (func_pointer == nullptr) {
      return original_func;
    }
    return reinterpret_cast<T *>(func_pointer);
  }();
  return func;
#endif
}

inline HANDLE CreateFile2FromAppW(_In_ LPCWSTR lpFileName, _In_ DWORD dwDesiredAccess, _In_ DWORD dwShareMode,
                                  _In_ DWORD dwCreationDisposition,
                                  _In_opt_ LPCREATEFILE2_EXTENDED_PARAMETERS pCreateExParams) {
  auto func = get_from_app_function<0>("CreateFile2FromAppW", &CreateFile2);
  return func(lpFileName, dwDesiredAccess, dwShareMode, dwCreationDisposition, pCreateExParams);
}

inline BOOL CreateDirectoryFromAppW(_In_ LPCWSTR lpPathName, _In_opt_ LPSECURITY_ATTRIBUTES lpSecurityAttributes) {
  auto func = get_from_app_function<1>("CreateDirectoryFromAppW", &CreateDirectory);
  return func(lpPathName, lpSecurityAttributes);
}

inline BOOL RemoveDirectoryFromAppW(_In_ LPCWSTR lpPathName) {
  auto func = get_from_app_function<2>("RemoveDirectoryFromAppW", &RemoveDirectory);
  return func(lpPathName);
}

inline BOOL DeleteFileFromAppW(_In_ LPCWSTR lpFileName) {
  auto func = get_from_app_function<3>("DeleteFileFromAppW", &DeleteFile);
  return func(lpFileName);
}

inline BOOL MoveFileExFromAppW(_In_ LPCWSTR lpExistingFileName, _In_ LPCWSTR lpNewFileName, _In_ DWORD dwFlags) {
  auto func = get_from_app_function<4>("MoveFileFromAppW", static_cast<BOOL(WINAPI *)(LPCWSTR, LPCWSTR)>(nullptr));
  if (func == nullptr || (dwFlags & ~MOVEFILE_REPLACE_EXISTING) != 0) {
    // if can't find MoveFileFromAppW or have unsupported flags, call MoveFileEx directly
    return MoveFileEx(lpExistingFileName, lpNewFileName, dwFlags);
  }
  if ((dwFlags & MOVEFILE_REPLACE_EXISTING) != 0) {
    td::DeleteFileFromAppW(lpNewFileName);
  }
  return func(lpExistingFileName, lpNewFileName);
}

inline HANDLE FindFirstFileExFromAppW(_In_ LPCWSTR lpFileName, _In_ FINDEX_INFO_LEVELS fInfoLevelId,
                                      _Out_writes_bytes_(sizeof(WIN32_FIND_DATAW)) LPVOID lpFindFileData,
                                      _In_ FINDEX_SEARCH_OPS fSearchOp, _Reserved_ LPVOID lpSearchFilter,
                                      _In_ DWORD dwAdditionalFlags) {
  auto func = get_from_app_function<5>("FindFirstFileExFromAppW", &FindFirstFileEx);
  return func(lpFileName, fInfoLevelId, lpFindFileData, fSearchOp, lpSearchFilter, dwAdditionalFlags);
}

}  // namespace td

#endif
