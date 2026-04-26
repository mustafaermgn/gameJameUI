# Project Water - Optimization Audit

Date: 2026-04-25
Scope: Full codebase (26 GDScript files, 200x200 grid Godot 4.6 game)

## 1) Summary

Tower defense + pipe placement game. Flow simulation, minimap, container visuals, cursor preview had significant per-frame overhead. Critical AABB bug in turret logic. 6 dead utility scripts. 5x duplicated AABB logic.

**Top 3 fixes applied:**
1. Flow sim throttled 60Hz → 10Hz (~80% CPU savings)
2. Minimap pool centroids cached (recalculated only on depletion signal)
3. Container lookup O(n) → O(1) via Dictionary

**Biggest risk if skipped:** Frame time degradation with more pipes — flow sim was O(pipes × containers × networks) per frame.

## 2) Changes Applied

### Critical / High

| ID | Fix | File(s) | Impact |
|----|-----|---------|--------|
| F-01 | Throttle `_simulate_flow` to 10Hz via accumulator | `pipe_system.gd` | ~80% flow sim CPU |
| F-02 | Cache minimap centroids, recompute on `pool_depleted` signal only | `minimap.gd` | Eliminates per-frame centroid loop |
| F-03 | `_container_set` Dictionary for O(1) lookup in flow sim | `pipe_system.gd` | Eliminates O(n) linear scan in hot loop |
| F-04 | Fix turret `_collect_aabb` pass-by-value bug (rewrote with return-value pattern) | `turret_logic.gd` | Correct turret centering |

### Medium

| ID | Fix | File(s) | Impact |
|----|-----|---------|--------|
| F-05 | Extract shared `Utils.collect_aabb` / `Utils.compute_visual_aabb` | New `utils.gd`, 5 files updated | Eliminates 4 duplicate implementations |
| F-06 | Pre-create shared `_mat_flowing` / `_mat_idle` materials | `pipe_system.gd` | N materials → 2, improves batching |
| F-07 | Guard container visual update on `absf(level - prev) < 0.5` | `pipe_system.gd` | Eliminates per-frame material writes |
| F-09 | Consolidate `place_pipe` / `place_pump` into `_place_internal` | `pipe_system.gd` | Removes 20-line duplicate |
| F-20 | Enemy `_face_velocity` applies rotation to `model.transform` instead of `global_transform` | `enemy.gd` | Correct facing behavior |

### Low

| ID | Fix | File(s) | Impact |
|----|-----|---------|--------|
| F-08 | Throttle cursor preview redraw — only on state/mouse-cell change | `cursor_preview.gd` | ~90% fewer redraws |
| F-10 | Remove 7 dead utility scripts (update_bullet, print_aabb, create_better_fx, attach_scripts, generate_turret, generate_assets, fix_particles) + .gd.uid files | Root dir | Cleaner repo |
| F-11 | Remove unused `turret2.tscn` | `scenes/props/` | Dead scene removal |
| F-12 | Remove `Sprint.glb.bak`, add `*.bak` to `.gitignore` | `models/`, `.gitignore` | 126KB saved |
| F-13 | Remove dead `_on_container_level_changed` handler | `hud.gd` | Dead code removal |
| F-15 | Guard `global.gd` coin signal on `coins != value` | `global.gd` | Prevents redundant UI updates |
| F-17 | Bullet/flash spawn uses `get_parent().add_child()` instead of `get_tree().current_scene` | `turret_logic.gd` | Less fragile hierarchy coupling |

## 3) Files Modified

- `scenes/utils.gd` — NEW shared AABB utilities
- `scenes/props/pipe_system.gd` — F-01, F-03, F-06, F-07, F-09
- `scenes/props/turret_logic.gd` — F-04, F-17
- `scenes/props/enemy.gd` — F-05, F-20
- `scenes/player/player_controller.gd` — F-05
- `scenes/world/world_generator.gd` — F-05
- `scenes/ui/minimap.gd` — F-02
- `scenes/ui/cursor_preview.gd` — F-08
- `scenes/ui/hud.gd` — F-13
- `scenes/ui/global.gd` — F-15
- `.gitignore` — F-12

## 4) Files Deleted

- `update_bullet.gd` + `.uid`
- `print_aabb.gd` + `.uid`
- `create_better_fx.gd` + `.uid`
- `attach_scripts.gd` + `.uid`
- `generate_turret.gd` + `.uid`
- `generate_assets.gd` + `.uid`
- `fix_particles.gd` + `.uid`
- `scenes/props/turret2.tscn`
- `models/Sprint.glb.bak`

## 5) Remaining Recommendations (Not Implemented)

| ID | What | Priority | Why Skipped |
|----|------|----------|-------------|
| F-14 | Remove empty `stop_water()` / `repair_pipe()` stubs in player_controller | Low | Needs verification — may be called via `has_method`/`call` |
| F-16 | Bullet material `duplicate()` on impact | Low | Short-lived allocation, GC handles it |
| F-18 | Pre-build submenu backgrounds in scene editor | Low | Pattern works, low priority |
| F-19 | Convert `biome_map` Dictionary to flat array | Low | Only affects one-time generation |
| F-21 | LOD / visibility ranges / MultiMesh for scatter instances | Medium | Requires more architectural thought |

## 6) Validation Plan

- **Flow sim:** Profile with Godot debugger. `_process` time in `pipe_system` should drop ~80% with 50+ pipes
- **Minimap:** `_draw()` time should no longer include centroid computation
- **Container lookup:** Test with many containers — no linear scan overhead
- **Turret AABB:** Visual check — turret model should be centered at placement
- **Material sharing:** Check "Resources" in debugger — flowing/idle materials should be 2 shared instances
- **Scatter/LOD:** Future — measure draw calls with camera at center vs edge
