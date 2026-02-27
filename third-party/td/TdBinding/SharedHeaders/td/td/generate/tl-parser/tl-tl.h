/*
    This file is part of VK/KittenPHP-DB-Engine.

    VK/KittenPHP-DB-Engine is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    VK/KittenPHP-DB-Engine is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with VK/KittenPHP-DB-Engine.  If not, see <http://www.gnu.org/licenses/>.

    This program is released under the GPL with the additional exemption
    that compiling, linking, and/or using OpenSSL is allowed.
    You are free to remove this exemption from derived works.

    Copyright 2012-2013 Vkontakte Ltd
              2012-2013 Vitaliy Valtman
*/

#ifndef __TL_TL_H__
#define __TL_TL_H__

// Current tl-tl schema is V2
// See https://core.telegram.org/mtproto/TL-tl

#define TLS_SCHEMA_V2 0x3a2f9be2
#define TLS_TYPE 0x12eb4386
#define TLS_COMBINATOR 0x5c0a1ed5
#define TLS_COMBINATOR_LEFT_BUILTIN 0xcd211f63
#define TLS_COMBINATOR_LEFT 0x4c12c6d9
#define TLS_COMBINATOR_RIGHT_V2 0x2c064372
#define TLS_ARG_V2 0x29dfe61b

#define TLS_EXPR_TYPE 0xecc9da78
#define TLS_EXPR_NAT 0xdcb49bd8

#define TLS_NAT_CONST 0xdcb49bd8
#define TLS_NAT_VAR 0x4e8a14f0
#define TLS_TYPE_VAR 0x0142ceae
#define TLS_ARRAY 0xd9fb20de
#define TLS_TYPE_EXPR 0xc1863d08

/* Deprecated (old versions), read-only */
#define TLS_TREE_NAT_CONST 0xc09f07d7
#define TLS_TREE_NAT_VAR 0x90ea6f58
#define TLS_TREE_TYPE_VAR 0x1caa237a
#define TLS_TREE_ARRAY 0x80479360
#define TLS_TREE_TYPE 0x10f32190

#endif
