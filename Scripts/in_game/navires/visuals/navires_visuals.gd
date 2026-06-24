## Classe de gestion des visuels d'un navire
class_name NaviresVisuals
extends Node

"""
Cette classe va gérer la partie visuelle associée à un navire.

Parmi les tâches de cette classe, il y a :
	- l'affichage du bateau et son animation
	- la gestion de l'affichage des stats
	- la gestion de l'affichage des animations liées à une action (exemple : déplacement, pêche)
	- la gestion des animations récurrentes (flèche de déplacement, cercle de sélection,...)

objectif :
	- réduire la taille de navires.gd
	- séparer les fonctions liées à l'UI/UX des fonctions gameplay
	- faciliter la maintenance du projet
"""

var ship : Navires
@export var ship_model_path: String = "res://Assets/navire/pirateShip.glb"

#region rotation navire
## Angle cible vers lequel le bateau doit se tourner (en radians)
var target_rotation_angle: float = 0.0
## Vitesse de rotation en radians/seconde
@export var rotation_speed: float = 5.0
## Correction d'angle selon l'orientation par défaut de votre asset (en degrés).
@export var rotation_offset_deg: float = -90.0
## Inverser le sens de rotation si le bateau tourne à l'envers
@export var rotation_invert: bool = false

## Nœud visuel à tourner (Sprite2D) — résolu dans _ready
var _visual_node: Node2D = null

## Décalage du centre visuel réel du bateau par rapport au centre de la texture.
@export var pivot_offset_y: float = 0.0

#si rien ne casse, ce sera supprimé
## Centre visuel du bateau en coordonnées locales du Node2D racine (calculé au _ready).
#var _pivot_local: Vector2 = Vector2.ZERO

## Référence au Node3D pirateShip — tourné via Transform3D axe Y uniquement
var _pirate_ship_3d: Node3D = null
#endregion rotation navire

# =========================
# DÉCALAGE VISUEL DU SPRITE
# =========================
## Décale le Sprite2D pour que le centre VISUEL du bateau coïncide avec
## global_position (= l'ancre logique utilisée pour déterminer la case occupée).
@export var hull_offset: Vector2 = Vector2.ZERO

func _init(bateau:Navires):
	self.ship = bateau
	self._setup_node3d_instance()


func _setup_node3d_instance() -> void:
	"""
	SOLUTION FINALE — doc Godot Transform3D + own_world_3d :

	1. own_world_3d = true sur le SubViewport → chaque navire a son propre
	   monde 3D isolé, les rotations ne se partagent plus entre instances.

	2. On charge dynamiquement le modèle défini dans ship_model_path,
	   ce qui permet d'avoir des modèles différents selon le joueur propriétaire.
	   Le modèle est nommé "pirateShip" après instanciation pour que le reste
	   du code (rotation, etc.) fonctionne de manière uniforme.

	3. Le Sprite2D n'est jamais tourné → pas de problème de pivot 2D.
	"""
	# Isoler le monde 3D de ce SubViewport pour éviter le partage entre instances
	var subviewport = ship.get_node_or_null("Sprite2D/SubViewport")
	if subviewport:
		subviewport.own_world_3d = true
		DEBUG.log("Navire [%d] - SubViewport.own_world_3d = true" % ship.id)
	else:
		DEBUG.log("Navire [%d] - Aucun SubViewport trouvé" % ship.id)

	# Récupérer le Node3D parent qui contiendra notre modèle
	var node3d = subviewport.get_node_or_null("Node3D")
	if not node3d:
		DEBUG.log("Navire [%d] - ERREUR : Node3D introuvable" % ship.id)
		return

	# Supprimer le modèle par défaut présent dans la scène de base
	# (free() immédiat : on est dans _ready avant que le modèle soit utilisé)
	var existing = node3d.get_node_or_null("pirateShip")
	if existing:
		existing.free()
		DEBUG.log("Navire [%d] - Modèle par défaut supprimé" % ship.id)

	# Charger et instancier le bon modèle selon ship_model_path
	var model_scene: PackedScene = load(ship_model_path)
	if model_scene:
		var model_instance: Node3D = model_scene.instantiate()
		# Nom uniforme "pirateShip" pour que toute la logique de rotation
		# reste identique quel que soit le modèle chargé
		model_instance.name = "pirateShip"
		node3d.add_child(model_instance)
		_pirate_ship_3d = model_instance
		target_rotation_angle = model_instance.rotation.y
		DEBUG.log("Navire [%d] - Modèle chargé avec succès : '%s'" % [ship.id, ship_model_path])
	else:
		DEBUG.log("Navire [%d] - ERREUR : Impossible de charger le modèle '%s'" % [ship.id, ship_model_path])

	# Le Sprite2D reste en place — on ne le tourne pas.
	# hull_offset décale le sprite pour que le centre VISUEL du bateau
	# coïncide avec global_position (ancre logique = case occupée).
	_visual_node = ship.get_node_or_null("Sprite2D")
	if _visual_node:
		_visual_node.position = hull_offset
		DEBUG.log("Navire [%d] - hull_offset appliqué : %s" % [ship.id, hull_offset])


# function qui sert peut-être à rien, sera peut-être supprimée si rien ne casse
#func _resolve_visual_node() -> void:
	#pass


func get_visual_rotation() -> float:
	if _pirate_ship_3d:
		return _pirate_ship_3d.rotation.y
	return target_rotation_angle


func _set_visual_rotation(angle: float) -> void:
	"""
	Tourne le pirateShip UNIQUEMENT sur l'axe Y via Transform3D.basis.
	Les axes X et Z restent intacts → pas de surrélevement quelle que soit
	la position du modèle dans le SubViewport.
	own_world_3d = true garantit que cette rotation n'affecte pas les autres navires.
	"""
	if _pirate_ship_3d == null:
		return
	var new_basis = Basis.from_euler(Vector3(0.0, angle, 0.0))
	_pirate_ship_3d.transform = Transform3D(new_basis, _pirate_ship_3d.transform.origin)


#region rotation
func _update_ship_rotation(delta: float) -> void:
	if _pirate_ship_3d == null:
		return
	var current = _pirate_ship_3d.rotation.y
	var diff    = angle_difference(current, target_rotation_angle)
	if abs(diff) < 0.009:
		_set_visual_rotation(target_rotation_angle)
		return
	_set_visual_rotation(lerp_angle(current, target_rotation_angle, rotation_speed * delta))


func compute_target_rotation(direction: Vector2) -> float:
	# Le SubViewport 3D a son axe X miroir par rapport au 2D :
	# → haut/bas sont corrects, mais gauche/droite sont inversés.
	# On négative uniquement X pour corriger ce miroir horizontal.
	var mirrored := Vector2(-direction.x, direction.y)
	var angle = mirrored.angle() + deg_to_rad(rotation_offset_deg)
	if rotation_invert:
		angle += PI
	self.set_target_rotation(angle)
	return angle


func set_target_rotation(angle):
	self.target_rotation_angle = angle

#endregion rotation

func _process(delta: float) -> void:
	if self.get_visual_rotation() != self.target_rotation_angle :
		_update_ship_rotation(delta)
