dofile("data/scripts/perks/perk.lua")

local mats = CellFactory_GetAllLiquids()

local function insert_constant(outcome)
  table.insert(outcome_generators, function()
    return outcome
  end)
end

table.insert(outcome_generators, function()
  -- spawn a random flask
  local mat = mats[math.random(1, #mats)]
  local matname = GameTextGet("$mat_" .. mat)
  return {
    name = "Flask: " .. matname,
    desc = "Enjoy",
    func = function()
      local x, y = get_player_pos()
      -- just go ahead and assume cheatgui is installed
      local entity = EntityLoad("data/hax/potion_empty.xml", x, y)
      AddMaterialInventoryMaterial( entity, mat, 1000 )
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
  local perkname = resolve_localized_name(perk.ui_name, perk.id)
  return {
    name = "Perk: " .. perkname,
    desc = "Have fun",
    func = function()
      local x, y = get_player_pos()
      perk_spawn( x, y - 8, perk.id )
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

insert_constant{
  name = "The Gods Are Angry",
  desc = "...",
  func = wrap_spawn("data/entities/animals/necromancer_shop.xml", 300)
}

insert_constant{
  name = "ACID??",
  desc = "Who thought this was a good idea",
  func = wrap_spawn("data/entities/projectiles/deck/circle_acid.xml", 300)
}