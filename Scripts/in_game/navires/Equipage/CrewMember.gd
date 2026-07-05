class_name CrewMember
extends RefCounted

# =========================
# TYPES DE MEMBRES D'ÉQUIPAGE
# =========================
enum Role {
	CAPITAINE,       # Slot 0 - toujours présent, ne peut pas être retiré
	CANONNIER,       # Augmente les dégâts de tir
	NAVIGATEUR,      # Augmente la vitesse et l'énergie max
	MEDECIN,         # Augmente les PV max et régénère des PV
	PECHEUR,         # Améliore le rendement de pêche
	CORSAIRE,        # Gros dégâts de tir, spécialiste du combat
	TIREUR_ELITE,    # Augmente la portée de tir
	ECLAIREUR,       # Augmente le rayon de vision + vitesse
	INGENIEUR,       # Augmente l'énergie max
	CUISINIER,       # +1 poisson par tour
	MATELOT,         # +PV max, polyvalent et pas cher
	DIPLOMATE,       # Réduit le coût de recrutement de tous
}

# Noms affichés en boutique
const ROLE_NAMES: Dictionary = {
	Role.CAPITAINE:      "Capitaine",
	Role.CANONNIER:      "Canonnier",
	Role.NAVIGATEUR:     "Navigateur",
	Role.MEDECIN:        "Médecin",
	Role.PECHEUR:        "Pêcheur",
	Role.CORSAIRE:       "Corsaire",
	Role.TIREUR_ELITE:   "Tireur d'élite",
	Role.ECLAIREUR:      "Éclaireur",
	Role.INGENIEUR:      "Ingénieur",
	Role.CUISINIER:      "Cuisinier",
	Role.MATELOT:        "Matelot",
	Role.DIPLOMATE:      "Diplomate",
}

const ROLE_ICONS: Dictionary = {
	Role.CAPITAINE:      "🎖️",
	Role.CANONNIER:      "💣",
	Role.NAVIGATEUR:     "🧭",
	Role.MEDECIN:        "⚕️",
	Role.PECHEUR:        "🎣",
	Role.CORSAIRE:       "🏴",
	Role.TIREUR_ELITE:   "🎯",
	Role.ECLAIREUR:      "🔭",
	Role.INGENIEUR:      "⚙️",
	Role.CUISINIER:      "🍳",
	Role.MATELOT:        "⚓",
	Role.DIPLOMATE:      "🤝",
}

const ROLE_DESCRIPTIONS: Dictionary = {
	Role.CAPITAINE:      "Dirige le navire. Ne peut pas être remplacé.",
	Role.CANONNIER:      "+1 dégâts de tir",
	Role.NAVIGATEUR:     "+10 énergie max, -15% coût de déplacement",
	Role.MEDECIN:        "+5 PV max, régénère 1 PV/tour",
	Role.PECHEUR:        "+2 poissons par pêche",
	Role.CORSAIRE:       "+3 dégâts de tir",
	Role.TIREUR_ELITE:   "+2 portée de tir",
	Role.ECLAIREUR:      "+15 rayon de vision",
	Role.INGENIEUR:      "+10 énergie max",
	Role.CUISINIER:      "+1 poisson par tour",
	Role.MATELOT:        "+6 PV max",
	Role.DIPLOMATE:      "-20% coût de recrutement",
}

const ROLE_COSTS: Dictionary = {
	Role.CAPITAINE:      0,
	Role.CANONNIER:      12,
	Role.NAVIGATEUR:     15,
	Role.MEDECIN:        18,
	Role.PECHEUR:        12,
	Role.CORSAIRE:       30,
	Role.TIREUR_ELITE:   17,
	Role.ECLAIREUR:      13,
	Role.INGENIEUR:      12,
	Role.CUISINIER:      8,
	Role.MATELOT:        5,
	Role.DIPLOMATE:      14,
}

# =========================
# DONNÉES DU MEMBRE
# =========================
var role: Role
var nom: String
var cost: int  # En poissons

# Bonus appliqués au navire
var bonus_dgt_tir: int       = 0
var bonus_maxvie: int        = 0
var bonus_maxenergie: int    = 0
var reduction_cout_deplacement: float = 0.0  # Réduction du coût en énergie par case (0.0–1.0)
var bonus_peche: int         = 0
var regen_vie_par_tour: int  = 0
var bonus_tir: int           = 0   # Portée de tir
var bonus_vision: int        = 0   # Bonus en cases de vision (pour FogOfWar)
var poissons_par_tour: int   = 0   # Poissons gagnés en fin de tour
var reduction_cout: float    = 0.0 # Réduction sur les coûts de recrutement (0.0–1.0)


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
			reduction_cout_deplacement = 0.15  # -15% coût en énergie par case
		Role.MEDECIN:
			bonus_maxvie = 5
			regen_vie_par_tour = 1
		Role.PECHEUR:
			bonus_peche = 2
		Role.CORSAIRE:
			bonus_dgt_tir = 3
		Role.TIREUR_ELITE:
			bonus_tir = 2
		Role.ECLAIREUR:
			bonus_vision = 2   # +2 cases de vision
		Role.INGENIEUR:
			bonus_maxenergie = 10
		Role.CUISINIER:
			poissons_par_tour = 1
		Role.MATELOT:
			bonus_maxvie = 6
		Role.DIPLOMATE:
			reduction_cout = 0.20
		Role.CAPITAINE:
			pass  # Aucun bonus particulier, c'est le chef


func get_icon() -> String:
	return ROLE_ICONS.get(role, "👤")


func get_description() -> String:
	return ROLE_DESCRIPTIONS.get(role, "")


func get_display_name() -> String:
	return "%s %s" % [get_icon(), nom]
