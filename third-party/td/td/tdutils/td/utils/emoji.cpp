//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/emoji.h"

#include "td/utils/base64.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Gzip.h"

namespace td {

static constexpr size_t MAX_EMOJI_LENGTH = 28;

static bool is_emoji_element(Slice str) {
  static const FlatHashSet<Slice, SliceHash> emojis = [max_emoji_length = MAX_EMOJI_LENGTH] {
#if TD_HAVE_ZLIB
    Slice packed_emojis(
        "eJxtmlly40iWRbdCs_rrr56H3WVmzBHE4A6AxCCFqiodcBFOKShSComawqyWglpAl1lvoP0wcdPK2vrDnY8WF453z_"
        "NJCk3LdjEtu8WUbWIbYwuxbWPbxXZYTOuX2F4XU13GVi2m5mNsn2L7HNuX2JaxJbGlsWWx5bGZ2GxsRWw_FlMbP9s_xRbHb-"
        "P4bRyzjWN2b2N7F1t8tovjd_Hfu31s8b3dXWyPsUXtWdScxfedxfedXS6m8_jO8_jMeRz3PD53HvM6Xy-mr_Hz6yo24pj_1_"
        "jubfS2PVtMVzGvq2rxt4uf3sbuTRa79ymdobN0BV1Jh-79im5NV9M1dG3sPv5Md4q-0e3pDnS3dHd03-ke6I50j7H7lNPxtuVPdIyy_"
        "IXuDR1ZLd_Rvaf7QPeR7hPdZ7ovdEu6hI7sl_hYMvLyNDI-lvhY4mOJjyU-lvhY4mOJjyXZx6rH7ozunO4r3QXdH-"
        "mu6K7pcLnc0d3Q4XeJ3yV-l_hd3tPhd4nfJX6XT3TPdC90r3Q_YpdgP8F-gv0E-wn2E-wn2E-wn2A_wX6C_QT7CfYT7CfYT7CfYD_"
        "BfoL9BPsJ9hPsJ9hPsJ9gP8F-gv0E-wn2E-wn2E-wn2A_-RPdn-l-pXN0Pd1A5-"
        "ku6TZ0I12g29KBLgFdAroEdAnoEtAloEtAl4AuYaok8Evgl8AvgV8CvwR-"
        "CegS0KWgS0GXgi4FXQq6FHQp6FLQpaBLQZeCLgVdCroUdCnoUtCloEtBl4IuBV2K_RT7KfZT7KfYT7GfYj_Ffor9FPsp9lPsp9hPsZ9iP8V-"
        "iv0U-yn2U-yn2E-xn2I_xX6K_RT7KfZT7KfYT5k-KQxSGGQwyGCQwSCDQQaDDAYZDDIYZDDIYJDBIMNvht8Mvxl-M_xm-M3wm-E3w2-G3wy_"
        "GX4z_"
        "Gb4zfCb4TfDb4bfDL8ZfjP8ZvjNMJjhKMNRhqMMRxmOMhxlOMpwlOMox1GOoxxHOY5yHOU4ynGU4yjHUY6jnKrmVDWnqjlVzXGZ4zLHZY7LHJc"
        "5CyJnQeQsiJwFkbMgchZEzoLIWRA5CyJnQeQsiJwFkUMoh1AOoRxCOYRyCOUQyiGUQyiHUA6hHEI5hHII5RDKIZRDKGdG5MyInBmRAyxnRuTMi"
        "JwZkcMvh18Ovxx-Ofxy-"
        "OXwM6AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1A"
        "zUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzUDNQM1AzJ2rMOgs6y6yz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_"
        "Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_Cz8LPws_"
        "Cz8LPws_Cz8LPws_Cz8LPwK-BXwK-AXwG_An4F_Ar4FfAr4FfAr4BfAb8CfgX8CvgV8CvgV8CvgF8BvwJ-BfwK-BXwK-BXwK-AXwG_An4F_"
        "Ar4FfAr4FfAr4BfAb8CfgX8CvgV8CvgV8CvgF8BvwJ-BfwK-BXwK-BXwK-AXwG_An4F_"
        "Ar4FfAr4FfAr4BfAb8CfgXUSqiVUCuhVkKthFoJtRJqJdRKqJVQK6FWQq2EWgm1Emol1EqolVAroVZCrYRaCbUSaiXUSqiVUCuhVkKthFoJtRJ"
        "qJdRKqJVQK6FWQq2EWgm1Emol1EqolVAroVZCrYRaCbUSaiXUSqiVUCuhVkKthFoJtRJqJdRKqJVQK6FWQq2EWsmsq7BfYb_"
        "CfoX9CucVziucVzivcF7hvMJ5hfMK5xXOK5xXOK9wXuG8wnmF8wrnFc4rnFc4r3Be4bzCeYXzivxWvGPFO1ZI1qS7Jt016a5ZJGvKXVPumnLXl"
        "Lum3DXlril3Tblryl1T7ppy15S7xm-N3xq_"
        "NX5ryl1jusZ0jeka0zWmaxKqSajGdI3pGtM1pmtM15iuMV1jusZ0jeka0zWma0zXOKoxXWO6xnRNuWvKXVPumnLXlLum3DXlril3Tblryl1T7p"
        "py15S7ptw15a4pd025a8pdg7OGXw2_Gn41_Gr4NfBr4NfAr4FfA78Gfg38Gvg18Gvg18CvgV8DvwZ-Dfwa-"
        "LWM1zJey3gt47WM1zJey3gt47WM1zJey3gt47WM1zJey3jtaTzq0VKPlnq01KOlHi31aKlHSz1a6tFSj5Z6tNSjpR4t9WipR0s9WurRUo-"
        "WerTUo6UeLfVoqUdLPVrq0VKPlnq01KOlHi31aKlHSz1a6tFSj5Z6tNSjpR4t9WipR0s9WurRUo-"
        "WerTUo6UeLfVoqUdLPTr4dfDr4NfBr4NfB78OQh1IOpB0IOkA0QGiA0SH6Q7THaY7THdk35F9R2odqXWk1pFaR2odqXWk1pFaR2oXsLqA1QWsL"
        "mB1AasLWF3A6gJWF7C6gNUFrC542wVcHOk6CuooqKOgjuwd2TuydxTUUVCHD4cPhw9HQR0FdRTUUVCHN4c3hzeHN0eSjiQdSTqSdCTpSNKRpCN"
        "JR5KOJB1JOpJ0IHEU1FFQR0HdKXEK6iioo6AOag5qDmoOag5qDmoOag5gjlo6aumoZU8te2rZU8ueWvbUsqeWPcugZxn0LIOeZdCzDHqo9VDro"
        "dZDrYdaD7Ueaj3Ueqj1UOuh1kOth1oPtR5qPdR6qPVQ66HWQ62HWg-"
        "1Hmo91Hqo9VDrodZDrYdaD7Ueaj3Ueqj1UOuh1kOth1oPtR5qPdR6qPVQ66HWQ62HWg-1Hmo9c60HXQ-"
        "6HnQ96AbQDaAbQDeAbgDdALqBbWSA3wC_AX4D_Ab4DfAb4DfAb4DfAL8BfgP8BvgN8BvgN8BvgN8AvwF-A_wG-A3wG-A3wG-A3wC_AX4D_"
        "Ab4DfAb4DfAb4DfAL8BfgP8BvgN8BvgN8BvgN8AvwF-A_wG-A3wG-A3wG-A3wC_AX4D_Ab4DfAb4DfAb4Cfh5-Hn4efh5-Hn4efh5-Hn4efh5-"
        "Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-"
        "Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh5-Hn4efh9-G8TaMt2G8DeNtGG_"
        "DeBvG2zDehvE2jLdhvA3jbRhvpAAjBRgpwEgBRgowUoCRAowUYKQAIwUY4TzCeYTzCOcRziOcRziPcB7hPMJ5hPMI5xHOI5xHOI9wHuE8wnmE8"
        "wjnEc4jnEc4j3Ae4TzCeYTzCOcRziOcRziPcB7hPMJlhMsIlxEuI1xGuIxwGeEywmWEywiXES7jiQucRziPcA5gCmAKYApgCmAKYApgCkzCAJw"
        "AnACcAJwAnACcAJwAnACcAJwAnACcAJwAnACSAJIAkgCSAJIAkgCSAJIAkgCSAJKA6YDpgOmA6YDpgOmA6YDp8LD4y2bxl-vF9NPzYvr502J6-"
        "-fYjovpfRlbFdsqtnVsdWxNbJvYxsW0vFxMWRbbVWzx-exbbDex7WN7iC2OkT0upviD4LSK-lWI7ftiWv8U21Ns8X3xJjzFi_"
        "AU78FTvAZP8RY8xXvtFC-zU7ytTvFiOsXb6BTvoVO8hk7x7jnFu-YU75ZTvFpO8cY4xQvjFO-LU7wVTvE-ODUXscVnmqhv-"
        "tjiM03MtYnvbF4XU7yTTfE2NsXL2BTvYlO8ik3xEjbF69cUb19TvG1N8To1xVvSFC9JU_cxtugz3l6mrogt-u_iv3X8221s97HFPOJtZDqL7z-"
        "L-rPI8WwZWxJbfPYsvvMsvvMsvu8sejr7U2yH2OLz59Hz-YfYYr7nbjF9jf8WD-8pnt3T9l1s72P7sPjrT7vYXhZ__byOjYnyjhK_"
        "o8TvmJvvmJsfmZEfT794ZrYsmSNL5siSObJkjiyZI0vmyJJls2TZLFk2y9MvXU-_V2RapkzLlBelzMiUGZmySFNmZMaum7HrZuy6GRM-"
        "Y15nzOuMATIGyJjXGaNkjJIxSsa8zlj0GeNlp_"
        "GYoBlzMzv9lgsz5vR7hNOPemw2Fbt9xYqucF7xRMWUrnisIvuKZyvWccU6XrFbrXhsRbor0l2R7opVuYLLChorIK5YJ6vTj2tAXLOs1yzrNat3"
        "zepds3rXZL8m-zXZr-G8ZkGuGWpNfmtSW58upry345UdhDq2hI7F3PFYx2LueLajUB0JdVSmw2B3WPxhevPr4g___ZDx-Q-nbv7yj6du_"
        "vJPp27-8s-nbv7yL6du_vKvp27-8m-nbv7y76du_vIfp27-8p-nbv7yX6du_"
        "vK3iw9DbJcKNgpGBUHBVsG1ghsFewW3Cr4ruFfwoOCo4FHBs4IXBUycD54vCryCjYJRQVCwVXCl4FrBNwU3CvYKDgpuFXxXcK_"
        "gQcFRwZOCZwWvCk7JXyr5S-G9VPKXyvlSOV8q50vlTLBTcKNgr-Cg4FbBnYLvCu4VPCp4UvCs4EXBq4JT8hvh3SjDjRhulNhG-WyUxkaPj_I-"
        "yvuoAUcNOMryqFRHcR7FeVTyQViC0ghKIyiNoDSCBtwqja3mz1Yl2CqfrWqxVWJbJbbVS7cqwVbv2qoEW5Hfivz279_-oOCo4FHBs4IT-"
        "SvZudIrrvSKKw14pXGuNM618F7L17V8XSvnaw14rQGvBepaOV_rFdfK-Vrv-qYBv2mcb3r8m7zvpNmJ4U4Md2K40-M7pbH7-"
        "8fvFTwreFVwmlE3KuWNSnkj7zd6xY0Y3mjAG9m5kZ0boSN4UnB6116v2GvkvajuZXCv2bKX072c7vX2vcjvZXkvy3uh28v7XiXYK-"
        "e9ct4r571y3ivnvUARvCj43cWJ2EF2DrJzkIuDXBzk4iCGByV_UKoHpXpQhgflc9C7buX0Ti-"
        "907vu9K47vetOxO5E7E4vvfv7cQ4K7hU8KDgqeFZw8v5db7_X2-_l4l6P3yv5ez3-oKcIvIJLBRsFo4KtgisF1wq-"
        "KdgpuFGwV3BQcKvgXsGDgqOCJwUvCl4VnMgflfxROR-V81Hkj8r5qJyPSvWoVI9K9ahUj0r1qFSPSvWoDI_K8CiYRyX2qMQe9fZHjfyokR9l-"
        "VG-HvX4kx5_kq8nleBJAz6J_JMGfFJxn-X9Wa94kdNXjfMqFz_0rh_K8MdsJ7v9nz_-7GP7c2x9bNfz9x__9x8Psf0a2-3_94_3sW1n0Q9-"
        "HDr9h_lvn8_z58v8-Tp__uBHkd90p8_n-fNl_nydP3_w50O_6U6fz_Pny_z5On-i-"
        "zLrvsy6L7Puy6z7MuuWs24565azbjnrlrMumXXJrEtmXTLrkvmPANJ3818InIJnBS8KXhWcyP2iPyf4RX9S8Iv-rOAX_WnBLxK_"
        "kfiNxG8kfiPxG4nfSvxW4rcSv5X4rcQfJP4g8QeJP0j8QeLPEn-W-LPEnyX-LPEXib9I_EXiLxJ_"
        "kXgp8VLipcRLiZez2AidETojdEbojNAZoTNCZ4TOCJ0ROvNe4vcSv5f4vcTvJRY6I3RG6IzQGaEzHyX-KPFHiT9K_FHiTxJ_kviTxJ8k_"
        "iSximJUFKOiGBXFqChGRTEqilFRjIpiVBSjohgVxagoRkUxvxclkTiROJE4kVgrxaQSpxKnEqcSpxJnEmcSZxJnEmcS5xLnEucS5xLnEg8SDxI"
        "PEg8SDxJ7ib3EXmIvsZf4UuJLiS8lvpT4UuKNxBuJNxJvJN5IHCQOEgeJg8RB4q3EW4m3Em8l3kp8JfGVxFcSX0l8JfG1xNcSX0t8LfG1xDuJd"
        "xLvJN5JvJP4RuIbiW8kvpH4RuK9xHuJ9xLvJd5LfJD4IPFB4oPEB4lvJb6V-FbiW4lvJb6T-E7iO4nvJL6T-LvE3yX-LvF3ib9LfC_"
        "xvcT3Et9LfC_xg8QPEj9I_CDxg8TPEj9L_Czxs8TPs9j-PItPwbOCFwWvCk5i7c9W-7PV_my1P1vtz1b7s9X-bLU_W-"
        "3PVvuz1QlrdcJanbBWJ6zVCWu1mVtt5labudVmbrWZW23mVpu51WZutZlbbeZWO5LVjmS1I1ntSFY7kjUSG4mNxEZiI_"
        "Eo8SjxKPEo8TiLK03RSlO00hStNEUrTdFKU7TSFK00RStN0UpTtHqU-FHiR4kfJX6cxat8Fp-"
        "CZwUvCl4VnMSVxJXElcSVxJXEK4lXEq8kXkm8msWN5kajudFobjSaG43mRqO50WhuNJobjeZGo7nRaG40mhuN5kajudFobjQ6YRudsI1O2EYnb"
        "KMTttEJ2-iEbXTCNjphG52wjU7YRidsoxO20Qnb6IRtdMI2OmEbnbCNTthGJ2yj-dxoPjeaz43mc6P53P46i0_"
        "Bs4IXBa8KTmJN0VZTtNUUbTVFW03RVlO01RRtNUVbTdFWU7TVLtpqF221i7baRVvtot1Ps_"
        "gUPCt4UfCq4CRWUToVpVNROhWlU1GcxE5iJ7GT2P0uFmcnzk6cnTg7cXa1xLXEtcS1xLXEjcSNxI3EjcSNxK3ErcStxK3ErcSdxJ3EncSdxJ3E"
        "ZxKfSXwm8ZnEZxKfS3wu8bnE5xKfS_xV4q8Sf5X4q8RfJb6Q-"
        "ELiC4kvJL6QWJdAp0ug0yXQ6RLodAl0O4l3Eu8k3km8k1g3GaebjNNNxukm43STcbrJON1knG4yTjcZp5uM003G6SbjdJNxusk43WSc1qDTGnR"
        "ag05r0GkNOq1BpzXotAad1qDTGnRag05r0GkNOq1BpzXodJNxusk43WScbjJONxmnm4zTTcbpJuN0k3G6ybijxEeJjxIfJT5K_CLxi8QvEr9I_"
        "CLxq8SvEr9K_Crx6yzuZbCXwV4GexnsZXAQ50GcB3EexHkQ50GcB3EexHkQ50GcB6EbhG4QukHoBqEbhG4QukHoBqEbhG54kvhJ4ieJnyR-"
        "msVep5XXaeV1WnmdVl6nlddp5XVaeZ1WXqeV12nltYt67aJeu6jXLuq1i3rdvrxuX163L6_"
        "bl9fty1uJrcRWYiuxlbiQuJC4kLiQuJC4lLiUuJS4lLiUWHckrzuS1x3J647kdUfyuiN53ZG87khedySvO5JfS7yWeC3xWuK1xDqAvA4grwPI6"
        "wDyOoC8DiCvA8jrAPI6gLwOIK8DyOsA8jqAvA4grwPI6wDyOoC8DiCvA8jrAPI6gLwOIK8DyOsA8jqAvA4grwPI6wDyOoC8DqCgn1OCfk4J-"
        "jkl6OeUoJ9Tgn4FF_"
        "QruKBfwQX9Ci7oV3BBF9egi2vQxTXo4hp0cQ07iXcS7yTeSbyTWAdQ0AEUdAAFHUBBB1DQARR0AAUdQEEHUNABFHQABR1AQQdQ0AEUdAAFHUBB"
        "B1DQARR0AAUdQEEbY9DGGLQxBm2MQRtj0MYYtDEGbYxBG2PQxhi0Pwftz0H7c9D-HLQ_B-2iQbto0C4atIuG33bR_wUTXk_W");
    static string all_emojis_str = gzdecode(base64url_decode(packed_emojis).ok()).as_slice().str();
    constexpr size_t EMOJI_COUNT = 2334;
#else
    string all_emojis_str;
    constexpr size_t EMOJI_COUNT = 0;
#endif
    FlatHashSet<Slice, SliceHash> all_emojis;
    all_emojis.reserve(EMOJI_COUNT);
    for (size_t i = 0; i < all_emojis_str.size(); i++) {
      CHECK(all_emojis_str[i] != ' ');
      CHECK(all_emojis_str[i + 1] != ' ');
      size_t j = i + 2;
      while (j < all_emojis_str.size() && all_emojis_str[j] != ' ') {
        j++;
      }
      CHECK(j < all_emojis_str.size());
      all_emojis.insert(Slice(&all_emojis_str[i], &all_emojis_str[j]));
      CHECK(j - i <= max_emoji_length);
      i = j;
    }
    CHECK(all_emojis.size() == EMOJI_COUNT);
    return all_emojis;
  }();
  auto len = str.size();
  if (len > MAX_EMOJI_LENGTH + 3) {
    return false;
  }
  if (emojis.count(str) != 0) {
    return true;
  }
  if (len <= 3 || str[len - 3] != '\xEF' || str[len - 2] != '\xB8' || str[len - 1] != '\x8F') {
    return false;
  }
  if (len >= 6 && str[len - 6] == '\xEF' && str[len - 5] == '\xB8' && str[len - 4] == '\x8F') {
    return false;
  }
  return emojis.count(str.substr(0, len - 3)) != 0;
}

bool is_emoji(Slice str) {
  size_t i = str.substr(0, MAX_EMOJI_LENGTH + 4).find('\xE2');
  if (i == Slice::npos) {
    return is_emoji_element(str);
  }

  size_t start_pos = 0;
  for (; i + 3 < str.size(); i++) {
    if (str[i] == '\xE2' && str[i + 1] == '\x80' && str[i + 2] == '\x8D') {
      // zero-width joiner \u200D
      if (!is_emoji_element(str.substr(start_pos, i - start_pos))) {
        return false;
      }
      start_pos = i + 3;
      i += 2;
    }
  }
  return is_emoji_element(str.substr(start_pos));
}

int get_fitzpatrick_modifier(Slice emoji) {
  if (emoji.size() < 4 || emoji[emoji.size() - 4] != '\xF0' || emoji[emoji.size() - 3] != '\x9F' ||
      emoji[emoji.size() - 2] != '\x8F') {
    return 0;
  }
  auto c = static_cast<unsigned char>(emoji.back());
  if (c < 0xBB || c > 0xBF) {
    return 0;
  }
  return (c - 0xBB) + 2;
}

Slice remove_fitzpatrick_modifier(Slice emoji) {
  while (get_fitzpatrick_modifier(emoji) != 0) {
    emoji.remove_suffix(4);
  }
  return emoji;
}

string remove_emoji_modifiers(Slice emoji, bool remove_selectors) {
  string result = emoji.str();
  remove_emoji_modifiers_in_place(result, remove_selectors);
  return result;
}

void remove_emoji_modifiers_in_place(string &emoji, bool remove_selectors) {
  static const Slice modifiers[] = {u8"\uFE0F" /* variation selector-16 */,
                                    u8"\u200D\u2640" /* zero width joiner + female sign */,
                                    u8"\u200D\u2642" /* zero width joiner + male sign */,
                                    u8"\U0001F3FB" /* emoji modifier fitzpatrick type-1-2 */,
                                    u8"\U0001F3FC" /* emoji modifier fitzpatrick type-3 */,
                                    u8"\U0001F3FD" /* emoji modifier fitzpatrick type-4 */,
                                    u8"\U0001F3FE" /* emoji modifier fitzpatrick type-5 */,
                                    u8"\U0001F3FF" /* emoji modifier fitzpatrick type-6 */};
  const size_t start_index = remove_selectors ? 0 : 1;
  size_t j = 0;
  for (size_t i = 0; i < emoji.size();) {
    bool is_found = false;
    for (size_t k = start_index; k < sizeof(modifiers) / sizeof(*modifiers); k++) {
      auto length = modifiers[k].size();
      if (i + length <= emoji.size() && Slice(&emoji[i], length) == modifiers[k]) {
        // skip the modifier
        i += length;
        is_found = true;
        break;
      }
    }
    if (!is_found) {
      emoji[j++] = emoji[i++];
    }
  }
  if (j != 0) {
    emoji.resize(j);
  }
}

string remove_emoji_selectors(Slice emoji) {
  if (!is_emoji(emoji)) {
    return emoji.str();
  }
  string str;
  for (size_t i = 0; i < emoji.size(); i++) {
    if (i + 3 <= emoji.size() && emoji[i] == '\xEF' && emoji[i + 1] == '\xB8' && emoji[i + 2] == '\x8F') {
      // skip \uFE0F
      i += 2;
    } else {
      str += emoji[i];
    }
  }
  CHECK(is_emoji(str));
  return str;
}

}  // namespace td
