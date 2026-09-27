# Verification

Verified on 2026-09-12 with the installed
`4.7.2.stable.official.ed1daf0bf` Windows Godot executable.

- **49 native integration checks passed, 0 failed.**
- Final physics run produced no engine errors or script warnings.
- A complete three-launch rooftop delivery passed without teleporting the
  courier. The route includes landing/relaunching, cable travel, billboard
  destruction, and the real delivery Area2D trigger.
- Individual collision checks cover the high-bounce awning, wall stun and
  recovery, connected ragdoll limbs, and billboard debris cleanup.
- Native viewport input checks cover mouse drags, a release over the toolbar,
  touch aiming, ignoring a second finger, and focus-loss cancellation.
- Pause/resume, checkpoint retry, complete restart, and the torso-only test yard
  passed. A real Windows mouse drag was also used in the running game.
- Seven native viewport captures were rendered using OpenGL Compatibility on
  the local NVIDIA GPU, covering dispatch, aiming, flight, billboard lettering,
  debris, the win receipt, and a smaller window. Layouts were visually checked
  at **1280x720** and **960x540**.

Run `tests/physics_checks.gd` as described in the README to repeat the checks.
Run `tests/render_checks.gd` with the normal renderer to regenerate PNGs here.
Logs and PNGs are generated outputs and are excluded by `.gitignore`.

This is a prototype: artwork is placeholder, the trajectory is a free-flight
approximation, and the cable grip is an arcade trolley over real simulated
links. Touch events were tested through Godot, not on a physical touch device.
