#import <NumberPluralizationForm/NumberPluralizationForm.h>

NumberPluralizationForm numberPluralizationForm(unsigned int lc, int n) {
    switch (lc) {
            
            // set1
        case 0x6c74: // lt
            if (((n % 10) == 1) && (((n % 100) < 11 || (n % 100) > 19))) // n mod 10 is 1 and n mod 100 not in 11..19
                return NumberPluralizationFormOne;
            if ((((n % 10) >= 2 && (n % 10) <= 9)) && (((n % 100) < 11 || (n % 100) > 19))) // n mod 10 in 2..9 and n mod 100 not in 11..19
                return NumberPluralizationFormFew;
            break;
            
            // set2
        case 0x6c76: // lv
            if (n == 0) // n is 0
                return NumberPluralizationFormZero;
            if (((n % 10) == 1) && ((n % 100) != 11)) // n mod 10 is 1 and n mod 100 is not 11
                return NumberPluralizationFormOne;
            break;
            
            // set3
        case 0x6379: // cy
            if (n == 2) // n is 2
                return NumberPluralizationFormTwo;
            if (n == 3) // n is 3
                return NumberPluralizationFormFew;
            if (n == 0) // n is 0
                return NumberPluralizationFormZero;
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            if (n == 6) // n is 6
                return NumberPluralizationFormMany;
            break;
            
            // set4
        case 0x6265: // be
        case 0x7275: // ru
        case 0x756b: // uk
            if (((n % 10) == 1) && ((n % 100) != 11)) // n mod 10 is 1 and n mod 100 is not 11
                return NumberPluralizationFormOne;
            if ((((n % 10) >= 2 && (n % 10) <= 4)) && (((n % 100) < 12 || (n % 100) > 14))) // n mod 10 in 2..4 and n mod 100 not in 12..14
                return NumberPluralizationFormFew;
            if (((n % 10) == 0) || (((n % 10) >= 5 && (n % 10) <= 9)) || (((n % 100) >= 11 && (n % 100) <= 14))) // n mod 10 is 0 or n mod 10 in 5..9 or n mod 100 in 11..14
                return NumberPluralizationFormMany;
            break;
        
            // set4 - bugfix
        case 0x6273: // bs
        case 0x6872: // hr
        case 0x7368: // sh
        case 0x7372: // sr
            if (((n % 10) == 1) && ((n % 100) != 11)) // n mod 10 is 1 and n mod 100 is not 11
                return NumberPluralizationFormOne;
            if ((((n % 10) >= 2 && (n % 10) <= 4)) && (((n % 100) < 12 || (n % 100) > 14))) // n mod 10 in 2..4 and n mod 100 not in 12..14
                return NumberPluralizationFormFew;
            if (((n % 10) == 0) || (((n % 10) >= 5 && (n % 10) <= 9)) || (((n % 100) >= 11 && (n % 100) <= 14))) // n mod 10 is 0 or n mod 10 in 5..9 or n mod 100 in 11..14
                return NumberPluralizationFormOther;
            break;
            
            // set5
        case 0x6b7368: // ksh
            if (n == 0) // n is 0
                return NumberPluralizationFormZero;
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            break;
            
            // set6
        case 0x736869: // shi
            if ((n >= 2 && n <= 10)) // n in 2..10
                return NumberPluralizationFormFew;
            if ((n >= 0 && n <= 1)) // n within 0..1
                return NumberPluralizationFormOne;
            break;
            
            // set7
        case 0x6865: // he
            if (n == 2) // n is 2
                return NumberPluralizationFormTwo;
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            if ((n != 0) && ((n % 10) == 0)) // n is not 0 AND n mod 10 is 0
                return NumberPluralizationFormMany;
            break;
            
            // set8
        case 0x6373: // cs
        case 0x736b: // sk
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            if ((n >= 2 && n <= 4)) // n in 2..4
                return NumberPluralizationFormFew;
            break;
            
            // set9
        case 0x6272: // br
            if ((n != 0) && ((n % 1000000) == 0)) // n is not 0 and n mod 1000000 is 0
                return NumberPluralizationFormMany;
            if (((n % 10) == 1) && (((n % 100) != 11) && ((n % 100) != 71) && ((n % 100) != 91))) // n mod 10 is 1 and n mod 100 not in 11,71,91
                return NumberPluralizationFormOne;
            if (((n % 10) == 2) && (((n % 100) != 12) && ((n % 100) != 72) && ((n % 100) != 92))) // n mod 10 is 2 and n mod 100 not in 12,72,92
                return NumberPluralizationFormTwo;
            if ((((n % 10) >= 3 && (n % 10) <= 4) || ((n % 10) == 9)) && (((n % 100) < 10 || (n % 100) > 19) && ((n % 100) < 70 || (n % 100) > 79) && ((n % 100) < 90 || (n % 100) > 99))) // n mod 10 in 3..4,9 and n mod 100 not in 10..19,70..79,90..99
                return NumberPluralizationFormFew;
            break;
            
            // set10
        case 0x736c: // sl
            if ((n % 100) == 2) // n mod 100 is 2
                return NumberPluralizationFormTwo;
            if ((n % 100) == 1) // n mod 100 is 1
                return NumberPluralizationFormOne;
            if (((n % 100) >= 3 && (n % 100) <= 4)) // n mod 100 in 3..4
                return NumberPluralizationFormFew;
            break;
            
            // set11
        case 0x6c6167: // lag
            if (n == 0) // n is 0
                return NumberPluralizationFormZero;
            if (((n >= 0 && n <= 2)) && (n != 0) && (n != 2)) // n within 0..2 and n is not 0 and n is not 2
                return NumberPluralizationFormOne;
            break;
            
            // set12
        case 0x706c: // pl
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            if ((((n % 10) >= 2 && (n % 10) <= 4)) && (((n % 100) < 12 || (n % 100) > 14))) // n mod 10 in 2..4 and n mod 100 not in 12..14
                return NumberPluralizationFormFew;
            if (((n != 1) && (((n % 10) >= 0 && (n % 10) <= 1))) || (((n % 10) >= 5 && (n % 10) <= 9)) || (((n % 100) >= 12 && (n % 100) <= 14))) // n is not 1 and n mod 10 in 0..1 or n mod 10 in 5..9 or n mod 100 in 12..14
                return NumberPluralizationFormMany;
            break;
            
            // set13
        case 0x6764: // gd
            if ((n == 2) || (n == 12)) // n in 2,12
                return NumberPluralizationFormTwo;
            if ((n == 1) || (n == 11)) // n in 1,11
                return NumberPluralizationFormOne;
            if ((n >= 3 && n <= 10) || (n >= 13 && n <= 19)) // n in 3..10,13..19
                return NumberPluralizationFormFew;
            break;
            
            // set14
        case 0x6776: // gv
            if ((((n % 10) >= 1 && (n % 10) <= 2)) || ((n % 20) == 0)) // n mod 10 in 1..2 or n mod 20 is 0
                return NumberPluralizationFormOne;
            break;
            
            // set15
        case 0x6d6b: // mk
            if (((n % 10) == 1) && (n != 11)) // n mod 10 is 1 and n is not 11
                return NumberPluralizationFormOne;
            break;
            
            // set16
        case 0x6d74: // mt
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            if (((n % 100) >= 11 && (n % 100) <= 19)) // n mod 100 in 11..19
                return NumberPluralizationFormMany;
            if ((n == 0) || (((n % 100) >= 2 && (n % 100) <= 10))) // n is 0 or n mod 100 in 2..10
                return NumberPluralizationFormFew;
            break;
            
            // set17
        case 0x6d6f: // mo
        case 0x726f: // ro
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            if ((n == 0) || ((n != 1) && (((n % 100) >= 1 && (n % 100) <= 19)))) // n is 0 OR n is not 1 AND n mod 100 in 1..19
                return NumberPluralizationFormFew;
            break;
            
            // set18
        case 0x6761: // ga
            if (n == 2) // n is 2
                return NumberPluralizationFormTwo;
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            if ((n >= 3 && n <= 6)) // n in 3..6
                return NumberPluralizationFormFew;
            if ((n >= 7 && n <= 10)) // n in 7..10
                return NumberPluralizationFormMany;
            break;
            
            // set19
        case 0x6666: // ff
        case 0x6672: // fr
        case 0x6b6162: // kab
            if (((n >= 0 && n <= 2)) && (n != 2)) // n within 0..2 and n is not 2
                return NumberPluralizationFormOne;
            break;
            
            // set20
        case 0x6975: // iu
        case 0x6b77: // kw
        case 0x7365: // se
        case 0x6e6171: // naq
        case 0x736d61: // sma
        case 0x736d69: // smi
        case 0x736d6a: // smj
        case 0x736d6e: // smn
        case 0x736d73: // sms
            if (n == 2) // n is 2
                return NumberPluralizationFormTwo;
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            break;
            
            // set21
        case 0x616b: // ak
        case 0x616d: // am
        case 0x6268: // bh
        case 0x6869: // hi
        case 0x6c6e: // ln
        case 0x6d67: // mg
        case 0x7469: // ti
        case 0x746c: // tl
        case 0x7761: // wa
        case 0x66696c: // fil
        case 0x677577: // guw
        case 0x6e736f: // nso
            if ((n >= 0 && n <= 1)) // n in 0..1
                return NumberPluralizationFormOne;
            break;
            
            // set22
        case 0x747a6d: // tzm
            if (((n >= 0 && n <= 1)) || ((n >= 11 && n <= 99))) // n in 0..1 or n in 11..99
                return NumberPluralizationFormOne;
            break;
            
            // set23
        case 0x6166: // af
        case 0x6267: // bg
        case 0x626e: // bn
        case 0x6361: // ca
        case 0x6461: // da
        case 0x6465: // de
        case 0x6476: // dv
        case 0x6565: // ee
        case 0x656c: // el
        case 0x656e: // en
        case 0x656f: // eo
        case 0x6573: // es
        case 0x6574: // et
        case 0x6575: // eu
        case 0x6669: // fi
        case 0x666f: // fo
        case 0x6679: // fy
        case 0x676c: // gl
        case 0x6775: // gu
        case 0x6861: // ha
        case 0x6973: // is
        case 0x6974: // it
        case 0x6b6b: // kk
        case 0x6b6c: // kl
        case 0x6b73: // ks
        case 0x6b75: // ku
        case 0x6b79: // ky
        case 0x6c62: // lb
        case 0x6c67: // lg
        case 0x6d6c: // ml
        case 0x6d6e: // mn
        case 0x6d72: // mr
        case 0x6e62: // nb
        case 0x6e64: // nd
        case 0x6e65: // ne
        case 0x6e6c: // nl
        case 0x6e6e: // nn
        case 0x6e6f: // no
        case 0x6e72: // nr
        case 0x6e79: // ny
        case 0x6f6d: // om
        case 0x6f72: // or
        case 0x6f73: // os
        case 0x7061: // pa
        case 0x7073: // ps
        case 0x7074: // pt
        case 0x726d: // rm
        case 0x736e: // sn
        case 0x736f: // so
        case 0x7371: // sq
        case 0x7373: // ss
        case 0x7374: // st
        case 0x7376: // sv
        case 0x7377: // sw
        case 0x7461: // ta
        case 0x7465: // te
        case 0x746b: // tk
        case 0x746e: // tn
        case 0x7473: // ts
        case 0x7572: // ur
        case 0x7665: // ve
        case 0x766f: // vo
        case 0x7868: // xh
        case 0x7a75: // zu
        case 0x617361: // asa
        case 0x617374: // ast
        case 0x62656d: // bem
        case 0x62657a: // bez
        case 0x627278: // brx
        case 0x636767: // cgg
        case 0x636872: // chr
        case 0x636b62: // ckb
        case 0x667572: // fur
        case 0x677377: // gsw
        case 0x686177: // haw
        case 0x6a676f: // jgo
        case 0x6a6d63: // jmc
        case 0x6b616a: // kaj
        case 0x6b6367: // kcg
        case 0x6b6b6a: // kkj
        case 0x6b7362: // ksb
        case 0x6d6173: // mas
        case 0x6d676f: // mgo
        case 0x6e6168: // nah
        case 0x6e6e68: // nnh
        case 0x6e796e: // nyn
        case 0x706170: // pap
        case 0x726f66: // rof
        case 0x72776b: // rwk
        case 0x736171: // saq
        case 0x736568: // seh
        case 0x737379: // ssy
        case 0x737972: // syr
        case 0x74656f: // teo
        case 0x746967: // tig
        case 0x76756e: // vun
        case 0x776165: // wae
        case 0x786f67: // xog
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            break;
            
            // set24
        case 0x6172: // ar
            if (n == 2) // n is 2
                return NumberPluralizationFormTwo;
            if (n == 1) // n is 1
                return NumberPluralizationFormOne;
            if (n == 0) // n is 0
                return NumberPluralizationFormZero;
            if (((n % 100) >= 3 && (n % 100) <= 10)) // n mod 100 in 3..10
                return NumberPluralizationFormFew;
            if (((n % 100) >= 11 && (n % 100) <= 99)) // n mod 100 in 11..99
                return NumberPluralizationFormMany;
            break;
    }
    
    return NumberPluralizationFormOther;
}

NSString * _Nonnull formatNumberWithGroupingSeparator(NSString * _Nonnull groupingSeparator, int32_t value) {
    NSString *string = [[NSString alloc] initWithFormat:@"%d", (int)value];

    if (ABS(value) < 1000 || groupingSeparator.length == 0) {
        return string;
    } else {
        NSMutableString *groupedString = [[NSMutableString alloc] init];

        int numberOfPlaces = 0;
        for (int i = ((int)string.length) - 1; i >= 0; i--) {
            if (numberOfPlaces != 0 && numberOfPlaces % 3 == 0) {
                [groupedString insertString:groupingSeparator atIndex:0];
            }
            [groupedString insertString:[string substringWithRange:NSMakeRange(i, 1)] atIndex:0];
            numberOfPlaces++;
        }

        return groupedString;
    }
}
