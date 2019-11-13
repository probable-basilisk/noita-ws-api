$(function(){
  initCodeMirror();
  initConnection();
});

var codeWindow = null;
var connection = null;
var connected = false;
var repl = null;
var lineWindow = null;
var fit = null;

var commandHistory = [];

function ansiRGB(r, g, b) {
  return `\x1b[38;2;${r};${g};${b}m`
}

function ansiBgRGB(r, g, b) {
  return `\x1b[48;2;${r};${g};${b}m`
}

function ansiReset() {
  return '\x1b[0m'
}


function getToken() {
  var parts = document.URL.split("/");
  if (parts[parts.length - 1].length == 32) {
    return parts[parts.length - 1]
  } else {
    return parts[parts.length - 2]
  }
}

function initConnection(url) {
  if(!url) {
      url = "ws://localhost:9090"
  }
  console.log("Connecting to url " + url);

  connection = new WebSocket(url);
  connection.addEventListener('open', function (event) {
    console.log('Connected: ' + url);
    connected = true;
    connection.send(JSON.stringify({kind: 'heartbeat', source: 'console', token: getToken()}));
  });

  connection.addEventListener('message', function (event) {
    var jdata = JSON.parse(event.data);
    if (jdata["kind"] === "print") {
      replPrint(jdata["text"]);
    } else {
      console.log("Unknown message: " + event.data)
    }
  });
}

function remoteEval(code) {
  if(code[0] === '!') {
    let parts = code.slice(1).split(" ");
    if(parts[0] === "connect") {
      initConnection(parts[1]);
    } else {
      replPrint("Unknown local command: " + parts[0]);
    }
  } else if(connected) {
    connection.send(JSON.stringify({kind: "command", command: code}));
  }
}

function replPrint(message) {
  message = message.replace(/\n/g, "\r\n");
  if(message.indexOf("ERR>") == 0) {
    message = ansiRGB(200, 0, 0) + message + ansiReset();
  } else if(message.indexOf("RES>") == 0) {
    message = ansiRGB(100, 100, 255) + message + ansiReset();
  } else if(message.indexOf("EVAL>") == 0) {
    message = ansiRGB(100, 255, 100) + message + ansiReset();
  } else if(message.indexOf("COM>") == 0) {
    // see how many suggestions we got
    let opts = message.slice(4).split(",");
    if(opts.length == 1) {
      // fill in this completion
      lineWindow.setValue(opts[0]);
      lineWindow.setCursor(lineWindow.lineCount(), 0);
    }
    message = ansiRGB(150, 150, 150) + message + ansiReset();
  }
  repl.writeln(message);
}

function initCodeMirror() {
  codeWindow = CodeMirror.fromTextArea(document.getElementById("code"), {
    value: "-- Put multiline Lua stuff here\n",
    mode:  "lua",
    theme:  "dracula",
    lineNumbers: true
  });

  codeWindow.setOption("extraKeys", {
    "Shift-Enter": function(cm) {
      remoteEval(cm.getValue());
      replPrint("EVAL> [buffer]");
    }
  });

  lineWindow = CodeMirror.fromTextArea(document.getElementById("replinput"), {
    value: "",
    mode:  "lua",
    theme:  "dracula"
  });

  lineWindow.setOption("extraKeys", {
    "Enter": function(cm) {
      const val = cm.getValue();
      if(val == "") {
        return;
      }
      remoteEval(val);
      if(commandHistory.indexOf(val) < 0) {
        commandHistory.push(val);
      }
      replPrint("EVAL> " + val);
      cm.setValue("");
    },
    "Tab": function(cm) {
      console.log("TAB");
      const val = cm.getValue().trim();
      if(val == "") {
        return;
      }
      // Note that [=[ some string ]=] is a special Lua
      // string literal that allows nesting of other string
      // literals, including the more typical [[ ]] pair
      remoteEval(`complete([=[${val}]=])`);
    },
    "Up": function(cm) {
      let hpos = commandHistory.indexOf(cm.getValue());
      if(hpos > 0) {
        cm.setValue(commandHistory[hpos-1]);
      } else if(hpos == 0) {
        // don't do anything
      } else {
        cm.setValue(commandHistory[commandHistory.length-1]);
      }
    },
    "Down": function(cm) {
      let hpos = commandHistory.indexOf(cm.getValue());
      if(hpos >= 0 && hpos < commandHistory.length - 1) {
        cm.setValue(commandHistory[hpos+1]);
      }
    }
  });

  repl = new Terminal({
    theme: {
      background: '#111'
    }
  });
  fit = new FitAddon.FitAddon();
  repl.loadAddon(fit);
  repl.open(document.getElementById("repl"));
  repl._initialized = true;

  fit.fit();

  repl.writeln('Noita console');
  repl.writeln('(Note that this panel is for output only)');
  repl.writeln('');
}
