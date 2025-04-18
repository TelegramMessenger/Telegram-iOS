// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/quant.h"

#include <algorithm>
#include <cmath>
#include <vector>

#include "lib/jpegli/adaptive_quantization.h"
#include "lib/jpegli/common.h"
#include "lib/jpegli/encode_internal.h"
#include "lib/jpegli/error.h"
#include "lib/jpegli/memory_manager.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/status.h"

namespace jpegli {

namespace {

// Global scale is chosen in a way that butteraugli 3-norm matches libjpeg
// with the same quality setting. Fitted for quality 90 on jyrki31 corpus.
constexpr float kGlobalScaleXYB = 1.43951668f;
constexpr float kGlobalScaleYCbCr = 1.73966010f;

static constexpr float kBaseQuantMatrixXYB[] = {
    // c = 0
    7.5629935265f,
    19.8247814178f,
    22.5724945068f,
    20.6706695557f,
    22.6864585876f,
    23.5696277618f,
    25.8129081726f,
    36.3307571411f,
    19.8247814178f,
    21.5503177643f,
    19.9372234344f,
    20.5424213409f,
    21.8645496368f,
    23.9041385651f,
    28.2844066620f,
    32.6609764099f,
    22.5724945068f,
    19.9372234344f,
    21.9017257690f,
    19.1223449707f,
    21.7515811920f,
    24.6724700928f,
    25.4249649048f,
    32.6653823853f,
    20.6706695557f,
    20.5424213409f,
    19.1223449707f,
    20.1610221863f,
    25.3719692230f,
    25.9668903351f,
    30.9804954529f,
    31.3406009674f,
    22.6864585876f,
    21.8645496368f,
    21.7515811920f,
    25.3719692230f,
    26.2431850433f,
    40.5992202759f,
    43.2624626160f,
    63.3010940552f,
    23.5696277618f,
    23.9041385651f,
    24.6724700928f,
    25.9668903351f,
    40.5992202759f,
    48.3026771545f,
    34.0964355469f,
    61.9852142334f,
    25.8129081726f,
    28.2844066620f,
    25.4249649048f,
    30.9804954529f,
    43.2624626160f,
    34.0964355469f,
    34.4937438965f,
    66.9702758789f,
    36.3307571411f,
    32.6609764099f,
    32.6653823853f,
    31.3406009674f,
    63.3010940552f,
    61.9852142334f,
    66.9702758789f,
    39.9652709961f,
    // c = 1
    1.6262000799f,
    3.2199242115f,
    3.4903779030f,
    3.9148359299f,
    4.8337211609f,
    4.9108843803f,
    5.3137121201f,
    6.1676793098f,
    3.2199242115f,
    3.4547898769f,
    3.6036829948f,
    4.2652835846f,
    4.8368387222f,
    4.8226222992f,
    5.6120514870f,
    6.3431472778f,
    3.4903779030f,
    3.6036829948f,
    3.9044559002f,
    4.3374395370f,
    4.8435096741f,
    5.4057979584f,
    5.6066360474f,
    6.1075134277f,
    3.9148359299f,
    4.2652835846f,
    4.3374395370f,
    4.6064834595f,
    5.1751475334f,
    5.4013924599f,
    6.0399808884f,
    6.7825231552f,
    4.8337211609f,
    4.8368387222f,
    4.8435096741f,
    5.1751475334f,
    5.3748049736f,
    6.1410837173f,
    7.6529307365f,
    7.5235214233f,
    4.9108843803f,
    4.8226222992f,
    5.4057979584f,
    5.4013924599f,
    6.1410837173f,
    6.3431472778f,
    7.1083049774f,
    7.6008300781f,
    5.3137121201f,
    5.6120514870f,
    5.6066360474f,
    6.0399808884f,
    7.6529307365f,
    7.1083049774f,
    7.0943155289f,
    7.0478363037f,
    6.1676793098f,
    6.3431472778f,
    6.1075134277f,
    6.7825231552f,
    7.5235214233f,
    7.6008300781f,
    7.0478363037f,
    6.9186143875f,
    // c = 2
    3.3038473129f,
    10.0689258575f,
    12.2785224915f,
    14.6041173935f,
    16.2107315063f,
    19.2314529419f,
    28.0129547119f,
    55.6682891846f,
    10.0689258575f,
    11.4085016251f,
    11.3871345520f,
    15.4934167862f,
    16.5364933014f,
    14.9153423309f,
    26.3748722076f,
    40.8614425659f,
    12.2785224915f,
    11.3871345520f,
    17.0886878967f,
    13.9500350952f,
    16.0003223419f,
    28.5660629272f,
    26.2124195099f,
    30.1260128021f,
    14.6041173935f,
    15.4934167862f,
    13.9500350952f,
    21.1235027313f,
    26.1579780579f,
    25.5579223633f,
    40.6859359741f,
    33.8056335449f,
    16.2107315063f,
    16.5364933014f,
    16.0003223419f,
    26.1579780579f,
    26.8042831421f,
    26.1587715149f,
    35.7343978882f,
    43.6857032776f,
    19.2314529419f,
    14.9153423309f,
    28.5660629272f,
    25.5579223633f,
    26.1587715149f,
    34.5418128967f,
    41.3197937012f,
    48.7867660522f,
    28.0129547119f,
    26.3748722076f,
    26.2124195099f,
    40.6859359741f,
    35.7343978882f,
    41.3197937012f,
    47.6329460144f,
    55.3498458862f,
    55.6682891846f,
    40.8614425659f,
    30.1260128021f,
    33.8056335449f,
    43.6857032776f,
    48.7867660522f,
    55.3498458862f,
    63.6065597534f,
};

static const float kBaseQuantMatrixYCbCr[] = {
    // c = 0
    1.2397409345866273f,  //
    1.7227115097630963f,  //
    2.9212167156636855f,  //
    2.812737435286529f,   //
    3.339819711906184f,   //
    3.463603762596166f,   //
    3.840915217993518f,   //
    3.86956f,             //
    1.7227115097630963f,  //
    2.0928894413636874f,  //
    2.8456760904429297f,  //
    2.704506820909662f,   //
    3.4407673520905337f,  //
    3.166232352090534f,   //
    4.025208741558432f,   //
    4.035324490952577f,   //
    2.9212167156636855f,  //
    2.8456760904429297f,  //
    2.9587403520905338f,  //
    3.3862948970669273f,  //
    3.619523781336757f,   //
    3.9046279999999998f,  //
    3.757835838431854f,   //
    4.237447515714274f,   //
    2.812737435286529f,   //
    2.704506820909662f,   //
    3.3862948970669273f,  //
    3.380058821812233f,   //
    4.1679867415584315f,  //
    4.805510627261856f,   //
    4.784259f,            //
    4.605934f,            //
    3.339819711906184f,   //
    3.4407673520905337f,  //
    3.619523781336757f,   //
    4.1679867415584315f,  //
    4.579851258441568f,   //
    4.923237f,            //
    5.574107f,            //
    5.48533336146308f,    //
    3.463603762596166f,   //
    3.166232352090534f,   //
    3.9046279999999998f,  //
    4.805510627261856f,   //
    4.923237f,            //
    5.43936f,             //
    5.093895741558431f,   //
    6.0872254423617225f,  //
    3.840915217993518f,   //
    4.025208741558432f,   //
    3.757835838431854f,   //
    4.784259f,            //
    5.574107f,            //
    5.093895741558431f,   //
    5.438461f,            //
    5.4037359493250845f,  //
    3.86956f,             //
    4.035324490952577f,   //
    4.237447515714274f,   //
    4.605934f,            //
    5.48533336146308f,    //
    6.0872254423617225f,  //
    5.4037359493250845f,  //
    4.37787101190424f,
    // c = 1
    2.8236197786377537f,  //
    6.495639358561486f,   //
    9.310489207538302f,   //
    10.64747864717083f,   //
    11.07419143098738f,   //
    17.146390223910462f,  //
    18.463982229408998f,  //
    29.087001644203088f,  //
    6.495639358561486f,   //
    8.890103846667353f,   //
    8.976895794294748f,   //
    13.666270550318826f,  //
    16.547071905624193f,  //
    16.63871382827686f,   //
    26.778396930893695f,  //
    21.33034294694781f,   //
    9.310489207538302f,   //
    8.976895794294748f,   //
    11.08737706005991f,   //
    18.20548239870446f,   //
    19.752481654011646f,  //
    23.985660533114896f,  //
    102.6457378402362f,   //
    24.450989f,           //
    10.64747864717083f,   //
    13.666270550318826f,  //
    18.20548239870446f,   //
    18.628012327860365f,  //
    16.042509519487183f,  //
    25.04918273242625f,   //
    25.017140189353015f,  //
    35.79788782635831f,   //
    11.07419143098738f,   //
    16.547071905624193f,  //
    19.752481654011646f,  //
    16.042509519487183f,  //
    19.373482748612577f,  //
    14.677529999999999f,  //
    19.94695960400931f,   //
    51.094112f,           //
    17.146390223910462f,  //
    16.63871382827686f,   //
    23.985660533114896f,  //
    25.04918273242625f,   //
    14.677529999999999f,  //
    31.320412426835304f,  //
    46.357234000000005f,  //
    67.48111451705412f,   //
    18.463982229408998f,  //
    26.778396930893695f,  //
    102.6457378402362f,   //
    25.017140189353015f,  //
    19.94695960400931f,   //
    46.357234000000005f,  //
    61.315764694388044f,  //
    88.34665293823721f,   //
    29.087001644203088f,  //
    21.33034294694781f,   //
    24.450989f,           //
    35.79788782635831f,   //
    51.094112f,           //
    67.48111451705412f,   //
    88.34665293823721f,   //
    112.16099098350989f,
    // c = 2
    2.9217254961255255f,  //
    4.497681013199305f,   //
    7.356344520940414f,   //
    6.583891506504051f,   //
    8.535608740100237f,   //
    8.799434353234647f,   //
    9.188341534163023f,   //
    9.482700481227672f,   //
    4.497681013199305f,   //
    6.309548851989123f,   //
    7.024608962670982f,   //
    7.156445324163424f,   //
    8.049059218663244f,   //
    7.0124290657218555f,  //
    6.711923184393611f,   //
    8.380307846134853f,   //
    7.356344520940414f,   //
    7.024608962670982f,   //
    6.892101177327445f,   //
    6.882819916277163f,   //
    8.782226090078568f,   //
    6.8774750000000004f,  //
    7.8858175969577955f,  //
    8.67909f,             //
    6.583891506504051f,   //
    7.156445324163424f,   //
    6.882819916277163f,   //
    7.003072944847055f,   //
    7.7223464701024875f,  //
    7.955425720217421f,   //
    7.4734110000000005f,  //
    8.362933242943903f,   //
    8.535608740100237f,   //
    8.049059218663244f,   //
    8.782226090078568f,   //
    7.7223464701024875f,  //
    6.778005927001542f,   //
    9.484922741558432f,   //
    9.043702663686046f,   //
    8.053178199770173f,   //
    8.799434353234647f,   //
    7.0124290657218555f,  //
    6.8774750000000004f,  //
    7.955425720217421f,   //
    9.484922741558432f,   //
    8.607606527385098f,   //
    9.922697394370815f,   //
    64.25135180237939f,   //
    9.188341534163023f,   //
    6.711923184393611f,   //
    7.8858175969577955f,  //
    7.4734110000000005f,  //
    9.043702663686046f,   //
    9.922697394370815f,   //
    63.184936549738225f,  //
    83.35294340273799f,   //
    9.482700481227672f,   //
    8.380307846134853f,   //
    8.67909f,             //
    8.362933242943903f,   //
    8.053178199770173f,   //
    64.25135180237939f,   //
    83.35294340273799f,   //
    114.89202448569779f,  //
};

static const float k420GlobalScale = 1.22;
static const float k420Rescale[64] = {
    0.4093, 0.3209, 0.3477, 0.3333, 0.3144, 0.2823, 0.3214, 0.3354,  //
    0.3209, 0.3111, 0.3489, 0.2801, 0.3059, 0.3119, 0.4135, 0.3445,  //
    0.3477, 0.3489, 0.3586, 0.3257, 0.2727, 0.3754, 0.3369, 0.3484,  //
    0.3333, 0.2801, 0.3257, 0.3020, 0.3515, 0.3410, 0.3971, 0.3839,  //
    0.3144, 0.3059, 0.2727, 0.3515, 0.3105, 0.3397, 0.2716, 0.3836,  //
    0.2823, 0.3119, 0.3754, 0.3410, 0.3397, 0.3212, 0.3203, 0.0726,  //
    0.3214, 0.4135, 0.3369, 0.3971, 0.2716, 0.3203, 0.0798, 0.0553,  //
    0.3354, 0.3445, 0.3484, 0.3839, 0.3836, 0.0726, 0.0553, 0.3368,  //
};

static const float kBaseQuantMatrixStd[] = {
    // c = 0
    16.0f, 11.0f, 10.0f, 16.0f, 24.0f, 40.0f, 51.0f, 61.0f,      //
    12.0f, 12.0f, 14.0f, 19.0f, 26.0f, 58.0f, 60.0f, 55.0f,      //
    14.0f, 13.0f, 16.0f, 24.0f, 40.0f, 57.0f, 69.0f, 56.0f,      //
    14.0f, 17.0f, 22.0f, 29.0f, 51.0f, 87.0f, 80.0f, 62.0f,      //
    18.0f, 22.0f, 37.0f, 56.0f, 68.0f, 109.0f, 103.0f, 77.0f,    //
    24.0f, 35.0f, 55.0f, 64.0f, 81.0f, 104.0f, 113.0f, 92.0f,    //
    49.0f, 64.0f, 78.0f, 87.0f, 103.0f, 121.0f, 120.0f, 101.0f,  //
    72.0f, 92.0f, 95.0f, 98.0f, 112.0f, 100.0f, 103.0f, 99.0f,   //
    // c = 1
    17.0f, 18.0f, 24.0f, 47.0f, 99.0f, 99.0f, 99.0f, 99.0f,  //
    18.0f, 21.0f, 26.0f, 66.0f, 99.0f, 99.0f, 99.0f, 99.0f,  //
    24.0f, 26.0f, 56.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f,  //
    47.0f, 66.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f,  //
    99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f,  //
    99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f,  //
    99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f,  //
    99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f, 99.0f,  //
};

static const float kZeroBiasMulYCbCrLQ[] = {
    // c = 0
    0.0000f, 0.0568f, 0.3880f, 0.6190f, 0.6190f, 0.4490f, 0.4490f, 0.6187f,  //
    0.0568f, 0.5829f, 0.6189f, 0.6190f, 0.6190f, 0.7190f, 0.6190f, 0.6189f,  //
    0.3880f, 0.6189f, 0.6190f, 0.6190f, 0.6190f, 0.6190f, 0.6187f, 0.6100f,  //
    0.6190f, 0.6190f, 0.6190f, 0.6190f, 0.5890f, 0.3839f, 0.7160f, 0.6190f,  //
    0.6190f, 0.6190f, 0.6190f, 0.5890f, 0.6190f, 0.3880f, 0.5860f, 0.4790f,  //
    0.4490f, 0.7190f, 0.6190f, 0.3839f, 0.3880f, 0.6190f, 0.6190f, 0.6190f,  //
    0.4490f, 0.6190f, 0.6187f, 0.7160f, 0.5860f, 0.6190f, 0.6204f, 0.6190f,  //
    0.6187f, 0.6189f, 0.6100f, 0.6190f, 0.4790f, 0.6190f, 0.6190f, 0.3480f,  //
    // c = 1
    0.0000f, 1.1640f, 0.9373f, 1.1319f, 0.8016f, 0.9136f, 1.1530f, 0.9430f,  //
    1.1640f, 0.9188f, 0.9160f, 1.1980f, 1.1830f, 0.9758f, 0.9430f, 0.9430f,  //
    0.9373f, 0.9160f, 0.8430f, 1.1720f, 0.7083f, 0.9430f, 0.9430f, 0.9430f,  //
    1.1319f, 1.1980f, 1.1720f, 1.1490f, 0.8547f, 0.9430f, 0.9430f, 0.9430f,  //
    0.8016f, 1.1830f, 0.7083f, 0.8547f, 0.9430f, 0.9430f, 0.9430f, 0.9430f,  //
    0.9136f, 0.9758f, 0.9430f, 0.9430f, 0.9430f, 0.9430f, 0.9430f, 0.9430f,  //
    1.1530f, 0.9430f, 0.9430f, 0.9430f, 0.9430f, 0.9430f, 0.9430f, 0.9480f,  //
    0.9430f, 0.9430f, 0.9430f, 0.9430f, 0.9430f, 0.9430f, 0.9480f, 0.9430f,  //
    // c = 2
    0.0000f, 1.3190f, 0.4308f, 0.4460f, 0.0661f, 0.0660f, 0.2660f, 0.2960f,  //
    1.3190f, 0.3280f, 0.3093f, 0.0750f, 0.0505f, 0.1594f, 0.3060f, 0.2113f,  //
    0.4308f, 0.3093f, 0.3060f, 0.1182f, 0.0500f, 0.3060f, 0.3915f, 0.2426f,  //
    0.4460f, 0.0750f, 0.1182f, 0.0512f, 0.0500f, 0.2130f, 0.3930f, 0.1590f,  //
    0.0661f, 0.0505f, 0.0500f, 0.0500f, 0.3055f, 0.3360f, 0.5148f, 0.5403f,  //
    0.0660f, 0.1594f, 0.3060f, 0.2130f, 0.3360f, 0.5060f, 0.5874f, 0.3060f,  //
    0.2660f, 0.3060f, 0.3915f, 0.3930f, 0.5148f, 0.5874f, 0.3060f, 0.3060f,  //
    0.2960f, 0.2113f, 0.2426f, 0.1590f, 0.5403f, 0.3060f, 0.3060f, 0.3060f,  //
};

static const float kZeroBiasMulYCbCrHQ[] = {
    // c = 0
    0.0000f, 0.0044f, 0.2521f, 0.6547f, 0.8161f, 0.6130f, 0.8841f, 0.8155f,  //
    0.0044f, 0.6831f, 0.6553f, 0.6295f, 0.7848f, 0.7843f, 0.8474f, 0.7836f,  //
    0.2521f, 0.6553f, 0.7834f, 0.7829f, 0.8161f, 0.8072f, 0.7743f, 0.9242f,  //
    0.6547f, 0.6295f, 0.7829f, 0.8654f, 0.7829f, 0.6986f, 0.7818f, 0.7726f,  //
    0.8161f, 0.7848f, 0.8161f, 0.7829f, 0.7471f, 0.7827f, 0.7843f, 0.7653f,  //
    0.6130f, 0.7843f, 0.8072f, 0.6986f, 0.7827f, 0.7848f, 0.9508f, 0.7653f,  //
    0.8841f, 0.8474f, 0.7743f, 0.7818f, 0.7843f, 0.9508f, 0.7839f, 0.8437f,  //
    0.8155f, 0.7836f, 0.9242f, 0.7726f, 0.7653f, 0.7653f, 0.8437f, 0.7819f,  //
    // c = 1
    0.0000f, 1.0816f, 1.0556f, 1.2876f, 1.1554f, 1.1567f, 1.8851f, 0.5488f,  //
    1.0816f, 1.1537f, 1.1850f, 1.0712f, 1.1671f, 2.0719f, 1.0544f, 1.4764f,  //
    1.0556f, 1.1850f, 1.2870f, 1.1981f, 1.8181f, 1.2618f, 1.0564f, 1.1191f,  //
    1.2876f, 1.0712f, 1.1981f, 1.4753f, 2.0609f, 1.0564f, 1.2645f, 1.0564f,  //
    1.1554f, 1.1671f, 1.8181f, 2.0609f, 0.7324f, 1.1163f, 0.8464f, 1.0564f,  //
    1.1567f, 2.0719f, 1.2618f, 1.0564f, 1.1163f, 1.0040f, 1.0564f, 1.0564f,  //
    1.8851f, 1.0544f, 1.0564f, 1.2645f, 0.8464f, 1.0564f, 1.0564f, 1.0564f,  //
    0.5488f, 1.4764f, 1.1191f, 1.0564f, 1.0564f, 1.0564f, 1.0564f, 1.0564f,  //
    // c = 2
    0.0000f, 0.5392f, 0.6659f, 0.8968f, 0.6829f, 0.6328f, 0.5802f, 0.4836f,  //
    0.5392f, 0.6746f, 0.6760f, 0.6102f, 0.6015f, 0.6958f, 0.7327f, 0.4897f,  //
    0.6659f, 0.6760f, 0.6957f, 0.6543f, 0.4396f, 0.6330f, 0.7081f, 0.2583f,  //
    0.8968f, 0.6102f, 0.6543f, 0.5913f, 0.6457f, 0.5828f, 0.5139f, 0.3565f,  //
    0.6829f, 0.6015f, 0.4396f, 0.6457f, 0.5633f, 0.4263f, 0.6371f, 0.5949f,  //
    0.6328f, 0.6958f, 0.6330f, 0.5828f, 0.4263f, 0.2847f, 0.2909f, 0.6629f,  //
    0.5802f, 0.7327f, 0.7081f, 0.5139f, 0.6371f, 0.2909f, 0.6644f, 0.6644f,  //
    0.4836f, 0.4897f, 0.2583f, 0.3565f, 0.5949f, 0.6629f, 0.6644f, 0.6644f,  //
};

static const float kZeroBiasOffsetYCbCrDC[] = {0.0f, 0.0f, 0.0f};

static const float kZeroBiasOffsetYCbCrAC[] = {
    0.59082f,
    0.58146f,
    0.57988f,
};

constexpr uint8_t kTransferFunctionPQ = 16;
constexpr uint8_t kTransferFunctionHLG = 18;

float DistanceToLinearQuality(float distance) {
  if (distance <= 0.1f) {
    return 1.0f;
  } else if (distance <= 4.6f) {
    return (200.0f / 9.0f) * (distance - 0.1f);
  } else if (distance <= 6.4f) {
    return 5000.0f / (100.0f - (distance - 0.1f) / 0.09f);
  } else if (distance < 25.0f) {
    return 530000.0f /
           (3450.0f -
            300.0f * std::sqrt((848.0f * distance - 5330.0f) / 120.0f));
  } else {
    return 5000.0f;
  }
}

constexpr float kExponent[DCTSIZE2] = {
    1.00f, 0.51f, 0.67f, 0.74f, 1.00f, 1.00f, 1.00f, 1.00f,  //
    0.51f, 0.66f, 0.69f, 0.87f, 1.00f, 1.00f, 1.00f, 1.00f,  //
    0.67f, 0.69f, 0.84f, 0.83f, 0.96f, 1.00f, 1.00f, 1.00f,  //
    0.74f, 0.87f, 0.83f, 1.00f, 1.00f, 0.91f, 0.91f, 1.00f,  //
    1.00f, 1.00f, 0.96f, 1.00f, 1.00f, 1.00f, 1.00f, 1.00f,  //
    1.00f, 1.00f, 1.00f, 0.91f, 1.00f, 1.00f, 1.00f, 1.00f,  //
    1.00f, 1.00f, 1.00f, 0.91f, 1.00f, 1.00f, 1.00f, 1.00f,  //
    1.00f, 1.00f, 1.00f, 1.00f, 1.00f, 1.00f, 1.00f, 1.00f,  //
};
constexpr float kDist0 = 1.5f;  // distance where non-linearity kicks in.

float DistanceToScale(float distance, int k) {
  if (distance < kDist0) {
    return distance;
  }
  const float exp = kExponent[k];
  const float mul = std::pow(kDist0, 1.0 - exp);
  return std::max<float>(0.5f * distance, mul * std::pow(distance, exp));
}

float ScaleToDistance(float scale, int k) {
  if (scale < kDist0) {
    return scale;
  }
  const float exp = 1.0 / kExponent[k];
  const float mul = std::pow(kDist0, 1.0 - exp);
  return std::min<float>(2.0f * scale, mul * std::pow(scale, exp));
}

float QuantValsToDistance(j_compress_ptr cinfo) {
  jpeg_comp_master* m = cinfo->master;
  float global_scale = kGlobalScaleYCbCr;
  if (m->cicp_transfer_function == kTransferFunctionPQ) {
    global_scale *= .4f;
  } else if (m->cicp_transfer_function == kTransferFunctionHLG) {
    global_scale *= .5f;
  }
  int quant_max = m->force_baseline ? 255 : 32767U;
  static const float kDistMax = 10000.0f;
  float dist_min = 0.0f;
  float dist_max = kDistMax;
  for (int c = 0; c < cinfo->num_components; ++c) {
    int quant_idx = cinfo->comp_info[c].quant_tbl_no;
    uint16_t* quantval = cinfo->quant_tbl_ptrs[quant_idx]->quantval;
    const float* base_qm = &kBaseQuantMatrixYCbCr[quant_idx * DCTSIZE2];
    for (int k = 0; k < DCTSIZE2; ++k) {
      float dmin = 0.0;
      float dmax = kDistMax;
      float invq = 1.0f / base_qm[k] / global_scale;
      int qval = quantval[k];
      if (qval > 1) {
        float scale_min = (qval - 0.5f) * invq;
        dmin = ScaleToDistance(scale_min, k);
      }
      if (qval < quant_max) {
        float scale_max = (qval + 0.5f) * invq;
        dmax = ScaleToDistance(scale_max, k);
      }
      if (dmin <= dist_max) {
        dist_min = std::max(dmin, dist_min);
      }
      if (dmax >= dist_min) {
        dist_max = std::min(dist_max, dmax);
      }
    }
  }
  float distance;
  if (dist_min == 0) {
    distance = dist_max;
  } else if (dist_max == kDistMax) {
    distance = dist_min;
  } else {
    distance = 0.5f * (dist_min + dist_max);
  }
  return distance;
}

bool IsYUV420(j_compress_ptr cinfo) {
  return (cinfo->jpeg_color_space == JCS_YCbCr &&
          cinfo->comp_info[0].h_samp_factor == 2 &&
          cinfo->comp_info[0].v_samp_factor == 2 &&
          cinfo->comp_info[1].h_samp_factor == 1 &&
          cinfo->comp_info[1].v_samp_factor == 1 &&
          cinfo->comp_info[2].h_samp_factor == 1 &&
          cinfo->comp_info[2].v_samp_factor == 1);
}

}  // namespace

void SetQuantMatrices(j_compress_ptr cinfo, float distances[NUM_QUANT_TBLS],
                      bool add_two_chroma_tables) {
  jpeg_comp_master* m = cinfo->master;
  const bool xyb = m->xyb_mode && cinfo->jpeg_color_space == JCS_RGB;
  const bool is_yuv420 = IsYUV420(cinfo);

  float global_scale;
  bool non_linear_scaling = true;
  const float* base_quant_matrix[NUM_QUANT_TBLS];
  int num_base_tables;

  if (xyb) {
    global_scale = kGlobalScaleXYB;
    num_base_tables = 3;
    base_quant_matrix[0] = kBaseQuantMatrixXYB;
    base_quant_matrix[1] = kBaseQuantMatrixXYB + DCTSIZE2;
    base_quant_matrix[2] = kBaseQuantMatrixXYB + 2 * DCTSIZE2;
  } else if (cinfo->jpeg_color_space == JCS_YCbCr && !m->use_std_tables) {
    global_scale = kGlobalScaleYCbCr;
    if (m->cicp_transfer_function == kTransferFunctionPQ) {
      global_scale *= .4f;
    } else if (m->cicp_transfer_function == kTransferFunctionHLG) {
      global_scale *= .5f;
    }
    if (is_yuv420) {
      global_scale *= k420GlobalScale;
    }
    if (add_two_chroma_tables) {
      cinfo->comp_info[2].quant_tbl_no = 2;
      num_base_tables = 3;
      base_quant_matrix[0] = kBaseQuantMatrixYCbCr;
      base_quant_matrix[1] = kBaseQuantMatrixYCbCr + DCTSIZE2;
      base_quant_matrix[2] = kBaseQuantMatrixYCbCr + 2 * DCTSIZE2;
    } else {
      num_base_tables = 2;
      base_quant_matrix[0] = kBaseQuantMatrixYCbCr;
      // Use the Cr table for both Cb and Cr.
      base_quant_matrix[1] = kBaseQuantMatrixYCbCr + 2 * DCTSIZE2;
    }
  } else {
    global_scale = 0.01f;
    non_linear_scaling = false;
    num_base_tables = 2;
    base_quant_matrix[0] = kBaseQuantMatrixStd;
    base_quant_matrix[1] = kBaseQuantMatrixStd + DCTSIZE2;
  }

  int quant_max = m->force_baseline ? 255 : 32767U;
  for (int quant_idx = 0; quant_idx < num_base_tables; ++quant_idx) {
    const float* base_qm = base_quant_matrix[quant_idx];
    JQUANT_TBL** qtable = &cinfo->quant_tbl_ptrs[quant_idx];
    if (*qtable == nullptr) {
      *qtable = jpegli_alloc_quant_table(reinterpret_cast<j_common_ptr>(cinfo));
    }
    for (int k = 0; k < DCTSIZE2; ++k) {
      float scale = global_scale;
      if (non_linear_scaling) {
        scale *= DistanceToScale(distances[quant_idx], k);
        if (is_yuv420 && quant_idx > 0) {
          scale *= k420Rescale[k];
        }
      } else {
        scale *= DistanceToLinearQuality(distances[quant_idx]);
      }
      int qval = std::round(scale * base_qm[k]);
      (*qtable)->quantval[k] = std::max(1, std::min(qval, quant_max));
    }
    (*qtable)->sent_table = FALSE;
  }
}

void InitQuantizer(j_compress_ptr cinfo, QuantPass pass) {
  jpeg_comp_master* m = cinfo->master;
  // Compute quantization multupliers from the quant table values.
  for (int c = 0; c < cinfo->num_components; ++c) {
    int quant_idx = cinfo->comp_info[c].quant_tbl_no;
    JQUANT_TBL* quant_table = cinfo->quant_tbl_ptrs[quant_idx];
    if (!quant_table) {
      JPEGLI_ERROR("Missing quantization table %d for component %d", quant_idx,
                   c);
    }
    for (size_t k = 0; k < DCTSIZE2; k++) {
      int val = quant_table->quantval[k];
      if (val == 0) {
        JPEGLI_ERROR("Invalid quantval 0.");
      }
      switch (pass) {
        case QuantPass::NO_SEARCH:
          m->quant_mul[c][k] = 8.0f / val;
          break;
        case QuantPass::SEARCH_FIRST_PASS:
          m->quant_mul[c][k] = 128.0f;
          break;
        case QuantPass::SEARCH_SECOND_PASS:
          m->quant_mul[c][kJPEGZigZagOrder[k]] = 1.0f / (16 * val);
          break;
      }
    }
  }
  if (m->use_adaptive_quantization) {
    for (int c = 0; c < cinfo->num_components; ++c) {
      for (int k = 0; k < DCTSIZE2; ++k) {
        m->zero_bias_mul[c][k] = k == 0 ? 0.0f : 0.5f;
        m->zero_bias_offset[c][k] = k == 0 ? 0.0f : 0.5f;
      }
    }
    if (cinfo->jpeg_color_space == JCS_YCbCr) {
      float distance = QuantValsToDistance(cinfo);
      static const float kDistHQ = 1.0f;
      static const float kDistLQ = 3.0f;
      float mix0 = (distance - kDistHQ) / (kDistLQ - kDistHQ);
      mix0 = std::max(0.0f, std::min(1.0f, mix0));
      float mix1 = 1.0f - mix0;
      for (int c = 0; c < cinfo->num_components; ++c) {
        for (int k = 0; k < DCTSIZE2; ++k) {
          float mul0 = kZeroBiasMulYCbCrLQ[c * DCTSIZE2 + k];
          float mul1 = kZeroBiasMulYCbCrHQ[c * DCTSIZE2 + k];
          m->zero_bias_mul[c][k] = mix0 * mul0 + mix1 * mul1;
          m->zero_bias_offset[c][k] =
              k == 0 ? kZeroBiasOffsetYCbCrDC[c] : kZeroBiasOffsetYCbCrAC[c];
        }
      }
    }
  } else if (cinfo->jpeg_color_space == JCS_YCbCr) {
    for (int c = 0; c < cinfo->num_components; ++c) {
      for (int k = 0; k < DCTSIZE2; ++k) {
        m->zero_bias_offset[c][k] =
            k == 0 ? kZeroBiasOffsetYCbCrDC[c] : kZeroBiasOffsetYCbCrAC[c];
      }
    }
  }
}

}  // namespace jpegli
