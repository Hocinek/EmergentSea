extends Node2D

# Liste des navires créés
@export var liste_navires : Dictionary[int, Navires] = {}

# Liste des joueurs
@export var liste_joueurs : Dictionary = {
	1: { "nom": "Joueur 1", "couleur": Color.BLUE, "is_player": true },   # Joueur humain
	2: { "nom": "Joueur 2", "couleur": Color.RED, "is_player": false }     # Ennemi (immobile)
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _enter_tree():
	add_to_group("shared_entities")

func getPlayerList() -> Dictionary:
	return liste_joueurs

# permet de récupérer la liste des navires sur une case précise
func getNavireByPosition(pos: Vector2i) -> Array:
	# liste des navires trouvés
	var found : Array = []
	
	if not liste_navires.is_empty():
		# Créer une liste des UUIDs à supprimer
		var to_remove : Array = []
		
		for uuid in liste_navires.keys():
			var ship = liste_navires[uuid]
			
			# Vérifier que le navire existe toujours
			if not is_instance_valid(ship):
				to_remove.append(uuid)
				continue
			
			# Vérifier la position
			if ship.getPosition() == pos:
				found.append(ship)
		
		# Nettoyer les navires invalides
		for uuid in to_remove:
			liste_navires.erase(uuid)
			DEBUG.log("Navire avec UUID %d supprimé de la liste (invalide)" % uuid)
	
	return found

func addNavireToData(ship: Navires) -> bool:
	# Vérifier que le navire a un propriétaire
	if not ship.player_owner:
		DEBUG.log("Le navire n'a pas de propriétaire (player_owner est null) !",DEBUG.ERROR)
		return false
	
	# Utiliser l'ID du joueur propriétaire
	var player_id = ship.player_owner.player_id if ship.player_owner else 0
	
	# Générer un UUID simple : utiliser la taille actuelle + ID du navire
	var uuid = liste_navires.size() + (player_id * 1000) + ship.id
	
	# S'assurer que l'UUID est unique
	var attempts = 0
	while liste_navires.has(uuid) and attempts < 100:
		uuid += 1
		attempts += 1
	
	if attempts >= 100:
		DEBUG.log("Impossible de générer un UUID unique pour le navire !",DEBUG.ERROR)
		return false
	
	# Ajouter le navire à la liste
	liste_navires[uuid] = ship
	
	# Connecter le signal de mort pour nettoyer automatiquement
	if not ship.sig_navire_died.is_connected(_on_navire_died):
		ship.sig_navire_died.connect(_on_navire_died.bind(uuid))
	
	DEBUG.log("Navire ajouté à la liste avec UUID: %d (Joueur: %s, ID: %d)" % [uuid, ship.player_owner.player_name, ship.id])
	return true

# Callback appelé quand un navire meurt
func _on_navire_died(navire: Navires, uuid: int) -> void:
	if liste_navires.has(uuid):
		liste_navires.erase(uuid)
		DEBUG.log("Navire avec UUID %d retiré de la liste (mort)" % uuid)

# Fonction utilitaire pour nettoyer tous les navires invalides
func cleanup_invalid_ships() -> void:
	var to_remove : Array = []
	
	for uuid in liste_navires.keys():
		var ship = liste_navires[uuid]
		if not is_instance_valid(ship):
			to_remove.append(uuid)
	
	for uuid in to_remove:
		liste_navires.erase(uuid)
	
	if to_remove.size() > 0:
		DEBUG.log("%d navire(s) invalide(s) nettoyé(s)" % to_remove.size())
