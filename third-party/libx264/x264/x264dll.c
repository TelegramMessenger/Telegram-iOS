/*****************************************************************************
 * x264dll: x264 DLLMain for win32
 *****************************************************************************
 * Copyright (C) 2009-2022 x264 project
 *
 * Authors: Anton Mitrofanov <BugMaster@narod.ru>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
 *
 * This program is also available under a commercial proprietary license.
 * For more information, contact us at licensing@x264.com.
 *****************************************************************************/

#include "common/base.h"
#include <windows.h>

/* Callback for our DLL so we can initialize pthread */
BOOL WINAPI DllMain( HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved )
{
#if PTW32_STATIC_LIB
    switch( fdwReason )
    {
        case DLL_PROCESS_ATTACH:
            pthread_win32_process_attach_np();

        case DLL_THREAD_ATTACH:
            pthread_win32_thread_attach_np();
            break;

        case DLL_THREAD_DETACH:
            pthread_win32_thread_detach_np();
            break;

        case DLL_PROCESS_DETACH:
            pthread_win32_thread_detach_np();
            pthread_win32_process_detach_np();
            break;
    }
#endif

    return TRUE;
}
