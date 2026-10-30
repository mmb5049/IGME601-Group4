# Turn preparation integration test

Enemy planning and friendly-fire attacks:

```text
godot --headless --path . res://tests/enemy_attack_test.tscn
```

Checks immediate Whirlwind plans, approaching within the 2-3-slot budget,
obstacle-aware movement prediction, a real Move/Whirlwind turn, player damage,
friendly fire, delayed damage and model restoration, dodging by moving out of
the prepared ring, lethal friendly fire, and cancellation on attacker death.

Whirlwind procedural presentation:

```text
godot --headless --path . res://tests/whirlwind_presentation_test.tscn
```

Checks ordered ring traversal, delayed damage/queue consumption, fixed actor
transform and occupancy, exact visual restoration, repeated casts, outer and
clipped rings, disabling the optional presentation, cancellation on death, and
temporary playback-node cleanup. Append `-- --capture-whirlwind` without
`--headless` to save a mid-orbit preview.

Annular targeting:

```text
godot --headless --path . res://tests/annular_target_test.tscn
```

Checks selectable radii, whole-ring preview, invalid center/out-of-range tiles,
clipping at arena edges, relative targets after movement, single-entry mana
cost/consumption, multi-enemy damage, single-tile attack compatibility, and
ring-wide trap placement. Run without `--headless` and append
`-- --capture-annular` to save a targeting preview.

Run from the Godot project directory with Godot 4.7:

```text
godot --headless --path . res://tests/turn_preparation_test.tscn
```

The test loads the real Arena and verifies initial preparation, random enemy
plan sizes, shared Move resources, unique action numbers, preparation idempotence,
unequal queue round-robin execution, input locking, duplicate start requests,
mana refill, replanning, empty player plans, freed enemies, blocked movement,
and enemy death from a trap during movement. Success prints
`TURN_TEST_RESULT: PASS (0 failures)` and exits with code 0.

For enemy overhead queue visuals:

```text
godot --headless --path . res://tests/enemy_queue_ui_test.tscn
```

This checks queue synchronization, direction signs, input passthrough, half-size
artwork, red enemy frames, the upper-left screen offset, the fixed bottom slot
with 1/2/6 entries, bottom-first execution order, removal followed by downward
reflow, animation cleanup, movement following, camera visibility, and death cleanup.
It also checks player/enemy action numbers, centered head placement, immediate
number updates, and hiding on death. The turn test checks refreshed head numbers
after the next preparation phase.

For overlap fading and hover priority:

```text
godot --headless --path . res://tests/queue_overlap_test.tscn
```

This checks world-Z priority independently of screen geometry, opacity and
draw order, hover selection and stability, multiple intersections, restored
visibility after separation, number visibility, animated removal bounds, and
cleanup of the shared-canvas roots on death. Run without `--headless` and append
`-- --capture-overlap` to save default/hover rendering previews.
To save a rendered preview in the repository's parent directory, run without
`--headless` and append `-- --capture`.
