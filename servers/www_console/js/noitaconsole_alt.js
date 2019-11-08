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
    console.log(event.data);
    var jdata = JSON.parse(event.data);
    if (jdata["kind"] === "print") {
      replPrint(jdata["text"]);
    } else {
      console.log("Unknown message: " + event.data)
    }
  });
}

function remoteEval(code) {
  console.log("Would eval: " + code);
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
  repl.writeln(message);
}

function printArt() {
  repl.print("Noita console");
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
      console.log(cm.getValue());
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
      console.log(val);
      remoteEval(val);
      replPrint("EVAL> " + val);
      lineWindow.setValue("");
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

  // repl.prompt = () => {
  //     repl.write('\r\n> ');
  // };

  repl.writeln('Noita console');
  repl.writeln('(Note that this panel is for output only)');
  repl.writeln('');
  //repl.prompt();

  // repl.onKey(e => {
  //     const printable = !e.domEvent.altKey && !e.domEvent.altGraphKey && !e.domEvent.ctrlKey && !e.domEvent.metaKey;

  //     if (e.domEvent.keyCode === 13) {
  //       if(repl.buffer.cursorX == 0) {
  //         console.log("ZEROX?");
  //         repl.prompt();
  //         return;
  //       }
  //       let lastLine = repl.buffer.getLine(repl.buffer.cursorY).translateToString(true);
  //       lastLine = lastLine.slice(2);
  //       console.log(lastLine);
  //       repl.prompt();
  //       remoteEval(lastLine);
  //     } else if (e.domEvent.keyCode === 8) {
  //         // Do not delete the prompt
  //         if (repl._core.buffer.x > 2) {
  //             repl.write('\b \b');
  //         }
  //     } else if (printable) {
  //         repl.write(e.key);
  //     }
  // });

  // repl.onData(function(data) {
  //   console.log(data);
  //   repl.write(data);
  // });
}
