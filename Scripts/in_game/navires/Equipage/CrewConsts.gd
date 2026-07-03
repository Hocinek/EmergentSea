class_name CrewConsts

# =========================
# CONSTANTES DE SYNERGIES
# =========================
const MAX_CREW: int = 6

## Synergie "Flotte de guerre" : Canonnier + Corsaire + Tireur d'élite -> dgt_tir x1.5
const SYNERGIE_GUERRE := [CrewMember.Role.CANONNIER, CrewMember.Role.CORSAIRE, CrewMember.Role.TIREUR_ELITE]

## Synergie "Navire de pêche" : Pêcheur + Cuisinier -> bonus_peche x2
const SYNERGIE_PECHE := [CrewMember.Role.PECHEUR, CrewMember.Role.CUISINIER]

## Synergie "Duo de soins" : Médecin + Cuisinier -> regen_vie doublée
const SYNERGIE_SOINS := [CrewMember.Role.MEDECIN, CrewMember.Role.CUISINIER]

## Synergie "Vitesse maximale" : Navigateur + Éclaireur -> +200 vitesse
const SYNERGIE_VITESSE := [CrewMember.Role.NAVIGATEUR, CrewMember.Role.ECLAIREUR]

## Synergie "Équipage complet" : 6 membres -> +10% sur toutes les stats
const SYNERGIE_FULL_CREW_SIZE: int = 6


# Limite maximale par rôle (-1 ou absent = pas de limite)
const ROLE_MAX: Dictionary = {
	CrewMember.Role.DIPLOMATE:  1,
	CrewMember.Role.INGENIEUR:  2,
	CrewMember.Role.NAVIGATEUR: 1,
}

# Membres disponibles à l'achat (tous les rôles sauf capitaine)
const HIREABLE_ROLES: Array = [
	CrewMember.Role.CANONNIER,
	CrewMember.Role.NAVIGATEUR,
	CrewMember.Role.MEDECIN,
	CrewMember.Role.PECHEUR,
	CrewMember.Role.CORSAIRE,
	CrewMember.Role.TIREUR_ELITE,
	CrewMember.Role.ECLAIREUR,
	CrewMember.Role.INGENIEUR,
	CrewMember.Role.CUISINIER,
	CrewMember.Role.MATELOT,
	CrewMember.Role.DIPLOMATE,
]


# =========================
# DONNÉES DES SYNERGIES (pour le panel d'info)
# Chaque entrée : { icon, nom, membres_requis, effet }
# Les noms correspondent exactement aux chaînes retournées par get_active_synergies()
# =========================
static var SYNERGY_DATA: Array = []
static func _init_synergie_data():
	SYNERGY_DATA = [
		{
			"icon":           "⚔️",
			"nom":            "Flotte de guerre",
			"membres_requis": [
				get_role_string(CrewMember.Role.CANONNIER),
				get_role_string(CrewMember.Role.CORSAIRE),
				get_role_string(CrewMember.Role.TIREUR_ELITE)
			],
			"effet":          "dgt_tir x 1.5 (bonus proportionnel aux dégâts déjà accumulés)",
		},
		{
			"icon":           "🎣",
			"nom":            "Navire de pêche",
			"membres_requis": [
				get_role_string(CrewMember.Role.PECHEUR),
				get_role_string(CrewMember.Role.CUISINIER)
			],
			"effet":          "Rendement de pêche x 2",
		},
		{
			"icon":           "⚕️",
			"nom":            "Duo de soins",
			"membres_requis": [
				get_role_string(CrewMember.Role.MEDECIN),
				get_role_string(CrewMember.Role.CUISINIER)
			],
			"effet":          "Régénération de PV du Médecin x 2 par tour",
		},
		{
			"icon":           "🧭",
			"nom":            "Vitesse maximale",
			"membres_requis": [
				get_role_string(CrewMember.Role.NAVIGATEUR),
				get_role_string(CrewMember.Role.ECLAIREUR)
			],
			"effet":          "-25% coût de déplacement",
		},
		{
			"icon":           "👥",
			"nom":            "Équipage complet",
			"membres_requis": ["6 membres à bord (Capitaine inclus)"],
			"effet":          "+10% sur les dégâts de tir et les poissons passifs par tour",
		},
	]

static func get_role_string(role: CrewMember.Role) -> String:
	return "%s %s" % [CrewMember.ROLE_ICONS[role], CrewMember.ROLE_NAMES[role]]

static func _static_init() -> void:
	_init_synergie_data()
