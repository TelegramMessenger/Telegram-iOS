; Errors caught during EA checking

[bits 32]
vpgatherqq ymm0,[ymm0+ecx*2],ymm0

[bits 64]
addpd xmm0,[xmm0] ; not a VSIB128 template
addpd xmm0,[ymm0] ; not a VSIB256 template

[bits 32]
vpgatherdq xmm0,[bp+xmm0],xmm0

vpgatherdq xmm0,[xmm0+ymm0],xmm0

vpgatherqq ymm0,[word ymm0],ymm0

vpgatherqq ymm0,[byte ymm0],ymm0


