$(function(){
    initCodeMirror();
    printArt();
    initConnection();
});

var repl = null;
var connection = null;
var connected = false;
var targetPlayer = 1;

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
  repl.print(message);
}

function printArt() {
  repl.print("Noita console");
}

function bracketsBalanced(code) {
    var length = code.length;
    var delimiter = '';
    var brackets = [];
    var matching = {
        ')': '(',
        ']': '[',
        '}': '{'
    };

    for (var i = 0; i < length; i++) {
        var char = code.charAt(i);

        switch (delimiter) {
        case "'":
        case '"':
        default:
            switch (char) {
            case "'":
            case '"':
                delimiter = char;
                break;
            case "(":
            case "[":
            case "{":
                brackets.push(char);
                break;
            case ")":
            case "]":
            case "}":
                if (!brackets.length || matching[char] !== brackets.pop()) {
                    repl.print(new SyntaxError("Unexpected closing bracket: '" + char + "'"), "error");
                    return null;
                }
            }
        }
    }

    return brackets.length ? false : true;
}

function doEndBalanced(code) {
    // TODO: function doesn't work if there isn't a space between
    // 'function' and the opening '('
    var startTokens = new Set(["function", "do", "then", "else"]);
    var endTokens = new Set(["end"]);

    codeTokens = code.split(/\s+/);
    var nestLevel = 0;
    var curtoken;

    for(var i = 0; i < codeTokens.length; ++i) {
        curtoken = codeTokens[i];
        if(startTokens.has(curtoken)) {
            nestLevel += 1;
        } else if(endTokens.has(curtoken)) {
            nestLevel -= 1;
        }

        // unrecoverable situation like "do [...] end end"
        if(nestLevel < 0) {
            return null;
        }
    }

    return (nestLevel == 0);
}

function initCodeMirror() {
    var geval = eval;

    repl = new CodeMirrorREPL("repl", {
        mode: "lua",
        theme: "dracula"
    });

    $("#console-column").click(function() {
        repl.mirror.focus();
    });

    window.print = function (message, mclass) {
        repl.print(message, mclass || "message");
    };

    repl.isBalanced = function (code) {
        var b0 = true; //bracketsBalanced(code);
        var b1 = doEndBalanced(code);
        if(b0 == null || b1 == null) {
            return null;
        } else {
            return b0 && b1;
        }
    };

    repl.eval = function (code) {
        remoteEval(code);
    };
}
