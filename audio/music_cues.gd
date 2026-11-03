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
	  "length": 26.84921875,
	  "loop": false,
	  "stems": [
	   "main"
	  ]
	 },
	 "calm_1": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "calm_1"
	  ],
	  "kind": "phrase",
	  "loop": false,
	  "mood": "calm"
	 },
	 "calm_2": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "calm_2"
	  ],
	  "kind": "phrase",
	  "loop": false,
	  "mood": "calm"
	 },
	 "calm_3": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "calm_3"
	  ],
	  "kind": "phrase",
	  "loop": false,
	  "mood": "calm"
	 },
	 "calm_4": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "calm_4"
	  ],
	  "kind": "phrase",
	  "loop": false,
	  "mood": "calm"
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
	 "dawn": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "dawn"
	  ],
	  "kind": "phrase",
	  "length": 25.0145625,
	  "loop": false,
	  "mood": "dawn"
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
	 "fog_1": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "fog_1"
	  ],
	  "kind": "phrase",
	  "length": 20.31396875,
	  "loop": false,
	  "mood": "fog"
	 },
	 "fog_2": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "fog_2"
	  ],
	  "kind": "phrase",
	  "length": 18.47290625,
	  "loop": false,
	  "mood": "fog"
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
	 "night_1": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "night_1"
	  ],
	  "kind": "phrase",
	  "length": 22.12215625,
	  "loop": false,
	  "mood": "night"
	 },
	 "night_2": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "night_2"
	  ],
	  "kind": "phrase",
	  "length": 21.30984375,
	  "loop": false,
	  "mood": "night"
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
	 "rain_1": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "rain_1"
	  ],
	  "kind": "phrase",
	  "length": 22.45353125,
	  "loop": false,
	  "mood": "rain"
	 },
	 "rain_2": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "rain_2"
	  ],
	  "kind": "phrase",
	  "length": 21.2343125,
	  "loop": false,
	  "mood": "rain"
	 },
	 "storm_1": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "storm_1"
	  ],
	  "kind": "phrase",
	  "length": 17.9634375,
	  "loop": false,
	  "mood": "storm"
	 },
	 "storm_2": {
	  "bar_beats": 4,
	  "bars": 0,
	  "bpm": 0.0,
	  "files": [
	   "storm_2"
	  ],
	  "kind": "phrase",
	  "length": 17.024125,
	  "loop": false,
	  "mood": "storm"
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
