window.indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;
window.IDBTransaction = window.IDBTransaction || window.webkitIDBTransaction || window.msIDBTransaction;
window.IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;

if (!window.indexedDB) {
    window.alert("Your browser doesn't support a stable version of IndexedDB.");
}

window.kanban = {
    beginTransaction: function(mode) {
        var transaction = db.transaction('boards', mode);
        transaction.onerror = db.error;
        return transaction.objectStore('boards');
    },
    addBoard: function(parent, json, objectStore) {
        if (parent === undefined || json === undefined) {
            throw 'Usage: addBoard(parent, json, [objectStore])';
        }
        if (json.name === undefined) {
            throw 'Board must have a name';
        }
        objectStore = objectStore || kanban.beginTransaction('readwrite');
        json.columns = json.columns || ['TODO', 'IN PROGRESS', 'REVIEW'];
        json.cards = json.cards || [ [], [], [] ];
        var request = objectStore.add(json);
        request.onsuccess = function(event) {
            kanban.getBoard(parent, objectStore, function(board) {
                board.cards[0].push(request.result);
                var update = objectStore.put(board);
                update.onsuccess = function(event) {
                    kanban.getBoard(0, objectStore, function(board) {
                        kanban.drawBoard(board);
                    });
                };
            });
        };
    },
    getBoard: function(id, objectStore, callback) {
        if (Object.prototype.toString.call(objectStore) == "[object Function]") {
            callback = objectStore;
            objectStore = undefined;
        }
        if (id === undefined) {
            throw 'Usage: getBoard(id, [objectStore], [callback])';
        }
        objectStore = objectStore || kanban.beginTransaction();
        var request = objectStore.get(id);
        request.onsuccess = function(event) {
            if (callback) {
                callback(request.result);
            } else {
                console.log(request.result);
            }
        };
    },
    drawCards: function(cards, root, objectStore) {
        for (var i = 0; i < cards.length; i++) {
            kanban.getBoard(cards[i], objectStore, function(ret) {
                var card = document.createElement('p');
                card.innerHTML = ret.name;
                root.appendChild(card);
            });
        }
    },
    drawBoard: function(board, root, objectStore) {
        objectStore = objectStore || kanban.beginTransaction();
        root = root || document.body;
        root.innerHTML = "";
        root.innerHTML += "<header><h1>" + board.name + "</h1></header>";
        var sections = [];
        for (var i = 0; i < board.columns.length; i++) {
            section = document.createElement('section');
            section.innerHTML = "<h2>" + board.columns[i] + "</h2>";
            kanban.drawCards(board.cards[i], section, objectStore);
            root.appendChild(section);
        }
    },
};

window.onload = function() {
    var request = indexedDB.open("kanban", 20);
    var dberror = function(event) {
        throw 'Database error: ' + event.target.errorCode;
    };
    request.onerror = function(event) {
        throw 'Error opening database';
    };
    request.onsuccess = function(event) {
        window.db = event.target.result;
        db.onerror = dberror;
        kanban.getBoard(0, function(board) {
            if (board) {
                kanban.drawBoard(board);
            } else {
                var root = {
                    id: 0,
                    name: 'Root Board',
                    columns: ['TODO', 'IN PROGRESS', 'REVIEW'],
                    cards: [ [], [], [] ]
                };
                var objectStore = kanban.beginTransaction('readwrite');
                objectStore.add(root);
                kanban.drawBoard(root);
            }
        });
    };
    request.onupgradeneeded = function(event) {
        var db = event.target.result;
        db.deleteObjectStore('boards');
        db.onerror = dberror;
        var objectStore = db.createObjectStore('boards', {keyPath: 'id', autoIncrement: true});
        objectStore.createIndex('name', 'name', {unique: false});
    };
};
