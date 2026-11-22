call $0x1234, $0x567890ab
lcall $0x1234, $0x567890ab
jmp $0x1234, $0x567890ab
ljmp $0x1234, $0x567890ab
ljmp *(%eax)
lcall *(%eax)
jmp *(%eax)
call *(%eax)
jmp *%eax
call *%eax
ret
lret
lret $0x100
