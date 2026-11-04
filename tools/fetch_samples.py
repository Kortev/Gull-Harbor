"""Fetches the recorded instruments tools/music.py plays (into tools/samples/, kept out of git): a few instruments
from two free CC0 libraries by Versilian Studios, Sam Gossner's VCSL (the Versilian Community Sample Library) and
VSCO 2 Community Edition, both public domain (CC0 1.0) on GitHub. Only the files listed below, each checked for its
size; a file already there is left as it is.
Run: python tools/fetch_samples.py"""
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "samples")
REPOS = {"vcsl": "sgossner/VCSL", "vsco": "sgossner/VSCO-2-CE"}

# instrument: [(library, path in it, bytes)]
FILES = {
    'fiddle (solo violin, sustained, soft)': [
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_A3_p.wav', 2911130),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_A4_p.wav', 2612122),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_A5_p.wav', 2562122),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_A6_p.wav', 2614110),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_C4_p.wav', 3096650),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_C5_p.wav', 2498790),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_C6_p.wav', 2358906),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_C7_p.wav', 2274706),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_E4_p.wav', 2600174),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_E5_p.wav', 2517094),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_E6_p.wav', 2514702),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_G3_p.wav', 2788822),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_G4_p.wav', 2594066),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_G5_p.wav', 2596714),
        ('vsco', 'Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_G6_p.wav', 2417222),
    ],
    'upright bass (double bass, plucked)': [
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_A1_v1_rr1.wav', 623260),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_A1_v1_rr2.wav', 485472),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_B2_v1_rr1.wav', 417472),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_B2_v1_rr2.wav', 332204),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_C#2_v1_rr1.wav', 513824),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_C#2_v1_rr2.wav', 498308),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_C1_v1_rr1.wav', 270720),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_C1_v1_rr2.wav', 405984),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_D1_v1_rr1.wav', 856252),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_D1_v1_rr2.wav', 1062672),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_E1_v1_rr1.wav', 294356),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_E1_v1_rr2.wav', 315292),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_E2_v1_rr1.wav', 438040),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_E2_v1_rr2.wav', 595380),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_F#1_v1_rr1.wav', 868632),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_F#1_v1_rr2.wav', 1036836),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_G#1_v1_rr1.wav', 601752),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_G#1_v1_rr2.wav', 537212),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_G#2_v1_rr1.wav', 376048),
        ('vsco', 'Strings/Solo Contrabass/Pizz/BKCtbss_Pizz_G#2_v1_rr2.wav', 273224),
    ],
    'cello (section, sustained, soft)': [
        ('vsco', 'Strings/Cello Section/susvib/susvib_A2_v1_1.wav', 2336738),
        ('vsco', 'Strings/Cello Section/susvib/susvib_B1_v1_1.wav', 2372492),
        ('vsco', 'Strings/Cello Section/susvib/susvib_C3_v1_1.wav', 2444174),
        ('vsco', 'Strings/Cello Section/susvib/susvib_D2_v1_1.wav', 2550956),
        ('vsco', 'Strings/Cello Section/susvib/susvib_E1_v1_1.wav', 2468348),
        ('vsco', 'Strings/Cello Section/susvib/susvib_E3_v1_1.wav', 2456672),
        ('vsco', 'Strings/Cello Section/susvib/susvib_F2_v1_1.wav', 2186012),
        ('vsco', 'Strings/Cello Section/susvib/susvib_G1_v1_1.wav', 2161700),
        ('vsco', 'Strings/Cello Section/susvib/susvib_G3_v1_1.wav', 2431598),
    ],
    'strumstick (fingerpicked)': [
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str1_Main_D2_vl2_rr1.wav', 3466544),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str1_Main_E2_vl2_rr1.wav', 1889636),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str1_Main_F#2_vl2_rr1.wav', 1524986),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str1_Main_G2_vl2_rr1.wav', 1555622),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str2_Main_A2_vl2_rr1.wav', 2448434),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str2_Main_B2_vl2_rr1.wav', 1532882),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str2_Main_C#3_vl2_rr1.wav', 1948022),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str2_Main_D3_vl2_rr1.wav', 2256716),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_A3_vl2_rr1.wav', 2144744),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_A4_vl2_rr1.wav', 339980),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_B3_vl2_rr1.wav', 2108888),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_C#4_vl2_rr1.wav', 1825982),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_D4_vl2_rr1.wav', 1729442),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_E3_vl2_rr1.wav', 1592642),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_E4_vl2_rr1.wav', 1591118),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_F#3_vl2_rr1.wav', 1143626),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_F#4_vl2_rr1.wav', 1035302),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_G3_vl2_rr1.wav', 1750172),
        ('vcsl', 'Chordophones/Composite Chordophones/Strumstick/Finger/Strumstick_Finger_Str3_Main_G4_vl2_rr2.wav', 628832),
    ],
    'folk harp': [
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_A#3_v2_RR1.wav', 691094),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_A#4_v2_RR1.wav', 339042),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_C3_v2_RR1.wav', 1382798),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_C4_v2_RR1.wav', 775134),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_C5_v2_RR1.wav', 366550),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_D3_v2_RR1.wav', 1008386),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_D4_v2_RR1.wav', 955322),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_D5_v2_RR1.wav', 460266),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_E3_v2_RR1.wav', 1177490),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_E4_v2_RR1.wav', 723350),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_E5_v2_RR1.wav', 284994),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_F#3_v2_RR1.wav', 1166902),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_F#4_v2_RR1.wav', 517414),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_F#5_v2_RR1.wav', 276122),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_G#3_v2_RR1.wav', 718130),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_G#4_v2_RR1.wav', 348666),
        ('vcsl', 'Chordophones/Composite Chordophones/Folk Harp/EWHarp_Normal_G#5_v2_RR1.wav', 222890),
    ],
    'recorder (the whistle)': [
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_A#4_rr1_Main.wav', 2148688),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_A#5_rr1_Main.wav', 2064280),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_C4_rr1_Main.wav', 1992312),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_C5_rr1_Main.wav', 2031908),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_C6_rr1_Main.wav', 1979600),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_D4_rr1_Main.wav', 2696024),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_D5_rr1_Main.wav', 2393280),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_E4_rr1_Main.wav', 2616636),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_E5_rr1_Main.wav', 2747436),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_F#4_rr1_Main.wav', 2254524),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_F#5_rr1_Main.wav', 2777292),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_G#4_rr1_Main.wav', 1727644),
        ('vcsl', 'Aerophones/Edge-blown Aerophones/Baroque Soprano Recorder/Sustain/SopRecorder_Sus_G5_rr1_Main.wav', 2469240),
    ],
    'harmonica (the reed)': [
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _C2.wav', 539142),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _C3.wav', 634830),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _C4.wav', 644312),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _C5.wav', 635444),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _C6.wav', 594824),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _E2.wav', 644774),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _E3.wav', 709116),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _E4.wav', 730404),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _E5.wav', 708864),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _G2.wav', 640310),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _G3.wav', 724836),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _G4.wav', 600588),
        ('vcsl', 'Aerophones/Free Aerophones/Harmonica-Hohner-Super64/Sustains/Normal/Hohner-Super64_Normal _G5.wav', 689304),
    ],
    'frame drum': [
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumL_Hand_rr1_Sum.wav', 205484),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumL_HitMuted_v2_rr1_Sum.wav', 305388),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumL_HitMuted_v2_rr2_Sum.wav', 287200),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumL_HitMuted_v3_rr1_Sum.wav', 301668),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumL_HitMuted_v3_rr2_Sum.wav', 326976),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumL_Hit_v2_rr1_Sum.wav', 659856),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumL_Hit_v2_rr2_Sum.wav', 607780),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumL_Hit_v3_rr1_Sum.wav', 637712),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumL_Hit_v3_rr2_Sum.wav', 575896),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumS_Hand_v1_rr1_Sum.wav', 148516),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumS_HitMuted_v2_rr1_Sum.wav', 180420),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumS_HitMuted_v2_rr2_Sum.wav', 164000),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumS_HitMuted_v3_rr1_Sum.wav', 173168),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumS_HitMuted_v3_rr2_Sum.wav', 175876),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumS_Hit_v2_rr1_Sum.wav', 456272),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumS_Hit_v2_rr2_Sum.wav', 377260),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumS_Hit_v3_rr1_Sum.wav', 370992),
        ('vcsl', 'Membranophones/Struck Membranophones/Frame Drum/HDrumS_Hit_v3_rr2_Sum.wav', 491912),
    ],
    'giant hand drum (the war drums)': [
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/hand/EthnicLargeHand_hit_f_1.wav', 327544),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/hand/EthnicLargeHand_hit_f_2.wav', 286996),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/hand/EthnicLargeHand_hit_ff_1.wav', 277636),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/hand/EthnicLargeHand_hit_ff_2.wav', 233974),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/hand/EthnicLargeHand_hit_mp_1.wav', 308830),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/hand/EthnicLargeHand_hit_mp_2.wav', 187186),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/hand/EthnicLargeHand_hit_pp_1.wav', 302590),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/hand/EthnicLargeHand_hit_pp_2.wav', 212140),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/mallet/EthnicLargeMallet_hit_f_1.wav', 399286),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/mallet/EthnicLargeMallet_hit_ff_1.wav', 396166),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/mallet/EthnicLargeMallet_hit_ff_2.wav', 411760),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/mallet/EthnicLargeMallet_hit_mf_1.wav', 371212),
        ('vsco', 'VSCO 1 Percussion/drums/other/ethnic/giant/mallet/EthnicLargeMallet_hit_pp_1.wav', 258922),
    ],
    'timpani': [
        ('vsco', 'Percussion/Timpani/Timpani1_Hit_v3_rr1_Sum.wav', 1602676),
        ('vsco', 'Percussion/Timpani/Timpani2_Hit_v3_rr1_Sum.wav', 1895164),
        ('vsco', 'Percussion/Timpani/Timpani3_Hit_v3_rr1_Sum.wav', 1608252),
        ('vsco', 'Percussion/Timpani/Timpani4_Hit_v3_rr1_Sum.wav', 1012976),
        ('vsco', 'Percussion/Timpani/Timpani5_Hit_v3_rr1_Sum.wav', 1036528),
    ],
    'shaker': [
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerDouble_Down_rr1.wav', 46844),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerDouble_Down_rr2.wav', 46652),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerDouble_Up_rr1.wav', 22352),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerDouble_Up_rr2.wav', 29168),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerHighFaster_Down_rr1.wav', 31556),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerHighFaster_Down_rr2.wav', 24012),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerHighFaster_Up_rr1.wav', 32196),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerHighFaster_Up_rr2.wav', 24672),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerLowFaster_Down_rr1.wav', 29920),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerLowFaster_Down_rr2.wav', 20440),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerLowFaster_Up_rr1.wav', 21020),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_ShakerLowFaster_Up_rr2.wav', 14620),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_Shaker_Roll_Fast_rr1.wav', 451540),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_Shaker_Roll_Fast_rr2.wav', 775688),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_Shaker_Slap_rr1.wav', 120316),
        ('vcsl', 'Idiophones/Struck Idiophones/Shaker, Small/Mid_Shaker_Slap_rr2.wav', 124008),
    ],
    'claps': [
        ('vcsl', 'Idiophones/Struck Idiophones/Claps/Clap_rr1.wav', 141974),
        ('vcsl', 'Idiophones/Struck Idiophones/Claps/Clap_rr2.wav', 136950),
        ('vcsl', 'Idiophones/Struck Idiophones/Claps/Clap_rr3.wav', 132222),
        ('vcsl', 'Idiophones/Struck Idiophones/Claps/Clap_rr4.wav', 147686),
        ('vcsl', 'Idiophones/Struck Idiophones/Claps/Clap_rr5.wav', 126446),
        ('vcsl', 'Idiophones/Struck Idiophones/Claps/Clap_rr6.wav', 89770),
    ],
    'cymbal (soft mallet hit, swell)': [
        ('vsco', 'VSCO 1 Percussion/varMetal/Cymbals/susp/susp_hit_softmall_f.wav', 1490614),
        ('vsco', 'VSCO 1 Percussion/varMetal/Cymbals/susp/susp_hit_softmall_roll2_cresc.wav', 2547556),
    ],
    'glockenspiel': [
        ('vcsl', 'Idiophones/Struck Idiophones/Glockenspiel/glock_medium_C5_01.wav', 1271310),
        ('vcsl', 'Idiophones/Struck Idiophones/Glockenspiel/glock_medium_C6_01.wav', 1271310),
        ('vcsl', 'Idiophones/Struck Idiophones/Glockenspiel/glock_medium_C7_01.wav', 492418),
        ('vcsl', 'Idiophones/Struck Idiophones/Glockenspiel/glock_medium_G4_01.wav', 1271310),
        ('vcsl', 'Idiophones/Struck Idiophones/Glockenspiel/glock_medium_G5_01.wav', 1226714),
        ('vcsl', 'Idiophones/Struck Idiophones/Glockenspiel/glock_medium_G6_01.wav', 843122),
    ],
    'hand chimes': [
        ('vcsl', 'Idiophones/Struck Idiophones/Hand Chimes/sus_A4_r01_main.wav', 2349762),
        ('vcsl', 'Idiophones/Struck Idiophones/Hand Chimes/sus_C4_r01_main.wav', 2177592),
        ('vcsl', 'Idiophones/Struck Idiophones/Hand Chimes/sus_C5_r01_main.wav', 1894740),
        ('vcsl', 'Idiophones/Struck Idiophones/Hand Chimes/sus_D4_r01_main.wav', 2595720),
        ('vcsl', 'Idiophones/Struck Idiophones/Hand Chimes/sus_D5_r01_main.wav', 2411250),
        ('vcsl', 'Idiophones/Struck Idiophones/Hand Chimes/sus_E4_r01_main.wav', 1827102),
        ('vcsl', 'Idiophones/Struck Idiophones/Hand Chimes/sus_F#4_r01_main.wav', 1218348),
        ('vcsl', 'Idiophones/Struck Idiophones/Hand Chimes/sus_F#5_r01_main.wav', 1531950),
    ],
    'ocean drum': [
        ('vcsl', 'Membranophones/Other Membranophones/Ocean Drum/OceanDrum_Sus_2_Mid.wav', 3966032),
    ],
}


def local(lib, path):
    return os.path.join(OUT, lib, *path.split("/"))


def main():
    todo = [(lib, path, size) for files in FILES.values() for lib, path, size in files]
    total = sum(s for _, _, s in todo)
    print("%d files, %.1f MB, into %s" % (len(todo), total / 1e6, OUT))
    for lib, path, size in todo:
        to = local(lib, path)
        if os.path.exists(to) and os.path.getsize(to) == size:
            continue
        os.makedirs(os.path.dirname(to), exist_ok=True)
        url = "https://raw.githubusercontent.com/%s/master/%s" % (REPOS[lib], urllib.parse.quote(path))
        with urllib.request.urlopen(url) as r, open(to + ".part", "wb") as f:
            f.write(r.read())
        got = os.path.getsize(to + ".part")
        if got != size:
            os.remove(to + ".part")
            sys.exit("%s: %d bytes, expected %d" % (path, got, size))
        os.replace(to + ".part", to)
        print("  %s" % path)
    # (Godot leaves the folder alone: no imports of 200 MB of recordings, nothing of it in a build)
    open(os.path.join(OUT, ".gdignore"), "w").close()
    print("done")


if __name__ == "__main__":
    main()
