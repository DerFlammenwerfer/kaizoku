/obj/item/needle
	name = "needle"
	icon_state = "needle"
	desc = "A firm needle affixed with a simple thread, Pestra's most favored tool."
	icon = 'icons/roguetown/items/misc.dmi'
	lefthand_file = 'icons/mob/inhands/misc/food_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/food_righthand.dmi'
	w_class = WEIGHT_CLASS_TINY
	force = 0
	throwforce = 0
	resistance_flags = FLAMMABLE
	slot_flags = ITEM_SLOT_MOUTH
	max_integrity = 20
	anvilrepair = /datum/skill/craft/blacksmithing
	tool_behaviour = TOOL_SUTURE
	/// Amount of uses left
	var/stringamt = 10
	var/maxstring = 20
	/// If this needle is infinite
	var/infinite = FALSE
	/// If this needle can be used to repair items
	var/can_repair = TRUE

/obj/item/needle/examine()
	. = ..()
	if(!infinite)
		. += "<span class='bold'>It has [stringamt] of [maxstring] uses left.</span>"
	else
		. += "Can be used indefinitely."

/obj/item/needle/Initialize()
	. = ..()
	update_icon()

/obj/item/needle/update_overlays()
	. = ..()
	if(stringamt <= 0)
		. -= "[icon_state]string"
	else
		. += "[icon_state]string"

/obj/item/needle/use(used)
	if(infinite)
		return TRUE
	stringamt = stringamt - used
	update_overlays()
//	if(stringamt <= 0) Needles will no longer delete themselves and can be refilled with individual fibers.
//		qdel(src)

/obj/item/needle/attack(mob/living/M, mob/user)
	sew(M, user)

/obj/item/needle/attack_obj(obj/O, mob/living/user)
	if(can_repair && isitem(O))
		var/obj/item/I = O
		if(I.sewrepair && I.max_integrity && !I.obj_broken)
			if(I.obj_integrity == I.max_integrity)
				to_chat(user, "<span class='warning'>This is not broken.</span>")
				return
			if(user.mind.get_skill_level(/datum/skill/misc/sewing) < I.required_repair_skill)
				to_chat(user, "<span class='warning'>I don't know how to repair this...</span>")
				return
			if(!I.ontable())
				to_chat(user, "<span class='warning'>I should put this on a table first.</span>")
				return
			if(stringamt < 1)
				to_chat(user, "<span class='warning'>There's no thread left...</span>")
				return
			playsound(loc, 'sound/foley/sewflesh.ogg', 100, TRUE, -2)
			var/sewtime = 70
			if(user.mind)
				sewtime = (70 - ((user.mind.get_skill_level(/datum/skill/misc/sewing)) * 10))
			if(do_after(user, sewtime, target = I))
				playsound(loc, 'sound/foley/sewflesh.ogg', 100, TRUE, -2)
				user.visible_message("<span class='info'>[user] repairs [I]!</span>")
				I.obj_integrity = I.max_integrity
				return
		return
	return ..()

/obj/item/needle/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/natural/fibers))
		if(infinite)
			to_chat(user, "<span class='green'>This needle creates its own thread and never needs replenishing.</span>")
			return
		if(maxstring - stringamt < 5)
			to_chat(user, "<span class='warning'>Not enough room for more thread!</span>")
			return
		else
			to_chat(user, "I begin threading the needle with additional fibers...")
			if(do_after(user, 6 SECONDS - user.mind.get_skill_level(/datum/skill/misc/sewing), target = I))
				stringamt += 5
				to_chat(user, "<span class='green'>I replenish the needle's thread.</span>")
				qdel(I)
			return
	return ..()

/obj/item/needle/proc/sew(mob/living/target, mob/living/user)
	if(!istype(user))
		return FALSE
	var/mob/living/doctor = user
	var/mob/living/carbon/human/patient = target
	if(!get_location_accessible(patient, check_zone(doctor.zone_selected)))
		to_chat(doctor, "<span class='warning'>Something in the way.</span>")
		return FALSE
	var/list/sewable
	var/obj/item/bodypart/affecting
	if(iscarbon(patient))
		affecting = patient.get_bodypart(check_zone(doctor.zone_selected))
		if(!affecting)
			to_chat(doctor, "<span class='warning'>That limb is missing.</span>")
			return FALSE
		if(affecting.bandage)
			to_chat(doctor, "<span class='warning'>There is a bandage in the way.</span>")
			return FALSE
		sewable = affecting.get_sewable_wounds()
	else
		sewable = patient.get_sewable_wounds()
	if(stringamt < 1)
		to_chat(user, "<span class='warning'>There's no thread left...</span>")
		return
	if(!length(sewable))
		to_chat(doctor, "<span class='warning'>There aren't any wounds to be sewn.</span>")
		return FALSE
	var/datum/wound/target_wound = input(doctor, "Which wound?", "[src]") as null|anything in sewable
	if(!target_wound)
		return FALSE

	playsound(loc, 'sound/foley/sewflesh.ogg', 100, TRUE, -2)
	var/moveup = 10
	if(doctor.mind)
		moveup = ((doctor.mind.get_skill_level(/datum/skill/misc/medicine)+1) * 5)
	while(!QDELETED(target_wound) && !QDELETED(src) && \
		!QDELETED(user) && (target_wound.sew_progress < target_wound.sew_threshold) && \
		stringamt >= 1)
		if(!do_after(doctor, 20, target = patient))
			break
		playsound(loc, 'sound/foley/sewflesh.ogg', 100, TRUE, -2)
		target_wound.sew_progress = min(target_wound.sew_progress + moveup, target_wound.sew_threshold)
		if(target_wound.sew_progress < target_wound.sew_threshold)
			continue
		if(doctor.mind)
			doctor.mind.adjust_experience(/datum/skill/misc/medicine, doctor.STAINT * 5)
		use(1)
		target_wound.sew_wound()
		if(patient == doctor)
			doctor.visible_message("<span class='notice'>[doctor] sews \a [target_wound.name] on [doctor.p_them()]self.</span>", "<span class='notice'>I stitch \a [target_wound.name] on my [affecting].</span>")
		else
			if(affecting)
				doctor.visible_message("<span class='notice'>[doctor] sews \a [target_wound.name] on [patient]'s [affecting].</span>", "<span class='notice'>I stitch \a [target_wound.name] on [patient]'s [affecting].</span>")
			else
				doctor.visible_message("<span class='notice'>[doctor] sews \a [target_wound.name] on [patient].</span>", "<span class='notice'>I stitch \a [target_wound.name] on [patient].</span>")
		log_combat(doctor, patient, "sew", "needle")
		return TRUE
	return FALSE

/obj/item/needle/thorn
	name = "wooden needle"
	icon_state = "thornneedle"
	desc = "This rough needle can be used to sew cloth and wounds."
	stringamt = 5

/obj/item/needle/blessed
	name = "blessed needle"
	desc = "<span class='hierophant'>A needle blessed by the ordained of the Church. A coveted item.</span>"
	infinite = TRUE
