[bits 16]
vpcomltb xmm1, xmm2, xmm3	; 8F E8 68 CC 313 00
vpcomleb xmm1, xmm2, xmm3	; 8F E8 68 CC 313 01
vpcomgtb xmm1, xmm2, xmm3	; 8F E8 68 CC 313 02
vpcomgeb xmm1, xmm2, xmm3	; 8F E8 68 CC 313 03
vpcomeqb xmm1, xmm2, xmm3	; 8F E8 68 CC 313 04
vpcomneqb xmm1, xmm2, xmm3	; 8F E8 68 CC 313 05
vpcomneb xmm1, xmm2, xmm3	; 8F E8 68 CC 313 05
vpcomfalseb xmm1, xmm2, xmm3	; 8F E8 68 CC 313 06
vpcomtrueb xmm1, xmm2, xmm3	; 8F E8 68 CC 313 07

vpcomltuw xmm1, xmm2, xmm3	; 8F E8 68 ED 313 00
vpcomleuw xmm1, xmm2, xmm3	; 8F E8 68 ED 313 01
vpcomgtuw xmm1, xmm2, xmm3	; 8F E8 68 ED 313 02
vpcomgeuw xmm1, xmm2, xmm3	; 8F E8 68 ED 313 03
vpcomequw xmm1, xmm2, xmm3	; 8F E8 68 ED 313 04
vpcomnequw xmm1, xmm2, xmm3	; 8F E8 68 ED 313 05
vpcomneuw xmm1, xmm2, xmm3	; 8F E8 68 ED 313 05
vpcomfalseuw xmm1, xmm2, xmm3	; 8F E8 68 ED 313 06
vpcomtrueuw xmm1, xmm2, xmm3	; 8F E8 68 ED 313 07


