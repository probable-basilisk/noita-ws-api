function hello()
  GamePrintImportant("Hello", "Hello")
  GamePrint("Hello")
  print("Hello")
end

function get_player()
  return EntityGetWithTag( "player_unit" )[1]
end

function get_player_pos()
  return EntityGetTransform(get_player())
end

function get_closest_entity(px, py, tag)
  if not py then
    tag = px
    px, py = get_player_pos()
  end
  return EntityGetClosestWithTag( px, py, tag)
end

function get_entity_mouse(tag)
  local mx, my = DEBUG_GetMouseWorld()
  return get_closest_entity(mx, my, tag or "hittable")
end

function teleport(x, y)
  EntitySetTransform(get_player(), x, y)
end

function spawn_entity(ename, offset_x, offset_y)
  local x, y = get_player_pos()
  x = x + (offset_x or 0)
  y = y + (offset_y or 0)
  return EntityLoad(ename, x, y)
end

function print_component_info(c)
  local members = ComponentGetMembers(c)
  if not members then return end
  local frags = {}
  for k, v in pairs(members) do
    table.insert(frags, k .. ': ' .. tostring(v))
  end
  print(table.concat(frags, '\n'))
end

function print_detailed_component_info(c)
  local members = ComponentGetMembers(c)
  if not members then return end
  local frags = {}
  for k, v in pairs(members) do
    if (not v) or #v == 0 then
      local mems = ComponentObjectGetMembers(10, k)
      if mems then
        table.insert(frags, k .. ">")
        for k2, v2 in pairs(mems) do
          table.insert(frags, "  " .. k2 .. ": " .. tostring(v2))
        end
      else
        v = "?"
      end
    end
    table.insert(frags, k .. ': ' .. tostring(v))
  end
  print(table.concat(frags, '\n'))

end

function print_entity_info(e)
  local comps = EntityGetAllComponents(e)
  if not comps then
    print("Invalid entity?")
    return
  end
  for idx, comp in ipairs(comps) do
    print(comp, "-----------------")
    print_component_info(comp)
  end
end

function list_funcs(filter)
  local ff = {}
  for k, v in pairs(getfenv()) do
    local first_letter = k:sub(1,1)
    if first_letter:upper() == first_letter then
      if (not filter) or k:lower():find(filter:lower()) then
        table.insert(ff, k)
      end
    end
  end
  table.sort(ff)
  print(table.concat(ff, "\n"))
end

function get_child_info(e)
  local children = EntityGetAllChildren(e)
  for _, child in ipairs(children) do
    print(child, EntityGetName(child) or "[no name]")
  end
end

function do_here(fn)
  local f = loadfile(fn)
  if type(f) ~= "function" then
    print("Loading error; check logger.txt for details.")
  end
  setfenv(f, getfenv())
  f()
end