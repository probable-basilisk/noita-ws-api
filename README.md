![Screenshot of the example webconsole being used to print an "important" game message](/screenshot.jpg?raw=true)

# noita-ws-api
Websocket based API to Noita: allows Noita to connect through a websocket to a server, which can then execute
arbitrary Lua within Noita's environment.

## Installation (mod / API host)

The mod dynamically links the [pollws](https://github.com/probable-basilisk/pollws) library through 
luajit's FFI in order to act as a websocket client.

* Grab the [pollws binaries](https://github.com/probable-basilisk/pollws/releases/download/0.1.0/pollws_0_1_0_windows.zip): copy
the *32 bit* `pollws.dll` into your Noita install dir (so it should be in the same directory as `Noita.exe`). You don't need
to care about the includes, bindings, or `.lib` files-- only the `.dll` is needed.

* Copy the `mod_ws` directory into `{your_Noita_install_dir}/mods/`: you should end up with a file in
`{your_Noita_install_dir}/mods/mod_ws/mod.xml`.

* Enable the `mod_ws` mod in the Noita mods menu. It will ask for full permissions (in order to use the FFI); presumably
you understand what that means and the risks involved.

* (optional) Copy the `mod_dev_settings` directory into your mods dir. This mod disables Noita from pausing when
it loses focus, which is very convenient when using the console. Enable this mod also in the Noita mods menu.

## Installation (example servers)

The example servers run on nodejs, so get nodejs installed, and then
```
cd {the_example_servers_dir}
npm install
```

To run the webconsole, then
```
node main_console.js
```

A web browser window should automatically open to a Noita webconsole. Start up Noita (with `mod_ws` enabled),
and then you can directly execute Lua commands from the webconsole. For example, try:

```Lua
hello()
GamePrintImportant("Big Message", "Sub Message")
print_entity_info(get_player())
```

## API Overview

The `mod_ws` mod acts as a websocket client, and automatically tries to connect to `ws://localhost:9090`.

* Websocket messages sent *TO* Noita are treated as raw Lua source and directly executed as Lua
* Noita will reply with two kinds of messages: JSON payloads, and raw strings. Raw strings are
prefixed with `>`. Approximately every second Noita will send a heartbeat message, in JSON, of the
form `{"kind": "heartbeat", "source": "noita"}`.