# Bluefin fight rebuild: build spec ("Loaded Rod, Crewed")

I read these before writing this: `tuna/fight.gd` (all 467 lines), `rods/rods.gd` (`_process`, `_fight_mine`, `_fight_holder`, `_new_fight`, `_take`, `rub_on_hull`, `_in_hands`, the rpcs), `rods/rod.gd`, `crew/player.gd` (input, camera, `arms`), `tuna/landing.gd`, `boat/kinds.gd`, `boat/chair.gd`, `ui/hud.gd`, `ui/tips.gd`, `ui/manual.gd`, `tests/fight_test.gd`, and the fight loops in `tests/strike_test.gd`, `tests/trip_test.gd` and `tests/rods_test.gd`.

I also built a Python prototype of the 1-D tension model, to get starting numbers before any GDScript exists: `C:\Users\gamek\AppData\Local\Temp\claude\C--Users-gamek-Documents-GitHub-Gull-Harbor\2f0f37a0-da73-469a-8dc6-8f9d8de69ee6\scratchpad\full_t.py`. Its results are in §11.

---

## 0. Cut lines

Each stage leaves the game playable and all tests green. The order is fixed. Stop at any line.

| Stage | What | Ships alone because |
|---|---|---|
| **A, Day 1 (tonight)** | The spring and tension core, hook hold, jumps, side pressure, rod aim apart from the camera, the camera rule, solo scroll drag, all fight text removed, the bot harness (built first), a quick fix to the false hull rub | A whole new fight that plays end to end. The landing is unchanged. |
| **B, Day 2** | `tuna/hull_wrap.gd` (real line contact, the user's tug complaint), the rod and line feel pass (bend toward the contact point, creak, grind, click, ping-and-coil, spool and backing), the fish visible in the last 30 m | Pure upgrades to what Stage A reads and draws. |
| **C, Day 3** | The pacing director and its fixed beats (second wind, comeback, wallow, lunge, bow circle), the mate's drag lever, the mate fending the line off the rail, the director tests | Each beat is behind `Fight.director := true`. The lever and fending are extra roles; solo play is already complete. |

**Not in scope, said plainly:**
- **Rivals 1v1** is watch-only: each boat fights its own fish with scroll drag, and you see the other rod bend across the water. Rival interaction (engine spooking) is a follow-up.
- **landing.gd is unchanged.** The proposal's "crewmate gaffs it" is the existing wire, harpoon and haul, which is already a crewmate's job.
- No stamina, no binoculars, no sonar or radar on the skiff.
- No settings menu exists, so "Rod weight" is a const `ROD_WEIGHT := 1.0` in rods.gd. A slider is a follow-up.

---

## 1. Text removed (all in Stage A)

| Where | Remove | Replace with |
|---|---|---|
| `fight.gd` | `TELLS`, `tell()`, `answer()`, `_pump`, `_lift_low`, the per-answer strain `target` block, `STRAIN_GRACE`, `SLACK_GRACE`, `_slack_t`, `arms`, `arms_mul`, `ARMS_*`, `RUB_ALL`, `HULL_MARGIN`, `rub()` (in Stage B; Stage A keeps `rub_now`) | §4 |
| `rods.gd _process`, the `mine` branch (lines 647-660) | The tell, the ring (`wrong`), the "N m out · gaining · fish tiring" line, `_trend` | `hud.call("fight", "", 0.0)`: empty tell, no ring, line hidden |
| `rods.gd _process`, the captain block (673-704) | "Keep the stern on it!", "OUT OF GEAR!…", "Death spiral! Out of gear…", "It's under her!…", "It's on the hull!…", and `hud.call("plot", …)` | Nothing. The captain reads the line. See §6.6 for the prop warning sound. |
| `rods.gd WHY` | All six advice strings | One 3 s caption per loss, from `_off`: `broke`: "Line parted." · `broke_rail`: "Line parted on the rail." · `pulled`: "Hook pulled." · `thrown`: "Thrown on the jump." · `spooled`: "Spooled." · `chafed`: "Chafed through on the hull." · `cut`: "Cut on the props." · `tangle`: "Lines tangled and parted." |
| `crew/player.gd` | `var arms` (46-47), the `REST` regen (544), `const REST` | |
| `ui/hud.gd` | `_draw_ring`'s arms arc, and `plot`/`_draw_plot` (delete them, or leave them uncalled) | |
| `ui/tips.gd` "fight" | The ring and answer text | Dale, once: "Rod bent, he's pulling. Reel screaming, hands off the crank. Reel grinding, stop winding and pump: lift slow, wind as you drop. Lay the rod over against the way he's swimming and you'll turn his head. He jumps, drop the tip." |
| `ui/tips.gd` "spiral" | | "Colour! Wind while he comes up, ease off while he goes under her. Captain, out of gear." |
| `ui/manual.gd` §6 | The answer list | The control list from §2 |

These stay: "FISH ON! The x rod!", "You've got it!", the interact prompts, and the landing and fish-hold hints. Those are not the fight.

---

## 2. Input mapping

**Angler (holding a rod with a fish on):**

| Input | Effect |
|---|---|
| Mouse Y | Rod elevation `aim_pitch`, 0.15 (tip at the water) to 1.35 (near vertical), at 0.0035 rad/px × `look_scale`. Mouse up raises it. |
| Mouse X | Rod laid over, `aim_side`, ±0.9 rad from the line, at 0.003 rad/px. Yaw sense: + is left of the line. Movement past ±0.9 **spills** into camera yaw `_look_off` (±1.4 rad), which eases back to 0 at 0.8 rad/s once there has been no spill for 1 s. This replaces the Alt glance (boss note 4): you always own a look. |
| LMB (hold) | Crank (`use_primary`). |
| RMB (hold) | Raise the rod at 0.9 rad/s (`use_secondary`), a trackpad alias for the heave. |
| Wheel up / down | Drag one detent tighter / looser: FREE 0.0, LIGHT 0.45, STRIKE 0.72, FULL 0.95. At most one notch per 0.2 s. Locked while a mate holds the lever (Stage C). |
| WASD / Space | Walk / jump, as now. The rod moves with you. |
| Q | Rod into its holder (`drop`), as now. |
| E | Unchanged. Taking over a crewmate's rod works as now. |

The `rod_reel`, `rod_brace`, `rod_left` and `rod_right` actions already in `project.godot` stay unused. `slot_next` and `slot_prev` (the wheel) have no code users, so the wheel is free.

**Captain:** the helm as now (W/S throttle, A/D wheel). No fight UI.

**Mate (Stage C):**

| Input | Effect |
|---|---|
| E on a fishing rod's reel within 1.3 m | Take the drag lever |
| Mouse Y | Lever, continuous 0..1, at 0.002/px, with sticky zones ±0.03 at each detent |
| Mouse X | Looks as normal |
| E again, or walking more than 1.6 m away | Let go. The lever stays where it was left. |
| Hold E within 1.2 m of the line's contact point ("Fend the line") | Fend it off the rail |

---

## 3. Rod aim and camera (Stage A)

This fixes the lease bug in boss note 2 by having **rods.gd pull** the mouse instead of player.gd pushing a weight.

### crew/player.gd (about 30 lines)

```gdscript
var rod_lease_frame := -10        # rods.gd stamps Engine.get_process_frames() every frame you fight
var lease_kind := "rod"           # "rod": both mouse axes go to fight_mouse; "lever": only Y (Stage C)
var fight_mouse := Vector2.ZERO   # raw px, consumed (and zeroed) by rods.gd
var cam_goal := Vector2(NAN, NAN) # (yaw, pitch) in your own _yaw/_pitch terms, set by rods.gd

func leased() -> bool:
	return Engine.get_process_frames() - rod_lease_frame <= 1   # (input runs before rods' _process)
```

In `_input`: if `leased()` and the mouse is captured, add `m.relative * look_scale` to `fight_mouse` (for "lever", only `.y`; X still turns `_yaw`) and return.

In `_process`, before setting `head.global_basis`: if `leased()` and `cam_goal` is valid, ease toward it:

```gdscript
var k := 1.0 - exp(-8.0 * delta)
_yaw += clampf(wrapf(cam_goal.x - _yaw, -PI, PI) * k, -6.0 * delta, 6.0 * delta)
_pitch += clampf((cam_goal.y - _pitch) * k, -6.0 * delta, 6.0 * delta)
```

If the lease isn't fresh, you get normal mouse look. Every exit path (Q, a handover, a loss, landing, death, disconnect, pause) restores normal look on the next frame, because nothing stamps the lease any more.

### rods.gd `_aim(r, me, delta)` (called from `_fight_mine`)

1. `var m := me.fight_mouse; me.fight_mouse = Vector2.ZERO`.
2. `T := r.strain`.
3. Pitch:
   - `dp := -m.y * 0.0035`.
   - If `dp > 0`: `dp *= 1.0 - 0.55 * T * ROD_WEIGHT` (the rod is heavier going up).
   - `r.aim_pitch += dp + (0.9 * delta if RMB else 0.0)`.
   - If `T > 0.3`: `r.aim_pitch -= 0.35 * T * ROD_WEIGHT * delta` (the fish drags the tip down).
   - Clamp to 0.15..1.35.
4. Side:
   - `var s := r.aim_side - m.x * 0.003`.
   - `var spill := s - clampf(s, -0.9, 0.9)`.
   - `r.aim_side = clampf(s, -0.9, 0.9)`.
   - `_look_off = clampf(_look_off + spill, -1.4, 1.4)`.
   - Ease `_look_off` back as described in §2.
   - While `r.slipping`: `r.aim_side = move_toward(r.aim_side, 0, 0.08 * T * delta)` (a run pulls the rod round to the fish).
5. Test hook: `var bot_aim := Vector3(NAN, 0, 0)`. If `bot_aim.x` is not NaN, `aim_pitch = bot_aim.x` and the fight-sense side is `bot_aim.y`. Skip steps 3 and 4.
6. Geometry, in the boat frame:
   - `hands := p.global_transform * Vector3(0.2, 0.95, -0.3)`.
   - `d := boat.global_basis.inverse() * (r.line_end - hands)`.
   - `line_yaw := atan2(-d.x, -d.z)`. (The player's forward is `(-sin yaw, 0, -cos yaw)`.)
   - `entry_pitch := clampf(atan2(dy, horiz) from head to r.line_end, -0.75, 0.05)`.
7. Camera goal:
   - `yaw = line_yaw + 0.4 * r.aim_side + _look_off`.
   - `pitch = clampf(entry_pitch + 0.35 * (r.aim_pitch - 0.75), entry_pitch - 0.12, entry_pitch + 0.28)`.
   - Then `me.cam_goal = …; me.rod_lease_frame = Engine.get_process_frames()`.
8. Fight-sense side (+ = toward increasing bearing):
   - `left := Vector2(-cos(line_yaw), sin(line_yaw))` in (x, z).
   - `dir_b := Vector2(cos(r.bearing), -sin(r.bearing))`.
   - `side_fight := clampf(r.aim_side / 0.9, -1, 1) * signf(left.dot(dir_b))`.

### rods.gd `_in_hands(p, r)` (the signature changes from `lift` to `r`)

- If `r.hooked and not r.alongside`:
  - `rod_yaw := line_yaw + r.aim_side`.
  - `rel := clampf(wrapf(rod_yaw - p._yaw, -PI, PI), -1.2, 1.2)`.
  - Basis: `p.global_basis * Basis(UP, rel) * Basis(RIGHT, r.aim_pitch) * Basis(UP, PI)`.
- Otherwise, as today (`0.55 + pitch * 0.6`).

`aim_pitch` is the rod's elevation above the deck plane: `Basis(RIGHT, a) * Basis(UP, PI)` lifts the tip by `a`. Every peer runs this from the synced `aim_pitch`/`aim_side`, so everyone sees the real rod angle.

`_set_holder` and `_strike` reset `r.aim_pitch = 0.6`, `r.aim_side = 0.0`, `_look_off = 0`.

---

## 4. Fish model: tuna/fight.gd (Stage A, about 250 of 467 lines change)

### API

```gdscript
func _init(weight_kg: float, out: float, fresh := 1.0, seed_value := -1, strike_seed := -1)
func step(dt: float, crank: float, rod_pitch: float, side: float, drag_set: float, contact := {}) -> void
func cues() -> Dictionary
func carry_on(m: String, stretch_was := 0.0, turn := 0.0, hold_was := 1.0, beats_was := 0) -> void
```

- `seed_value` drives the noise (strike seed + free_t, as now).
- `strike_seed` drives the director's triggers in Stage C, so a handover never rerolls the comeback.
- `contact` is `{angle: float, slide: float}` from HullWrap, or empty.

### Kept

`line_out`, `energy`, `bearing`, `depth`, `move`, `throttle`, `boat_vel`, `moving`, `in_holder`, the hull outline vars, `tip`, `reach`, `corner_tip()` (headless tip), `tangled`, `wear`, `chafe`, `rub_now` (Stage A only), the prop cut (`UNDER`, raise `PROP_GRACE` to 2.5), `TANGLE_LIFE`, `BACK_SPEED`, `TOW`, `CAPACITY`, `BOATSIDE`, `SPIRAL_IN`, `_going_under`, the spiral geometry, the signals.

`strain` is kept as the name for T, so the `rods.gd` plumbing survives.

### New state

`stretch` (m, negative means slack), `T`, `shock`, `bind`, `slipping`, `paying` (m/s), `wind` (m/s actually wound), `grinding`, `hold` (1 → 0), `airborne`, `_fv` (fish speed along the line, m/s, + away), `_tip_was`, `_jit`, `_low_t`, `_over_t`, `_side_t`, `_toward_t`, `_thrown_t`, `grace` (0.5 after any `_new_fight`), `beats` (bitmask, Stage C).

### Constants (the four ★ are the knobs that matter, boss note 5)

| Const | Value | Meaning |
|---|---|---|
| ★ `REEL_STALL` | 0.42 | T where cranking stops winning line. `eff = clamp((REEL_STALL - T) / (REEL_STALL - 0.2), 0, 1)`, and `eff = 1` while slack. This is what makes the pump matter. |
| ★ `PULL_IN` | 6.0 | m/s per T unit that a fish gives when T > its pull (max 3 m/s) |
| ★ `TIRE`, `LIFT` | 0.25, 4.0 | Energy: `(TIRE*T*(0.4+thrust) + LIFT*T*max(0,-_fv)) * dt / _goal_s`. Lifting it toward you is what tires it. |
| ★ `SPRING_BASE`, `SPRING_PER_M` | 0.8, 0.012 | m of stretch per unit T. Long line is soft; short line is stiff and dangerous. |
| `_goal_s` | 40 + 0.25·kg | |
| `E_FLOOR` | 0.15 | `e = E_FLOOR + (1 - E_FLOOR) * energy` (was 0.35: a beaten fish must come easily) |
| `SIZE(kg)` | min(0.35 + kg/285, 1.9) | Pull scale. 30 kg 0.46, 150 kg 0.88, 300 kg 1.40. |
| `TAU(kg)` | 0.4 + kg/400 s | The fish's inertia. Its speed eases toward target, so a fast drop after a heave leaves slack to wind. |
| `CRANK` | 2.4 m/s × crank_mul | As now |
| `RUN_SPEED` | 9.0 | Cap: `RUN_SPEED * e * thrust` |
| `ROD_REACH` | 1.7 m | Tip travel along the line over 0.15..1.35 rad |
| `TIP_H` | 2.0 m | Tip height for the headless line elevation |
| `DETENTS` | [0, 0.45, 0.72, 0.95] | |
| `BIND_MAX`, `BIND_RATE` | 0.4, 1.2/s | Cranking into a slipping drag adds T (the creak, then the snap) |
| `BREAK_HOLD` | 0.5 s (+0.25 with heavy line; replaces grace_add 0.6) | T_fish ≥ 1.0 this long breaks the line. `SNAP` 1.35 breaks it at once. |
| `CAPSTAN_MU` | 0.25 | `T_fish = (T + bind + shock + tangle) * exp(MU * contact.angle)` |
| `HOLD_SHOCK`, `HOLD_SLACK`, `AIR_WEAR`, `HOLD_HEAL` | 4.0, 0.5, 3.0, 0.05/s | Hook hold |
| `SHAKE_SHOCK`, `REENTRY` | 0.35, 0.6 | |
| `REGAIN` | lerp(0.02, 0.012, clamp((kg-40)/260, 0, 1)) /s | Breath back after 1 s with T < 0.15 |
| `SLACK_MAX` | 8 m | |
| `SIDE_TURN`, `SIDE_TIRE`, `HEAD_TURN_T` | 0.7, 0.5, 2.0 s | Side pressure |

### MOVES (replace the table)

`answer` is gone. `k` is how fast the fish takes line: (pull - T) × k m/s.

| move | thrust | away | k | turn | depth | dur s | head_motion |
|---|---|---|---|---|---|---|---|
| run | 1.0 | 1.0 | 12 | 0.10 | 20 | 5-12 | 0.25 |
| sound | 0.8 | 0.8 | 6 | 0.04 | 110 | 6-10 | 0.25 |
| dog (alias "rest") | 0.45 | 0.6 | 3 | 0.03 | 60 | 4-8 | 0.25 |
| shake | 0.6 ± 0.3 at 3.5 Hz | 0.5 | 3 | 0.06 | 15 | 1.5-2.5 | 1.0 |
| circle | 0.6 | 0.35 | 3 | 0.25 (×1.6 under 60 kg) | 50 | 6-10 | 0.25 |
| surge | 1.0 | 1.0 | 12 | 0.15 | 10 | 1-2 | 1.0 |
| jump | see below | | | 0.0 | → 0 | 1.6 | 2.5 airborne |
| spiral | 0.35 | 0.25 up / 0.8 going under | 3 | 0.3 | as now | 6-9 | 0.25 |

- `_pick()` weights: run 2e (0 if the last move was a run), sound 3, shake 1.2 (×2 under 60 kg), circle 3(1-e), dog 0.8, surge 0.6.
- jump: 1.2 under 60 kg, 0.4 for 60-150 kg, 0 above that, and only when depth < 15.
- Stage A spacing: never two runs in a row. That is all, until the director arrives.
- The opening run stays: 8-20 s for a giant, 4-8 s for a schoolie.

**Jump** (phases on `move_t`):
- 0-0.5 s, rise: depth → 0 at 12 m/s, pull = -0.2·SIZE. It comes at you and the line goes slack.
- 0.5-1.2 s, airborne: pull 0, `airborne = true`. No slack wear. `hold -= max(0, T - 0.25) * AIR_WEAR * (0.4 + 0.6 * rod_pitch / 1.35) * dt`.
- 1.2 s, re-entry: one shock of `REENTRY * SIZE * (rod_pitch / 1.35) * (1.3 - cushion)`, then thrashing at head_motion 1.0 until 1.6 s.

So dropping the tip ("bow") is the safe play, and winding up the slack as it lands is the follow-through.

### step() order

1. If `done` or `dt <= 0`, return. `grace -= dt`.
2. `move_t += dt * adv`, where `adv = 1 + 1.5*|side_eff|` in a circle with side pressure against its turn, else 1. At `_len`, `_next_move()`.
3. `e`, `sz = SIZE(kg)`.
   - `_jit += (rng.randf_range(-1, 1) - _jit) * min(1, 2*dt)`.
   - `thrust = clamp(m.thrust + shake_osc + 0.15*_jit, 0, 1.2)`.
   - `pull = sz * thrust * away * e`.
   - If `_toward_t > 0`, `pull = -0.15*sz` (head turned, swimming at you).
4. Boat: keep the existing moving / headless block. It now yields `boat_close` (m/s toward the fish), **not** a change to `line_out`: `boat_close = -gap/dt` in moving mode, or `BACK_SPEED*back - 1.5*ahead` headless. In the holder, backing down still makes slack, and nobody winds it.
5. Tip:
   - `tip_along = ROD_REACH * (rod_pitch - 0.15) / 1.2`.
   - `tip_v = (tip_along - _tip_was) / dt` (on the first step, `_tip_was = tip_along`).
6. `eff` as defined above.
   - `wind = 0 if slipping else CRANK * crank_mul * crank * eff`.
   - `grinding = crank > 0.1 and eff < 0.3 and not slipping`.
7. Fish speed:
   - `vt = min((pull - T) * m.k, RUN_SPEED * e * thrust)` if `pull > T`, else `-min((T - pull) * PULL_IN, 3.0)`.
   - `_fv += (vt - _fv) * min(1, dt / TAU)`.
8. `stretch += (_fv + tip_v + wind - boat_close) * dt`; `line_out -= wind * dt`.
9. `spring = SPRING_BASE + SPRING_PER_M * line_out`; `T = max(stretch, 0) / spring`.
10. Drag:
    - If `T > drag_set`: `dx = (T - drag_set) * spring`; `line_out += dx`; `stretch -= dx`; `T = drag_set`; `slipping = true`.
    - Else `slipping = false`. (The flag must come from the slip itself. A threshold test flickers, which the prototype showed.)
    - `paying = lerp(paying, dx/dt, min(1, 6*dt))`.
    - `stretch = max(stretch, -SLACK_MAX)`.
11. `bind = move_toward(bind, BIND_MAX * crank if slipping and crank > 0.1 else 0.0, (BIND_RATE if slipping else 3.0) * dt)`.
12. Cushion: the angle between the rod direction `(elev rod_pitch, lateral side*0.9)` and the line `(elev -atan2(depth + TIP_H, hd))`. `cushion = clamp(angle / 1.2, 0.15, 1)`.
13. Shock:
    - shake: `SHAKE_SHOCK * clamp(kg/150, 0.5, 1.5) * |sin(phase)| * (1.3 - cushion)`.
    - plus the re-entry impulse.
    - decays at 6/s. `shock = 0` while `grace > 0`.
14. `T_fish = (T + bind + shock + (0.15 if tangled else 0)) * exp(CAPSTAN_MU * contact.get("angle", 0))`. Set `strain = T`.
15. Break:
    - `_over_t` accumulates while `T_fish >= 1`, and decays at 2/s otherwise.
    - `_over_t >= BREAK_HOLD + grace_add`, or `T_fish >= SNAP`, ends the fight: `_end("broke_rail" if contact angle > 0.2 else "broke")`.
    - Frozen during grace.
16. Hook hold (frozen during grace):
    - `hold -= max(0, T + shock - 0.9) * HOLD_SHOCK * dt`.
    - If `stretch < 0` and not airborne: `hold -= head_motion * HOLD_SLACK * dt`.
    - Airborne wear as above.
    - Heal `HOLD_HEAL` while `0.2 < T < 0.85` and not in a shake.
    - At `hold <= 0`: `_end("thrown" if _thrown_t > 0 else "pulled")`, where `_thrown_t` is 1 s after airborne.
17. Wear:
    - Stage A: `wear += chafe * (0.4 + 0.6*T) * dt / (CHAFE_LIFE * chafe_mul)`, with `chafe = rub_now`.
    - Stage B: `wear += max(slide, 0.3) * angle * T * dt / (25.0 * chafe_mul)`.
    - Tangle as now.
18. Props: as now, PROP_GRACE 2.5. Spool: `line_out >= CAPACITY`.
19. Tiring:
    - `energy -= (TIRE*T*(0.4+thrust) + LIFT*T*max(0,-_fv) + side_tire) * dt / _goal_s`.
    - `_low_t` counts while T < 0.15. After 1 s, `energy += REGAIN * dt`. (This is what the slack and the holder cost you.)
20. Geometry: the existing bearing, turn, tow and depth code, with the side-pressure changes below. A jump forces depth → 0.
21. `pull` var = `max(pull, 0)` for visuals. `line_out = max(line_out, BOATSIDE - 1)`.
22. Boatside: `energy < 0.2 and line_out <= BOATSIDE` (Stage C adds: and the lunge is survived).

`_next_move()` keeps today's spiral rule (energy < 0.25, line ≤ SPIRAL_IN) and its beaten rule.

### Side pressure (in Stage A, so mouse X is never a dead input)

`side_eff = side * clamp(T / 0.6, 0, 1) * cushion`. It is "against" when `signf(side_eff) == -_turn_sign and |side_eff| > 0.05`.

| Situation | Effect |
|---|---|
| Against | turn × (1 - SIDE_TURN·\|side_eff\|); circle `adv` as in step 2; `side_tire = SIDE_TIRE * \|side_eff\| * thrust * e` |
| With | turn × (1 + 0.3·\|side_eff\|), and nothing else |
| Head turn | Against with \|side_eff\| > 0.5, in a circle or dog, for `HEAD_TURN_T`: `_turn_sign = -_turn_sign`, `_toward_t = 2.0`, then `_next_move()`. Worth about 6-10 m. |
| Run, against | Once 1 s has built up: `_len = move_t + (_len - move_t) * 0.7`. While held, `bearing -= _turn_sign * 0.08 * \|side_eff\| * dt`. |

### Holder

rods.gd calls `step(dt, 0.0, 0.6, 0.0, r.drag, contact)`. Nothing else is special: no wind, so slack turns into breath back, and a running fish takes line through `r.drag`.

### carry_on / handover

`_new_fight` passes `r.stretch`, `r.hold`, `r.turn_sign` and `r.beats`, and sets `grace = 0.5`. `_turn_sign` and the beats survive; the queue is rebuilt from `strike_seed`.

### cues()

Only the bots and the in-world feedback read this:

```
{bend: T + shock, slipping, paying, grinding, airborne, thrash (head_motion >= 1),
 line_pitch (elevation, rad), sweep (d bearing/dt, rad/s, + increasing bearing),
 spool (line_out / CAPACITY), contact_angle, visible (line_out < 30 and depth < 10),
 drag (drag_set)}
```

---

## 5. HullWrap: the line tugs only where it touches (the user's complaint)

### Stage A quick fix (5 lines, tonight)

In `rub_on_hull`:
- Delete the three offset casts (`side * HULL_MARGIN`, `-side * HULL_MARGIN`, `-down * HULL_MARGIN`).
- Delete the `+ 0.25`.

Only the drawn line passing through her collider rubs now. Update `tests/rods_test.gd`: dead astern is still < 0.05; dead ahead near the top is still > 0.5.

**Why today's tug is wrong:** it is a proximity test. Any of 4 lines within 0.5 m of the hull counts as rubbing, and a straight segment to a deep fish that slices through the hull's underwater volume rubs at full, where a real line would hang clear or bend at the chine.

### Stage B: new tuna/hull_wrap.gd (static, about 110 lines; no rope physics, no gameplay rays)

**Outline, per boat, in `boat/kinds.gd`** under a new key `"wrap"`. Boat-local, Godot axes; Blender y maps to Godot -z.
- Sample the art scripts' `s_half(u)`, `z_sheer(u)` and `z_keel(u)` at u = 0, 0.3, 0.55, 0.75, 0.9, 1.0, mirrored to port. That gives a 10-12 point **rail loop** `(x, sheer_y, z)` and a **keel loop** (the rail loop's xz inset by 0.6 m, at z_keel).
  - skiff: `L` 8.5, `Y0` -4.25.
  - sportfisher: `L` 14, `Y0` -7, `BW` 4.8/4.3.
- **House box:**
  - sportfisher: x ±1.95, z -3.0..0.4, top y 2.6. The roof overhang to z 2.0 at y 2.6 is a second, thin box.
  - skiff: console x ±0.55, z -0.85..0.25, top y 1.6, plus the T-top x ±1.0, z -1.15..1.05, y 2.6-2.7.

**`static func wrap(tip: Vector3, fish: Vector3, w: Dictionary, was_touching: bool) -> Dictionary`** returns `{touching, via, angle}`, all in the boat frame. Hull roll is ignored.

1. `inside(p)`: p.xz is inside the rail-loop polygon (convex test), and `keel_y(z) < p.y < sheer_y(z)` (interpolated by z), or p is inside a house box. Grow everything by 0.05 m when `was_touching` (hysteresis, so the line doesn't flicker in the swell).
2. `clear(a, b)`: none of 48 samples along a→b is `inside`. Skip the first and last 0.15 m.
3. If `clear(tip, fish)`, the result is no contact. **No margins.** A line 0.4 m from the rail is clear.
4. Otherwise, for each candidate loop (the rail loop, the keel loop, and each house box's top-edge loop):
   - Sample 32 points by perimeter.
   - Take P minimising `|tip-P| + |P-fish|` among those where `clear(tip, P)` and `clear(P, fish)`.
   - Golden-section refine on the best edge (about 12 iterations).
   - Take the shortest valid one. If none is valid (a double wrap), take the rail candidate with the largest angle.
5. `angle = acos(dot(normalize(P - tip), normalize(fish - P)))`.

That is exact for a taut line over a convex hull, which is why no line physics is needed. Cost is about 3k point tests per fighting rod per frame. Fine at 30 Hz.

**Wiring in rods.gd:**
- `contact_for(r)` calls HullWrap with `to_her * r.tip_position()` and `to_her * fish_point(r, boat)`.
- `slide = |Δline_out|/dt + |Δvia|/dt`, in the boat frame.
- The result goes to `step(…, {angle, slide})`. `r.via = via` (or `Vector3(NAN, …)`).
- Delete `rub_on_hull`, `_hull_hit`, `rub_now`, `RUB_ALL` and `HULL_MARGIN`.
- Rays live only behind `const RUB_DEBUG := false`, which draws the outline loops and the old ray result side by side, for tuning the numbers against the art.

---

## 6. rods.gd every frame

### 6.1 Order in `_process` (per rod, unchanged where not listed)

1. Swing the bearings by the helm turn, as now.
2. If the rod is `mine`: `_aim()` (§3), then `contact_for(r)` (Stage B; in Stage A, `rub_now` from the fixed `rub_on_hull`), then `fight.step(dt, crank, r.aim_pitch, side_fight, r.drag, contact)`, then `_take()`.
3. If it's in the holder and we are the host: `_fight_holder` with the fixed aim.
4. Transform: `_in_hands(p, r)` for a held rod, the holder tube as now otherwise.
5. `line_end`, as now.
6. `_show_fish`.
7. HUD: `hud.call("fight", "", 0.0)` while you hold a hooked rod. The non-fight hints otherwise. No captain text, no plot.
8. `me.shake = clamp(fight.shock * 1.5 + (0.25 * T if slipping else 0.0), 0, 1)` (only the angler's own view).

### 6.2 `_take(r, f)`

- `r.strain = clamp(f.T + 0.5 * f.shock, 0, 1.2)`. This drives the bend.
- Also copies `line_out`, `bearing`, `depth`, `energy`, `move`, `wear`, `turn_sign`, `stretch`, `hold`, and the flags `slipping`, `grinding`, `airborne`, `cranking`.
- `r.reeling = f.wind`. The handle turns at the real gain, and doesn't turn while grinding.
- Delete `r.lift`, `r.wrong`, `fight.answer()`, and the `me.arms` plumbing.

### 6.3 Scroll drag

In `_unhandled_input`, on `MOUSE_BUTTON_WHEEL_UP`/`DOWN` pressed:
- Only when `held_by(me)` is hooked, not alongside, with `lever_holder == 0`, and 0.2 s since the last notch.
- `r.drag = DETENTS[next index]`.

`_strike` sets `r.drag = 0.72`.

### 6.4 Sync

`_fight_state` and `_holder_state` become `(i: int, move: String, s: PackedFloat32Array)`, unreliable_ordered at 10 Hz as now. Layout:

```
[0 line_out, 1 strain(T), 2 bearing, 3 depth, 4 energy, 5 aim_pitch, 6 aim_side, 7 wear, 8 turn_sign,
 9 drag, 10 hold, 11 stretch, 12 flags (1 slipping, 2 grinding, 4 airborne, 8 cranking, 16 thrash),
 13 reeling, 14-16 via (boat-local; NAN = none), 17 beats]
```

- The receivers keep today's sender checks.
- `_states()` and `_sync` (late joiners) gain `drag`, `hold` and `beats`.
- Reliable rpcs are unchanged (strike, off, report_end, set_holder), plus Stage C's lever and fender ask/set.
- HullWrap runs only on the rod holder's machine. `via` arrives at 10 Hz and is for drawing only.

### 6.5 Rod feel (Stage B, in rods/rod.gd, about 90 lines)

New Rod vars: `aim_pitch`, `aim_side`, `drag`, `hold`, `stretch`, `slipping`, `grinding`, `airborne`, `cranking`, `via`, `beats`, `lever_holder`, `fender`.

| Cue | Rule |
|---|---|
| Bend | Toward the world point of `via` when there's contact, else toward `line_end`. Magnitude `0.05 + 0.55 * min(strain, 1)`. |
| Quiver | Moves from strain > 0.3 to **strain > 0.85**: 23/17 Hz at `0.02 * (strain - 0.85) / 0.15 + 0.005`. It now means "near the limit". |
| Line straight / sag | Sag factor `(0.02 + 0.3 * slack) * (1 - 0.85 * min(strain, 1))`, with `slack = clamp(-stretch / 4, 0, 1)` while hooked. |
| Thrum | strain > 0.8: interior vertex jitter `0.01 + 0.02 * (strain - 0.8) / 0.2` m at 40 Hz |
| Contact | Two segments, tip → via → line_end, plus a spray fleck (`Splash.burst(via, 0.15)` every 0.3 s while slide > 1.5) and a squeal (line_sing at `0.7 + slide / 8`) placed at via |
| Scream | Existing, from `paying` |
| Whir | `reeling > 0.05 and not grinding` |
| Grind | A second reel_whir loop at pitch 0.5, -2 dB, while `grinding` |
| Tick | `0.1 < paying < 0.6`: `Sfx.play_point(self, reel, "kit.switch", 0.3, 1.6)` every `1 / (paying * 8)` s |
| Creak | The existing `_sing`, re-thresholded: strain ≥ 0.92, pitch `0.55 + 2.5 * (strain - 0.92)`. Your only warning. |
| Detent click | When `drag` changes by more than 0.05: `Sfx.play_at(self, "kit.switch")`. Audible to everyone near, so the angler hears the mate. |
| Break | `rods._off` with broke or broke_rail: `Sfx.play_at(rod, "sea.crack")`, and the rod draws a 12-vertex coil from the tip falling 1.5 m over 0.8 s |
| Hook pull | The bend snaps to 0 in 0.15 s (a soft whip), and the line is drawn fully slack, floating to the water. A different sound and picture from the break. |
| Spool | A CylinderMesh at (0, 0.1, 0.37), radius `0.05 * (0.4 + 0.6 * (1 - line_out / 500))`. Line colour, then **white backing** once line_out > 400, then bare metal grey above 425. |

### 6.6 Water (`_show_fish`, Stage B)

- The fish is visible when `line_out < 30 and depth < 10`, or while airborne.
- Airborne: `y = top + 1.2 * sin(PI * air_frac)`, with `Splash.burst` at exit and at entry.
- Shake slaps, run boils and spiral swirls stay as now.
- A head turn (`_toward_t` is visible as `move == "dog"` with the turn sign flipped) also reads as the line's sweep reversing.
- **Prop warning without text:** while the fight's `_prop_t > 0`, loop line_sing at pitch 1.6 placed at `boat * stern`. Every peer runs this from `r.bearing`, `r.depth` and `helm.throttle`.

---

## 7. Crew roles and wiring

- **Angler** (Stage A): §2-3. Walking to the stern and laying the tip outboard changes `tip`, and so the wrap (Stage B uses the real tip). The fighting chair is unchanged: same controls, and it swivels to the look.
- **Captain** (Stage A): no change in code. Backing down feeds `boat_close`, which makes slack, so the angler must wind ("backing!" / "winding!"). Driving away pays line through the drag. The props warning is the sound in §6.6.
- **Mate lever** (Stage C):
  - On Rod: `lever_holder`, host-arbitrated with the `_ask_grab`/`_host_set` pattern: `_ask_lever(i, take)` → `_set_lever.rpc(i, who)`.
  - The prompt "Take the drag" shows when the rod is hooked, `holder != me`, and you are within 1.3 m of the reel.
  - The mate runs `me.lease_kind = "lever"`. Mouse Y moves a local value, which goes `_lever_in.rpc_id(r.holder or 1, i, v)` (any_peer, unreliable_ordered, 10 Hz, sender must be `lever_holder`).
  - The fight's peer sets `r.drag = v`, so it syncs back to everyone via `_fight_state`.
  - The scroll is locked while the lever is held. Letting go keeps `r.drag`.
- **Mate fending** (Stage C, boss note 3, the payoff for the wrap):
  - On Rod: `fender`, host-arbitrated the same way.
  - The prompt shows when `r.via` is valid and you are within 1.2 m of its world point, not on a rod, the lever or the wheel. Hold E.
  - On the rod holder's machine, while the fender's synced position is within 1.4 m of via, contact becomes `{}` (no capstan, no wear), and the line is drawn tip → hand (`via + 0.35` outboard `+ 0.2` up) → fish.
  - Burn: slide > 3 m/s for 1.5 s, and the hand comes off. The holder asks the host to clear `fender`, the fender gets `shake = 0.6` and a thrash Sfx, and can't fend again for 3 s. No stamina.
- **Two players:** one fights, and the other shuttles between the wheel, the lever and the rail. Rod in the holder (Q) means breath back and no gain.
- **Landing:** unchanged.

---

## 8. Director (Stage C, about 80 lines, behind `director := true`)

**Triggers**, rolled at `_init` from `strike_seed` with a separate rng:
- `second_wind_e` 0.55 ± 0.08 (fish over 200 kg)
- `comeback_m` 40 ± 8, run 60% / sound 40% (fish over 100 kg)
- `wallow_m` 30 ± 5 (fish over 200 kg, and 50% of 60-150 kg fish)
- `lunge_m` 15 ± 4, direction down, under, or along (over 100 kg; 50% of schoolies at thrust 0.7)
- `bow_circle_t` for crews of 2+ (`crew_n` set by rods.gd)

**Each fires once** and sets a `beats` bit, carried across handovers:

| Beat | What it does |
|---|---|
| Comeback, run | Run at 0.8 of fresh speed, 30-60 m |
| Comeback, sound | Down to 70-100 m under the transom |
| Second wind | A full-thrust run (8-12 s) or a sound to 120 m |
| Lunge | 2-3 s at thrust 1. "Under" sets bearing toward PI, where the props get teeth. |
| Bow circle | A circle with `_turn_sign` chosen to swing the fish forward of the beam |

**Wallow:** new move `wallow`, 3-4 s. Depth → 0.3, `head_motion` 1.0. 2-3 slaps, 0.9-1.4 s apart (seeded), each a shock of `1.6 * SIZE * (1.3 - cushion)`. rods.gd draws the back and tail out (Tuna at depth 0.3, rolled) and does `Splash.burst(at, 1.4, true)` with slap.wav on each slap.

**Spacing**, as a filter on `_pick()`:
- 12 s between peak starts (8 s for a schoolie)
- valleys of at least 6 s
- a valley over 15 s gets a shake dropped in
- no peak stacks on a beat
- peaks are scaled by energy, except the fixed beats

Boatside for fish over 100 kg requires the lunge bit.

---

## 9. Tests

### New tests/fight_bot.gd

`static func act(c: Dictionary, dt: float, style: String, mem: Dictionary) -> Dictionary` returns `{crank, pitch, side, drag_notch}`. It is used by `fight_test`, `strike_test` and `trip_test`, and reads `cues()` only.

**GOOD angler**, a state machine. This is the prototype's policy.

| Check, in order | Action |
|---|---|
| `airborne` | pitch → 0.25 at 4 rad/s, crank 0 (bow) |
| `slipping` for > 0.3 s | **HOLD**: crank 0, pitch → 1.0 at 0.9 rad/s |
| HOLD and no slip for 0.3 s | → **CRANK** |
| CRANK | crank 1, pitch eases to 0.8. Grinding for 0.5 s → **PUMP**. |
| PUMP, heave | `pitch += clamp((drag - 0.06 - bend) * 8 + 0.2, 0, 1.2) * dt` to 1.3 (0.95 if `line_pitch < -0.9`: short strokes, deep) |
| PUMP, drop | `pitch -= 1.7 * dt` with crank 1, down to 0.3 (0.55 short). At the bottom, bend < 0.3 → CRANK. |
| `thrash` | pitch ≥ 0.9, crank only if bend < 0.25 |
| Side | `-sign(sweep) * 0.9` when \|sweep\| > 0.02 and bend > 0.3, else ease to 0 |
| Drag | solo: STRIKE |

**The other bots:**

| Bot | Behaviour |
|---|---|
| NO_SIDE | GOOD with side 0 |
| REELER | Cranks unless screaming (0.3 s reaction), pitch 0.8, never pumps, no side |
| CRANKER | crank 1, pitch 0.8 |
| STATUE | pitch 0.6, nothing else |
| HIGH_TIP | GOOD, but airborne gives pitch 1.35 and crank 1 |
| Captain | The current "right" captain (stern to the fish at TURN 0.45), backing down only while `slipping and line_out > 25` and \|b\| < 0.6. Blind: as now. |
| MATE (Stage C) | Lever 0.45 on runs, 0.85 in a dog or circle, 0.72 otherwise, and dumps to 0.3 on the lunge |
| FULL_DRAG, POINTED (Stage C) | |

### tests/fight_test.gd, rewritten

Same `_check`/print style. 20 seeds unless noted. Print `ends` and medians for every row.

| Check | Stage | Target |
|---|---|---|
| GOOD + captain, 35 kg | A | ≥ 19 landed, median 40-100 s |
| GOOD + captain, 300 kg | A | ≥ 18 landed, median 180-330 s |
| GOOD alone, 35 / 300 kg | A | ≥ 18 / ≥ 16 landed. 300 kg median ≤ 1.45 × the captain median, and > the captain median. |
| REELER vs GOOD alone, 150 and 300 kg | A | REELER median ≥ 1.15 × GOOD (the pump matters) |
| NO_SIDE vs GOOD, 300 kg | A | GOOD ≥ 10% faster; mean circle length ≥ 30% shorter |
| CRANKER, 150 / 300 kg | A | ≥ 15 broke |
| STATUE, 35 / 300 kg | A | Never boatside, minimum energy > 0.3 |
| HIGH_TIP, 35 kg | A | ≥ 8 lost (pulled or thrown) |
| Holder, 200 kg, 30 s | A | Still on ≥ 18. ≤ 0.05 m of line per step outside run/sound/surge. |
| Blind captain, 300 kg, 40 seeds | A | ≥ 4 cut |
| Tangle left alone | A | Saws through in < TANGLE_LIFE + 5 s |
| `carry_on` | A | Move, stretch, hold and turn are carried. No shock or hold loss in the 0.5 s grace. |
| Spiral only close in | A | Furthest spiral ≤ SPIRAL_IN + 0.5 |
| Determinism | A | Same seed and same bot give the identical result twice |
| Director, 500 seeds | C | Peak spacing respected; comeback trigger spread across 32-48 m; exactly one comeback and one lunge per fish over 100 kg |
| MATE vs solo GOOD, 300 kg | C | Mate ≥ 20% faster. Solo ≥ 65% landed. |
| FULL_DRAG on the lunge | C | ≥ 50% broke |
| POINTED on the wallow | C | ≥ 35% lost |

Delete: the `Fight.rub` checks (they move to the hull_wrap test), the arms and two-anglers block, and the `answer()` uses.

### Other tests

- **tests/hull_wrap_test.gd** (Stage B), on the sportfisher and skiff outlines:
  - fish dead astern: no contact
  - fish ahead of the beam: contact, angle > 0.3
  - line 0.4 m clear of the rail: **no contact** (today's false positive)
  - fish deep under the hull: keel contact
  - tip swung 0.8 m outboard aft: clears a shallow wrap
  - hysteresis holds at the 0.03 m boundary
- **strike_test / trip_test:** replace the `answer()` loops with `var a := FightBot.act(rod.fight.cues(), dt, "good", mem)`, then `sea.rods.bot_aim = Vector3(a.pitch, a.side, 0)` and `_hold("use_primary", a.crank > 0.5)`. Change `strike_test:44` `rod.strain > 0.8` to `> 0.65` (a run now sits on STRIKE drag, 0.72).
- **rods_test:** the Stage A quick-fix checks. In Stage B, `contact_for` replaces `rub_on_hull`. Add a lease check: drop the rod (Q), and on the next process frame `me.leased()` is false and mouse motion turns `_yaw`.

Run: `godot --headless --path . res://tests/fight_test.tscn` (and the same for the others).

---

## 10. Build steps, in order, each testable

**Stage A (tonight)**
1. **The harness first.** Write `tests/fight_bot.gd` and the fight_test skeleton against the new `step()` signature, with fight.gd stubbed. Test: it parses and runs.
2. **fight.gd core:** the §4 constants, MOVES, step order, hook hold, jumps, side pressure, cues and carry_on. Test: `fight_test` Stage A rows. Tune only the four ★ knobs first, then GOAL0 for schoolies.
3. **rods.gd plumbing:** the new `step()` calls in `_fight_mine` and `_fight_holder`, `_take`, `r.drag` with STRIKE set on the strike, the packed `_fight_state`/`_holder_state`, `_sync` fields, and deleting `answer`/`tell`/`arms`. Test: the strike_test and trip_test bots land a fish.
4. **player.gd lease and camera**, plus rods.gd `_aim()` and `_in_hands(p, r)`. Test: the rods_test lease check. By hand: heave, and the water stays in frame.
5. **Scroll drag** with the detent click. Test: rods_test sets `r.drag` with a wheel event; the rate limit holds.
6. **The rub_on_hull quick fix.** Test: rods_test rub checks.
7. **Text removal** (§1), loss captions, the tips and manual copy, `player.arms` deleted, the prop warning sound. Test: grep shows no `answer(`, `tell(` or `.arms` left. All tests green.

**Stage B**

8. hull_wrap.gd and the kinds.gd `"wrap"` outlines. Test: hull_wrap_test.
9. Wire `contact_for` into the fight, the chafe formula, `T_fish` capstan; delete the rays (except RUB_DEBUG). Test: fight_test plus a new rail-wrap row (a 300 kg fish forward of the beam at FULL drag breaks ≥ 50%).
10. rod.gd feel: bend toward via, quiver and creak re-thresholds, grind, tick, two segments, spray and squeal, ping and coil versus spring-straight, spool and backing. Test: `crew_shot` screenshots at heave, wrap and backing.
11. `_show_fish`: visible in the last 30 m, and jumps out of the water. Test: trip_test shots.

**Stage C**

12. The director, triggers, beats bitmask and spacing. Test: the director property test and the one-comeback, one-lunge test.
13. Wallow move plus visuals. Test: the POINTED row.
14. Mate lever (rpc and lease kind). Test: the MATE row; `tools/net_test.sh` with a two-peer lever.
15. Mate fending and the burn. Test: a fight_test row where contact is fended (no wear) on the rail wrap.

---

## 11. Prototype evidence and risks

**What the Python prototype showed** (24 seeds, 1-D, no geometry, jumps, side pressure or director; starting numbers from the table above):

| Bot | 35 kg | 150 kg | 300 kg |
|---|---|---|---|
| GOOD + captain | 36 s | 74 s | 243 s |
| GOOD alone | 36 s | 86 s | 328 s |
| REELER alone | 42 s | 108 s | 372 s |

- CRANKER broke 24/24 at 150 kg and at 300 kg. STATUE never landed one.
- **Three model fixes the prototype forced, all now in §4:**
  1. The `slipping` flag must come from the slip itself; a threshold test flickers.
  2. The fish needs inertia (TAU) and a soft give rate, k = 3 outside runs. Without them the pump is useless.
  3. Tiring must be driven by lifting the fish in (LIFT), and the energy floor must be low (E_FLOOR 0.15). Otherwise the fish is spent at 200 m and you just winch for 2.5 minutes, which is the user's complaint.

**Risks:**
- **The pump's edge over plain reeling is the main tuning risk.** In the prototype it was only 13-26%. Levers: lower `REEL_STALL`, raise `PULL_IN` or `LIFT`.
- Schoolies at 36 s are short. Jumps and shakes will lengthen them; raise GOAL0 if not.
- The camera follow could feel floaty. Fall back to 0.2× follow.
- HullWrap outlines can drift from the art. Use the RUB_DEBUG overlay.
- Lever latency at 10 Hz is absorbed by the detent margins and the 0.5 s handover grace.

**Follow-ups:** a rival-spooking interaction, a Rod weight slider in a settings menu, the sportfisher's physical plotter, a harpoon window timed to the lunge.