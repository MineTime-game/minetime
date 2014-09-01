minetest.register_on_newplayer(function(player)
	--print("on_newplayer")
	if minetest.setting_getbool("give_initial_stuff") then
		minetest.log("action", "Giving initial stuff to player "..player:get_player_name())
		player:get_inventory():add_item('main', 'default:pick_steel')
		player:get_inventory():add_item('main', 'default:torch 99')
		player:get_inventory():add_item('main', 'default:axe_steel')
		player:get_inventory():add_item('main', 'default:shovel_steel')
		player:get_inventory():add_item('main', 'default:cobble 80')
		player:get_inventory():add_item('main', 'default:wood 160')
		player:get_inventory():add_item('main', 'landclaim 2')
		player:get_inventory():add_item('main', 'default:locked_chest 4')
		player:get_inventory():add_item('main', 'default:apple 5')
	end
end)

