perplayer_gamemode = { creative = {}, damage = {} }

dofile(minetest.get_modpath("perplayer_gamemode") .. "/ChatCmdBuilder.lua")

function perplayer_gamemode.is_in_creative_mode(name)
	if perplayer_gamemode.creative[name] == nil then
		return minetest.setting_getbool("creative_mode")
	else
		return perplayer_gamemode.creative[name]
	end
end
function perplayer_gamemode.can_take_damage(name)
	if perplayer_gamemode.creative[name] == nil then
		return false
	else
		return perplayer_gamemode.damage[name]
	end
end

function perplayer_gamemode.set_creative(name, v)
	perplayer_gamemode.creative[name] = v

	local player = minetest.get_player_by_name(name)
	if player then
		local context = sfinv.contexts[name]
		context.page = sfinv.get_homepage_name(player)
		sfinv.set_player_inventory_formspec(player)
	end
end
function perplayer_gamemode.set_damage(name, v)
	perplayer_gamemode.damage[name] = v

	local player = minetest.get_player_by_name(name)
	if player then
		local context = sfinv.contexts[name]
		context.page = sfinv.get_homepage_name(player)
		sfinv.set_player_inventory_formspec(player)
	end
end

if creative.is_enabled_for then
	creative.is_enabled_for = perplayer_gamemode.is_in_creative_mode
else
	for name, def in pairs(sfinv.pages) do
		if #name > 9 and name:sub(1, 9) == "creative:" then
			def.is_in_nav = function(self, player, context)
				return perplayer_gamemode.is_in_creative_mode(player:get_player_name())
			end
		end
	end

	local old_homepage_name = sfinv.get_homepage_name
	function sfinv.get_homepage_name(player)
		if perplayer_gamemode.is_in_creative_mode(player:get_player_name()) then
			return "creative:all"
		else
			return "sfinv:crafting"
		end
	end
end

minetest.register_privilege("gamemode", "Can set own gamemode")
minetest.register_privilege("gamemode_super", "Can set anyone's gamemode")

local GamemodeNames = {}

-- Gamemodes with creative mode (infinite blocks)
GamemodeNames[true] = {}

GamemodeNames[true][false] = "creative"  -- Free resources. Damage is disabled.
GamemodeNames[true][true] = "deadly"  -- Free resources. Damage is enabled.

-- Gamemodes without creative mode
GamemodeNames[false] = {}

GamemodeNames[false][false] = "management"  -- No free resources. Damage is disabled.
GamemodeNames[false][true] = "survival"  -- No free resources. Damage is enabled.

local function is_creative(str)
	return str:sub(1, 1) == "c" or str:sub(1, 1) == "d" or str:sub(1, 1) == "0"
end

local function is_damage(str)
	return str:sub(1, 1) == "d" or str:sub(1, 1) == "s" or str:sub(1, 1) == "0"
end

perplayer_gamemode.ChatCmdBuilder.new("gamemode", function(cmd)
	cmd:sub(":value", function(name, value)
		if minetest.check_player_privs(name, { gamemode = true }) then
			local isCreative, isDamage = is_creative(value), is_damage(value)
			perplayer_gamemode.set_creative(name, isCreative)
			perplayer_gamemode.set_damage(name, isDamage)
			return true, "Set gamemode to " .. GamemodeNames[isCreative][isDamage]
				.. ". Creative = " .. tostring(isCreative) .. ", damage = " .. tostring(isDamage)
		else
			return false, "Missing privs: gamemode"
		end
	end)

	cmd:sub(":username :value", function(name, username, value)
		if minetest.check_player_privs(name, { gamemode_super = true }) then
			local isCreative, isDamage = is_creative(value), is_damage(value)
			perplayer_gamemode.set_creative(username, isCreative)
			perplayer_gamemode.set_damage(username, isDamage)
			return true, "Set gamemode to " .. GamemodeNames[isCreative][isDamage]
				.. ". Creative = " .. tostring(isCreative) .. ", damage = " .. tostring(isDamage)
		else
			return false, "Missing privs: gamemode_super"
		end
	end)
end, {
	description = "Set gamemode (creative or survival)"
})

minetest.register_on_player_hpchange(function (player, hp_change)
	if not perplayer_gamemode.can_take_damage(player:get_player_name()) then
		return 0, true
	end
	return hp_change
end, true)

if not minetest.setting_getbool("enable_damage") then
	minetest.log("warning", "Damage is disabled, meaning that "
		.. GamemodeNames[true][true]
		.. " and "
		.. GamemodeNames[false][true]
		.. " modes will not work as intended.")
end