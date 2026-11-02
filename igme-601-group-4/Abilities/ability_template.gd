extends Resource
class_name Ability

@export_category("Basic Information")
@export var ability_name: String = ""
## Icon displayed by Ability UI components.
@export var icon: Texture2D

@export_category("Ability Properties")
@export var type: Global.AbilityType = Global.AbilityType.ATTACK
@export var cost: int = 0
@export var cooldown: float = 0.0
@export var range: int = 0
@export var damage: int = 0

@export_category("Animation")
@export var animation:Animation
## Optional replaceable presentation, awaited before attack damage.
@export var presentation: AbilityPresentation

@export_category("Targeting")
## ANNULAR: hover any tile at distance 1..range to select its entire ring.
@export var targeting_type: Global.TargetingType = Global.TargetingType.NONE

@export_category("Shape")
@export var shape: Array[Vector2i] = []
