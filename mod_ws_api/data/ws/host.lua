-- This file exists so that mods can conveniently override it to 
-- change the URL that ws-api attempts to connect to
WS_HOST_URL = "ws://localhost:9090"

function get_ws_host_url()
  return WS_HOST_URL
end