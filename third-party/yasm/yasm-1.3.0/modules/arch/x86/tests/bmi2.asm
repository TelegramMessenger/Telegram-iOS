[bits 64]
bzhi eax, ebx, ecx	; c4 e2 70 f5 c3
bzhi eax, [0], ecx	; c4 e2 70 f5 04 25 00 00 00 00
bzhi rax, rbx, rcx	; c4 e2 f0 f5 c3
bzhi rax, [0], rcx	; c4 e2 f0 f5 04 25 00 00 00 00

mulx eax, ebx, ecx	; c4 e2 63 f6 c1
mulx eax, ebx, [0]	; c4 e2 63 f6 04 25 00 00 00 00
mulx rax, rbx, rcx	; c4 e2 e3 f6 c1
mulx rax, rbx, [0]	; c4 e2 e3 f6 04 25 00 00 00 00

pdep eax, ebx, ecx	; c4 e2 63 f5 c1
pdep eax, ebx, [0]	; c4 e2 63 f5 04 25 00 00 00 00
pdep rax, rbx, rcx	; c4 e2 e3 f5 c1
pdep rax, rbx, [0]	; c4 e2 e3 f5 04 25 00 00 00 00

pext eax, ebx, ecx	; c4 e2 62 f5 c1
pext eax, ebx, [0]	; c4 e2 62 f5 04 25 00 00 00 00
pext rax, rbx, rcx	; c4 e2 e2 f5 c1
pext rax, rbx, [0]	; c4 e2 e2 f5 04 25 00 00 00 00

rorx eax, ebx, 3	; c4 e3 7b f0 c3 03
rorx eax, [0], 3	; c4 e3 7b f0 04 25 00 00 00 00 03
rorx rax, rbx, 3	; c4 e3 fb f0 c3 03
rorx rax, [0], 3	; c4 e3 fb f0 04 25 00 00 00 00 03

sarx eax, ebx, ecx	; c4 e2 72 f7 c3
sarx eax, [0], ecx	; c4 e2 72 f7 04 25 00 00 00 00
sarx rax, rbx, rcx	; c4 e2 f2 f7 c3
sarx rax, [0], rcx	; c4 e2 f2 f7 04 25 00 00 00 00

shlx eax, ebx, ecx	; c4 e2 71 f7 c3
shlx eax, [0], ecx	; c4 e2 71 f7 04 25 00 00 00 00
shlx rax, rbx, rcx	; c4 e2 f1 f7 c3
shlx rax, [0], rcx	; c4 e2 f1 f7 04 25 00 00 00 00

shrx eax, ebx, ecx	; c4 e2 73 f7 c3
shrx eax, [0], ecx	; c4 e2 73 f7 04 25 00 00 00 00
shrx rax, rbx, rcx	; c4 e2 f3 f7 c3
shrx rax, [0], rcx	; c4 e2 f3 f7 04 25 00 00 00 00
