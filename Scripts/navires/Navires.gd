class_name Navires
extends Node3D

@export var id: int
@export var joueur_id: int
@export var hex_pos: Vector2i = Vector2i(0, 0)
@export var vie: int = 10
@export var maxvie: int = 10
@export var energie: int = 5
@export var maxenergie: int = 5
@export var vitesse: float = 1.0
@export var nrbequipage: int = 0
#var Equipage
