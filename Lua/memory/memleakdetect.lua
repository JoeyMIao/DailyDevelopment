START_INFO = {[1] = false}
function newindex_meta(tbl, key, value)
  if START_INFO[1] then
    if is_valid_vertex(value) then
      if type(value)=="table" then
        local t = debug.getinfo(2)
        _G._leakinfo[tostring(value)] = {line=t.currentline,value=tostring(key),file = t.source}
      end
      DFS(vertex, _G._leakindex_table, key)
    end
  end
end

function newindex_meta_ext(tbl, key, value)
  rawset(tbl,key,value)
  if START_INFO[1] then
    if is_valid_vertex(value) then
      if type(value)=="table" then
        local t = debug.getinfo(2)
        _G._leakinfo[tostring(value)] = {line=t.currentline,value=tostring(key),file = t.source}
      end
      DFS(vertex, _G._leakindex_table, key)
    end
  end
end



function is_valid_vertex(vertex)
  local vertex_type = type(vertex)
  if vertex_type == "table" or vertex_type == "function" then
    return true
  else
    return false
  end
end

function DFS(vertex, visited_tbl, vertex_name)
  local vertex_str = tostring(vertex)
  local vertex_type = type(vertex)
  
  -- mark it as visited
  visited_tbl[vertex_str]= vertex_name or true
  
  -- only tables and functions are vertex
  if vertex_type =="table" then
    visit_table(vertex, visited_tbl)
  elseif vertex_type == "function" then
    visit_func(vertex, visited_tbl)
  end
end

function visit_func(vertex, visited_tbl)
  for i=1,100,1 do
    local name,value =debug.getupvalue(vertex,i)
    if name then
      if not visited_tbl[tostring(value)] and is_valid_vertex(value) then  
        DFS(value, visited_tbl, name)
      end
    else
      return
    end
  end
  assert(false, "one function has more than 100 upvalue")
end

function visit_table(vertex, visited_tbl)
  --  setmetatable
  local othermeta = getmetatable(vertex)
  if othermeta then
    if othermeta.__newindex then
      local t_newindexfunc = othermeta.__newindex
      othermeta.__newindex = function(tab, key, value)
        newindex_meta(tab, key, value)
        t_newindexfunc(tab, key, value)
      end
    else
        othermeta.__newindex = newindex_meta_ext
    end
  else
    setmetatable(vertex, {__newindex =newindex_meta_ext})
  end
   
  for i,v in pairs(vertex) do
    if not visited_tbl[tostring(v)] and is_valid_vertex(v) then 
      DFS(v, visited_tbl, i)
    end
  end
end

function detec_begin()
  local visit_table = {}
  local graph = {["[_G]"]=_G, ["[registry]"]=debug.getregistry()}
  for i,v in pairs(graph) do
    DFS(v, visit_table, i)
  end
  
  _G._leakvisit_table = visit_table
  _G._leakindex_table = {}
  for i,v in pairs(visit_table) do
    _G._leakindex_table[i] =v
  end
  _G._leakinfo = {}
  
  START_INFO[1] = true
end

function detec_end()
  START_INFO[1] = false
  
  local leakvisit_table = _G._leakvisit_table
  local leakinfo = _G._leakinfo
  
  _G._leakvisit_table = nil
  _G._leakinfo = nil
  _G._leakindex_table = nil
  
  local visit_table = {}
  local graph = {[1]=_G, [2]=debug.getregistry()}
  for i,v in pairs(graph) do
    DFS(v, visit_table)
  end
  
  local result_table = {}
  for i,v in pairs(visit_table) do 
    if not leakvisit_table[i] then
      local info = leakinfo[i]
      if info then
        result_table[info.file]             = result_table[info.file] or {}
        result_table[info.file][info.line]  = result_table[info.file][info.line] or {}
        table.insert(result_table[info.file][info.line], info.value)
      else
        print("can't find info", i,v)
      end
    end
  end
  
  return result_table
end

return {detec_begin = detec_begin, detec_end = detec_end}



