perplayer_gamemode = { users = {} }

dofile(minetest.get_modpath("perplayer_gamemode") .. "/ChatCmdBuilder.lua")

function perplayer_gamemode.is_enabled_for(name)
	if perplayer_gamemode.users[name] == nil then
		return minetest.setting_getbool("creative_mode")
	else
		return perplayer_gamemode.users[name]
	end
end

function perplayer_gamemode.set_creative(name, v)
	perplayer_gamemode.users[name] = v

	local player = minetest.get_player_by_name(name)
	if player then
		local context = sfinv.contexts[name]
		context.page = sfinv.get_homepage_name(player)
		sfinv.set_player_inventory_formspec(player)
	end
end

if creative.is_enabled_for then
	creative.is_enabled_for = perplayer_gamemode.is_enabled_for
else
	for name, def in pairs(sfinv.pages) do
		if #name > 9 and name:sub(1, 9) == "creative:" then
			def.is_in_nav = function(self, player, context)
				return perplayer_gamemode.is_enabled_for(player:get_player_name())
			end
		end
	end

	local old_homepage_name = sfinv.get_homepage_name
	function sfinv.get_homepage_name(player)
		if perplayer_gamemode.is_enabled_for(player:get_player_name()) then
			return "creative:all"
		else
			return "sfinv:crafting"
		end
	end
end

minetest.register_privilege("gamemode", "Can set own creative mode")
minetest.register_privilege("gamemode_super", "Can set anyone's creative mode")

local function is_creative(str)
	return minetest.is_yes(str) or str == "creative"
end

perplayer_gamemode.ChatCmdBuilder.new("gamemode", function(cmd)
	cmd:sub(":value", function(name, value)
		if minetest.check_player_privs(name, { gamemode = true }) then
			local v = is_creative(value)
			perplayer_gamemode.set_creative(name, v)
			if v then
				return true, "Turned creative mode on"
			else
				return true, "Turned creative mode off"
			end
		else
			return false, "Missing privs: gamemode"
		end
	end)

	cmd:sub(":username :value", function(name, username, value)
		if minetest.check_player_privs(name, { gamemode_super = true }) then
			local v = is_creative(value)
			perplayer_gamemode.set_creative(username, v)
			if v then
				return true, "Turned creative mode on for " .. username
			else
				return true, "Turned creative mode off for " .. username
			end
		else
			return false, "Missing privs: gamemode_super"
		end
	end)
end, {
	description = "Set game mode (creative or survival)"
})
