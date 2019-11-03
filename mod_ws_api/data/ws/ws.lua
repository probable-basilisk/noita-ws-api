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
    if not scratch_size then scratch_size = 64000 end
    local res = {
      _socket = pollws.pollws_open(url),
      _scratch = ffi.new("int8_t[?]", scratch_size),
      _scratch_size = scratch_size
    }
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
  
  reload_utils()
end
new_console_env()

local function do_command(msg)
  local f, err = loadstring(msg)
  if not f then
    cprint("ERR> Parse error: " .. tostring(err))
    return
  end
  setfenv(f, console_env)
  local happy, retval = pcall(f)
  if happy then
    cprint("OK>")
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
end