; Errors caught during instruction matching

[bits 64]

vpgatherdq xmm0,xmm0,xmm0 ; no reg EA template

vpgatherdq xmm0,[ymm0],xmm0 ; not a VSIB256 template
vpgatherqq ymm0,[xmm0],ymm0 ; not a VSIB128 template

vpgatherdq xmm0,[rel 0],xmm0
vpgatherdq xmm0,[0],xmm0
vpgatherdq xmm0,[rax],xmm0
vpgatherdq xmm0,[rax+rbx],xmm0

