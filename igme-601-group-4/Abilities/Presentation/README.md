# Optional ability presentations

`Ability.presentation` references an `AbilityPresentation` resource. The attack
controller awaits `play(actor, visual, target)` and applies damage once after a
successful return. Returning false cancels damage. Without a presentation, the
existing AnimationPlayer/keyframe or immediate-attack path remains active.

Whirlwind uses `WhirlwindPresentation.tres` (default duration 0.48 seconds).
It moves only the player's `VisualPivot`: AnimationPlayer and the skeleton sit
inside that pivot, while the actor, collisions, grid occupancy and overhead UI
remain stationary. It follows the selected ring's valid hex centers, closes
complete rings, returns home and restores the original local transform.

Runtime Tween state lives on a temporary `presentation_motion.gd` node per
playback, not on the shared resource. Death, scene exit or runtime-node removal
cancels playback and restores the visual transform. The node is freed afterward.

To disable this temporary effect, clear **Presentation** on `Whirlwind.tres`.
To tune its timing, edit **Duration** on `WhirlwindPresentation.tres`.
To replace it, assign a different resource extending `AbilityPresentation`.
