class_name CrewMember
extends RefCounted

# =========================
# TYPES DE MEMBRES D'ÉQUIPAGE
# =========================
enum Role {
	CAPITAINE,    # Slot 0 — toujours présent, ne peut pas être retiré
	CANONNIER,    # Augmente les dégâts de tir
	NAVIGATEUR,   # Augmente la vitesse et l'énergie max
	MEDECIN,      # Augmente les PV max
	PECHEUR,      # Améliore le rendement de pêche
}

# Noms affichés en boutique
const ROLE_NAMES: Dictionary = {
	Role.CAPITAINE:  "Capitaine",
	Role.CANONNIER:  "Canonnier",
	Role.NAVIGATEUR: "Navigateur",
	Role.MEDECIN:    "Médecin",
	Role.PECHEUR:    "Pêcheur",
}

const ROLE_ICONS: Dictionary = {
	Role.CAPITAINE:  "🎖️",
	Role.CANONNIER:  "💣",
	Role.NAVIGATEUR: "🧭",
	Role.MEDECIN:    "⚕️",
	Role.PECHEUR:    "🎣",
}

const ROLE_DESCRIPTIONS: Dictionary = {
	Role.CAPITAINE:  "Dirige le navire. Ne peut pas être remplacé.",
	Role.CANONNIER:  "+3 dégâts de tir",
	Role.NAVIGATEUR: "+10 énergie max, +80 vitesse",
	Role.MEDECIN:    "+5 PV max, régénère 1 PV par tour",
	Role.PECHEUR:    "+2 poissons par pêche",
}

const ROLE_COSTS: Dictionary = {
	Role.CAPITAINE:  0,
	Role.CANONNIER:  15,
	Role.NAVIGATEUR: 12,
	Role.MEDECIN:    18,
	Role.PECHEUR:    10,
}

# =========================
# DONNÉES DU MEMBRE
# =========================
var role: Role
var nom: String
var cost: int  # En poissons

# Bonus appliqués au navire
var bonus_dgt_tir: int     = 0
var bonus_maxvie: int      = 0
var bonus_maxenergie: int  = 0
var bonus_vitesse: float   = 0.0
var bonus_peche: int       = 0
var regen_vie_par_tour: int = 0


func _init(p_role: Role) -> void:
	role = p_role
	nom = ROLE_NAMES[role]
	cost = ROLE_COSTS[role]
	_apply_role_bonuses()


func _apply_role_bonuses() -> void:
	match role:
		Role.CANONNIER:
			bonus_dgt_tir = 1
		Role.NAVIGATEUR:
			bonus_maxenergie = 10
			bonus_vitesse = 80.0
		Role.MEDECIN:
			bonus_maxvie = 5
			regen_vie_par_tour = 1
		Role.PECHEUR:
			bonus_peche = 2
		Role.CAPITAINE:
			pass  # Aucun bonus particulier, c'est le chef


func get_icon() -> String:
	return ROLE_ICONS.get(role, "👤")


func get_description() -> String:
	return ROLE_DESCRIPTIONS.get(role, "")


func get_display_name() -> String:
	return "%s %s" % [get_icon(), nom]
