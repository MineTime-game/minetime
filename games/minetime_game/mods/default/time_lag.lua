	

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-------Minetest Time--kazea's code tweaked by cg72 with help from crazyR--------
----------------Zeno` simplified some math and additional tweaks ---------------
--------------------------------------------------------------------------------
     
    player_hud = {}
    player_hud.time = {}
    player_hud.lag = {}
    local timer = 0;
    local function explode(sep, input)
            local t={}
                    local i=0
            for k in string.gmatch(input,"([^"..sep.."]+)") do
                t[i]=k;i=i+1
            end
            return t
    end
    local function floormod ( x, y )
            return (math.floor(x) % y);
    end
    local function get_lag(raw)
            local a = explode(", ",minetest.get_server_status())
            local b = explode("=",a[4])
                    local lagnum = tonumber(string.format("%.2f", b[1]))
 		    local clag = 0
		    if lagnum > clag then 
			    clag = lagnum 
		    else
			    clag = clag * .75
		    end
                    if raw ~= nil then
                            return clag
                    else
                            return ("Current Lag: %s sec"):format(clag);
                    end
    end
    local function get_time ()
    local t, m, h, d
    t = 24*60*minetest.get_timeofday()
    m = floormod(t, 60)
    t = t / 60
    h = floormod(t, 60)
           
        
    if h == 12 then
        d = "pm"
    elseif h >= 13 then
        h = h - 12
        d = "pm"
    elseif h == 0 then
        h = 12
        d = "am"
    else
        d = "am"
    end
        return ("Minetest time %02d:%02d %s"):format(h, m, d);
    end
    local function generatehud(player)
            local name = player:get_player_name()
            player_hud.time[name] = player:hud_add({
                    hud_elem_type = "text",
                    name = "player_hud:time",
                    position = {x=0.20, y=0.965},
                    text = get_time(),
                    scale = {x=100,y=100},
                    alignment = {x=0,y=0},
                    number = 0xFFFFFF,
            })
            player_hud.lag[name] = player:hud_add({
                    hud_elem_type = "text",
                    name = "player_hud:lag",
                    position = {x=0.80, y=0.965},
                    text = get_lag(),
                    scale = {x=100,y=100},
                    alignment = {x=0,y=0},
                    number = 0xFFFFFF,
            })
    end
    local function updatehud(player, dtime)
            local name = player:get_player_name()
            timer = timer + dtime;
            if (timer >= 1.0) then
                    timer = 0;
                    if player_hud.time[name] then player:hud_change(player_hud.time[name], "text", get_time()) end
                    if player_hud.lag[name] then player:hud_change(player_hud.lag[name], "text", get_lag()) end
            end
    end
    local function removehud(player)
            local name = player:get_player_name()
            if player_hud.time[name] then
                    player:hud_remove(player_hud.time[name])
            end
            if player_hud.lag[name] then
                    player:hud_remove(player_hud.lag[name])
            end
    end
    minetest.register_globalstep(function ( dtime )
            for _,player in ipairs(minetest.get_connected_players()) do
                    updatehud(player, dtime)
            end
    end);
    minetest.register_on_joinplayer(function(player)
            minetest.after(0,generatehud,player)
    end)
    minetest.register_on_leaveplayer(function(player)
            minetest.after(1,removehud,player)
    end)


