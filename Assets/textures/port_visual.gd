extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	await RenderingServer.frame_post_draw

func _process(_delta: float) -> void:
	sprite.global_position = global_position + Vector2(0, -70)
	# Tweake X et Y jusqu'à ce que ça tombe pile sur la case grise
	# X positif = vers la droite, Y négatif = vers le haut
