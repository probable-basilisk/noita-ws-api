local HOST_URL = "ws://localhost:9090"

if not async then
  dofile( "data/scripts/lib/coroutines.lua" )
end

if not pollws then
  print("Attempting to link pollws.dll through FFI")
  local ffi = ffi or _G.ffi or require("ffi")
  ffi.cdef[[
  struct pollsocket* pollws_open(const char* url);
  void pollws_close(struct pollsocket* ctx);
  int pollws_status(struct pollsocket* ctx);
  void pollws_send(struct pollsocket* ctx, const char* msg);
  int pollws_poll(struct pollsocket* ctx);
  unsigned int pollws_get(struct pollsocket* ctx, char* dest, unsigned int dest_size);
  unsigned int pollws_pop(struct pollsocket* ctx, char* dest, unsigned int dest_size);
  ]]
  print("CDEF was OK")
  pollws = ffi.load("pollws")
  print("FFI was OK")

  function open_socket(url, scratch_size)
    -- might as well have a comfortable megabyte of space
    if not scratch_size then scratch_size = 1000000 end
    local res = {
      _socket = pollws.pollws_open(url),
      _scratch = ffi.new("int8_t[?]", scratch_size),
      _scratch_size = scratch_size
    }
    function res:set_scratch_size(scratch_size)
      self._scratch = ffi.new("int8_t[?]", scratch_size)
      self._scratch_size = scratch_size
    end
    function res:poll()
      if not self._socket then return end
      local msg_size = pollws.pollws_pop(self._socket, self._scratch, self._scratch_size)
      if msg_size > 0 then
        local smsg = ffi.string(self._scratch, msg_size)
        return smsg
      else
        return nil
      end
    end
    function res:send(msg)
      if not self._socket then return end
      pollws.pollws_send(self._socket, msg)
    end
    function res:close()
      pollws.pollws_close(self._socket)
      self._socket = nil
    end
    return res
  end
end

local main_socket = open_socket(HOST_URL)
main_socket:poll()

local printing_to_socket = false

local function set_scratch_size(scratch_size)
  if not scratch_size then error("Scratch size cannot be nil") end
  main_socket:set_scratch_size(scratch_size)
end

local function socket_print(str)
  local msg = ">" .. str
  main_socket:send(msg)
end

local function cprint(...)
  local m = table.concat({...}, " ")
  if printing_to_socket then
    socket_print(m)
  else
    print(m)
  end
end

local function set_print_to_socket(p)
  printing_to_socket = p
end

local function cprint_table(t)
  local s = {}
  for k, v in pairs(t) do
    table.insert(s, k .. ": " .. type(v))
  end
  cprint(table.concat(s, "\n"))
end

local console_env = nil

local function reload_utils()
  local env_utils, err = loadfile("data/ws/utils.lua")
  if type(env_utils) ~= "function" then
    cprint("Error loading utils: " .. tostring(err))
    return
  end
  setfenv(env_utils, console_env)
  local happy, err = pcall(env_utils)
  if not happy then
    cprint("Error executing utils: " .. tostring(err))
  end
  cprint("Utils loaded.")
end

local _persistent_funcs = {}

local function add_persistent_func(name, f)
  _persistent_funcs[name] = f
end

local function remove_persistent_func(name)
  _persistent_funcs[name] = nil
end

local function run_persistent_funcs()
  for fname, f in pairs(_persistent_funcs) do
    pcall(f, fname)
  end
end

local function _dofile(fn)
  local s = loadfile(fn)
  if type(s) == 'string' then
    -- work around Noita's broken loadfile that returns error
    -- message as first argument rather than as second
    error(fn .. ": " .. s)
  end
  setfenv(s, console_env)
  return s()
end

local function _strinfo(v)
  if v == nil then return "nil" end
  local vtype = type(v)
  if vtype == "number" then
    return ("%0.4f"):format(v)
  elseif vtype == "string" then
    return '"' .. v .. '"'
  elseif vtype == "boolean" then
    return tostring(v)
  else
    return ("[%s] %s"):format(vtype, tostring(v))
  end
end

local function strinfo(...)
  local frags = {}
  local nargs = select('#', ...)
  if nargs == 0 then
    return "[no value]"
  end
  for idx = 1, nargs do
    frags[idx] = _strinfo(select(idx, ...))
  end
  return table.concat(frags, ", ")
end

local function info(...)
  cprint(strinfo(...))
end

local function new_console_env()
  console_env = {}
  for k, v in pairs(getfenv()) do
    console_env[k] = v
  end
  console_env.new_console_env = new_console_env
  console_env.set_print_to_socket = set_print_to_socket
  console_env.print = cprint
  console_env.print_table = cprint_table
  console_env.socket_print = socket_print
  console_env.rawprint = print
  console_env.reload_utils = reload_utils
  console_env.add_persistent_func = add_persistent_func
  console_env.set_persistent_func = add_persistent_func -- alias
  console_env.remove_persistent_func = remove_persistent_func
  console_env.strinfo = strinfo
  console_env.info = info
  console_env.dofile = _dofile
  
  reload_utils()
end
new_console_env()

local function _collect(happy, ...)
  if happy then
    return happy, strinfo(...)
  else
    return happy, ...
  end
end

local function do_command(msg)
  local f, err = nil, nil
  if not msg:find("\n") then
    -- if this is a single line, try putting "return " in front
    -- (convenience to allow us to inspect values)
    f, err = loadstring("return " .. msg)
  end
  if not f then -- multiline, or not an expression
    f, err = loadstring(msg)
    if not f then
      cprint("ERR> Parse error: " .. tostring(err))
      return
    end
  end
  setfenv(f, console_env)
  local happy, retval = _collect(pcall(f))
  if happy then
    cprint("RES> " .. tostring(retval))
  else
    cprint("ERR> " .. tostring(retval))
  end
end

local count = 0

_ws_main = function()
  local msg = main_socket:poll()
  if msg then
    do_command(msg)
  end
  count = count + 1
  if count % 60 == 0 then
    main_socket:send('{"kind": "heartbeat", "source": "noita"}')
  end
  run_persistent_funcs()
  wake_up_waiting_threads(1) -- from coroutines.lua
end