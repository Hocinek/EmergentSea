extends Node
class_name Player

# ===============================
# DONNEES DU JOUEUR
# ===============================
@export var player_id: int = -1
@export var player_name: String = ""
@export var is_human: bool = true
@export var is_local: bool = false

# ===============================
# DONNEES DE JEU
# ===============================
## Liste des navires appartenant à ce joueur
var navires: Array[Navires] = []

## Liste des ports appartenant à ce joueur
var ports: Array[Ports] = []

# ===============================
# NAVIRES
# ===============================
func add_navire(navire: Navires) -> void:
	if navire == null:
		return
	if navires.has(navire):
		return
	
	navires.append(navire)
	# Utiliser player_owner au lieu de owner
	navire.player_owner = self


func remove_navire(navire: Navires) -> void:
	if navire == null:
		return
	if navires.has(navire):
		navires.erase(navire)
		navire.player_owner = null


func owns_navire(navire: Navires) -> bool:
	return navires.has(navire)


func get_navires() -> Array[Navires]:
	return navires


# ===============================
# PORTS
# ===============================
func add_port(port: Ports) -> void:
	if port == null:
		return
	if ports.has(port):
		return
	
	ports.append(port)
	# Utiliser player_owner au lieu de owner
	port.player_owner = self


func remove_port(port: Ports) -> void:
	if port == null:
		return
	if ports.has(port):
		ports.erase(port)
		port.player_owner = null


func owns_port(port: Ports) -> bool:
	return ports.has(port)


func get_ports() -> Array[Ports]:
	return ports


# ===============================
# ETAT DU JOUEUR 
# ===============================
func has_alive_navires() -> bool:
	for n in navires:
		if n.is_alive():
			return true
	return false


func get_navire_count() -> int:
	return navires.size()


func get_alive_navire_count() -> int:
	var count = 0
	for n in navires:
		if n.is_alive():
			count += 1
	return count


## Retourne le total de poissons accumulés sur tous les navires du joueur
func get_poissons() -> int:
	var total: int = 0
	for n in navires:
		if "nourriture" in n:
			total += n.nourriture
	return total
