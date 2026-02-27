[bits 16]
; test promotion to 32-bit address size
vpgatherdq xmm0,[xmm0],xmm0		; 67 c4 e2 f9 90 04 05 00 00 00 00
vpgatherqq ymm0,[ymm0],ymm0		; 67 c4 e2 fd 91 04 05 00 00 00 00

[bits 32]
; test promotion from base to index
vpgatherdq xmm0,[xmm0],xmm0		; c4 e2 f9 90 04 05 00 00 00 00
vpgatherqq ymm0,[ymm0],ymm0		; c4 e2 fd 91 04 05 00 00 00 00

; various combinations
vpgatherdq xmm0,[ecx+xmm5],xmm0		; c4 e2 f9 90 04 29
vpgatherqq ymm0,[ecx+ymm5],ymm0		; c4 e2 fd 91 04 29
vpgatherdq xmm0,[ebp+xmm5],xmm0		; c4 e2 f9 90 44 2d 00
vpgatherqq ymm0,[ebp+ymm5],ymm0		; c4 e2 fd 91 44 2d 00
 
vpgatherdq xmm0,[xmm5+ecx],xmm0		; c4 e2 f9 90 04 29
vpgatherqq ymm0,[ymm5+ecx],ymm0		; c4 e2 fd 91 04 29
vpgatherdq xmm0,[xmm5+ebp],xmm0		; c4 e2 f9 90 44 2d 00
vpgatherqq ymm0,[ymm5+ebp],ymm0		; c4 e2 fd 91 44 2d 00

vpgatherdq xmm0,[ecx+xmm5*1],xmm0	; c4 e2 f9 90 04 29
vpgatherqq ymm0,[ecx+ymm5*1],ymm0	; c4 e2 fd 91 04 29
vpgatherdq xmm0,[ebp+xmm5*1],xmm0	; c4 e2 f9 90 44 2d 00
vpgatherqq ymm0,[ebp+ymm5*1],ymm0	; c4 e2 fd 91 44 2d 00

vpgatherdq xmm0,[xmm5+ecx*1],xmm0	; c4 e2 f9 90 04 29
vpgatherqq ymm0,[ymm5+ecx*1],ymm0	; c4 e2 fd 91 04 29
vpgatherdq xmm0,[xmm5+ebp*1],xmm0	; c4 e2 f9 90 44 2d 00
vpgatherqq ymm0,[ymm5+ebp*1],ymm0	; c4 e2 fd 91 44 2d 00

vpgatherdq xmm0,[nosplit 12345678h + xmm5*1],xmm0; c4 e2 f9 90 04 2d 78 56 34 12
vpgatherqq ymm0,[nosplit 12345678h + ymm5*1],ymm0; c4 e2 fd 91 04 2d 78 56 34 12

vpgatherdq xmm0,[byte ecx + 12 + xmm5*2],xmm0	; c4 e2 f9 90 44 69 0c
vpgatherqq ymm0,[byte ecx + 12 + ymm5*2],ymm0	; c4 e2 fd 91 44 69 0c
vpgatherdq xmm0,[byte ebp + 12 + xmm5*2],xmm0	; c4 e2 f9 90 44 6d 0c
vpgatherqq ymm0,[byte ebp + 12 + ymm5*2],ymm0	; c4 e2 fd 91 44 6d 0c

vpgatherdq xmm0,[dword ecx + 12 + xmm5*4],xmm0	; c4 e2 f9 90 84 a9 0c 00 00 00
vpgatherqq ymm0,[dword ecx + 12 + ymm5*4],ymm0	; c4 e2 fd 91 84 a9 0c 00 00 00
vpgatherdq xmm0,[dword ebp + 12 + xmm5*4],xmm0	; c4 e2 f9 90 84 ad 0c 00 00 00
vpgatherqq ymm0,[dword ebp + 12 + ymm5*4],ymm0	; c4 e2 fd 91 84 ad 0c 00 00 00

vpgatherdq xmm0,[ecx + 12345678h + xmm5*4],xmm0	; c4 e2 f9 90 84 a9 78 56 34 12
vpgatherqq ymm0,[ecx + 12345678h + ymm5*4],ymm0	; c4 e2 fd 91 84 a9 78 56 34 12
vpgatherdq xmm0,[ebp + 12345678h + xmm5*4],xmm0	; c4 e2 f9 90 84 ad 78 56 34 12
vpgatherqq ymm0,[ebp + 12345678h + ymm5*4],ymm0	; c4 e2 fd 91 84 ad 78 56 34 12

vpgatherdq xmm0,[ecx + 12 + xmm5*4],xmm0	; c4 e2 f9 90 44 a9 0c
vpgatherqq ymm0,[ecx + 12 + ymm5*4],ymm0	; c4 e2 fd 91 44 a9 0c
vpgatherdq xmm0,[ebp + 12 + xmm5*4],xmm0	; c4 e2 f9 90 44 ad 0c
vpgatherqq ymm0,[ebp + 12 + ymm5*4],ymm0	; c4 e2 fd 91 44 ad 0c

vpgatherdq xmm0,[dword 12 + xmm5*8],xmm0	; c4 e2 f9 90 04 ed 0c 00 00 00
vpgatherqq ymm0,[dword 12 + ymm5*8],ymm0	; c4 e2 fd 91 04 ed 0c 00 00 00
vpgatherdq xmm0,[12 + xmm5*8],xmm0		; c4 e2 f9 90 04 ed 0c 00 00 00
vpgatherqq ymm0,[12 + ymm5*8],ymm0		; c4 e2 fd 91 04 ed 0c 00 00 00

[bits 64]
; test promotion from base to index
vpgatherdq xmm0,[xmm0],xmm0		; c4 e2 f9 90 04 05 00 00 00 00
vpgatherqq ymm0,[ymm0],ymm0		; c4 e2 fd 91 04 05 00 00 00 00

; various combinations
vpgatherdq xmm0,[rcx+xmm5],xmm0		; c4 e2 f9 90 04 29
vpgatherqq ymm0,[rcx+ymm13],ymm0	; c4 a2 fd 91 04 29
vpgatherdq xmm0,[r13+xmm13],xmm0	; c4 82 f9 90 44 2d 00
vpgatherqq ymm0,[r13+ymm5],ymm0		; c4 c2 fd 91 44 2d 00
 
vpgatherdq xmm0,[xmm5+rcx],xmm0		; c4 e2 f9 90 04 29
vpgatherqq ymm0,[ymm13+rcx],ymm0	; c4 a2 fd 91 04 29
vpgatherdq xmm0,[xmm13+r13],xmm0	; c4 82 f9 90 44 2d 00
vpgatherqq ymm0,[ymm5+r13],ymm0		; c4 c2 fd 91 44 2d 00

vpgatherdq xmm0,[rcx+xmm5*1],xmm0	; c4 e2 f9 90 04 29
vpgatherqq ymm0,[rcx+ymm13*1],ymm0	; c4 a2 fd 91 04 29
vpgatherdq xmm0,[r13+xmm13*1],xmm0	; c4 82 f9 90 44 2d 00
vpgatherqq ymm0,[r13+ymm5*1],ymm0	; c4 c2 fd 91 44 2d 00

vpgatherdq xmm0,[xmm5+rcx*1],xmm0	; c4 e2 f9 90 04 29
vpgatherqq ymm0,[ymm13+rcx*1],ymm0	; c4 a2 fd 91 04 29
vpgatherdq xmm0,[xmm13+r13*1],xmm0	; c4 82 f9 90 44 2d 00
vpgatherqq ymm0,[ymm5+r13*1],ymm0	; c4 c2 fd 91 44 2d 00

vpgatherdq xmm0,[nosplit 12345678h + xmm5*1],xmm0; c4 e2 f9 90 04 2d 78 56 34 12
vpgatherqq ymm0,[nosplit 12345678h + ymm5*1],ymm0; c4 e2 fd 91 04 2d 78 56 34 12

vpgatherdq xmm0,[byte rcx + 12 + xmm5*2],xmm0	; c4 e2 f9 90 44 69 0c
vpgatherqq ymm0,[byte rcx + 12 + ymm13*2],ymm0	; c4 a2 fd 91 44 69 0c
vpgatherdq xmm0,[byte r13 + 12 + xmm13*2],xmm0	; c4 82 f9 90 44 6d 0c
vpgatherqq ymm0,[byte r13 + 12 + ymm5*2],ymm0	; c4 c2 fd 91 44 6d 0c

vpgatherdq xmm0,[dword rcx + 12 + xmm5*4],xmm0	; c4 e2 f9 90 84 a9 0c 00 00 00
vpgatherqq ymm0,[dword rcx + 12 + ymm13*4],ymm0	; c4 a2 fd 91 84 a9 0c 00 00 00
vpgatherdq xmm0,[dword r13 + 12 + xmm13*4],xmm0	; c4 82 f9 90 84 ad 0c 00 00 00
vpgatherqq ymm0,[dword r13 + 12 + ymm5*4],ymm0	; c4 c2 fd 91 84 ad 0c 00 00 00

vpgatherdq xmm0,[rcx + 12345678h + xmm5*4],xmm0	; c4 e2 f9 90 84 a9 78 56 34 12
vpgatherqq ymm0,[rcx + 12345678h + ymm13*4],ymm0; c4 a2 fd 91 84 a9 78 56 34 12
vpgatherdq xmm0,[r13 + 12345678h + xmm13*4],xmm0; c4 82 f9 90 84 ad 78 56 34 12
vpgatherqq ymm0,[r13 + 12345678h + ymm5*4],ymm0	; c4 c2 fd 91 84 ad 78 56 34 12

vpgatherdq xmm0,[rcx + 12 + xmm5*4],xmm0	; c4 e2 f9 90 44 a9 0c
vpgatherqq ymm0,[rcx + 12 + ymm13*4],ymm0	; c4 a2 fd 91 44 a9 0c
vpgatherdq xmm0,[r13 + 12 + xmm13*4],xmm0	; c4 82 f9 90 44 ad 0c
vpgatherqq ymm0,[r13 + 12 + ymm5*4],ymm0	; c4 c2 fd 91 44 ad 0c

vpgatherdq xmm0,[dword 12 + xmm5*8],xmm0	; c4 e2 f9 90 04 ed 0c 00 00 00
vpgatherqq ymm0,[dword 12 + ymm13*8],ymm0	; c4 a2 fd 91 04 ed 0c 00 00 00
vpgatherdq xmm0,[12 + xmm13*8],xmm0		; c4 a2 f9 90 04 ed 0c 00 00 00
vpgatherqq ymm0,[12 + ymm5*8],ymm0		; c4 e2 fd 91 04 ed 0c 00 00 00


