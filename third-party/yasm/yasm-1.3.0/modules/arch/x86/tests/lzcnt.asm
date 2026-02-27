[bits 64]

lzcnt ax, bx	; 66 f3 0f bd c3
lzcnt ax, [0]	; 66 f3 0f bd 04 25 00 00 00 00
lzcnt eax, ebx	; f3 0f bd c3
lzcnt eax, [0]	; f3 0f bd 04 25 00 00 00 00
lzcnt rax, rbx	; f3 48 0f bd c3
lzcnt rax, [0]	; f3 48 0f bd 04 25 00 00 00 00
