dofile("data/scripts/lib/utilities.lua")
dofile("data/scripts/perks/perk.lua")
dofile("data/scripts/perks/perk_list.lua")

local function insert_constant(outcome)
  table.insert(outcome_generators, function()
    return outcome
  end)
end


table.insert(outcome_generators, function()
  -- extracted from data/scripts/items/potion.lua
  local materials = nil
  if( Random( 0, 100 ) <= 75 ) then
    if( Random( 0, 100000 ) <= 50 ) then
      potion_material = "magic_liquid_hp_regeneration"
    elseif( Random( 200, 100000 ) <= 250 ) then
      potion_material = "purifying_powder"
    else
      potion_material = random_from_array( potion_materials_magic )
    end
  else
    potion_material = random_from_array( potion_materials_standard )
  end
  
  local matname = GameTextGet("$mat_" .. potion_material)
  
  return {
    name = "Flask: " .. matname,
    desc = "Enjoy",
    func = function()
      local x, y = get_player_pos()
      -- just go ahead and assume cheatgui is installed
      local entity = EntityLoad( "data/hax/potion_empty.xml", x, y )
      AddMaterialInventoryMaterial( entity, potion_material, 1000 )
    end
  }
end)

local function resolve_localized_name(s, default)
  if s:sub(1,1) ~= "$" then return s end
  local rep = GameTextGet(s)
  if rep and rep ~= "" then return rep else return default or s end
end

table.insert(outcome_generators, function()
  -- spawn a random perk
  local perk = perk_list[math.random(1, #perk_list)]

  -- reroll useless perk
  while perk.id == "MYSTERY_EGGPLANT" do
    perk = perk_list[math.random(1, #perk_list)]
  end
  
  local perkname = resolve_localized_name(perk.ui_name, perk.id)
  return {
    name = "Perk: " .. perkname,
    desc = "Have fun",
    func = function()
      local x, y = get_player_pos()

      -- player might be dead
      if x ~= nil and y ~= nil then
        local perk_entity = perk_spawn( x, y - 8, perk.id )
        local players = get_players()
        if players == nil  then return end
        for i,player in ipairs(players) do
          -- last argument set to false, so you dont kill others perks if triggered inside the shop
          perk_pickup( perk_entity, player, nil, true, false )
        end
      end
    end
  }
end)

local function twiddle_health(f)
  local damagemodels = EntityGetComponent( get_player(), "DamageModelComponent" )
  if( damagemodels ~= nil ) then
    for i,damagemodel in ipairs(damagemodels) do
      local max_hp = tonumber(ComponentGetValue( damagemodel, "max_hp"))
      local cur_hp = tonumber(ComponentGetValue( damagemodel, "hp"))
      local new_cur, new_max = f(cur_hp, max_hp)
      ComponentSetValue( damagemodel, "max_hp", new_max)
      ComponentSetValue( damagemodel, "hp", new_cur)
    end
  end
end

insert_constant{
  name = "Health Down",
  desc = "Unfortunate",
  func = function()
    twiddle_health(function(cur, max)
      max = max * 0.8
      cur = math.min(max, cur)
      return cur, max
    end)
  end
}

insert_constant{
  name = "Health Up",
  desc = "Amazing",
  func = function()
    twiddle_health(function(cur, max)
      return cur+1, max+1
    end)
  end
}

local function urand(mag)
  return math.floor((math.random()*2.0 - 1.0)*mag)
end

local function spawn_item(path, offset_mag)
  local x, y = get_player_pos()
  local dx, dy = urand(offset_mag or 0), urand(offset_mag or 0)
  print(x + dx, y + dy)
  local entity = EntityLoad(path, x + dx, y + dy)
end

local function wrap_spawn(path, offset_mag)
  return function() spawn_item(path, offset_mag) end
end

-- 0 to not limit axis, -1 to limit to negative values, 1 to limit to positive values
local function generate_value_in_range(max_range, min_range, limit_axis)
  local range = (max_range or 0) - (min_range or 0)
  if (limit_axis or 0) == 0 then
    limit_axis = Random(0, 1) == 0 and 1 or -1
  end

  return (Random(0, range) + (min_range or 0)) * limit_axis
end

local function spawn_item_in_range(path, min_x_range, max_x_range, min_y_range, max_y_range, limit_x_axis, limit_y_axis, spawn_blackhole)
  local x, y = get_player_pos()
  local dx = generate_value_in_range(max_x_range, min_x_range, limit_x_axis)
  local dy = generate_value_in_range(max_y_range, min_y_range, limit_y_axis)

  if spawn_blackhole then
    EntityLoad("data/entities/projectiles/deck/black_hole.xml", x + dx, y + dy)
  end
  
  return EntityLoad(path, x + dx, y + dy)
end

local function spawn_item(path, min_range, max_range, spawn_blackhole)
  return spawn_item_in_range(path, min_range, max_range, min_range, max_range, 0, 0, spawn_blackhole)
end


insert_constant{
  name = "The Gods Are Angry",
  desc = "...",
  func = function()
    spawn_item("data/entities/animals/necromancer_shop.xml", 100, 100, true)
  end
}

insert_constant{
  name = "A big worm",
  desc = "This could be a problem",
  func = function()
    spawn_item("data/entities/animals/worm_big.xml", 100, 100)
  end
}

insert_constant{
  name = "The biggest worm",
  desc = "oh ... oh no ... OH NO NO NO",
  func = function()
    spawn_item("data/entities/animals/worm_end.xml", 100, 150)
  end
}

insert_constant{
  name = "A couple of worms",
  desc = "That's annoying",
  func = function()
    spawn_item("data/entities/animals/worm.xml", 50, 200)
    spawn_item("data/entities/animals/worm.xml", 50, 200)
  end
}

insert_constant{
  name = "A can of worms",
  desc = "But why?",
  func = function()
    for i=1,10 do
      spawn_item("data/entities/animals/worm_tiny.xml", 50, 200)
    end
  end
}

insert_constant{
  name = "Deers",
  desc = "Oh dear!",
  func = function()
    for i=1,5 do
      spawn_item("data/entities/projectiles/deck/exploding_deer.xml", 100, 300) 
      spawn_item("data/entities/animals/deer.xml", 100, 300) 
    end
  end
}


insert_constant{
  name = "Gold rush",
  desc = "Quick, before it disappear",
  func = function()
    for i=1,20 do
      spawn_item("data/entities/items/pickup/goldnugget.xml", 50, 200) 
    end
  end
}

insert_constant{
  name = "Bomb rush",
  desc = "You better run",
  func = function()
    for i=1,3 do
      spawn_item("data/entities/projectiles/bomb.xml", 0, 50) 
    end
  end
}

insert_constant{
  name = "Sea of lava",
  desc = "Now, that's hot!!",
  func = function()
    spawn_item_in_range("data/entities/projectiles/deck/sea_lava.xml", 0, 200, 20, 100, 0, 1, false)
  end
}

insert_constant{
  name = "ACID??",
  desc = "Who thought this was a good idea",
  func = function()
    spawn_item("data/entities/projectiles/deck/circle_acid.xml", 40, 120, true)
  end
}

insert_constant{
  name = "Holy bombastic",
  desc = "That should clear the path",
  func = function()
    spawn_item("data/entities/projectiles/bomb_holy.xml", 130, 250, true)
  end
}

insert_constant{
  name = "Thunderstone madness",
  desc = "Careful now",
  func = function()
    for i=1,10 do
      spawn_item("data/entities/items/pickup/thunderstone.xml", 50, 250)
    end
  end
}

insert_constant{
  name = "Instant swimming pool",
  desc = "Don't forget your swimsuit",
  func = function()
    spawn_item_in_range("data/entities/projectiles/deck/sea_water.xml", 0, 0, 40, 80, 0, -1, false)
  end
}

insert_constant{
  name = "Random wand generator",
  desc = "Make good use of it",
  func = function()
    local rnd = Random(0, 1000)
    if rnd < 200 then
      spawn_item("data/entities/items/wand_level_01.xml")
    elseif rnd < 600 then
      spawn_item("data/entities/items/wand_level_02.xml")
    elseif rnd < 850 then
      spawn_item("data/entities/items/wand_level_03.xml")
    elseif rnd < 998 then
      spawn_item("data/entities/items/wand_level_04.xml")
    else
      spawn_item("data/entities/items/wand_level_05.xml")
    end
  end
}
