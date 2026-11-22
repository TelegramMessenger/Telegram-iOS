; Instructions are ordered in XOP databook order
; BITS=16 to minimize output length
[bits 16]
vfrczpd xmm1, xmm2			; 8F E9 78 81 312
vfrczpd xmm1, [0]			; 8F E9 78 81 016 00 00
vfrczpd xmm1, dqword [0]		; 8F E9 78 81 016 00 00
vfrczpd ymm1, ymm2			; 8F E9 7C 81 312
vfrczpd ymm1, [0]			; 8F E9 7C 81 016 00 00
vfrczpd ymm1, yword [0]			; 8F E9 7C 81 016 00 00

vfrczps xmm1, xmm2			; 8F E9 78 80 312
vfrczps xmm1, [0]			; 8F E9 78 80 016 00 00
vfrczps xmm1, dqword [0]		; 8F E9 78 80 016 00 00
vfrczps ymm1, ymm2			; 8F E9 7C 80 312
vfrczps ymm1, [0]			; 8F E9 7C 80 016 00 00
vfrczps ymm1, yword [0]			; 8F E9 7C 80 016 00 00

vfrczsd xmm1, xmm2			; 8F E9 78 83 312
vfrczsd xmm1, [0]			; 8F E9 78 83 016 00 00
vfrczsd xmm1, qword [0]			; 8F E9 78 83 016 00 00

vfrczss xmm1, xmm2			; 8F E9 78 82 312
vfrczss xmm1, [0]			; 8F E9 78 82 016 00 00
vfrczss xmm1, dword [0]			; 8F E9 78 82 016 00 00

vpcmov xmm1, xmm2, xmm3, xmm4		; 8F E8 68 A2 313 40 /or/ 8F E8 E8 A2 314 30
vpcmov xmm1, xmm2, xmm3, [0]		; 8F E8 E8 A2 016 00 00 30
vpcmov xmm1, xmm2, xmm3, dqword [0]	; 8F E8 E8 A2 016 00 00 30
vpcmov xmm1, xmm2, [0], xmm4		; 8F E8 68 A2 016 00 00 40
vpcmov xmm1, xmm2, dqword [0], xmm4	; 8F E8 68 A2 016 00 00 40
vpcmov ymm1, ymm2, ymm3, ymm4		; 8F E8 6C A2 313 40 /or/ 8F E8 EC A2 314 30
vpcmov ymm1, ymm2, ymm3, [0]		; 8F E8 EC A2 016 00 00 30
vpcmov ymm1, ymm2, ymm3, yword [0]	; 8F E8 EC A2 016 00 00 30
vpcmov ymm1, ymm2, [0], ymm4		; 8F E8 6C A2 016 00 00 40
vpcmov ymm1, ymm2, yword [0], ymm4	; 8F E8 6C A2 016 00 00 40

vpcomb xmm1, xmm4, xmm7, 5		; 8F E8 58 CC 317 05
vpcomb xmm2, xmm5, [0], byte 5		; 8F E8 50 CC 026 00 00 05
vpcomb xmm3, xmm6, dqword [0], 5	; 8F E8 48 CC 036 00 00 05

vpcomd xmm1, xmm4, xmm7, 5		; 8F E8 58 CE 317 05
vpcomd xmm2, xmm5, [0], byte 5		; 8F E8 50 CE 026 00 00 05
vpcomd xmm3, xmm6, dqword [0], 5	; 8F E8 48 CE 036 00 00 05

vpcomq xmm1, xmm4, xmm7, 5		; 8F E8 58 CF 317 05
vpcomq xmm2, xmm5, [0], byte 5		; 8F E8 50 CF 026 00 00 05
vpcomq xmm3, xmm6, dqword [0], 5	; 8F E8 48 CF 036 00 00 05

vpcomub xmm1, xmm4, xmm7, 5		; 8F E8 58 EC 317 05
vpcomub xmm2, xmm5, [0], byte 5		; 8F E8 50 EC 026 00 00 05
vpcomub xmm3, xmm6, dqword [0], 5	; 8F E8 48 EC 036 00 00 05

vpcomud xmm1, xmm4, xmm7, 5		; 8F E8 58 EE 317 05
vpcomud xmm2, xmm5, [0], byte 5		; 8F E8 50 EE 026 00 00 05
vpcomud xmm3, xmm6, dqword [0], 5	; 8F E8 48 EE 036 00 00 05

vpcomuq xmm1, xmm4, xmm7, 5		; 8F E8 58 EF 317 05
vpcomuq xmm2, xmm5, [0], byte 5		; 8F E8 50 EF 026 00 00 05
vpcomuq xmm3, xmm6, dqword [0], 5	; 8F E8 48 EF 036 00 00 05

vpcomuw xmm1, xmm4, xmm7, 5		; 8F E8 58 ED 317 05
vpcomuw xmm2, xmm5, [0], byte 5		; 8F E8 50 ED 026 00 00 05
vpcomuw xmm3, xmm6, dqword [0], 5	; 8F E8 48 ED 036 00 00 05

vpcomw xmm1, xmm4, xmm7, 5		; 8F E8 58 CD 317 05
vpcomw xmm2, xmm5, [0], byte 5		; 8F E8 50 CD 026 00 00 05
vpcomw xmm3, xmm6, dqword [0], 5	; 8F E8 48 CD 036 00 00 05

vphaddbd xmm1, xmm2			; 8F E9 78 C2 312
vphaddbd xmm1, [0]			; 8F E9 78 C2 016 00 00
vphaddbd xmm1, dqword [0]		; 8F E9 78 C2 016 00 00

vphaddbq xmm1, xmm2			; 8F E9 78 C3 312
vphaddbq xmm1, [0]			; 8F E9 78 C3 016 00 00
vphaddbq xmm1, dqword [0]		; 8F E9 78 C3 016 00 00

vphaddbw xmm1, xmm2			; 8F E9 78 C1 312
vphaddbw xmm1, [0]			; 8F E9 78 C1 016 00 00
vphaddbw xmm1, dqword [0]		; 8F E9 78 C1 016 00 00

vphadddq xmm1, xmm2			; 8F E9 78 CB 312
vphadddq xmm1, [0]			; 8F E9 78 CB 016 00 00
vphadddq xmm1, dqword [0]		; 8F E9 78 CB 016 00 00

vphaddubd xmm1, xmm2			; 8F E9 78 D2 312
vphaddubd xmm1, [0]			; 8F E9 78 D2 016 00 00
vphaddubd xmm1, dqword [0]		; 8F E9 78 D2 016 00 00

vphaddubq xmm1, xmm2			; 8F E9 78 D3 312
vphaddubq xmm1, [0]			; 8F E9 78 D3 016 00 00
vphaddubq xmm1, dqword [0]		; 8F E9 78 D3 016 00 00

vphaddubw xmm1, xmm2			; 8F E9 78 D1 312
vphaddubw xmm1, [0]			; 8F E9 78 D1 016 00 00
vphaddubw xmm1, dqword [0]		; 8F E9 78 D1 016 00 00

vphaddudq xmm1, xmm2			; 8F E9 78 DB 312
vphaddudq xmm1, [0]			; 8F E9 78 DB 016 00 00
vphaddudq xmm1, dqword [0]		; 8F E9 78 DB 016 00 00

vphadduwd xmm1, xmm2			; 8F E9 78 D6 312
vphadduwd xmm1, [0]			; 8F E9 78 D6 016 00 00
vphadduwd xmm1, dqword [0]		; 8F E9 78 D6 016 00 00

vphadduwq xmm1, xmm2			; 8F E9 78 D7 312
vphadduwq xmm1, [0]			; 8F E9 78 D7 016 00 00
vphadduwq xmm1, dqword [0]		; 8F E9 78 D7 016 00 00

vphaddwd xmm1, xmm2			; 8F E9 78 C6 312
vphaddwd xmm1, [0]			; 8F E9 78 C6 016 00 00
vphaddwd xmm1, dqword [0]		; 8F E9 78 C6 016 00 00

vphaddwq xmm1, xmm2			; 8F E9 78 C7 312
vphaddwq xmm1, [0]			; 8F E9 78 C7 016 00 00
vphaddwq xmm1, dqword [0]		; 8F E9 78 C7 016 00 00

vphsubbw xmm1, xmm2			; 8F E9 78 E1 312
vphsubbw xmm1, [0]			; 8F E9 78 E1 016 00 00
vphsubbw xmm1, dqword [0]		; 8F E9 78 E1 016 00 00

vphsubdq xmm1, xmm2			; 8F E9 78 E3 312
vphsubdq xmm1, [0]			; 8F E9 78 E3 016 00 00
vphsubdq xmm1, dqword [0]		; 8F E9 78 E3 016 00 00

vphsubwd xmm1, xmm2			; 8F E9 78 E2 312
vphsubwd xmm1, [0]			; 8F E9 78 E2 016 00 00
vphsubwd xmm1, dqword [0]		; 8F E9 78 E2 016 00 00

vpmacsdd xmm1, xmm4, xmm7, xmm3		; 8F E8 58 9E 317 30
vpmacsdd xmm2, xmm5, [0], xmm0		; 8F E8 50 9E 026 00 00 00
vpmacsdd xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 9E 036 00 00 20

vpmacsdqh xmm1, xmm4, xmm7, xmm3	; 8F E8 58 9F 317 30
vpmacsdqh xmm2, xmm5, [0], xmm0		; 8F E8 50 9F 026 00 00 00
vpmacsdqh xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 9F 036 00 00 20

vpmacsdql xmm1, xmm4, xmm7, xmm3	; 8F E8 58 97 317 30
vpmacsdql xmm2, xmm5, [0], xmm0		; 8F E8 50 97 026 00 00 00
vpmacsdql xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 97 036 00 00 20

vpmacssdd xmm1, xmm4, xmm7, xmm3	; 8F E8 58 8E 317 30
vpmacssdd xmm2, xmm5, [0], xmm0		; 8F E8 50 8E 026 00 00 00
vpmacssdd xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 8E 036 00 00 20

vpmacssdqh xmm1, xmm4, xmm7, xmm3	; 8F E8 58 8F 317 30
vpmacssdqh xmm2, xmm5, [0], xmm0	; 8F E8 50 8F 026 00 00 00
vpmacssdqh xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 8F 036 00 00 20

vpmacssdql xmm1, xmm4, xmm7, xmm3	; 8F E8 58 87 317 30
vpmacssdql xmm2, xmm5, [0], xmm0	; 8F E8 50 87 026 00 00 00
vpmacssdql xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 87 036 00 00 20

vpmacsswd xmm1, xmm4, xmm7, xmm3	; 8F E8 58 86 317 30
vpmacsswd xmm2, xmm5, [0], xmm0		; 8F E8 50 86 026 00 00 00
vpmacsswd xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 86 036 00 00 20

vpmacssww xmm1, xmm4, xmm7, xmm3	; 8F E8 58 85 317 30
vpmacssww xmm2, xmm5, [0], xmm0		; 8F E8 50 85 026 00 00 00
vpmacssww xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 85 036 00 00 20

vpmacswd xmm1, xmm4, xmm7, xmm3		; 8F E8 58 96 317 30
vpmacswd xmm2, xmm5, [0], xmm0		; 8F E8 50 96 026 00 00 00
vpmacswd xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 96 036 00 00 20

vpmacsww xmm1, xmm4, xmm7, xmm3		; 8F E8 58 95 317 30
vpmacsww xmm2, xmm5, [0], xmm0		; 8F E8 50 95 026 00 00 00
vpmacsww xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 95 036 00 00 20

vpmadcsswd xmm1, xmm4, xmm7, xmm3	; 8F E8 58 A6 317 30
vpmadcsswd xmm2, xmm5, [0], xmm0	; 8F E8 50 A6 026 00 00 00
vpmadcsswd xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 A6 036 00 00 20

vpmadcswd xmm1, xmm4, xmm7, xmm3	; 8F E8 58 B6 317 30
vpmadcswd xmm2, xmm5, [0], xmm0		; 8F E8 50 B6 026 00 00 00
vpmadcswd xmm3, xmm6, dqword [0], xmm2	; 8F E8 48 B6 036 00 00 20

vpperm xmm1, xmm2, xmm3, xmm4		; 8F E8 68 A3 313 40 /or/ 8F E8 E8 A3 314 30
vpperm xmm1, xmm2, xmm3, [0]		; 8F E8 E8 A3 016 00 00 30
vpperm xmm1, xmm2, xmm3, dqword [0]	; 8F E8 E8 A3 016 00 00 30
vpperm xmm1, xmm2, [0], xmm4		; 8F E8 68 A3 016 00 00 40
vpperm xmm1, xmm2, dqword [0], xmm4	; 8F E8 68 A3 016 00 00 40

vprotb xmm1, xmm2, xmm3			; 8F E9 60 90 312 /or/ 8F E9 E8 90 313
vprotb xmm1, xmm2, [0]			; 8F E9 E8 90 016 00 00
vprotb xmm1, xmm2, dqword [0]		; 8F E9 E8 90 016 00 00
vprotb xmm1, [0], xmm3			; 8F E9 60 90 016 00 00
vprotb xmm1, dqword [0], xmm3		; 8F E9 60 90 016 00 00
vprotb xmm1, xmm2, byte 5		; 8F E8 78 C0 312 05
vprotb xmm1, [0], byte 5		; 8F E8 78 C0 016 00 00 05
vprotb xmm1, dqword [0], 5		; 8F E8 78 C0 016 00 00 05

vprotd xmm1, xmm2, xmm3			; 8F E9 60 92 312 /or/ 8F E9 E8 92 313
vprotd xmm1, xmm2, [0]			; 8F E9 E8 92 016 00 00
vprotd xmm1, xmm2, dqword [0]		; 8F E9 E8 92 016 00 00
vprotd xmm1, [0], xmm3			; 8F E9 60 92 016 00 00
vprotd xmm1, dqword [0], xmm3		; 8F E9 60 92 016 00 00
vprotd xmm1, xmm2, byte 5		; 8F E8 78 C2 312 05
vprotd xmm1, [0], byte 5		; 8F E8 78 C2 016 00 00 05
vprotd xmm1, dqword [0], 5		; 8F E8 78 C2 016 00 00 05

vprotq xmm1, xmm2, xmm3			; 8F E9 60 93 312 /or/ 8F E9 E8 93 313
vprotq xmm1, xmm2, [0]			; 8F E9 E8 93 016 00 00
vprotq xmm1, xmm2, dqword [0]		; 8F E9 E8 93 016 00 00
vprotq xmm1, [0], xmm3			; 8F E9 60 93 016 00 00
vprotq xmm1, dqword [0], xmm3		; 8F E9 60 93 016 00 00
vprotq xmm1, xmm2, byte 5		; 8F E8 78 C3 312 05
vprotq xmm1, [0], byte 5		; 8F E8 78 C3 016 00 00 05
vprotq xmm1, dqword [0], 5		; 8F E8 78 C3 016 00 00 05

vprotw xmm1, xmm2, xmm3			; 8F E9 60 91 312 /or/ 8F E9 E8 91 313
vprotw xmm1, xmm2, [0]			; 8F E9 E8 91 016 00 00
vprotw xmm1, xmm2, dqword [0]		; 8F E9 E8 91 016 00 00
vprotw xmm1, [0], xmm3			; 8F E9 60 91 016 00 00
vprotw xmm1, dqword [0], xmm3		; 8F E9 60 91 016 00 00
vprotw xmm1, xmm2, byte 5		; 8F E8 78 C1 312 05
vprotw xmm1, [0], byte 5		; 8F E8 78 C1 016 00 00 05
vprotw xmm1, dqword [0], 5		; 8F E8 78 C1 016 00 00 05

vpshab xmm1, xmm2, xmm3			; 8F E9 60 98 312 /or/ 8F E9 E8 98 313
vpshab xmm1, xmm2, [0]			; 8F E9 E8 98 016 00 00
vpshab xmm1, xmm2, dqword [0]		; 8F E9 E8 98 016 00 00
vpshab xmm1, [0], xmm3			; 8F E9 60 98 016 00 00
vpshab xmm1, dqword [0], xmm3		; 8F E9 60 98 016 00 00

vpshad xmm1, xmm2, xmm3			; 8F E9 60 9A 312 /or/ 8F E9 E8 9A 313
vpshad xmm1, xmm2, [0]			; 8F E9 E8 9A 016 00 00
vpshad xmm1, xmm2, dqword [0]		; 8F E9 E8 9A 016 00 00
vpshad xmm1, [0], xmm3			; 8F E9 60 9A 016 00 00
vpshad xmm1, dqword [0], xmm3		; 8F E9 60 9A 016 00 00

vpshaq xmm1, xmm2, xmm3			; 8F E9 60 9B 312 /or/ 8F E9 E8 9B 313
vpshaq xmm1, xmm2, [0]			; 8F E9 E8 9B 016 00 00
vpshaq xmm1, xmm2, dqword [0]		; 8F E9 E8 9B 016 00 00
vpshaq xmm1, [0], xmm3			; 8F E9 60 9B 016 00 00
vpshaq xmm1, dqword [0], xmm3		; 8F E9 60 9B 016 00 00

vpshaw xmm1, xmm2, xmm3			; 8F E9 60 99 312 /or/ 8F E9 E8 99 313
vpshaw xmm1, xmm2, [0]			; 8F E9 E8 99 016 00 00
vpshaw xmm1, xmm2, dqword [0]		; 8F E9 E8 99 016 00 00
vpshaw xmm1, [0], xmm3			; 8F E9 60 99 016 00 00
vpshaw xmm1, dqword [0], xmm3		; 8F E9 60 99 016 00 00

vpshlb xmm1, xmm2, xmm3			; 8F E9 60 94 312 /or/ 8F E9 E8 94 313
vpshlb xmm1, xmm2, [0]			; 8F E9 E8 94 016 00 00
vpshlb xmm1, xmm2, dqword [0]		; 8F E9 E8 94 016 00 00
vpshlb xmm1, [0], xmm3			; 8F E9 60 94 016 00 00
vpshlb xmm1, dqword [0], xmm3		; 8F E9 60 94 016 00 00

vpshld xmm1, xmm2, xmm3			; 8F E9 60 96 312 /or/ 8F E9 E8 96 313
vpshld xmm1, xmm2, [0]			; 8F E9 E8 96 016 00 00
vpshld xmm1, xmm2, dqword [0]		; 8F E9 E8 96 016 00 00
vpshld xmm1, [0], xmm3			; 8F E9 60 96 016 00 00
vpshld xmm1, dqword [0], xmm3		; 8F E9 60 96 016 00 00

vpshlq xmm1, xmm2, xmm3			; 8F E9 60 97 312 /or/ 8F E9 E8 97 313
vpshlq xmm1, xmm2, [0]			; 8F E9 E8 97 016 00 00
vpshlq xmm1, xmm2, dqword [0]		; 8F E9 E8 97 016 00 00
vpshlq xmm1, [0], xmm3			; 8F E9 60 97 016 00 00
vpshlq xmm1, dqword [0], xmm3		; 8F E9 60 97 016 00 00

vpshlw xmm1, xmm2, xmm3			; 8F E9 60 95 312 /or/ 8F E9 E8 95 313
vpshlw xmm1, xmm2, [0]			; 8F E9 E8 95 016 00 00
vpshlw xmm1, xmm2, dqword [0]		; 8F E9 E8 95 016 00 00
vpshlw xmm1, [0], xmm3			; 8F E9 60 95 016 00 00
vpshlw xmm1, dqword [0], xmm3		; 8F E9 60 95 016 00 00

