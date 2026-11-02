extends Resource
class_name AbilityPresentation

## Optional, awaitable visual effect. Returning false cancels damage.
## Keep runtime state on a per-play node, never on this shared resource.
func play(_actor: Node3D, _visual: Node3D, _target: AbilityTarget) -> bool:
	return true
