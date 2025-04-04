/*
    This file is part of VK/KittenPHP-DB-Engine Library.

    VK/KittenPHP-DB-Engine Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    VK/KittenPHP-DB-Engine Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with VK/KittenPHP-DB-Engine Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2009-2012 Vkontakte Ltd
              2009-2012 Nikolai Durov
              2009-2012 Andrei Lopatin
                   2012 Anton Maydell
*/

#ifndef __CRC32_H__
#define __CRC32_H__


#ifdef __cplusplus
extern "C" {
#endif

unsigned int compute_crc32 (const void *data, int len);

#ifdef __cplusplus
}
#endif

#endif
