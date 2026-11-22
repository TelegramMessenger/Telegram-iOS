[bits 64]
vfmaddpd xmm0, xmm1, xmm2, xmm3
vfmaddpd xmm0, xmm1, [rax], xmm3
vfmaddpd xmm0, xmm1, dqword [rax], xmm3
vfmaddpd xmm0, xmm1, xmm2, [rax]
vfmaddpd xmm0, xmm1, xmm2, dqword [rax]
vfmaddpd ymm0, ymm1, ymm2, ymm3
vfmaddpd ymm0, ymm1, [rax], ymm3
vfmaddpd ymm0, ymm1, yword [rax], ymm3
vfmaddpd ymm0, ymm1, ymm2, [rax]
vfmaddpd ymm0, ymm1, ymm2, yword [rax]

vfmaddps xmm0, xmm1, xmm2, xmm3
vfmaddps xmm0, xmm1, dqword [rax], xmm3
vfmaddps xmm0, xmm1, xmm2, dqword [rax]
vfmaddps ymm0, ymm1, ymm2, ymm3
vfmaddps ymm0, ymm1, yword [rax], ymm3
vfmaddps ymm0, ymm1, ymm2, yword [rax]

vfmaddsd xmm0, xmm1, xmm2, xmm3
vfmaddsd xmm0, xmm1, [rax], xmm3
vfmaddsd xmm0, xmm1, qword [rax], xmm3
vfmaddsd xmm0, xmm1, xmm2, [rax]
vfmaddsd xmm0, xmm1, xmm2, qword [rax]

vfmaddss xmm0, xmm1, xmm2, xmm3
vfmaddss xmm0, xmm1, dword [rax], xmm3
vfmaddss xmm0, xmm1, xmm2, dword [rax]

vfmaddsubpd xmm0, xmm1, xmm2, xmm3
vfmaddsubpd xmm0, xmm1, dqword [rax], xmm3
vfmaddsubpd xmm0, xmm1, xmm2, dqword [rax]
vfmaddsubpd ymm0, ymm1, ymm2, ymm3
vfmaddsubpd ymm0, ymm1, yword [rax], ymm3
vfmaddsubpd ymm0, ymm1, ymm2, yword [rax]

vfmaddsubps xmm0, xmm1, xmm2, xmm3
vfmaddsubps xmm0, xmm1, dqword [rax], xmm3
vfmaddsubps xmm0, xmm1, xmm2, dqword [rax]
vfmaddsubps ymm0, ymm1, ymm2, ymm3
vfmaddsubps ymm0, ymm1, yword [rax], ymm3
vfmaddsubps ymm0, ymm1, ymm2, yword [rax]

vfmsubpd xmm0, xmm1, xmm2, xmm3
vfmsubpd xmm0, xmm1, dqword [rax], xmm3
vfmsubpd xmm0, xmm1, xmm2, dqword [rax]
vfmsubpd ymm0, ymm1, ymm2, ymm3
vfmsubpd ymm0, ymm1, yword [rax], ymm3
vfmsubpd ymm0, ymm1, ymm2, yword [rax]

vfmsubps xmm0, xmm1, xmm2, xmm3
vfmsubps xmm0, xmm1, dqword [rax], xmm3
vfmsubps xmm0, xmm1, xmm2, dqword [rax]
vfmsubps ymm0, ymm1, ymm2, ymm3
vfmsubps ymm0, ymm1, yword [rax], ymm3
vfmsubps ymm0, ymm1, ymm2, yword [rax]

vfmsubsd xmm0, xmm1, xmm2, xmm3
vfmsubsd xmm0, xmm1, qword [rax], xmm3
vfmsubsd xmm0, xmm1, xmm2, qword [rax]

vfmsubss xmm0, xmm1, xmm2, xmm3
vfmsubss xmm0, xmm1, dword [rax], xmm3
vfmsubss xmm0, xmm1, xmm2, dword [rax]

vfnmaddpd xmm0, xmm1, xmm2, xmm3
vfnmaddpd xmm0, xmm1, dqword [rax], xmm3
vfnmaddpd xmm0, xmm1, xmm2, dqword [rax]
vfnmaddpd ymm0, ymm1, ymm2, ymm3
vfnmaddpd ymm0, ymm1, yword [rax], ymm3
vfnmaddpd ymm0, ymm1, ymm2, yword [rax]

vfnmaddps xmm0, xmm1, xmm2, xmm3
vfnmaddps xmm0, xmm1, dqword [rax], xmm3
vfnmaddps xmm0, xmm1, xmm2, dqword [rax]
vfnmaddps ymm0, ymm1, ymm2, ymm3
vfnmaddps ymm0, ymm1, yword [rax], ymm3
vfnmaddps ymm0, ymm1, ymm2, yword [rax]

vfnmaddsd xmm0, xmm1, xmm2, xmm3
vfnmaddsd xmm0, xmm1, qword [rax], xmm3
vfnmaddsd xmm0, xmm1, xmm2, qword [rax]

vfnmaddss xmm0, xmm1, xmm2, xmm3
vfnmaddss xmm0, xmm1, dword [rax], xmm3
vfnmaddss xmm0, xmm1, xmm2, dword [rax]

vfnmsubpd xmm0, xmm1, xmm2, xmm3
vfnmsubpd xmm0, xmm1, dqword [rax], xmm3
vfnmsubpd xmm0, xmm1, xmm2, dqword [rax]
vfnmsubpd ymm0, ymm1, ymm2, ymm3
vfnmsubpd ymm0, ymm1, yword [rax], ymm3
vfnmsubpd ymm0, ymm1, ymm2, yword [rax]

vfnmsubps xmm0, xmm1, xmm2, xmm3
vfnmsubps xmm0, xmm1, dqword [rax], xmm3
vfnmsubps xmm0, xmm1, xmm2, dqword [rax]
vfnmsubps ymm0, ymm1, ymm2, ymm3
vfnmsubps ymm0, ymm1, yword [rax], ymm3
vfnmsubps ymm0, ymm1, ymm2, yword [rax]

vfnmsubsd xmm0, xmm1, xmm2, xmm3
vfnmsubsd xmm0, xmm1, qword [rax], xmm3
vfnmsubsd xmm0, xmm1, xmm2, qword [rax]

vfnmsubss xmm0, xmm1, xmm2, xmm3
vfnmsubss xmm0, xmm1, dword [rax], xmm3
vfnmsubss xmm0, xmm1, xmm2, dword [rax]

