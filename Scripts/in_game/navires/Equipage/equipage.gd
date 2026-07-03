class_name Equipage
extends Node

var pre_calc_bonus : Dictionary = {
	"dgt":0,
	"portee":0,
	"max_vie":0,
	"max_energie":0,
	"regen":0,
	"passif_peche":0,
	"reduction_cout_achat":0.,
	"peche":0,
	"reduction_cout_deplacement":0,
	"vision":0
}

var equipage: Array[CrewMember] = []
var nbequipage: int = 0

var _synergy_peche_mult: float           = 1.0
var _synergy_regen_mult: float           = 1.0
var _synergy_move_cost_reduction: float  = 0.0  # Réduction du coût de déplacement par synergie (0.0–1.0)
var _synergy_full_crew: bool             = false

var ship : Navires




func _init(bateau:Navires):
	self.ship = bateau
	_init_crew()
	compute_crew_bonus()


## Initialise l'équipage avec le capitaine par défaut.
func _init_crew() -> void:
	if equipage.is_empty():
		var capitaine = CrewMember.new(CrewMember.Role.CAPITAINE)
		equipage.append(capitaine)
		nbequipage = equipage.size()
		DEBUG.log("Navire [%d] - Capitaine ajouté, équipage initialisé." % ship.id)

func reset_stats() -> void:
	ship.maxvie = ship.DEFAULT_MAXVIE
	ship.maxenergie = ship.DEFAULT_MAXENERGIE
	ship.tir = ship.DEFAULT_PORTEE_TIR
	ship.dgt_tir = ship.DEFAULT_DEGAT_TIR

## Calcule les bonus apportés par l'équipage
func compute_crew_bonus():
	reset_stats()
	pre_calc_bonus.dgt = 0
	pre_calc_bonus.portee = 0
	pre_calc_bonus.max_vie = 0
	pre_calc_bonus.max_energie = 0
	pre_calc_bonus.regen = 0
	pre_calc_bonus.passif_peche = 0
	pre_calc_bonus.reduction_cout_achat = 0
	pre_calc_bonus.peche = 0
	pre_calc_bonus.vision = 0
	pre_calc_bonus.reduction_cout_deplacement = 0
	for member in equipage:
		pre_calc_bonus.dgt += member.bonus_dgt_tir
		pre_calc_bonus.portee += member.bonus_tir
		pre_calc_bonus.max_vie += member.bonus_maxvie
		pre_calc_bonus.max_energie += member.bonus_maxenergie
		pre_calc_bonus.passif_peche += member.poissons_par_tour
		if member.reduction_cout > pre_calc_bonus.reduction_cout_achat:
			pre_calc_bonus.reduction_cout_achat = member.reduction_cout
		pre_calc_bonus.peche += member.bonus_peche
		pre_calc_bonus.vision += member.bonus_vision
		if member.reduction_cout_deplacement > pre_calc_bonus.reduction_cout_deplacement:
			pre_calc_bonus.reduction_cout_deplacement = member.reduction_cout_deplacement
	compute_crew_synergies()
	pre_calc_bonus.reduction_cout_deplacement = minf(pre_calc_bonus.reduction_cout_deplacement, 0.5)
	apply_crew_bonus()

func apply_crew_bonus()->void:
	ship.maxvie += pre_calc_bonus.max_vie
	ship.maxenergie += pre_calc_bonus.max_energie
	ship.tir += pre_calc_bonus.portee

func get_equipage_array() -> Array[CrewMember]:
	return equipage

func get_equipage_size() -> int:
	return equipage.size()

#region modification_equipage
## Ajoute un membre d'équipage et applique ses bonus.
func add_crew_member(member: CrewMember) -> void:
	if equipage.size() >= CrewConsts.MAX_CREW:
		DEBUG.log("Navire [%d] - Équipage plein, impossible d'ajouter %s." % [ship.id, member.nom], DEBUG.WARNING)
		return

	equipage.append(member)
	nbequipage = equipage.size()
	compute_crew_bonus()
	DEBUG.log("Navire [%d] - %s rejoint l'équipage (total : %d)" % [ship.id, member.nom, nbequipage])


## Retire un membre à un index donné (0 = capitaine, protégé).
func remove_crew_member(index: int) -> void:
	if index <= 0 or index >= equipage.size():
		DEBUG.log("Navire [%d] - Impossible de retirer le membre à l'index %d." % [ship.id, index], DEBUG.WARNING)
		return

	var crew_name: String = equipage[index].nom
	equipage.remove_at(index)
	nbequipage = equipage.size()
	compute_crew_bonus()
	DEBUG.log("Navire [%d] - %s a quitté l'équipage (total : %d)" % [ship.id, crew_name, nbequipage])
#endregion modification_equipage


#region utils
## Vérifie si un rôle est déjà occupé dans l'équipage.
func has_crew_role(role: CrewMember.Role) -> bool:
	for member in equipage:
		if member.role == role:
			return true
	return false


## Retourne le nombre de membres ayant un rôle donné.
func count_crew_role(role: CrewMember.Role) -> int:
	var count := 0
	for member in equipage:
		if member.role == role:
			count += 1
	return count


## Retourne le coût d'un rôle après réduction Diplomate.
func get_hire_cost(role: CrewMember.Role) -> int:
	var base_cost: int = CrewMember.ROLE_COSTS[role]
	return maxi(1, int(float(base_cost) * (1.0 - pre_calc_bonus.reduction_cout_achat)))

#endregion utils



## Retourne le coût en énergie d'un déplacement d'une case (après réductions équipage + synergies).
func get_effective_move_cost() -> float:
	var reduction := _synergy_move_cost_reduction
	for member in equipage:
		reduction = maxf(reduction, member.reduction_cout_deplacement)
	return maxf(1.0 - reduction, 0.5)  # plancher à 0.5 -> roundi() donnera toujours au moins 1


## Calcule et applique toutes les synergies d'équipage.
## Appelée après chaque add/remove pour recalculer l'état courant.
func compute_crew_synergies() -> void:
	# Retire les anciens bonus de synergie avant recalcul
	_synergy_peche_mult           = 1.0
	_synergy_regen_mult           = 1.0
	_synergy_move_cost_reduction  = 0.0
	_synergy_full_crew            = false

	var roles_presents: Array = equipage.map(func(m): return m.role)

	# -- Flotte de guerre : Canonnier + Corsaire + Tireur d'élite -> dgt_tir x1.5 --
	if _has_all_roles(CrewConsts.SYNERGIE_GUERRE, roles_presents):
		var bonus := int(float(ship.dgt_tir + pre_calc_bonus.dgt) * 0.5)
		pre_calc_bonus.dgt += bonus
		DEBUG.log("Navire [%d] - ⚔️ Synergie Flotte de guerre active (+%d dgt)" % [ship.id, bonus])

	# -- Navire de pêche : Pêcheur + Cuisinier -> bonus_peche x2 --
	if _has_all_roles(CrewConsts.SYNERGIE_PECHE, roles_presents):
		_synergy_peche_mult = 2.0
		DEBUG.log("Navire [%d] - 🎣 Synergie Navire de pêche active (pêche x2)" % ship.id)

	# -- Duo de soins : Médecin + Cuisinier -> regen_vie doublée --
	if _has_all_roles(CrewConsts.SYNERGIE_SOINS, roles_presents):
		_synergy_regen_mult = 2.0
		DEBUG.log("Navire [%d] - ⚕️ Synergie Duo de soins active (regen x2)" % ship.id)

	# -- Vitesse maximale : Navigateur + Éclaireur -> -25% coût de déplacement --
	if _has_all_roles(CrewConsts.SYNERGIE_VITESSE, roles_presents):
		_synergy_move_cost_reduction = 0.25
		DEBUG.log("Navire [%d] - 🧭 Synergie Vitesse maximale active (-25%% coût déplacement)" % ship.id)

	# -- Équipage complet : 6 membres -> +10% toutes stats --
	if equipage.size() >= CrewConsts.SYNERGIE_FULL_CREW_SIZE:
		_synergy_full_crew = true
		DEBUG.log("Navire [%d] - 👥 Synergie Équipage complet active (+10%% stats)" % ship.id)


## Vérifie que tous les rôles de la liste sont présents dans l'équipage.
func _has_all_roles(required: Array, present: Array) -> bool:
	for r in required:
		if not r in present:
			return false
	return true


## Retourne le bonus total de vision de l'équipage (en cases, pour FogOfWar).
func get_crew_vision_bonus() -> int:
	return pre_calc_bonus.vision


## Retourne les dégâts de tir effectifs (bonus équipage complet inclus).
func get_effective_dgt_tir() -> int:
	var base :int= self.ship.dgt_tir + pre_calc_bonus.dgt
	if _synergy_full_crew:
		base = int(float(base) * 1.1)
	return base

## Retourne le nombre de poissons pêchés après application du bonus de l'équipage
func get_effective_peche(poissons : int) -> int:
	poissons += pre_calc_bonus.peche
	return int(float(poissons) * _synergy_peche_mult)


## À appeler en fin de tour (par le TurnManager) pour régénération et revenus passifs.
func apply_crew_end_of_turn() -> void:
	# Régénération PV (Médecin, x2 si synergie Duo de soins)
	var regen = int(float(pre_calc_bonus.regen) * _synergy_regen_mult)
	ship.vie = min(ship.vie + regen, ship.maxvie)
	DEBUG.log("Navire [%d] - Regen PV +%d -> %d/%d" % [ship.id, regen, ship.vie, ship.maxvie])

	# Poissons passifs (Cuisinier)
	var poissons_passifs :int= pre_calc_bonus.passif_peche
	if _synergy_full_crew:
		poissons_passifs = int(float(poissons_passifs) * 1.1)
	if poissons_passifs > 0:
		ship.nourriture += poissons_passifs
		DEBUG.log("Navire [%d] - Revenus passifs : +%d poissons" % [ship.id, poissons_passifs])


## Retourne un résumé des synergies actives pour l'UI.
func get_active_synergies() -> Array[String]:
	var result: Array[String] = []
	var roles_presents: Array = equipage.map(func(m): return m.role)
	if _has_all_roles(CrewConsts.SYNERGIE_GUERRE,  roles_presents): result.append("⚔️ Flotte de guerre")
	if _has_all_roles(CrewConsts.SYNERGIE_PECHE,   roles_presents): result.append("🎣 Navire de pêche")
	if _has_all_roles(CrewConsts.SYNERGIE_SOINS,   roles_presents): result.append("⚕️ Duo de soins")
	if _has_all_roles(CrewConsts.SYNERGIE_VITESSE, roles_presents): result.append("🧭 Vitesse maximale")
	if _synergy_full_crew:                               result.append("👥 Équipage complet")
	return result
