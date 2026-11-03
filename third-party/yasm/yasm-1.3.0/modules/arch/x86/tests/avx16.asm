[bits 16]
extractps eax, xmm1, 5
vextractps eax, xmm1, 5
pextrb eax, xmm1, 5
vpextrb eax, xmm1, 5
pextrw eax, xmm1, 5
vpextrw eax, xmm1, 5
pextrd eax, xmm1, 5
vpextrd eax, xmm1, 5
vpinsrd xmm1, xmm2, eax, 5
