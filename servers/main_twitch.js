//require('dotenv').config();
const ws = require('ws');
const tmi = require('tmi.js');
const fs = require('fs');

// eh...
const CHANNEL =  process.argv[2];

const WS_PORT = 9090;
const SECS_BETWEEN_VOTES = 10;
const SECS_FOR_VOTE = 60;

const wss = new ws.Server({ port: WS_PORT });
console.log("WS listening on " + WS_PORT);

let noita = null;

function getConnectionName(ws) {
  return ws._socket.remoteAddress + ":" + ws._socket.remotePort;
}

function isConnectionLocalhost(ws) {
  const addr = ws._socket.remoteAddress
  return (addr == "::1") || (addr == "127.0.0.1") || (addr == "localhost") || (addr == "::ffff:127.0.0.1")
}

function noitaDoFile(fn) {
  if (noita == null) {
    return;
  }
  const fdata = fs.readFileSync(fn);
  noita.send(fdata);
}

// TODO: refactor all this into a common file
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
      console.log(data);
      return;
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
      if (noita != ws) {
        console.log("Registering noita!");
        noita = ws;
        ws.send(`GamePrint('WS connected as ${cname}')`);
        ws.send("set_print_to_socket(true)");
        noitaDoFile("twitch_fragments/setup.lua");
        noitaDoFile("twitch_fragments/outcomes.lua");
      }
    }
  });

  ws.on('close', function closed(_ws, code, reason) {
    console.log("Connection closed: " + code + ", " + reason);
    if (ws === noita) {
      console.log("Noita closed");
      noita = null;
    }
  });
});

let timeleft = 0;
let user_votes = {};

function getVotes() {
  let votes = [0, 0, 0, 0];
  for(uname in user_votes) {
    let v = user_votes[uname];
    if (v >= 1 && v <= 4) {
      votes[v-1] += 1;
    }
  }
  return votes;
}

let accepting_votes = false;
function handleVote(username, v) {
  if(!accepting_votes) {
    return;
  }
  let iv = parseInt(v.slice(0,1));
  if(isNaN(iv)) {
    return;
  }
  user_votes[username] = iv;
}

function sleep(nsecs) {
  return new Promise(resolve => setTimeout(resolve, nsecs * 1000));
}

async function doQuestion() {
  // main timer
  timeleft = SECS_BETWEEN_VOTES;
  while(timeleft > 0) {
    if (noita == null) {
      return;
    }
    noita.send(`set_countdown(${timeleft})`);
    timeleft -= 1;
    await sleep(1);
  }
  if (noita == null) {
    return;
  }
  accepting_votes = true;
  user_votes = {};
  noita.send("clear_display()\ndraw_outcomes(4)");
  timeleft = SECS_FOR_VOTE;
  while(timeleft > 0) {
    if (noita == null) {
      return;
    }
    noita.send(`set_votes{${getVotes().join(",")}}`);
    noita.send(`update_outcome_display(${timeleft})`);
    timeleft -= 1;
    await sleep(1);
  }
  if (noita == null) {
    return;
  }
  noita.send("do_winner()");
}

async function gameLoop() {
  while(true) {
    accepting_votes = false;
    while(noita == null) {
      console.log("Waiting for Noita...");
      await sleep(5);
    }
    await doQuestion();
  }
}

const options = {
  options: {debug: true},
  connection: {reconnect: true}
  //identity: { username: process.env.TWITCH_USERNAME, password: process.env.TWITCH_OAUTH}
};

const chatClient = new tmi.client(options);
chatClient.connect().then((_client) => {
  chatClient.join(CHANNEL);

  chatClient.on("message", function (channel, userstate, message, self) {
    // console.log(message);
    // console.log(userstate);
    if (self) return; // Don't listen to my own messages..
    if (userstate["message-type"] === "chat") {
      handleVote(userstate['user-id'], message);
    }
  });
});

gameLoop();