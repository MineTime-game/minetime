
travelnet = {};

travelnet.targets = {};


-- read the configuration
travelnet.MAX_STATIONS_PER_NETWORK = 24;
travelnet.travelnet_sound_enabled  = false;
travelnet.travelnet_enabled        = true;
travelnet.allow_attach = function( player_name, owner_name, network_name )
   return false;
end
travelnet.allow_dig    = function( player_name, owner_name, network_name )
   return false;
end
travelnet.allow_travel = function( player_name, owner_name, network_name, station_name_start, station_name_target )
   return true;
end



-- TODO: save and restore ought to be library functions and not implemented in each individual mod!
-- called whenever a station is added or removed
travelnet.save_data = function()
   
   local data = minetest.serialize( travelnet.targets );
   local path = minetest.get_worldpath().."/mod_travel.data";

   local file = io.open( path, "w" );
   if( file ) then
      file:write( data );
      file:close();
   else
      print("[Mod travel] Error: Savefile '"..tostring( path ).."' could not be written.");
   end
end


travelnet.restore_data = function()

   local path = minetest.get_worldpath().."/mod_travel.data";
   
   local file = io.open( path, "r" );
   if( file ) then
      local data = file:read("*all");
      travelnet.targets = minetest.deserialize( data );
      file:close();
   else
      print("[Mod travel] Error: Savefile '"..tostring( path ).."' not found.");
   end
end




travelnet.update_formspec = function( pos, puncher_name )

   local meta = minetest.env:get_meta(pos);

   local this_node   = minetest.env:get_node( pos );
   local is_elevator = false; 

   if( not( meta )) then
      return;
   end

   local owner_name      = meta:get_string( "owner" );
   local station_name    = meta:get_string( "station_name" );
   local station_network = meta:get_string( "station_network" );

   if(  not( owner_name ) 
     or not( station_name ) or station_network == ''
     or not( station_network )) then

      meta:set_string("infotext",       "Travel cube (unconfigured)");
      meta:set_string("station_name",   "");
      meta:set_string("station_network","");
      meta:set_string("owner",          "");
      -- request initinal data
      meta:set_string("formspec", 
                            "size[12,10]"..
                            "field[0.3,7.6;9,0.9;station_name;Name of this station:;"..(station_name or "?").."]"..
                            "field[0.3,8.6;9,0.9;station_network;Assign to Network:;"..(station_network or "?").."]"..
                            "field[0.3,9.6;9,0.9;owner;Owned by:;"..(owner_name or "?").."]"..
                            "button_exit[6.3,8.2;1.7,0.7;station_set;Store]" );

      minetest.chat_send_player(puncher_name, "Error: Update failed! Resetting this box.");
      return;
   end

   -- if the station got lost from the network for some reason (savefile corrupted?) then add it again
   if(  not( travelnet.targets[ owner_name ] )
     or not( travelnet.targets[ owner_name ][ station_network ] )
     or not( travelnet.targets[ owner_name ][ station_network ][ station_name ] )) then

      -- first one by this player?
      if( not( travelnet.targets[ owner_name ] )) then
         travelnet.targets[       owner_name ] = {};
      end
 
      -- first station on this network?
      if( not( travelnet.targets[ owner_name ][ station_network ] )) then
         travelnet.targets[       owner_name ][ station_network ] = {};
      end


      local zeit = meta:get_int("timestamp");
      if( not( zeit) or zeit<100000 ) then
         zeit = os.time();
      end

      -- add this station
      travelnet.targets[ owner_name ][ station_network ][ station_name ] = {pos=pos, timestamp=zeit };

      minetest.chat_send_player(owner_name, "Station '"..station_name.."' has been reattached to the network '"..station_network.."'.");

   end


   -- add name of station + network + owner + update-button
   local formspec = "size[12,10]"..
                            "label[3.3,0.0;Travel cube:]".."label[6.3,0.0;Punch box to update target list.]"..
                            "label[0.3,0.4;Name of this station:]".."label[6.3,0.4;"..(station_name or "?").."]"..
                            "label[0.3,0.8;Assigned to Network:]" .."label[6.3,0.8;"..(station_network or "?").."]"..
                            "label[0.3,1.2;Owned by:]"            .."label[6.3,1.2;"..(owner_name or "?").."]"..
                            "label[3.3,1.6;Click on target to travel there:]";
--                            "button_exit[5.3,0.3;8,0.8;do_update;Punch box to update destination list. Click on target to travel there.]"..
   local x = 0;
   local y = 0;
   local i = 0;


   -- collect all station names in a table
   local stations = {};
   
   for k,v in pairs( travelnet.targets[ owner_name ][ station_network ] ) do
      table.insert( stations, k );
   end
   -- minetest.chat_send_player(puncher_name, "stations: "..minetest.serialize( stations ));
    
   local ground_level = 1; 
      -- sort the table according to the timestamp (=time the station was configured)
      table.sort( stations, function(a,b) return travelnet.targets[ owner_name ][ station_network ][ a ].timestamp < 
                                                 travelnet.targets[ owner_name ][ station_network ][ b ].timestamp  end);
   

   -- if there are only 8 stations (plus this one), center them in the formspec
   if( #stations < 10 ) then
      x = 4;
   end

   for index,k in ipairs( stations ) do 

      if( k ~= station_name ) then 
         i = i+1;

         -- new column
         if( y==8 ) then
            x = x+4;
            y = 0;
         end

         if( open_door_cmd ) then
            formspec = formspec .."button_exit["..(x)..","..(y+2.5)..";1,0.5;open_door;<>]"..
                                  "label["..(x+0.9)..","..(y+2.35)..";"..tostring( k ).."]";
         elseif( is_elevator ) then
            formspec = formspec .."button_exit["..(x)..","..(y+2.5)..";1,0.5;target;"..tostring( travelnet.targets[ owner_name ][ station_network ][ k ].nr ).."]"..
                                  "label["..(x+0.9)..","..(y+2.35)..";"..tostring( k ).."]";
         else
            formspec = formspec .."button_exit["..(x)..","..(y+2.5)..";4,0.5;target;"..k.."]";
         end

         y = y+1;
         --x = x+4;
      end
   end

   meta:set_string( "formspec", formspec );

   meta:set_string( "infotext", "Station '"..tostring( station_name ).."' on net '"..tostring( station_network )..
                                "' (owned by "..tostring( owner_name )..") ready for usage. Right-click to travel, punch to update.");

   minetest.chat_send_player(puncher_name, "The target list of this box on the net has been updated.");
end



-- add a new target; meta is optional
travelnet.add_target = function( station_name, network_name, pos, player_name, meta, owner_name )

   -- if it is an elevator, determine the network name through x and z coordinates
   local this_node   = minetest.env:get_node( pos );
   local is_elevator = false;

   if( this_node.name == 'default:elevator' ) then
--      owner_name   = '*'; -- the owner name is not relevant here
      is_elevator  = true;
      network_name = tostring( pos.x )..','..tostring( pos.z ); 
      if( not( station_name ) or station_name == '' ) then
         station_name = 'at '..tostring( pos.y )..'m';
      end
   end

   if( station_name == "" or not(station_name )) then
      minetest.chat_send_player(player_name, "Please provide a name for this station.");
      return;
   end

   if( network_name == "" or not( network_name )) then
      minetest.chat_send_player(player_name, "Please provide the name of the network this station ought to be connected to.");
      return;
   end

   if(     owner_name == nil or owner_name == '' or owner_name == player_name) then
      owner_name = player_name;

   elseif( is_elevator ) then -- elevator networks
      owner_name = player_name;

   elseif( not( travelnet.targets[ owner_name ] )
        or not( travelnet.targets[ owner_name ][ network_name ] )) then

      minetest.chat_send_player(player_name, "There is no network named "..tostring( network_name ).." owned by "..tostring( owner_name )..". Aborting.");
      return;

   elseif( not( minetest.check_player_privs(player_name, {admin=true}))
       and not( travelnet.allow_attach( player_name, owner_name, network_name ))) then

        minetest.chat_send_player(player_name, "You do not have the admin priv which is required to attach your box to the network of someone else. Aborting.");
      return;
   end

   -- first one by this player?
   if( not( travelnet.targets[ owner_name ] )) then
      travelnet.targets[       owner_name ] = {};
   end
 
   -- first station on this network?
   if( not( travelnet.targets[ owner_name ][ network_name ] )) then
      travelnet.targets[       owner_name ][ network_name ] = {};
   end

   -- lua doesn't allow efficient counting here
   local anz = 0;
   for k,v in pairs( travelnet.targets[ owner_name ][ network_name ] ) do

      if( k == station_name ) then
         minetest.chat_send_player(player_name, "Error: A station named '"..station_name.."' already exists on this network. Please choose a diffrent name!");
         return;
      end

      anz = anz + 1;
   end

   -- we don't want too many stations in the same network because that would get confusing when displaying the targets
   if( anz+1 > travelnet.MAX_STATIONS_PER_NETWORK ) then
      minetest.chat_send_player(player_name, "Error: Network '"..network_name.."' already contains the maximum number (="
              ..(travelnet.MAX_STATIONS_PER_NETWORK)..") of allowed stations per network. Please choose a diffrent/new network name.");
      return;
   end
     
   -- add this station
   travelnet.targets[ owner_name ][ network_name ][ station_name ] = {pos=pos, timestamp=os.time() };

   -- do we have a new node to set up? (and are not just reading from a safefile?)
   if( meta ) then

      minetest.chat_send_player(player_name, "Station '"..station_name.."' has been added to the network '"
                                          ..network_name.."', which now consists of "..( anz+1 ).." station(s).");

      meta:set_string( "station_name",    station_name );
      meta:set_string( "station_network", network_name );
      meta:set_string( "owner",           owner_name );
      meta:set_int( "timestamp",       travelnet.targets[ owner_name ][ network_name ][ station_name ].timestamp);

      meta:set_string("formspec", 
                     "size[12,10]"..
                     "field[0.3,0.6;6,0.7;station_name;Station:;"..   meta:get_string("station_name").."]"..
                     "field[0.3,3.6;6,0.7;station_network;Network:;"..meta:get_string("station_network").."]" );

      -- display a list of all stations that can be reached from here
      travelnet.update_formspec( pos, player_name );

      -- save the updated network data in a savefile over server restart
      travelnet.save_data();
   end
end


travelnet.on_receive_fields = function(pos, formname, fields, player)
   local meta = minetest.env:get_meta(pos);

   local name = player:get_player_name();

   -- if the box has not been configured yet
   if( meta:get_string("station_network")=="" ) then

      travelnet.add_target( fields.station_name, fields.station_network, pos, name, meta, fields.owner_name );
      return;
   end

   if( not( fields.target )) then
      minetest.chat_send_player(name, "Please click on the target you want to travel to.");
      return;
   end


   -- if there is something wrong with the data
   local owner_name      = meta:get_string( "owner" );
   local station_name    = meta:get_string( "station_name" );
   local station_network = meta:get_string( "station_network" );

   if(  not( owner_name  ) 
     or not( station_name ) 
     or not( station_network )
     or not( travelnet.targets[ owner_name ] )
     or not( travelnet.targets[ owner_name ][ station_network ] )) then


      minetest.chat_send_player(name, "Error: There is something wrong with the configuration of this station. "..
                                      " DEBUG DATA: owner: "..(  owner_name or "?")..
                                      " station_name: "..(station_name or "?")..
                                      " station_network: "..(station_network or "?")..".");
      return
   end

   local this_node = minetest.env:get_node( pos );
   if( this_node ~= nil and this_node.name == 'default:elevator' ) then 
      for k,v in pairs( travelnet.targets[ owner_name ][ station_network ] ) do
         if( travelnet.targets[ owner_name ][ station_network ][ k ].nr  --..' ('..tostring( travelnet.targets[ owner_name ][ station_network ][ k ].pos.y )..'m)'
               == fields.target) then
            fields.target = k;
         end
      end
   end


   -- if the target station is gone
   if( not( travelnet.targets[ owner_name ][ station_network ][ fields.target ] )) then

      minetest.chat_send_player(name, "Station '"..( fields.target or "?").." does not exist (anymore?) on this network.");
      travelnet.update_formspec( pos, name );
      return;
   end


   if( not( travelnet.allow_travel( name, owner_name, station_network, station_name, fields.target ))) then
      return;
   end
   minetest.chat_send_player(name, "Initiating transfer to station '"..( fields.target or "?").."'.'");

   -- transport the player to the target location
   local target_pos = travelnet.targets[ owner_name ][ station_network ][ fields.target ].pos;
   local to_pos = { x=target_pos.x, y=target_pos.y+1, z=target_pos.z }
   player:moveto( to_pos, false);

   -- check if the box has at the other end has been removed.
   local node2 = minetest.env:get_node(  target_pos );
   if( node2 ~= nil and node2.name ~= 'ignore' and node2.name ~= 'default:travelcube' and node2.name ~= 'default:elevator') then

      -- provide information necessary to identify the removed box
      local oldmetadata = { fields = { owner           = owner_name,
                                       station_name    = fields.target,
                                       station_network = station_network }};

      travelnet.remove_box( target_pos, nil, oldmetadata, player );

   -- do this only on servers where the function exists
   else

      -- rotate the player so that he/she can walk straight out of the box
      local yaw    = 0;
      local param2 = node2.param2;
      if( param2==0 ) then
         yaw = 180;
      elseif( param2==1 ) then
         yaw = 90;
      elseif( param2==2 ) then
         yaw = 0;
      elseif( param2==3 ) then
         yaw = 270;
      end
       
      player:set_look_yaw( math.rad( yaw )); -- this is only supported in recent versions of MT
      player:set_look_pitch( math.rad( 0 )); -- this is only supported in recent versions of MT
   end
end


travelnet.remove_box = function( pos, oldnode, oldmetadata, digger )

   if( not( oldmetadata ) or oldmetadata=="nil" or not(oldmetadata.fields)) then
      minetest.chat_send_player( digger:get_player_name(), "Error: Could not find information about the station that is to be removed.");
      return;
   end

   local owner_name      = oldmetadata.fields[ "owner" ];
   local station_name    = oldmetadata.fields[ "station_name" ];
   local station_network = oldmetadata.fields[ "station_network" ];

   -- station is not known? then just remove it
   if(  not( owner_name ) 
     or not( station_name ) 
     or not( station_network ) 
     or not( travelnet.targets[ owner_name ] )
     or not( travelnet.targets[ owner_name ][ station_network ] )) then
       
      minetest.chat_send_player( digger:get_player_name(), "Error: Could not find the station that is to be removed.");
      return;
   end

   travelnet.targets[ owner_name ][ station_network ][ station_name ] = nil;
   
   -- inform the owner
   minetest.chat_send_player( owner_name, "Station '"..station_name.."' has been REMOVED from the network '"..station_network.."'.");
   if( digger ~= nil and owner_name ~= digger:get_player_name() ) then
      minetest.chat_send_player( digger:get_player_name(), "Station '"..station_name.."' has been REMOVED from the network '"..station_network.."'.");
   end

   -- save the updated network data in a savefile over server restart
   travelnet.save_data();
end



travelnet.can_dig = function( pos, player, description )

   if( not( player )) then
      return false;
   end
   local name          = player:get_player_name();

   -- players with that priv can dig regardless of owner
   if( minetest.check_player_privs(name, {admin=true})
       or travelnet.allow_dig( player_name, owner_name, network_name )) then
      return true;
   end

   local meta          = minetest.env:get_meta( pos );
   local owner         = meta:get_string('owner');

   if( not( meta ) or not( owner) or owner=='') then
      minetest.chat_send_player(name, "This "..description.." has not been configured yet. Please set it up first to claim it. Afterwards you can remove it because you are then the owner.");
      return false;

   elseif( owner ~= name ) then
      minetest.chat_send_player(name, "This "..description.." belongs to "..tostring( meta:get_string('owner'))..". You can't remove it.");
      return false;
   end
   return true;
end

minetest.register_node("default:travelcube", {
    description = "Travel Cube",
    drawtype = "glasslike",
    sunlight_propagates = true,
    paramtype = 'light',
    paramtype2 = "facedir",
    tiles = {"default_travel_cube.png"},
    light_source = 5,
    groups = {cracky=3, oddly_breakable_by_hand=3},
    after_place_node  = function(pos, placer, itemstack)
  local meta = minetest.env:get_meta(pos);
        meta:set_string("infotext",       "Travel cube (unconfigured)");
        meta:set_string("station_name",   "");
        meta:set_string("station_network","");
        meta:set_string("owner",          placer:get_player_name() );
        -- request initinal data
        meta:set_string("formspec", 
                            "size[12,10]"..
                            "field[0.3,5.6;6,0.7;station_name;Name of this station:;]"..
                            "field[0.3,6.6;6,0.7;station_network;Assign to Network:;]"..
                            "field[0.3,7.6;6,0.7;owner_name;(optional) owned by:;]"..
                            "button_exit[6.3,6.2;1.7,0.7;station_set;Store]" );
    end,
    
    on_receive_fields = travelnet.on_receive_fields,
    on_punch          = function(pos, node, puncher)
                          travelnet.update_formspec(pos, puncher:get_player_name())
    end,

    can_dig = function( pos, player )
                          return travelnet.can_dig( pos, player, 'travel cube' )
    end,

    after_dig_node = function(pos, oldnode, oldmetadata, digger)
        travelnet.remove_box( pos, oldnode, oldmetadata, digger )
    end,

})

--[
minetest.register_craft({
        output = "default:travelcube",
        recipe = {
                {"default:glass", "default:steel_ingot", "default:glass", },
                {"default:glass", "default:mese",        "default:glass", },
                {"default:glass", "default:steel_ingot", "default:glass", },
        }
})


-- upon server start, read the savefile
travelnet.restore_data();
