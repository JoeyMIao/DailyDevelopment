START_FLAG =false


local record_new = function(tab, key, value)
  rawset(tab,key,value)
  if START_FLAG then
    local t = debug.getinfo(2)
    if t~= nil and type(value)=="table" then
       _G._index[tostring(value)] = {line=t.currentline,value=tostring(key),file = t.source}
    end
  end
end

local record_new_recursivly =function(tab, key, value)
  rawset(tab,key,value)
  if START_FLAG then
    local t = debug.getinfo(2)
    if t~= nil and type(value)=="table" then
      _G._index[tostring(value)] = {line=t.currentline,value=tostring(key),file = t.source}
      set_detecmetatable(value, true)
    end
  end
end


set_detecmetatable = function(tab,need_recursive)
  local meta = record_new
  if need_recursive then
    meta = record_new_recursivly
  end
  
  local othermeta = getmetatable(tab)
  if othermeta then
    if othermeta.__newindex then
      local t_newindexfunc = othermeta.__newindex
      othermeta.__newindex = function(tab, key, value)
        if START_FLAG then
          local t = debug.getinfo(2)
          if t~= nil and type(value)=="table" then
            _G._index[tostring(value)] = {line=t.currentline,value=tostring(key),file = t.source}
            if need_recursive then
              set_detecmetatable(key, true)
            end
          end
        end
        t_newindexfunc(tab, key, value)
      end
    else
        othermeta.__newindex = meta
    end
  else
    setmetatable(tab, {__newindex =meta})
  end
  
end


function detec_begin(need_all_recursive)
  local index_table  = {}
  
  local stack = {}
  -- stack.push操作
  table.insert(stack, _G)
  table.insert(stack, debug.getregistry())
  
  while #stack ~= 0 do 
    -- stack.pop操作
    local t_table = stack[#stack]
    table.remove(stack, #stack)
    for i,v in pairs(t_table) do
      if type(v) == "table" and not index_table[tostring(v)] then
        set_detecmetatable(v, need_all_recursive)
        
        table.insert(stack, v)
        index_table[tostring(v)] = true
      end
    end
  end
  
  rawset(_G, "_index", {})
  rawset(_G, "_leak", index_table)
  
  START_FLAG = true
end


function detec_end()
  collectgarbage("collect")
  
  local index_table = {}
  local leak_table = {}
  local begin_table = _G._leak
  local info_index = _G._index
   _G._index = nil
  _G._leak = nil
  
  local stack = {}
  -- stack.push操作
  table.insert(stack, _G)
  
  while #stack ~= 0 do 
    -- stack.pop操作
    local t_table = stack[#stack]
    table.remove(stack, #stack)
    for i,v in pairs(t_table) do
      if type(v) == "table" and not index_table[tostring(v)] then
        index_table[tostring(v)] = true
        if not begin_table[tostring(v)] then
          table.insert(leak_table, tostring(v))
        end
        table.insert(stack, v)
      end
    end
  end
  
  local result_table = {}
  for i,v in pairs(leak_table) do 
    local info = info_index[v]
    if info then
      result_table[info.file]             = result_table[info.file] or {}
      result_table[info.file][info.line]  = result_table[info.file][info.line] or {}
      table.insert(result_table[info.file][info.line], info.value)
    end
  end

  START_FLAG = false
  return result_table
end

function loop(a)
  for i,v in pairs(a) do
    if type(v) == "table" then
      print("loop("..tostring(i))
      loop(v)
    end
  end
end

return {detec_begin = detec_begin, detec_end = detec_end}


