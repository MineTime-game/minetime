-- Minetest 0.4 mod: player
-- See README.txt for licensing and other information.

--[[

API
---

default.player_register_model(name, def)
^ Register a new model to be used by players.
^ <name> is the model filename such as "character.x", "foo.b3d", etc.
^ See Model Definition below for format of <def>.

default.registered_player_models[name]
^ See Model Definition below for format.

default.player_set_model(player, model_name)
^ <player> is a PlayerRef.
^ <model_name> is a model registered with player_register_model.

default.player_set_animation(player, anim_name [, speed])
^ <player> is a PlayerRef.
^ <anim_name> is the name of the animation.
^ <speed> is in frames per second. If nil, default from the model is used

default.player_set_textures(player, textures)
^ <player> is a PlayerRef.
^ <textures> is an array of textures
^ If <textures> is nil, the default textures from the model def are used

default.player_get_animation(player)
^ <player> is a PlayerRef.
^ Returns a table containing fields "model", "textures" and "animation".
^ Any of the fields of the returned table may be nil.

Model Definition
----------------

model_def = {
	animation_speed = 30, -- Default animation speed, in FPS.
	textures = {"character.png", }, -- Default array of textures.
	visual_size = {x=1, y=1,}, -- Used to scale the model.
	animations = {
		-- <anim_name> = { x=<start_frame>, y=<end_frame>, },
		foo = { x= 0, y=19, },
		bar = { x=20, y=39, },
		-- ...
	},
}

]]

-- Player animation blending
-- Note: This is currently broken due to a bug in Irrlicht, leave at 0
local animation_blend = 0

default.registered_player_models = { }

-- Local for speed.
local models = default.registered_player_models

function default.player_register_model(name, def)
	models[name] = def
end

-- Default player appearance
default.player_register_model("characterm.b3d", {
	animation_speed = 30,
	textures = {"character.png", },
	animations = {
		-- Standard animations.
		stand     = { x=  0, y= 79, },
		lay       = { x=162, y=166, },
		walk      = { x=168, y=187, },
		mine      = { x=189, y=198, },
		walk_mine = { x=200, y=219, },
		-- Extra animations (not currently used by the game).
		sit       = { x= 81, y=160, },
	},
})

-- Player stats and animations
local player_model = {}
local player_textures = {}
local player_anim = {}
local player_sneak = {}

function default.player_get_animation(player)
	local name = player:get_player_name()
	return {
		model = player_model[name],
		textures = player_textures[name],
		animation = player_anim[name],
	}
end

-- Called when a player's appearance needs to be updated
function default.player_set_model(player, model_name)
	local name = player:get_player_name()
	local model = models[model_name]
	if model then
		if player_model[name] == model_name then
			return
		end
		player:set_properties({
			mesh = model_name,
			textures = player_textures[name] or model.textures,
			visual = "mesh",
			visual_size = model.visual_size or {x=1, y=1},
		})
		default.player_set_animation(player, "stand")
	else
		player:set_properties({
			textures = { "player.png", "player_back.png", },
			visual = "upright_sprite",
		})
	end
	player_model[name] = model_name
end

function default.player_set_textures(player, textures)
	local name = player:get_player_name()
	player_textures[name] = textures
	player:set_properties({textures = textures,})
end

function default.player_set_animation(player, anim_name, speed)
	local name = player:get_player_name()
	if player_anim[name] == anim_name then
		return
	end
	local model = player_model[name] and models[player_model[name]]
	if not (model and model.animations[anim_name]) then
		return
	end
	local anim = model.animations[anim_name]
	player_anim[name] = anim_name
	player:set_animation(anim, speed or model.animation_speed, animation_blend)
end

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	player_model[name] = nil
	player_anim[name] = nil
	player_textures[name] = nil
end)

-- Localize for better performance.
local player_set_animation = default.player_set_animation

-- Check each player and apply animations
minetest.register_globalstep(function(dtime)
	for _, player in pairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local model_name = player_model[name]
		local model = model_name and models[model_name]
		if model then
			local controls = player:get_player_control()
			local walking = false
			local animation_speed_mod = model.animation_speed or 30

			-- Determine if the player is walking
			if controls.up or controls.down or controls.left or controls.right then
				walking = true
			end

			-- Determine if the player is sneaking, and reduce animation speed if so
			if controls.sneak then
				animation_speed_mod = animation_speed_mod / 2
			end

			-- Apply animations based on what the player is doing
			if player:get_hp() == 0 then
				player_set_animation(player, "lay")
			elseif walking then
				if player_sneak[name] ~= controls.sneak then
					player_anim[name] = nil
					player_sneak[name] = controls.sneak
				end
				if controls.LMB then
					player_set_animation(player, "walk_mine", animation_speed_mod)
				else
					player_set_animation(player, "walk", animation_speed_mod)
				end
			elseif controls.LMB then
				player_set_animation(player, "mine")
			else
				player_set_animation(player, "stand", animation_speed_mod)
			end
		end
	end
end)

local gender = {}
gender.players = {}
 
gender.file = minetest.get_worldpath() .. "/player_genders"
gender.changed = false
 
gender.formname = "gender:selection"
gender.formspec = (
        "size[8,2]label[2.1,0;Do you want boy or a girl skin?]"..
        "button_exit[0,0;4,4;boy;Boy]"..
        "button_exit[4,0;4,4;girl;Girl]"
)
 
function gender.load_data()
        local input = io.open(gender.file, "r")
        if not input then return end
       
        for line in input:lines() do
                if line ~= "" then
                        local data = line:split(" ")
                        gender.players[data[1]] = data[2]
                end
        end
       
        io.close(input)
end
 
function gender.save_data()
        if not gender.changed then return end
       
        local output = io.open(gender.file, "w")
        for k,v in pairs(gender.players) do
                output:write(k.." "..v.."\n")
        end
        io.close(output)
        gender.changed = false
end
 
gender.load_data()
 
minetest.register_on_player_receive_fields(function(player, formname, fields)
        if gender.formname ~= formname then return end
        local plname = player:get_player_name()

        if fields.boy then -- Change skin to boy.
                player:set_properties({
                        visual = "mesh",
                        mesh = "character.b3d",
                        textures = {"characterm.png"},
                        visual_size = {x=1, y=1},
                })
                minetest.chat_send_player(plname, "Set player skin to boy!")
               
                gender.changed = true
                gender.players[plname] = "m"
        elseif fields.girl then -- Change skin to girl.
                player:set_properties({
                        visual = "mesh",
                        mesh = "characterf.b3d",
                        textures = {"characterf.png"},
                        visual_size = {x=1, y=1},
                })
                minetest.chat_send_player(plname, "Set player skin to girl!")
               
                gender.changed = true
                gender.players[plname] = "f"
        end
        gender.save_data()
end)
 
minetest.register_chatcommand("gender", {
        description = "Set your player skin.",
        func = function(name)
                minetest.show_formspec(name, gender.formname, gender.formspec)
        end
})
 
-- Update appearance when the player joins
minetest.register_on_joinplayer(function(player)
    local plname = player:get_player_name()
    player:set_local_animation({x=0, y=79}, {x=168, y=187}, {x=189, y=198}, {x=200, y=219}, 30)
    if gender.players[plname] == "m" then
        player:set_properties({
            visual = "mesh",
            mesh = "character.b3d",
            textures = {"characterm.png"},
            visual_size = {x=1, y=1},
        })
        minetest.chat_send_player(plname, "Your gender is set to boy, to change type /gender ")
    elseif gender.players[plname] == "f" then
        player:set_properties({
            visual = "mesh",
            mesh = "characterf.b3d",
            textures = {"characterf.png"},
            visual_size = {x=1, y=1},
        })
        minetest.chat_send_player(plname, "Your gender is set to girl, to change type /gender ")
    else
        minetest.chat_send_player(plname, "Please set your gender via /boy or /girl, thank you. You can also ignore this message and use the default male model. This message will be shown again when you rejoin.")
        minetest.show_formspec(plname, gender.formname, gender.formspec)
    end
end)