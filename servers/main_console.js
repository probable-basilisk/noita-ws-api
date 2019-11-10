const ws = require('ws');
const crypto = require('crypto');
const open = require('open');
const WS_PORT = 9090;


const wss = new ws.Server({ port: WS_PORT });
console.log("WS listening on " + WS_PORT);

let noita = null;
let con = null;

function getConnectionName(ws) {
  return ws._socket.remoteAddress + ":" + ws._socket.remotePort;
}

function isConnectionLocalhost(ws) {
  const addr = ws._socket.remoteAddress
  return (addr == "::1") || (addr == "127.0.0.1") || (addr == "localhost") || (addr == "::ffff:127.0.0.1")
}

function randomToken() {
  return crypto.randomBytes(16).toString('hex');
}
const TOKEN = randomToken();

wss.on('connection', function connection(ws) {
  const cname = getConnectionName(ws);
  console.log("New connection: " + cname);
  if (!isConnectionLocalhost(ws)) {
    console.log("Connection refused: not localhost!");
    ws.terminate();
    return
  }

  ws.on('message', function incoming(data, flags) {
    let jdata = null;
    // special case: if the string we get is prefixed with ">",  
    // don't try to interpret as JSON, just treat it as a print
    if (data.slice(0, 1) == ">") {
      jdata = {kind: "print", text: data.slice(1)};
    } else {
      try {
        jdata = JSON.parse(data);
      } catch (e) {
        console.log(data);
        console.error(e);
        return;
      }
    }

    if (jdata["kind"] === "heartbeat") {
      if (jdata["source"] === "noita") {
        if (noita != ws) {
          console.log("Registering noita!");
          noita = ws;
          ws.send(`GamePrint('WS connected as ${cname}')`);
          ws.send("set_print_to_socket(true)");
          ws.send("print('Noita connected')");
        }
      } else if (jdata["source"] === "console") {
        if (con != ws) {
          if (jdata["token"] != TOKEN) {
            console.log("Invalid token! Got: " + jdata["token"]);
            ws.terminate();
            return;
          }
          console.log("Registering console!");
          con = ws;
          ws.send(JSON.stringify({kind: "print", text: `Connected as ${cname}`}));
        }
      } else {
        console.log("Unknown source: " + jdata["source"]);
      }
    } else if (ws === noita) {
      // send noita->con
      if (con != null) {
        con.send(JSON.stringify(jdata));
      }
    } else if (ws === con) {
      // con -> noita
      if (noita != null) {
        // Don't want to involve JSON parser on Noita end,
        // so send just the raw command
        noita.send(jdata["command"]);
      }
    }
  });
  ws.on('close', function closed(_ws, code, reason) {
    console.log("Connection closed: " + code + ", " + reason);
    if (ws === noita) {
      console.log("Noita closed");
      noita = null;
    }
    if (ws === con) {
      console.log("Console webpage closed");
      con = null;
    }
  });
});

const { join } = require('path');
const polka = require('polka');

const HTTP_PORT = 8080;
const dir = join(__dirname, 'www_console');
const serve = require('serve-static')(dir);

const secret_dir = "/" + TOKEN

polka()
  .use(secret_dir, serve)
  .listen(HTTP_PORT, err => {
    if (err) throw err;
    console.log(`Console on localhost:${HTTP_PORT}${secret_dir}`);
    open(`http://localhost:${HTTP_PORT}${secret_dir}`);
  });
