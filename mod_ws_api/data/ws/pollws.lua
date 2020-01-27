if pollws then return end

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

local POLLWS_STATUS_CODES = {
  [-1] = "invalid",
  [ 0] = "closed",
  [ 1] = "opening",
  [ 2] = "open",
  [ 3] = "error"
}

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
  function res:raw_status()
    if not self._socket then return -1 end
    return pollws.pollws_status(self._socket)
  end
  function res:status()
    return POLLWS_STATUS_CODES[self:raw_status()] or "unknown"
  end
  function res:run_async(on_message)
    self.running = true
    async(function()
      while self._socket and self.running do
        local msg = self:poll()
        if msg then on_message(self, msg) end
        wait(1)
      end
    end)
  end
  function res:stop()
    self.running = false
  end

  return res
end