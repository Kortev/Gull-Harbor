extends RefCounted
## Made by tools/music.py (don't edit by hand): each cue in res://music/, what kind it is, its files, its
## timing (bpm: beats a minute, bar_beats, bars), whether it loops, its stems; stings their hit (s in).

const CUES := {
	 "afterglow": {
	  "bar_beats": 4,
	  "bars": 10,
	  "bpm": 112.0,
	  "files": [
	   "afterglow"
	  ],
	  "kind": "bed",
	  "length": 26.817125,
	  "loop": false,
	  "stems": [
	   "main"
	  ]
	 },
	 "countdown": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "countdown"
	  ],
	  "hit": 10.0,
	  "kind": "sting",
	  "loop": false,
	  "pre": 0.06
	 },
	 "fight": {
	  "bar_beats": 4,
	  "bars": 16,
	  "bpm": 112.0,
	  "files": [
	   "fight_bed",
	   "fight_pulse",
	   "fight_drive",
	   "fight_shaker",
	   "fight_click",
	   "fight_tension",
	   "fight_tension_hi",
	   "fight_deep",
	   "fight_tune"
	  ],
	  "kind": "bed",
	  "length": 34.28571875,
	  "loop": true,
	  "stems": [
	   "bed",
	   "pulse",
	   "drive",
	   "shaker",
	   "click",
	   "tension",
	   "tension_hi",
	   "deep",
	   "tune"
	  ]
	 },
	 "gaff": {
	  "bar_beats": 4,
	  "bars": 4,
	  "bpm": 112.0,
	  "files": [
	   "gaff_bed",
	   "gaff_pulse",
	   "gaff_shimmer"
	  ],
	  "kind": "bed",
	  "length": 8.5714375,
	  "loop": true,
	  "stems": [
	   "bed",
	   "pulse",
	   "shimmer"
	  ]
	 },
	 "harbour": {
	  "bar_beats": 3,
	  "bars": 16,
	  "bpm": 84.0,
	  "files": [
	   "harbour_guitar",
	   "harbour_reed"
	  ],
	  "kind": "bed",
	  "length": 34.28571875,
	  "loop": true,
	  "stems": [
	   "guitar",
	   "reed"
	  ]
	 },
	 "hunt": {
	  "bar_beats": 4,
	  "bars": 8,
	  "bpm": 112.0,
	  "files": [
	   "hunt_pulse",
	   "hunt_tick",
	   "hunt_glint"
	  ],
	  "kind": "bed",
	  "length": 17.14284375,
	  "loop": true,
	  "stems": [
	   "pulse",
	   "tick",
	   "glint"
	  ]
	 },
	 "lead_down": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "lead_down"
	  ],
	  "hit": 0.0,
	  "kind": "sting",
	  "loop": false,
	  "pre": 0.06
	 },
	 "lead_up": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "lead_up"
	  ],
	  "hit": 0.0,
	  "kind": "sting",
	  "loop": false,
	  "pre": 0.06
	 },
	 "leader": {
	  "bar_beats": 4,
	  "bars": 8,
	  "bpm": 112.0,
	  "files": [
	   "leader_bed",
	   "leader_pulse",
	   "leader_drive",
	   "leader_shaker",
	   "leader_click",
	   "leader_tension",
	   "leader_tension_hi",
	   "leader_deep",
	   "leader_tune"
	  ],
	  "kind": "bed",
	  "length": 17.14284375,
	  "loop": true,
	  "stems": [
	   "bed",
	   "pulse",
	   "drive",
	   "shaker",
	   "click",
	   "tension",
	   "tension_hi",
	   "deep",
	   "tune"
	  ]
	 },
	 "leader_in": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 112.0,
	  "files": [
	   "leader_in"
	  ],
	  "kind": "filler",
	  "length": 1.0714285714285714,
	  "loop": false,
	  "pre": 0.06
	 },
	 "lose": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "lose"
	  ],
	  "hit": 0.0,
	  "kind": "sting",
	  "loop": false,
	  "pre": 0.06
	 },
	 "race": {
	  "bar_beats": 2,
	  "bars": 32,
	  "bpm": 104.0,
	  "files": [
	   "race_a",
	   "race_b",
	   "race_c",
	   "race_d"
	  ],
	  "kind": "bed",
	  "length": 36.9230625,
	  "loop": true,
	  "stems": [
	   "a",
	   "b",
	   "c",
	   "d"
	  ]
	 },
	 "sea_a": {
	  "bar_beats": 4,
	  "bars": 8,
	  "bpm": 112.0,
	  "bright": true,
	  "files": [
	   "sea_a_pad",
	   "sea_a_bass",
	   "sea_a_pick",
	   "sea_a_lead",
	   "sea_a_rain",
	   "sea_a_storm",
	   "sea_a_night"
	  ],
	  "kind": "bed",
	  "length": 17.14284375,
	  "loop": true,
	  "stems": [
	   "pad",
	   "bass",
	   "pick",
	   "lead",
	   "rain",
	   "storm",
	   "night"
	  ]
	 },
	 "sea_b": {
	  "bar_beats": 4,
	  "bars": 8,
	  "bpm": 112.0,
	  "bright": true,
	  "files": [
	   "sea_b_pad",
	   "sea_b_bass",
	   "sea_b_pick",
	   "sea_b_lead",
	   "sea_b_rain",
	   "sea_b_storm",
	   "sea_b_night"
	  ],
	  "kind": "bed",
	  "length": 17.14284375,
	  "loop": true,
	  "stems": [
	   "pad",
	   "bass",
	   "pick",
	   "lead",
	   "rain",
	   "storm",
	   "night"
	  ]
	 },
	 "sea_c": {
	  "bar_beats": 4,
	  "bars": 8,
	  "bpm": 112.0,
	  "bright": false,
	  "files": [
	   "sea_c_pad",
	   "sea_c_bass",
	   "sea_c_pick",
	   "sea_c_lead",
	   "sea_c_rain",
	   "sea_c_storm",
	   "sea_c_night"
	  ],
	  "kind": "bed",
	  "length": 17.14284375,
	  "loop": true,
	  "stems": [
	   "pad",
	   "bass",
	   "pick",
	   "lead",
	   "rain",
	   "storm",
	   "night"
	  ]
	 },
	 "sea_d": {
	  "bar_beats": 4,
	  "bars": 8,
	  "bpm": 112.0,
	  "bright": false,
	  "files": [
	   "sea_d_pad",
	   "sea_d_bass",
	   "sea_d_pick",
	   "sea_d_lead",
	   "sea_d_rain",
	   "sea_d_storm",
	   "sea_d_night"
	  ],
	  "kind": "bed",
	  "length": 17.14284375,
	  "loop": true,
	  "stems": [
	   "pad",
	   "bass",
	   "pick",
	   "lead",
	   "rain",
	   "storm",
	   "night"
	  ]
	 },
	 "sea_e": {
	  "bar_beats": 4,
	  "bars": 8,
	  "bpm": 112.0,
	  "bright": true,
	  "files": [
	   "sea_e_pad",
	   "sea_e_bass",
	   "sea_e_pick",
	   "sea_e_lead",
	   "sea_e_rain",
	   "sea_e_storm",
	   "sea_e_night"
	  ],
	  "kind": "bed",
	  "length": 17.14284375,
	  "loop": true,
	  "stems": [
	   "pad",
	   "bass",
	   "pick",
	   "lead",
	   "rain",
	   "storm",
	   "night"
	  ]
	 },
	 "sea_f": {
	  "bar_beats": 4,
	  "bars": 8,
	  "bpm": 112.0,
	  "bright": false,
	  "files": [
	   "sea_f_pad",
	   "sea_f_bass",
	   "sea_f_pick",
	   "sea_f_lead",
	   "sea_f_rain",
	   "sea_f_storm",
	   "sea_f_night"
	  ],
	  "kind": "bed",
	  "length": 17.14284375,
	  "loop": true,
	  "stems": [
	   "pad",
	   "bass",
	   "pick",
	   "lead",
	   "rain",
	   "storm",
	   "night"
	  ]
	 },
	 "strike": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "strike"
	  ],
	  "hit": 0.0,
	  "kind": "sting",
	  "loop": false,
	  "pre": 0.06
	 },
	 "their_on": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "their_on"
	  ],
	  "hit": 0.0,
	  "kind": "sting",
	  "loop": false,
	  "pre": 0.06
	 },
	 "tie": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "tie"
	  ],
	  "hit": 0.0,
	  "kind": "sting",
	  "loop": false,
	  "pre": 0.06
	 },
	 "tired": {
	  "bar_beats": 4,
	  "bars": 16,
	  "bpm": 112.0,
	  "files": [
	   "tired_bed",
	   "tired_pulse",
	   "tired_drive",
	   "tired_shaker",
	   "tired_click",
	   "tired_tension",
	   "tired_tension_hi",
	   "tired_deep",
	   "tired_tune"
	  ],
	  "kind": "bed",
	  "length": 34.28571875,
	  "loop": true,
	  "stems": [
	   "bed",
	   "pulse",
	   "drive",
	   "shaker",
	   "click",
	   "tension",
	   "tension_hi",
	   "deep",
	   "tune"
	  ]
	 },
	 "title": {
	  "bar_beats": 2,
	  "bars": 32,
	  "bpm": 66.0,
	  "files": [
	   "title"
	  ],
	  "kind": "bed",
	  "length": 58.18181818181819,
	  "loop": true,
	  "stems": [
	   "main"
	  ]
	 },
	 "win": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "win"
	  ],
	  "hit": 0.0,
	  "kind": "sting",
	  "loop": false,
	  "pre": 0.06
	 }
	}
