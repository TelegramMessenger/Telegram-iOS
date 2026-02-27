[bits 16]
lar ax, bx
lar ax, [bx]
lar ax, word [bx]
lar eax, bx
lar eax, ebx
lar eax, [bx]
lar eax, word [bx]

lsl ax, bx
lsl ax, [bx]
lsl ax, word [bx]
lsl eax, bx
lsl eax, ebx
lsl eax, [bx]
lsl eax, word [bx]

[bits 32]
lar ax, bx
lar ax, [ebx]
lar ax, word [ebx]
lar eax, bx
lar eax, ebx
lar eax, [ebx]
lar eax, word [ebx]

lsl ax, bx
lsl ax, [ebx]
lsl ax, word [ebx]
lsl eax, bx
lsl eax, ebx
lsl eax, [ebx]
lsl eax, word [ebx]

[bits 64]
lar ax, bx
lar ax, [rbx]
lar ax, word [rbx]
lar eax, bx
lar eax, ebx
lar eax, [rbx]
lar eax, word [rbx]
lar rax, bx
lar rax, ebx
lar rax, [rbx]
lar rax, word [rbx]

lsl ax, bx
lsl ax, [rbx]
lsl ax, word [rbx]
lsl eax, bx
lsl eax, ebx
lsl eax, [rbx]
lsl eax, word [rbx]
lsl rax, bx
lsl rax, ebx
lsl rax, [rbx]
lsl rax, word [rbx]

