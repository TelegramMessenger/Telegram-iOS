[bits 64]
vcvtph2ps ymm1, xmm2
vcvtph2ps ymm1, oword [0]
vcvtph2ps xmm1, xmm2
vcvtph2ps xmm1, qword [0]

vcvtps2ph xmm1, ymm2, 4
vcvtps2ph oword [0], ymm2, 8
vcvtps2ph xmm1, xmm2, 3
vcvtps2ph qword [0], xmm2, 5
