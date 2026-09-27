# Slingshot Courier

A native Godot 4.7.2 2D physics prototype. No plugins, addons, C#, downloaded
libraries, or external dependencies. All art is editable placeholder SVG or
Godot drawing primitives; sound is generated with AudioStreamWAV.

## Play

Import `project.godot` into Godot 4.7.2 and press **F5**.

- **Launch:** press on the courier's white ring, pull back, and release.
  The character launches in the opposite direction. A longer pull adds power.
- **Relaunch:** land and let the courier recover. The white ring returns when
  another launch is available. There is no running, jumping, or air steering.
- **Cancel a pull:** right-click or Escape. Tiny drags do not spend a launch.
- **Cable:** catch it automatically while flying nearby. **Space** drops the
  grip early; reaching the far end releases automatically with current momentum.
- **R:** restart the whole level. **Escape:** pause/resume.
- The top selector switches between the rooftop route and a simpler test yard.
- A fall offers a retry from the last reached rooftop checkpoint. Restart resets
  the entire route, including the billboard, counters, cable, and checkpoints.
- Mouse and single-finger touch aiming are supported. Focus loss cancels aiming
  and pauses the game. This prototype is designed for a landscape desktop window.

The dotted arc previews free flight only. Collisions, limb drag, and cable grabs
change the actual flight path. Pink striped awnings bounce; the pink insurance
billboard breaks at speed; the brick chimney causes a short crash stun. Get the
courier's torso into the green delivery frame to complete the delivery.

## Project Map

| File | Responsibility |
| --- | --- |
| `scenes/main.tscn`, `scripts/main.gd` | Game flow, checkpoints, pause, win, restart |
| `scenes/courier.tscn`, `scripts/courier.gd` | Root RigidBody2D, launch impulse, pose and recovery |
| `scripts/limb.gd` | Independent child rigid bodies, tuck torque, contact feedback |
| `scripts/slingshot.gd` | Drag input, rubber-band Line2D, short trajectory preview |
| `scenes/route.tscn`, `scenes/test_yard.tscn` | Positions of editable world-object instances |
| `scripts/city.gd` | Building rectangles, native collision bodies, city placeholder art |
| `scripts/awning.gd` | High-bounce StaticBody2D and cosmetic canopy wobble |
| `scripts/power_line.gd` | Pinned rigid-body segments and spring-suspended sliding grip |
| `scripts/billboard.gd` | Speed threshold, sprite swap, physical debris cleanup |
| `scripts/goal.gd` | One-shot torso-only Area2D completion |
| `scripts/courier_camera.gd` | Speed zoom, look-ahead, impact shake |
| `scripts/hud.gd`, `scripts/sound.gd` | Native UI and synthesized sound |

Open `route.tscn` to move the awning, cable, billboard, or goal in the 2D editor.
Building art previews in the editor; its matching collision bodies are generated
on play. The courier limbs and cable links are also generated at runtime so that
dimensions and joint construction are readable in one place. Inspect the
**Remote** scene tree during play to see every native body and joint.

## Tuning

Select the courier root in `courier.tscn` for exported values:

- `max_drag`: 160 screen pixels. This stays consistent as the camera zooms.
- `max_launch_speed`: 1180 pixels/second. Root impulse is velocity times mass;
  proportional impulses give all limbs the same starting velocity.
- `hard_impact_speed`: 360 pixels/second into a contact normal.
- `flail_duration`: 0.95 seconds; `wall_stun_duration`: 1.15 seconds.
- `enable_limbs`: disables the rig for an isolated launch test.

`main.tscn` also exposes `enable_ragdoll` for the full game. The test yard can
be run without limbs using Godot's command line:

```powershell
& 'C:\Users\Mayur\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . -- --yard --no-limbs
```

The cable exports its endpoint offset, number of links, sag, and pickup radius.
Its grip advances along the **current simulated link positions**, using a
StaticBody2D anchor and DampedSpringJoint2D suspension. This is an arcade sliding
trolley, not a physically accurate friction/contact simulation of hands on wire.
The links themselves are solved by Godot's native physics engine.

Limbs use `top_level = true` so they remain children in the scene tree without
inheriting the moving torso's transform. PinJoint2D attaches them physically.
Damped pose torques tuck limbs and self-right the torso. Hard impacts disable
these torques briefly; collision shapes are never scaled for squash/stretch.
The awning's launch is a PhysicsMaterial bounce, not an extra scripted impulse.

Collision layers: 1 city, 2 torso, 3 limbs, 4 cable, 5 debris. Body parts do not
collide with one another; debris does not collide with the courier. Native CCD,
120 Hz physics, and 16 solver iterations keep fast impacts and joints stable.

## Verification

Native integration checks can be run without opening an editor:

```powershell
& 'C:\Users\Mayur\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 120 --script res://tests/physics_checks.gd
```

Implementation references: [RigidBody2D](https://docs.godotengine.org/en/stable/classes/class_rigidbody2d.html),
[PinJoint2D](https://docs.godotengine.org/en/stable/classes/class_pinjoint2d.html),
and [DampedSpringJoint2D](https://docs.godotengine.org/en/stable/classes/class_dampedspringjoint2d.html).

The tests cover native mouse/touch events, launch clamping, real collisions,
recovery, cable travel and release, billboard debris cleanup, completion,
checkpoint retry, pause, restart, and a full three-launch route without
teleporting. `tests/render_checks.gd` generates screenshots with a real renderer
at 1280x720 and 960x540; omit `--headless` when running that script.
