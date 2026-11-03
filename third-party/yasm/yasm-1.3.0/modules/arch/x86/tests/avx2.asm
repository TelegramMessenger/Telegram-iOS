; Exhaustive test of AVX2 instructions
;
;  Copyright (C) 2011  Peter Johnson
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions
; are met:
; 1. Redistributions of source code must retain the above copyright
;    notice, this list of conditions and the following disclaimer.
; 2. Redistributions in binary form must reproduce the above copyright
;    notice, this list of conditions and the following disclaimer in the
;    documentation and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND OTHER CONTRIBUTORS ``AS IS''
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR OTHER CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.
;

[bits 64]

vmpsadbw ymm1, ymm3, 3			; c4 e3 75 42 cb 03
vmpsadbw ymm1, yword [rax], 3		; c4 e3 75 42 08 03
vmpsadbw ymm1, ymm2, ymm3, 3		; c4 e3 6d 42 cb 03
vmpsadbw ymm1, ymm2, yword [rax], 3	; c4 e3 6d 42 08 03

vpabsb ymm1, ymm2			; c4 e2 7d 1c ca
vpabsb ymm1, yword [rax]		; c4 e2 7d 1c 08

vpabsw ymm1, ymm2			; c4 e2 7d 1d ca
vpabsw ymm1, yword [rax]		; c4 e2 7d 1d 08

vpabsd ymm1, ymm2			; c4 e2 7d 1e ca
vpabsd ymm1, yword [rax]		; c4 e2 7d 1e 08

vpacksswb ymm1, ymm3			; c5 f5 63 cb
vpacksswb ymm1, yword [rax]		; c5 f5 63 08
vpacksswb ymm1, ymm2, ymm3		; c5 ed 63 cb
vpacksswb ymm1, ymm2, yword [rax]	; c5 ed 63 08

vpackssdw ymm1, ymm3			; c5 f5 6b cb
vpackssdw ymm1, yword [rax]		; c5 f5 6b 08
vpackssdw ymm1, ymm2, ymm3		; c5 ed 6b cb
vpackssdw ymm1, ymm2, yword [rax]	; c5 ed 6b 08

vpackusdw ymm1, ymm3			; c4 e2 75 2b cb
vpackusdw ymm1, yword [rax]		; c4 e2 75 2b 08
vpackusdw ymm1, ymm2, ymm3		; c4 e2 6d 2b cb
vpackusdw ymm1, ymm2, yword [rax]	; c4 e2 6d 2b 08

vpackuswb ymm1, ymm3			; c5 f5 67 cb
vpackuswb ymm1, yword [rax]		; c5 f5 67 08
vpackuswb ymm1, ymm2, ymm3		; c5 ed 67 cb
vpackuswb ymm1, ymm2, yword [rax]	; c5 ed 67 08

vpaddb ymm1, ymm3			; c5 f5 fc cb
vpaddb ymm1, yword [rax]		; c5 f5 fc 08
vpaddb ymm1, ymm2, ymm3			; c5 ed fc cb
vpaddb ymm1, ymm2, yword [rax]		; c5 ed fc 08

vpaddw ymm1, ymm3			; c5 f5 fd cb
vpaddw ymm1, yword [rax]		; c5 f5 fd 08
vpaddw ymm1, ymm2, ymm3			; c5 ed fd cb
vpaddw ymm1, ymm2, yword [rax]		; c5 ed fd 08

vpaddd ymm1, ymm3			; c5 f5 fe cb
vpaddd ymm1, yword [rax]		; c5 f5 fe 08
vpaddd ymm1, ymm2, ymm3			; c5 ed fe cb
vpaddd ymm1, ymm2, yword [rax]		; c5 ed fe 08

vpaddq ymm1, ymm3			; c5 f5 d4 cb
vpaddq ymm1, yword [rax]		; c5 f5 d4 08
vpaddq ymm1, ymm2, ymm3			; c5 ed d4 cb
vpaddq ymm1, ymm2, yword [rax]		; c5 ed d4 08

vpaddsb ymm1, ymm3			; c5 f5 ec cb
vpaddsb ymm1, yword [rax]		; c5 f5 ec 08
vpaddsb ymm1, ymm2, ymm3		; c5 ed ec cb
vpaddsb ymm1, ymm2, yword [rax]		; c5 ed ec 08

vpaddsw ymm1, ymm3			; c5 f5 ed cb
vpaddsw ymm1, yword [rax]		; c5 f5 ed 08
vpaddsw ymm1, ymm2, ymm3		; c5 ed ed cb
vpaddsw ymm1, ymm2, yword [rax]		; c5 ed ed 08

vpaddusb ymm1, ymm3			; c5 f5 dc cb
vpaddusb ymm1, yword [rax]		; c5 f5 dc 08
vpaddusb ymm1, ymm2, ymm3		; c5 ed dc cb
vpaddusb ymm1, ymm2, yword [rax]	; c5 ed dc 08

vpaddusw ymm1, ymm3			; c5 f5 dd cb
vpaddusw ymm1, yword [rax]		; c5 f5 dd 08
vpaddusw ymm1, ymm2, ymm3		; c5 ed dd cb
vpaddusw ymm1, ymm2, yword [rax]	; c5 ed dd 08

vpalignr ymm1, ymm2, ymm3, 3		; c4 e3 6d 0f cb 03
vpalignr ymm1, ymm2, yword [rax], 3	; c4 e3 6d 0f 08 03

vpand ymm1, ymm3			; c5 f5 db cb
vpand ymm1, yword [rax]			; c5 f5 db 08
vpand ymm1, ymm2, ymm3			; c5 ed db cb
vpand ymm1, ymm2, yword [rax]		; c5 ed db 08

vpandn ymm1, ymm3			; c5 f5 df cb
vpandn ymm1, yword [rax]		; c5 f5 df 08
vpandn ymm1, ymm2, ymm3			; c5 ed df cb
vpandn ymm1, ymm2, yword [rax]		; c5 ed df 08

vpavgb ymm1, ymm3			; c5 f5 e0 cb
vpavgb ymm1, yword [rax]		; c5 f5 e0 08
vpavgb ymm1, ymm2, ymm3			; c5 ed e0 cb
vpavgb ymm1, ymm2, yword [rax]		; c5 ed e0 08

vpavgw ymm1, ymm3			; c5 f5 e3 cb
vpavgw ymm1, yword [rax]		; c5 f5 e3 08
vpavgw ymm1, ymm2, ymm3			; c5 ed e3 cb
vpavgw ymm1, ymm2, yword [rax]		; c5 ed e3 08

vpblendvb ymm1, ymm2, ymm3, ymm4	; c4 e3 6d 4c cb 40
vpblendvb ymm1, ymm2, yword [rax], ymm4	; c4 e3 6d 4c 08 40

vpblendw ymm1, ymm3, 3			; c4 e3 75 0e cb 03
vpblendw ymm1, yword [rax], 3		; c4 e3 75 0e 08 03
vpblendw ymm1, ymm2, ymm3, 3		; c4 e3 6d 0e cb 03
vpblendw ymm1, ymm2, yword [rax], 3	; c4 e3 6d 0e 08 03

vpcmpeqb ymm1, ymm3			; c5 f5 74 cb
vpcmpeqb ymm1, yword [rax]		; c5 f5 74 08
vpcmpeqb ymm1, ymm2, ymm3		; c5 ed 74 cb
vpcmpeqb ymm1, ymm2, yword [rax]	; c5 ed 74 08

vpcmpeqw ymm1, ymm3			; c5 f5 75 cb
vpcmpeqw ymm1, yword [rax]		; c5 f5 75 08
vpcmpeqw ymm1, ymm2, ymm3		; c5 ed 75 cb
vpcmpeqw ymm1, ymm2, yword [rax]	; c5 ed 75 08

vpcmpeqd ymm1, ymm3			; c5 f5 76 cb
vpcmpeqd ymm1, yword [rax]		; c5 f5 76 08
vpcmpeqd ymm1, ymm2, ymm3		; c5 ed 76 cb
vpcmpeqd ymm1, ymm2, yword [rax]	; c5 ed 76 08

vpcmpeqq ymm1, ymm3			; c4 e2 75 29 cb
vpcmpeqq ymm1, yword [rax]		; c4 e2 75 29 08
vpcmpeqq ymm1, ymm2, ymm3		; c4 e2 6d 29 cb
vpcmpeqq ymm1, ymm2, yword [rax]	; c4 e2 6d 29 08

vpcmpgtb ymm1, ymm3			; c5 f5 64 cb
vpcmpgtb ymm1, yword [rax]		; c5 f5 64 08
vpcmpgtb ymm1, ymm2, ymm3		; c5 ed 64 cb
vpcmpgtb ymm1, ymm2, yword [rax]	; c5 ed 64 08

vpcmpgtw ymm1, ymm3			; c5 f5 65 cb
vpcmpgtw ymm1, yword [rax]		; c5 f5 65 08
vpcmpgtw ymm1, ymm2, ymm3		; c5 ed 65 cb
vpcmpgtw ymm1, ymm2, yword [rax]	; c5 ed 65 08

vpcmpgtd ymm1, ymm3			; c5 f5 66 cb
vpcmpgtd ymm1, yword [rax]		; c5 f5 66 08
vpcmpgtd ymm1, ymm2, ymm3		; c5 ed 66 cb
vpcmpgtd ymm1, ymm2, yword [rax]	; c5 ed 66 08

vpcmpgtq ymm1, ymm3			; c4 e2 75 37 cb
vpcmpgtq ymm1, yword [rax]		; c4 e2 75 37 08
vpcmpgtq ymm1, ymm2, ymm3		; c4 e2 6d 37 cb
vpcmpgtq ymm1, ymm2, yword [rax]	; c4 e2 6d 37 08

vphaddw ymm1, ymm3			; c4 e2 75 01 cb
vphaddw ymm1, yword [rax]		; c4 e2 75 01 08
vphaddw ymm1, ymm2, ymm3		; c4 e2 6d 01 cb
vphaddw ymm1, ymm2, yword [rax]		; c4 e2 6d 01 08

vphaddd ymm1, ymm3			; c4 e2 75 02 cb
vphaddd ymm1, yword [rax]		; c4 e2 75 02 08
vphaddd ymm1, ymm2, ymm3		; c4 e2 6d 02 cb
vphaddd ymm1, ymm2, yword [rax]		; c4 e2 6d 02 08

vphaddsw ymm1, ymm3			; c4 e2 75 03 cb
vphaddsw ymm1, yword [rax]		; c4 e2 75 03 08
vphaddsw ymm1, ymm2, ymm3		; c4 e2 6d 03 cb
vphaddsw ymm1, ymm2, yword [rax]	; c4 e2 6d 03 08

vphsubw ymm1, ymm3			; c4 e2 75 05 cb
vphsubw ymm1, yword [rax]		; c4 e2 75 05 08
vphsubw ymm1, ymm2, ymm3		; c4 e2 6d 05 cb
vphsubw ymm1, ymm2, yword [rax]		; c4 e2 6d 05 08

vphsubd ymm1, ymm3			; c4 e2 75 06 cb
vphsubd ymm1, yword [rax]		; c4 e2 75 06 08
vphsubd ymm1, ymm2, ymm3		; c4 e2 6d 06 cb
vphsubd ymm1, ymm2, yword [rax]		; c4 e2 6d 06 08

vphsubsw ymm1, ymm3			; c4 e2 75 07 cb
vphsubsw ymm1, yword [rax]		; c4 e2 75 07 08
vphsubsw ymm1, ymm2, ymm3		; c4 e2 6d 07 cb
vphsubsw ymm1, ymm2, yword [rax]	; c4 e2 6d 07 08

vpmaddubsw ymm1, ymm3			; c4 e2 75 04 cb
vpmaddubsw ymm1, yword [rax]		; c4 e2 75 04 08
vpmaddubsw ymm1, ymm2, ymm3		; c4 e2 6d 04 cb
vpmaddubsw ymm1, ymm2, yword [rax]	; c4 e2 6d 04 08

vpmaddwd ymm1, ymm3			; c5 f5 f5 cb
vpmaddwd ymm1, yword [rax]		; c5 f5 f5 08
vpmaddwd ymm1, ymm2, ymm3		; c5 ed f5 cb
vpmaddwd ymm1, ymm2, yword [rax]	; c5 ed f5 08

vpmaxsb ymm1, ymm3			; c4 e2 75 3c cb
vpmaxsb ymm1, yword [rax]		; c4 e2 75 3c 08
vpmaxsb ymm1, ymm2, ymm3		; c4 e2 6d 3c cb
vpmaxsb ymm1, ymm2, yword [rax]		; c4 e2 6d 3c 08

vpmaxsw ymm1, ymm3			; c5 f5 ee cb
vpmaxsw ymm1, yword [rax]		; c5 f5 ee 08
vpmaxsw ymm1, ymm2, ymm3		; c5 ed ee cb
vpmaxsw ymm1, ymm2, yword [rax]		; c5 ed ee 08

vpmaxsd ymm1, ymm3			; c4 e2 75 3d cb
vpmaxsd ymm1, yword [rax]		; c4 e2 75 3d 08
vpmaxsd ymm1, ymm2, ymm3		; c4 e2 6d 3d cb
vpmaxsd ymm1, ymm2, yword [rax]		; c4 e2 6d 3d 08

vpmaxub ymm1, ymm3			; c5 f5 de cb
vpmaxub ymm1, yword [rax]		; c5 f5 de 08
vpmaxub ymm1, ymm2, ymm3		; c5 ed de cb
vpmaxub ymm1, ymm2, yword [rax]		; c5 ed de 08

vpmaxuw ymm1, ymm3			; c4 e2 75 3e cb
vpmaxuw ymm1, yword [rax]		; c4 e2 75 3e 08
vpmaxuw ymm1, ymm2, ymm3		; c4 e2 6d 3e cb
vpmaxuw ymm1, ymm2, yword [rax]		; c4 e2 6d 3e 08

vpmaxud ymm1, ymm3			; c4 e2 75 3f cb
vpmaxud ymm1, yword [rax]		; c4 e2 75 3f 08
vpmaxud ymm1, ymm2, ymm3		; c4 e2 6d 3f cb
vpmaxud ymm1, ymm2, yword [rax]		; c4 e2 6d 3f 08

vpminsb ymm1, ymm3			; c4 e2 75 38 cb
vpminsb ymm1, yword [rax]		; c4 e2 75 38 08
vpminsb ymm1, ymm2, ymm3		; c4 e2 6d 38 cb
vpminsb ymm1, ymm2, yword [rax]		; c4 e2 6d 38 08

vpminsw ymm1, ymm3			; c5 f5 ea cb
vpminsw ymm1, yword [rax]		; c5 f5 ea 08
vpminsw ymm1, ymm2, ymm3		; c5 ed ea cb
vpminsw ymm1, ymm2, yword [rax]		; c5 ed ea 08

vpminsd ymm1, ymm3			; c4 e2 75 39 cb
vpminsd ymm1, yword [rax]		; c4 e2 75 39 08
vpminsd ymm1, ymm2, ymm3		; c4 e2 6d 39 cb
vpminsd ymm1, ymm2, yword [rax]		; c4 e2 6d 39 08

vpminub ymm1, ymm3			; c5 f5 da cb
vpminub ymm1, yword [rax]		; c5 f5 da 08
vpminub ymm1, ymm2, ymm3		; c5 ed da cb
vpminub ymm1, ymm2, yword [rax]		; c5 ed da 08

vpminuw ymm1, ymm3			; c4 e2 75 3a cb
vpminuw ymm1, yword [rax]		; c4 e2 75 3a 08
vpminuw ymm1, ymm2, ymm3		; c4 e2 6d 3a cb
vpminuw ymm1, ymm2, yword [rax]		; c4 e2 6d 3a 08

vpminud ymm1, ymm3			; c4 e2 75 3b cb
vpminud ymm1, yword [rax]		; c4 e2 75 3b 08
vpminud ymm1, ymm2, ymm3		; c4 e2 6d 3b cb
vpminud ymm1, ymm2, yword [rax]		; c4 e2 6d 3b 08

vpmovmskb eax, ymm1			; c5 fd d7 c1
vpmovmskb rax, ymm1			; c5 fd d7 c1

vpmovsxbw ymm1, xmm2			; c4 e2 7d 20 ca
vpmovsxbw ymm1, [rax]			; c4 e2 7d 20 08
vpmovsxbw ymm1, oword [rax]		; c4 e2 7d 20 08

vpmovsxbd ymm1, xmm2			; c4 e2 7d 21 ca
vpmovsxbd ymm1, [rax]			; c4 e2 7d 21 08
vpmovsxbd ymm1, qword [rax]		; c4 e2 7d 21 08

vpmovsxbq ymm1, xmm2			; c4 e2 7d 22 ca
vpmovsxbq ymm1, [rax]			; c4 e2 7d 22 08
vpmovsxbq ymm1, dword [rax]		; c4 e2 7d 22 08

vpmovsxwd ymm1, xmm2			; c4 e2 7d 23 ca
vpmovsxwd ymm1, [rax]			; c4 e2 7d 23 08
vpmovsxwd ymm1, oword [rax]		; c4 e2 7d 23 08

vpmovsxwq ymm1, xmm2			; c4 e2 7d 24 ca
vpmovsxwq ymm1, [rax]			; c4 e2 7d 24 08
vpmovsxwq ymm1, qword [rax]		; c4 e2 7d 24 08

vpmovsxdq ymm1, xmm2			; c4 e2 7d 25 ca
vpmovsxdq ymm1, [rax]			; c4 e2 7d 25 08
vpmovsxdq ymm1, oword [rax]		; c4 e2 7d 25 08

vpmovzxbw ymm1, xmm2			; c4 e2 7d 30 ca
vpmovzxbw ymm1, [rax]			; c4 e2 7d 30 08
vpmovzxbw ymm1, oword [rax]		; c4 e2 7d 30 08

vpmovzxbd ymm1, xmm2			; c4 e2 7d 31 ca
vpmovzxbd ymm1, [rax]			; c4 e2 7d 31 08
vpmovzxbd ymm1, qword [rax]		; c4 e2 7d 31 08

vpmovzxbq ymm1, xmm2			; c4 e2 7d 32 ca
vpmovzxbq ymm1, [rax]			; c4 e2 7d 32 08
vpmovzxbq ymm1, dword [rax]		; c4 e2 7d 32 08

vpmovzxwd ymm1, xmm2			; c4 e2 7d 33 ca
vpmovzxwd ymm1, [rax]			; c4 e2 7d 33 08
vpmovzxwd ymm1, oword [rax]		; c4 e2 7d 33 08

vpmovzxwq ymm1, xmm2			; c4 e2 7d 34 ca
vpmovzxwq ymm1, [rax]			; c4 e2 7d 34 08
vpmovzxwq ymm1, qword [rax]		; c4 e2 7d 34 08

vpmovzxdq ymm1, xmm2			; c4 e2 7d 35 ca
vpmovzxdq ymm1, [rax]			; c4 e2 7d 35 08
vpmovzxdq ymm1, oword [rax]		; c4 e2 7d 35 08

vpmuldq ymm1, ymm3			; c4 e2 75 28 cb
vpmuldq ymm1, yword [rax]		; c4 e2 75 28 08
vpmuldq ymm1, ymm2, ymm3		; c4 e2 6d 28 cb
vpmuldq ymm1, ymm2, yword [rax]		; c4 e2 6d 28 08

vpmulhrsw ymm1, ymm3			; c4 e2 75 0b cb
vpmulhrsw ymm1, yword [rax]		; c4 e2 75 0b 08
vpmulhrsw ymm1, ymm2, ymm3		; c4 e2 6d 0b cb
vpmulhrsw ymm1, ymm2, yword [rax]	; c4 e2 6d 0b 08

vpmulhuw ymm1, ymm3			; c5 f5 e4 cb
vpmulhuw ymm1, yword [rax]		; c5 f5 e4 08
vpmulhuw ymm1, ymm2, ymm3		; c5 ed e4 cb
vpmulhuw ymm1, ymm2, yword [rax]	; c5 ed e4 08

vpmulhw ymm1, ymm3			; c5 f5 e5 cb
vpmulhw ymm1, yword [rax]		; c5 f5 e5 08
vpmulhw ymm1, ymm2, ymm3		; c5 ed e5 cb
vpmulhw ymm1, ymm2, yword [rax]		; c5 ed e5 08

vpmullw ymm1, ymm3			; c5 f5 d5 cb
vpmullw ymm1, yword [rax]		; c5 f5 d5 08
vpmullw ymm1, ymm2, ymm3		; c5 ed d5 cb
vpmullw ymm1, ymm2, yword [rax]		; c5 ed d5 08

vpmulld ymm1, ymm3			; c4 e2 75 40 cb
vpmulld ymm1, yword [rax]		; c4 e2 75 40 08
vpmulld ymm1, ymm2, ymm3		; c4 e2 6d 40 cb
vpmulld ymm1, ymm2, yword [rax]		; c4 e2 6d 40 08

vpmuludq ymm1, ymm3			; c5 f5 f4 cb
vpmuludq ymm1, yword [rax]		; c5 f5 f4 08
vpmuludq ymm1, ymm2, ymm3		; c5 ed f4 cb
vpmuludq ymm1, ymm2, yword [rax]	; c5 ed f4 08

vpor ymm1, ymm3				; c5 f5 eb cb
vpor ymm1, yword [rax]			; c5 f5 eb 08
vpor ymm1, ymm2, ymm3			; c5 ed eb cb
vpor ymm1, ymm2, yword [rax]		; c5 ed eb 08

vpsadbw ymm1, ymm3			; c5 f5 f6 cb
vpsadbw ymm1, yword [rax]		; c5 f5 f6 08
vpsadbw ymm1, ymm2, ymm3		; c5 ed f6 cb
vpsadbw ymm1, ymm2, yword [rax]		; c5 ed f6 08

vpshufb ymm1, ymm3			; c4 e2 75 00 cb
vpshufb ymm1, yword [rax]		; c4 e2 75 00 08
vpshufb ymm1, ymm2, ymm3		; c4 e2 6d 00 cb
vpshufb ymm1, ymm2, yword [rax]		; c4 e2 6d 00 08

vpshufd ymm1, ymm3, 3			; c5 fd 70 cb 03
vpshufd ymm1, yword [rax], 3		; c5 fd 70 08 03

vpshufhw ymm1, ymm3, 3			; c5 fe 70 cb 03
vpshufhw ymm1, yword [rax], 3		; c5 fe 70 08 03

vpshuflw ymm1, ymm3, 3			; c5 ff 70 cb 03
vpshuflw ymm1, yword [rax], 3		; c5 ff 70 08 03

vpsignb ymm1, ymm3			; c4 e2 75 08 cb
vpsignb ymm1, yword [rax]		; c4 e2 75 08 08
vpsignb ymm1, ymm2, ymm3		; c4 e2 6d 08 cb
vpsignb ymm1, ymm2, yword [rax]		; c4 e2 6d 08 08

vpsignw ymm1, ymm3			; c4 e2 75 09 cb
vpsignw ymm1, yword [rax]		; c4 e2 75 09 08
vpsignw ymm1, ymm2, ymm3		; c4 e2 6d 09 cb
vpsignw ymm1, ymm2, yword [rax]		; c4 e2 6d 09 08

vpsignd ymm1, ymm3			; c4 e2 75 0a cb
vpsignd ymm1, yword [rax]		; c4 e2 75 0a 08
vpsignd ymm1, ymm2, ymm3		; c4 e2 6d 0a cb
vpsignd ymm1, ymm2, yword [rax]		; c4 e2 6d 0a 08

vpslldq ymm1, 3				; c5 f5 73 f9 03
vpslldq ymm1, ymm2, 3			; c5 f5 73 fa 03

vpsllw ymm1, xmm3			; c5 f5 f1 cb
vpsllw ymm1, oword [rax]		; c5 f5 f1 08
vpsllw ymm1, 3				; c5 f5 71 f1 03
vpsllw ymm1, ymm2, xmm3			; c5 ed f1 cb
vpsllw ymm1, ymm2, oword [rax]		; c5 ed f1 08
vpsllw ymm1, ymm2, 3			; c5 f5 71 f2 03

vpslld ymm1, xmm3			; c5 f5 f2 cb
vpslld ymm1, oword [rax]		; c5 f5 f2 08
vpslld ymm1, 3				; c5 f5 72 f1 03
vpslld ymm1, ymm2, xmm3			; c5 ed f2 cb
vpslld ymm1, ymm2, oword [rax]		; c5 ed f2 08
vpslld ymm1, ymm2, 3			; c5 f5 72 f2 03

vpsllq ymm1, xmm3			; c5 f5 f3 cb
vpsllq ymm1, oword [rax]		; c5 f5 f3 08
vpsllq ymm1, 3				; c5 f5 73 f1 03
vpsllq ymm1, ymm2, xmm3			; c5 ed f3 cb
vpsllq ymm1, ymm2, oword [rax]		; c5 ed f3 08
vpsllq ymm1, ymm2, 3			; c5 f5 73 f2 03

vpsraw ymm1, xmm3			; c5 f5 e1 cb
vpsraw ymm1, oword [rax]		; c5 f5 e1 08
vpsraw ymm1, 3				; c5 f5 71 e1 03
vpsraw ymm1, ymm2, xmm3			; c5 ed e1 cb
vpsraw ymm1, ymm2, oword [rax]		; c5 ed e1 08
vpsraw ymm1, ymm2, 3			; c5 f5 71 e2 03

vpsrad ymm1, xmm3			; c5 f5 e2 cb
vpsrad ymm1, oword [rax]		; c5 f5 e2 08
vpsrad ymm1, 3				; c5 f5 72 e1 03
vpsrad ymm1, ymm2, xmm3			; c5 ed e2 cb
vpsrad ymm1, ymm2, oword [rax]		; c5 ed e2 08
vpsrad ymm1, ymm2, 3			; c5 f5 72 e2 03

vpsrldq ymm1, 3				; c5 f5 73 d9 03
vpsrldq ymm1, ymm2, 3			; c5 f5 73 da 03

vpsrlw ymm1, xmm3			; c5 f5 d1 cb
vpsrlw ymm1, oword [rax]		; c5 f5 d1 08
vpsrlw ymm1, 3				; c5 f5 71 d1 03
vpsrlw ymm1, ymm2, xmm3			; c5 ed d1 cb
vpsrlw ymm1, ymm2, oword [rax]		; c5 ed d1 08
vpsrlw ymm1, ymm2, 3			; c5 f5 71 d2 03

vpsrld ymm1, xmm3			; c5 f5 d2 cb
vpsrld ymm1, oword [rax]		; c5 f5 d2 08
vpsrld ymm1, 3				; c5 f5 72 d1 03
vpsrld ymm1, ymm2, xmm3			; c5 ed d2 cb
vpsrld ymm1, ymm2, oword [rax]		; c5 ed d2 08
vpsrld ymm1, ymm2, 3			; c5 f5 72 d2 03

vpsrld ymm1, xmm3			; c5 f5 d2 cb
vpsrld ymm1, oword [rax]		; c5 f5 d2 08
vpsrld ymm1, 3				; c5 f5 72 d1 03
vpsrld ymm1, ymm2, xmm3			; c5 ed d2 cb
vpsrld ymm1, ymm2, oword [rax]		; c5 ed d2 08
vpsrld ymm1, ymm2, 3			; c5 f5 72 d2 03

vpsubsb ymm1, ymm3			; c5 f5 e8 cb
vpsubsb ymm1, yword [rax]		; c5 f5 e8 08
vpsubsb ymm1, ymm2, ymm3		; c5 ed e8 cb
vpsubsb ymm1, ymm2, yword [rax]		; c5 ed e8 08

vpsubsw ymm1, ymm3			; c5 f5 e9 cb
vpsubsw ymm1, yword [rax]		; c5 f5 e9 08
vpsubsw ymm1, ymm2, ymm3		; c5 ed e9 cb
vpsubsw ymm1, ymm2, yword [rax]		; c5 ed e9 08

vpsubusb ymm1, ymm3			; c5 f5 d8 cb
vpsubusb ymm1, yword [rax]		; c5 f5 d8 08
vpsubusb ymm1, ymm2, ymm3		; c5 ed d8 cb
vpsubusb ymm1, ymm2, yword [rax]	; c5 ed d8 08

vpsubusw ymm1, ymm3			; c5 f5 d9 cb
vpsubusw ymm1, yword [rax]		; c5 f5 d9 08
vpsubusw ymm1, ymm2, ymm3		; c5 ed d9 cb
vpsubusw ymm1, ymm2, yword [rax]	; c5 ed d9 08

vpunpckhbw ymm1, ymm3			; c5 f5 68 cb
vpunpckhbw ymm1, yword [rax]		; c5 f5 68 08
vpunpckhbw ymm1, ymm2, ymm3		; c5 ed 68 cb
vpunpckhbw ymm1, ymm2, yword [rax]	; c5 ed 68 08

vpunpckhwd ymm1, ymm3			; c5 f5 69 cb
vpunpckhwd ymm1, yword [rax]		; c5 f5 69 08
vpunpckhwd ymm1, ymm2, ymm3		; c5 ed 69 cb
vpunpckhwd ymm1, ymm2, yword [rax]	; c5 ed 69 08

vpunpckhdq ymm1, ymm3			; c5 f5 6a cb
vpunpckhdq ymm1, yword [rax]		; c5 f5 6a 08
vpunpckhdq ymm1, ymm2, ymm3		; c5 ed 6a cb
vpunpckhdq ymm1, ymm2, yword [rax]	; c5 ed 6a 08

vpunpckhqdq ymm1, ymm3			; c5 f5 6d cb
vpunpckhqdq ymm1, yword [rax]		; c5 f5 6d 08
vpunpckhqdq ymm1, ymm2, ymm3		; c5 ed 6d cb
vpunpckhqdq ymm1, ymm2, yword [rax]	; c5 ed 6d 08

vpunpcklbw ymm1, ymm3			; c5 f5 60 cb
vpunpcklbw ymm1, yword [rax]		; c5 f5 60 08
vpunpcklbw ymm1, ymm2, ymm3		; c5 ed 60 cb
vpunpcklbw ymm1, ymm2, yword [rax]	; c5 ed 60 08

vpunpcklwd ymm1, ymm3			; c5 f5 61 cb
vpunpcklwd ymm1, yword [rax]		; c5 f5 61 08
vpunpcklwd ymm1, ymm2, ymm3		; c5 ed 61 cb
vpunpcklwd ymm1, ymm2, yword [rax]	; c5 ed 61 08

vpunpckldq ymm1, ymm3			; c5 f5 62 cb
vpunpckldq ymm1, yword [rax]		; c5 f5 62 08
vpunpckldq ymm1, ymm2, ymm3		; c5 ed 62 cb
vpunpckldq ymm1, ymm2, yword [rax]	; c5 ed 62 08

vpunpcklqdq ymm1, ymm3			; c5 f5 6c cb
vpunpcklqdq ymm1, yword [rax]		; c5 f5 6c 08
vpunpcklqdq ymm1, ymm2, ymm3		; c5 ed 6c cb
vpunpcklqdq ymm1, ymm2, yword [rax]	; c5 ed 6c 08

vpxor ymm1, ymm3			; c5 f5 ef cb
vpxor ymm1, yword [rax]			; c5 f5 ef 08
vpxor ymm1, ymm2, ymm3			; c5 ed ef cb
vpxor ymm1, ymm2, yword [rax]		; c5 ed ef 08

vmovntdqa ymm1, yword [rax]		; c4 e2 7d 2a 08

vbroadcastss xmm1, xmm2			; c4 e2 79 18 ca
vbroadcastss ymm1, xmm2			; c4 e2 7d 18 ca

vbroadcastsd ymm1, xmm2			; c4 e2 7d 19 ca

vbroadcasti128 ymm1, oword [rax]	; c4 e2 7d 5a 08

vpblendd ymm1, ymm2, ymm3, 3		; c4 e3 6d 02 cb 03
vpblendd ymm1, ymm2, yword [rax], 3	; c4 e3 6d 02 08 03

vpbroadcastb xmm1, xmm2			; c4 e2 79 78 ca
vpbroadcastb xmm1, byte [rax]		; c4 e2 79 78 08
vpbroadcastb ymm1, xmm2			; c4 e2 7d 78 ca
vpbroadcastb ymm1, byte [rax]		; c4 e2 7d 78 08

vpbroadcastw xmm1, xmm2			; c4 e2 79 79 ca
vpbroadcastw xmm1, word [rax]		; c4 e2 79 79 08
vpbroadcastw ymm1, xmm2			; c4 e2 7d 79 ca
vpbroadcastw ymm1, word [rax]		; c4 e2 7d 79 08

vpbroadcastd xmm1, xmm2			; c4 e2 79 58 ca
vpbroadcastd xmm1, dword [rax]		; c4 e2 79 58 08
vpbroadcastd ymm1, xmm2			; c4 e2 7d 58 ca
vpbroadcastd ymm1, dword [rax]		; c4 e2 7d 58 08

vpbroadcastq xmm1, xmm2			; c4 e2 79 59 ca
vpbroadcastq xmm1, qword [rax]		; c4 e2 79 59 08
vpbroadcastq ymm1, xmm2			; c4 e2 7d 59 ca
vpbroadcastq ymm1, qword [rax]		; c4 e2 7d 59 08

vpermd ymm1, ymm2, ymm3			; c4 e2 6d 36 cb
vpermd ymm1, ymm2, yword [rax]		; c4 e2 6d 36 08

vpermpd ymm1, ymm2, 3			; c4 e3 fd 01 ca 03
vpermpd ymm1, yword [rax], 3		; c4 e3 fd 01 08 03

vpermps ymm1, ymm2, ymm3		; c4 e2 6d 16 cb
vpermps ymm1, ymm2, yword [rax]		; c4 e2 6d 16 08

vpermq ymm1, ymm2, 3			; c4 e3 fd 00 ca 03
vpermq ymm1, yword [rax], 3		; c4 e3 fd 00 08 03

vperm2i128 ymm1, ymm2, ymm3, 3		; c4 e3 6d 46 cb 03
vperm2i128 ymm1, ymm2, yword [rax], 3	; c4 e3 6d 46 08 03

vextracti128 xmm1, ymm2, 3		; c4 e3 7d 39 d1 03
vextracti128 oword [rax], ymm2, 3	; c4 e3 7d 39 10 03

vinserti128 ymm1, ymm2, xmm3, 3		; c4 e3 6d 38 cb 03
vinserti128 ymm1, ymm2, oword [rax], 3	; c4 e3 6d 38 08 03

vpmaskmovd xmm1, xmm2, oword [rax]	; c4 e2 69 8c 08
vpmaskmovd ymm1, ymm2, yword [rax]	; c4 e2 6d 8c 08
vpmaskmovd oword [rax], xmm1, xmm2	; c4 e2 71 8e 10
vpmaskmovd yword [rax], ymm1, ymm2	; c4 e2 75 8e 10

vpmaskmovq xmm1, xmm2, oword [rax]	; c4 e2 e9 8c 08
vpmaskmovq ymm1, ymm2, yword [rax]	; c4 e2 ed 8c 08
vpmaskmovq oword [rax], xmm1, xmm2	; c4 e2 f1 8e 10
vpmaskmovq yword [rax], ymm1, ymm2	; c4 e2 f5 8e 10

vpsllvd xmm1, xmm2, xmm3		; c4 e2 69 47 cb
vpsllvd xmm1, xmm2, oword [rax]		; c4 e2 69 47 08
vpsllvd ymm1, ymm2, ymm3		; c4 e2 6d 47 cb
vpsllvd ymm1, ymm2, yword [rax]		; c4 e2 6d 47 08

vpsllvq xmm1, xmm2, xmm3		; c4 e2 e9 47 cb
vpsllvq xmm1, xmm2, oword [rax]		; c4 e2 e9 47 08
vpsllvq ymm1, ymm2, ymm3		; c4 e2 ed 47 cb
vpsllvq ymm1, ymm2, yword [rax]		; c4 e2 ed 47 08

vpsravd xmm1, xmm2, xmm3		; c4 e2 69 46 cb
vpsravd xmm1, xmm2, oword [rax]		; c4 e2 69 46 08
vpsravd ymm1, ymm2, ymm3		; c4 e2 6d 46 cb
vpsravd ymm1, ymm2, yword [rax]		; c4 e2 6d 46 08

vpsrlvd xmm1, xmm2, xmm3		; c4 e2 69 45 cb
vpsrlvd xmm1, xmm2, oword [rax]		; c4 e2 69 45 08
vpsrlvd ymm1, ymm2, ymm3		; c4 e2 6d 45 cb
vpsrlvd ymm1, ymm2, yword [rax]		; c4 e2 6d 45 08

vpsrlvq xmm1, xmm2, xmm3		; c4 e2 e9 45 cb
vpsrlvq xmm1, xmm2, oword [rax]		; c4 e2 e9 45 08
vpsrlvq ymm1, ymm2, ymm3		; c4 e2 ed 45 cb
vpsrlvq ymm1, ymm2, yword [rax]		; c4 e2 ed 45 08

vgatherdpd xmm1, [rax+xmm1], xmm2	; c4 e2 e9 92 0c 08
vgatherdpd xmm1, qword [rax+xmm1], xmm2	; c4 e2 e9 92 0c 08
vgatherdpd ymm1, [rax+xmm1], ymm2	; c4 e2 ed 92 0c 08
vgatherdpd ymm1, qword [rax+xmm1], ymm2	; c4 e2 ed 92 0c 08

vgatherqpd xmm1, [rax+xmm1], xmm2	; c4 e2 e9 93 0c 08
vgatherqpd xmm1, qword [rax+xmm1], xmm2	; c4 e2 e9 93 0c 08
vgatherqpd ymm1, [rax+ymm1], ymm2	; c4 e2 ed 93 0c 08
vgatherqpd ymm1, qword [rax+ymm1], ymm2	; c4 e2 ed 93 0c 08

vgatherdps xmm1, [rax+xmm1], xmm2	; c4 e2 69 92 0c 08
vgatherdps xmm1, dword [rax+xmm1], xmm2	; c4 e2 69 92 0c 08
vgatherdps ymm1, [rax+ymm1], ymm2	; c4 e2 6d 92 0c 08
vgatherdps ymm1, dword [rax+ymm1], ymm2	; c4 e2 6d 92 0c 08

vgatherqps xmm1, [rax+xmm1], xmm2	; c4 e2 69 93 0c 08
vgatherqps xmm1, dword [rax+xmm1], xmm2	; c4 e2 69 93 0c 08
vgatherqps xmm1, [rax+ymm1], xmm2	; c4 e2 6d 93 0c 08
vgatherqps xmm1, dword [rax+ymm1], xmm2	; c4 e2 6d 93 0c 08

vpgatherdd xmm1, [rax+xmm1], xmm2	; c4 e2 69 90 0c 08
vpgatherdd xmm1, dword [rax+xmm1], xmm2	; c4 e2 69 90 0c 08
vpgatherdd ymm1, [rax+ymm1], ymm2	; c4 e2 6d 90 0c 08
vpgatherdd ymm1, dword [rax+ymm1], ymm2	; c4 e2 6d 90 0c 08

vpgatherqd xmm1, [rax+xmm1], xmm2	; c4 e2 69 91 0c 08
vpgatherqd xmm1, dword [rax+xmm1], xmm2	; c4 e2 69 91 0c 08
vpgatherqd xmm1, [rax+ymm1], xmm2	; c4 e2 6d 91 0c 08
vpgatherqd xmm1, dword [rax+ymm1], xmm2	; c4 e2 6d 91 0c 08

vpgatherdq xmm1, [rax+xmm1], xmm2	; c4 e2 e9 90 0c 08
vpgatherdq xmm1, qword [rax+xmm1], xmm2	; c4 e2 e9 90 0c 08
vpgatherdq ymm1, [rax+xmm1], ymm2	; c4 e2 ed 90 0c 08
vpgatherdq ymm1, qword [rax+xmm1], ymm2	; c4 e2 ed 90 0c 08

vpgatherqq xmm1, [rax+xmm1], xmm2	; c4 e2 e9 91 0c 08
vpgatherqq xmm1, qword [rax+xmm1], xmm2	; c4 e2 e9 91 0c 08
vpgatherqq ymm1, [rax+ymm1], ymm2	; c4 e2 ed 91 0c 08
vpgatherqq ymm1, qword [rax+ymm1], ymm2	; c4 e2 ed 91 0c 08
