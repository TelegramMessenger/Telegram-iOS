[bits 64]
andn eax, ebx, ecx	; c4 e2 60 f2 c1
andn eax, ebx, [0]	; c4 e2 60 f2 04 25 00 00 00 00
andn rax, rbx, rcx	; c4 e2 e0 f2 c1
andn rax, rbx, [0]	; c4 e2 e0 f2 04 25 00 00 00 00

bextr eax, ebx, ecx	; c4 e2 70 f7 c3
bextr eax, [0], ecx	; c4 e2 70 f7 04 25 00 00 00 00
bextr rax, rbx, rcx	; c4 e2 f0 f7 c3
bextr rax, [0], rcx	; c4 e2 f0 f7 04 25 00 00 00 00

blsi eax, ecx		; c4 e2 78 f3 d9
blsi eax, [0]		; c4 e2 78 f3 1c 25 00 00 00 00
blsi rax, rcx		; c4 e2 f8 f3 d9
blsi rax, [0]		; c4 e2 f8 f3 1c 25 00 00 00 00

blsmsk eax, ecx		; c4 e2 78 f3 d1
blsmsk eax, [0]		; c4 e2 78 f3 14 25 00 00 00 00
blsmsk rax, rcx		; c4 e2 f8 f3 d1
blsmsk rax, [0]		; c4 e2 f8 f3 14 25 00 00 00 00

blsr eax, ecx		; c4 e2 78 f3 c9
blsr eax, [0]		; c4 e2 78 f3 0c 25 00 00 00 00
blsr rax, rcx		; c4 e2 f8 f3 c9
blsr rax, [0]		; c4 e2 f8 f3 0c 25 00 00 00 00

tzcnt ax, bx		; 66 f3 0f bc c3
tzcnt ax, [0]		; 66 f3 0f bc 04 25 00 00 00 00
tzcnt eax, ebx		; f3 0f bc c3
tzcnt eax, [0]		; f3 0f bc 04 25 00 00 00 00
tzcnt rax, rbx		; f3 48 0f bc c3
tzcnt rax, [0]		; f3 48 0f bc 04 25 00 00 00 00
