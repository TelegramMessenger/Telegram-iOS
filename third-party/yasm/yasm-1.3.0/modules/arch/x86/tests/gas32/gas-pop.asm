.code64
push %cx		# out: 66 51
pop %cx			# out: 66 59
push %rcx		# out: 51
pop %rcx		# out: 59
pushw %cx		# out: 66 51
popw %cx		# out: 66 59
pushq %rcx		# out: 51
popq %rcx		# out: 59

push -24(%rcx)		# out: ff 71 e8
pop -24(%rcx)		# out: 8f 41 e8
pushw -24(%rcx)		# out: 66 ff 71 e8
popw -24(%rcx)		# out: 66 8f 41 e8
pushq -24(%rcx)		# out: ff 71 e8
popq -24(%rcx)		# out: 8f 41 e8

.code32
push %cx		# out: 66 51
pop %cx			# out: 66 59
push %ecx		# out: 51
pop %ecx		# out: 59
pushw %cx		# out: 66 51
popw %cx		# out: 66 59
pushl %ecx		# out: 51
popl %ecx		# out: 59

push -24(%ecx)		# out: ff 71 e8
pop -24(%ecx)		# out: 8f 41 e8
pushw -24(%ecx)		# out: 66 ff 71 e8
popw -24(%ecx)		# out: 66 8f 41 e8
pushl -24(%ecx)		# out: ff 71 e8
popl -24(%ecx)		# out: 8f 41 e8

.code16
push %cx		# out: 51
pop %cx			# out: 59
push %ecx		# out: 66 51
pop %ecx		# out: 66 59
pushw %cx		# out: 51
popw %cx		# out: 59
pushl %ecx		# out: 66 51
popl %ecx		# out: 66 59

push -24(%bp)		# out: ff 76 e8
pop -24(%bp)		# out: 8f 46 e8
pushw -24(%bp)		# out: ff 76 e8
popw -24(%bp)		# out: 8f 46 e8
pushl -24(%bp)		# out: 66 ff 76 e8
popl -24(%bp)		# out: 66 8f 46 e8
