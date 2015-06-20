// Generated by CoffeeScript 1.9.3
(function() {
  var IDBKeyRange, IDBTransaction, addCard, deleteCard, indexedDB, kanban, makeButton, makeCard, makeContent, makeTitle, onDragEnd, onDragHandleMouseDown, onDragOver, onDragStart, onDropColumn, setAttr, toggleMinimise, updateCard, viewChild, viewParent;

  indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;

  IDBTransaction = window.IDBTransaction || window.webkitIDBTransaction || window.msIDBTransaction;

  IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;

  kanban = {
    db: null,
    board: null,
    draggedElement: null
  };

  window.kanban = kanban;

  kanban.error = function(message) {
    kanban = {};
    return document.body.innerHTML = "<div id='error'>" + message + "</div>";
  };

  kanban.beginTransaction = function(mode) {
    var transaction;
    transaction = kanban.db.transaction("boards", mode);
    return transaction.objectStore("boards");
  };

  kanban.reset = function() {
    return indexedDB.deleteDatabase("kanban");
  };

  updateCard = function(card, objectStore, callback) {
    var request;
    if (card == null) {
      throw "Usage: updateCard(card, [objectStore])";
    }
    if (card.name == null) {
      throw "Board must have a name";
    }
    if (objectStore == null) {
      objectStore = kanban.beginTransaction("readwrite");
    }
    request = objectStore.put(card);
    return request.onsuccess = callback;
  };

  kanban.loadCard = function(id, objectStore, callback) {
    var ref, request;
    if (Object.prototype.toString.call(objectStore) === "[object Function]") {
      ref = [objectStore, callback], callback = ref[0], objectStore = ref[1];
    }
    if (id == null) {
      throw "Usage: loadCard(id, [objectStore], [callback])";
    }
    if (objectStore == null) {
      objectStore = kanban.beginTransaction();
    }
    request = objectStore.get(id);
    return request.onsuccess = function() {
      var board;
      board = request.result;
      if (callback) {
        return callback(board);
      } else {
        return console.log(board);
      }
    };
  };

  kanban.loadBoard = function(id, objectStore, callback) {
    var board, outstanding, ref, setCard;
    if (Object.prototype.toString.call(objectStore) === "[object Function]") {
      ref = [objectStore, callback], callback = ref[0], objectStore = ref[1];
    }
    if (id == null) {
      id = 0;
    }
    if (objectStore == null) {
      objectStore = kanban.beginTransaction();
    }
    board = {
      root: id,
      cards: []
    };
    outstanding = 0;
    setCard = callback != null ? function(index, card) {
      this.cards[index] = card;
      if (--outstanding === 0) {
        return callback(board);
      }
    } : function(index, card) {
      return this.cards[index] = card;
    };
    kanban.loadCard(id, objectStore, (function(root) {
      var card, column, i, j, k, len, len1, len2, ref1, ref2;
      if (!root) {
        return typeof callback === "function" ? callback() : void 0;
      }
      this.cards[id] = root;
      if (callback) {
        ref1 = root.cards;
        for (i = 0, len = ref1.length; i < len; i++) {
          column = ref1[i];
          outstanding += column.length;
        }
        if (outstanding === 0) {
          callback(this);
        }
      }
      ref2 = root.cards;
      for (j = 0, len1 = ref2.length; j < len1; j++) {
        column = ref2[j];
        for (k = 0, len2 = column.length; k < len2; k++) {
          card = column[k];
          if (!this.cards[card]) {
            kanban.loadCard(card, objectStore, setCard.bind(this, card));
          }
        }
      }
      return void 0;
    }).bind(board));
    return board;
  };

  onDragHandleMouseDown = function(e) {
    kanban.draggedElement = this.parentElement;
    return this.parentElement.draggable = true;
  };

  onDragOver = function(e) {
    if (kanban.draggedElement !== this) {
      return e.preventDefault();
    }
  };

  onDragStart = function(e) {
    if (kanban.draggedElement != null) {
      setTimeout((function() {
        return kanban.draggedElement.classList.add("dragging");
      }), 0);
    }
    return e.dataTransfer.setData('Text', this.id);
  };

  onDragEnd = function(e) {
    if (this === kanban.draggedElement) {
      kanban.draggedElement.classList.remove("dragging");
      kanban.draggedElement = null;
      return this.draggable = false;
    }
  };

  onDropColumn = function(e) {
    var card, rect;
    if (!((kanban.draggedElement != null) && this.tagName === "KB-COLUMN")) {
      return;
    }
    card = e.target.closest('kb-card');
    if (card === kanban.draggedElement) {
      return;
    }
    rect = card === null ? this.getBoundingClientRect() : card.getBoundingClientRect();
    kanban.draggedElement.parentElement.removeChild(kanban.draggedElement);
    if (card === null) {
      if (e.clientY < rect.y + rect.height / 2) {
        card = this.getElementsByTagName("kb-card")[0];
        if (card != null) {
          this.insertBefore(kanban.draggedElement, card);
          return;
        }
      }
      return this.appendChild(kanban.draggedElement);
    } else {
      if (e.clientY < rect.y + rect.height / 2) {
        return this.insertBefore(kanban.draggedElement, card);
      } else {
        card = card.nextElementSibling;
        if (card != null) {
          return this.insertBefore(kanban.draggedElement, card);
        } else {
          return this.appendChild(kanban.draggedElement);
        }
      }
    }
  };

  toggleMinimise = function(e) {
    return this.parentElement.getElementsByClassName("content")[0].classList.toggle("hidden");
  };

  addCard = function(e) {
    var card, column, index, objectStore, request;
    column = this.parentElement;
    index = column.getAttribute("data-column-id");
    objectStore = kanban.beginTransaction("readwrite");
    card = {
      name: "New card",
      desc: "",
      columns: ["TODO", "IN PROGRESS", "REVIEW"],
      cards: [[], [], []],
      parent: kanban.board.root
    };
    request = objectStore.add(card);
    return request.onsuccess = function() {
      card.id = request.result;
      kanban.board.cards[card.id] = card;
      kanban.board.cards[kanban.board.root].cards[index].push(card.id);
      return column.appendChild(makeCard(card));
    };
  };

  viewChild = function(e) {
    return kanban.drawBoard(parseInt(this.parentElement.getAttribute("data-kb-id")));
  };

  viewParent = function(e) {
    return kanban.drawBoard(kanban.board.cards[kanban.board.root].parent);
  };

  deleteCard = function(e) {
    var index;
    index = parseInt(this.parentElement.getAttribute("data-kb-id"));
    return this.parentElement.parentElement.removeChild(this.parentElement);
  };

  setAttr = function(elem, attr) {
    var key, ref, results, value;
    if (attr == null) {
      return;
    }
    if (attr.id != null) {
      elem.id = attr.id;
    }
    if (attr.classes != null) {
      elem.className += " " + attr.classes;
    }
    if (attr.data != null) {
      ref = attr.data;
      results = [];
      for (key in ref) {
        value = ref[key];
        results.push((function(key, value) {
          return elem.setAttribute("data-" + key, value);
        })(key, value));
      }
      return results;
    }
  };

  makeTitle = function(value, attr) {
    var title, wrap;
    title = document.createElement("input");
    title.setAttribute("type", "text");
    title.className = "editable-text";
    title.value = value;
    if (attr != null) {
      setAttr(title, attr);
    }
    wrap = document.createElement("span");
    wrap.className = "title-wrap";
    wrap.appendChild(title);
    return wrap;
  };

  makeContent = function(value, attr) {
    var content;
    content = document.createElement("p");
    content.className = "content";
    content.setAttribute("contenteditable", true);
    content.innerHTML = value;
    if (attr != null) {
      setAttr(content, attr);
    }
    return content;
  };

  makeButton = function(name, handler, attr) {
    var button;
    button = document.createElement("kb-button");
    button.className = name;
    if (handler != null) {
      button.addEventListener("click", handler, false);
    }
    if (attr != null) {
      setAttr(button, attr);
    }
    return button;
  };

  makeCard = function(card) {
    var drag, wrap;
    wrap = document.createElement("kb-card");
    wrap.setAttribute("data-kb-id", card.id);
    wrap.addEventListener("dragstart", onDragStart, false);
    wrap.addEventListener("dragover", onDragOver, false);
    wrap.addEventListener("dragenter", onDragOver, false);
    wrap.addEventListener("dragend", onDragEnd, false);
    drag = makeButton("drag");
    drag.addEventListener("mousedown", onDragHandleMouseDown, false);
    wrap.appendChild(drag);
    wrap.appendChild(makeButton("minimise", toggleMinimise));
    wrap.appendChild(makeButton("viewboard", viewChild));
    wrap.appendChild(makeButton("delete", deleteCard));
    wrap.appendChild(makeTitle(card.name, {
      "classes": "title"
    }));
    wrap.appendChild(makeContent(card.desc, (card.minimised ? {
      classes: "hidden"
    } : void 0)));
    return wrap;
  };

  kanban.drawBoard = function(board, objectStore, recursed) {
    var board_header, fn, i, index, len, main, name, ref;
    if (Object.prototype.toString.call(board) === "[object Object]") {
      document.body.innerHTML = "";
      main = board.cards[board.root];
      board_header = document.createElement("header");
      if (main.id !== 0) {
        board_header.appendChild(makeButton("viewparent", viewParent));
      }
      board_header.appendChild(makeButton("saveboard", kanban.saveBoard));
      board_header.appendChild(makeTitle(main.name, {
        id: "kb-board-title",
        data: {
          "kb-id": main.id
        }
      }));
      board_header.appendChild(makeContent(main.desc, {
        id: "kb-board-desc"
      }));
      document.body.appendChild(board_header);
      ref = main.columns;
      fn = function(name, index) {
        var card, column, j, len1, ref1;
        column = document.createElement("kb-column");
        column.setAttribute("data-column-id", index);
        column.appendChild(makeButton("add", addCard));
        column.appendChild(makeTitle(name, {
          classes: "kb-column-title"
        }));
        column.addEventListener("dragover", onDragOver, false);
        column.addEventListener("dragenter", onDragOver, false);
        column.addEventListener("dragend", onDragEnd, false);
        column.addEventListener("drop", onDropColumn, false);
        ref1 = main.cards[index];
        for (j = 0, len1 = ref1.length; j < len1; j++) {
          card = ref1[j];
          column.appendChild(makeCard(board.cards[card]));
        }
        return document.body.appendChild(column);
      };
      for (index = i = 0, len = ref.length; i < len; index = ++i) {
        name = ref[index];
        fn(name, index);
      }
      kanban.board = board;
      return void 0;
    } else if (!recursed) {
      if (board == null) {
        board = 0;
      }
      if (objectStore == null) {
        objectStore = kanban.beginTransaction();
      }
      return kanban.loadBoard(board, function(brd) {
        return kanban.drawBoard(brd, objectStore, true);
      });
    } else {
      throw "Failed to load the board";
    }
  };

  kanban.saveBoard = function() {
    var board_title, card, column, delete_cards, fn, i, index, j, k, len, len1, len2, objectStore, ref, ref1, root;
    board_title = document.getElementById("kb-board-title");
    root = kanban.board.cards[board_title.getAttribute("data-kb-id")];
    root.name = board_title.value;
    root.desc = document.getElementById("kb-board-desc").innerHTML;
    delete_cards = new Set;
    ref = root.cards;
    for (i = 0, len = ref.length; i < len; i++) {
      column = ref[i];
      for (j = 0, len1 = column.length; j < len1; j++) {
        card = column[j];
        delete_cards.add(card);
      }
    }
    objectStore = kanban.beginTransaction("readwrite");
    ref1 = document.body.getElementsByTagName("kb-column");
    fn = function(column, index) {
      root.columns[index] = column.getElementsByClassName("kb-column-title")[0].value;
      return root.cards[index] = (function() {
        var l, len3, ref2, results;
        ref2 = column.getElementsByTagName("kb-card");
        results = [];
        for (l = 0, len3 = ref2.length; l < len3; l++) {
          card = ref2[l];
          results.push((function(card) {
            var card_id, content;
            card_id = parseInt(card.getAttribute("data-kb-id"));
            if (card_id === NaN) {
              return kanban.error("Invalid card id: " + card_id);
            }
            delete_cards["delete"](card_id);
            content = card.getElementsByClassName("content")[0];
            kanban.board.cards[card_id].name = card.getElementsByClassName("title")[0].value;
            kanban.board.cards[card_id].minimised = content.classList.contains("hidden");
            kanban.board.cards[card_id].desc = content.innerHTML;
            updateCard(kanban.board.cards[card_id], objectStore);
            return card_id;
          })(card));
        }
        return results;
      })();
    };
    for (index = k = 0, len2 = ref1.length; k < len2; index = ++k) {
      column = ref1[index];
      fn(column, index);
    }
    delete_cards.forEach(function(card) {
      console.log(card);
      return objectStore["delete"](card);
    });
    updateCard(root, objectStore);
    return void 0;
  };

  if (!indexedDB) {
    kanban.error("Your browser doesn't support a stable version of IndexedDB.");
  }

  window.onload = function() {
    var dberror, request;
    request = indexedDB.open("kanban", 20);
    dberror = function(event) {
      return kanban.error("Database error: " + event.target.errorCode);
    };
    request.onerror = kanban.error.bind(void 0, "Error opening database");
    request.onsuccess = function(event) {
      kanban.db = event.target.result;
      kanban.db.onerror = dberror;
      return kanban.loadBoard(0, function(root) {
        var card, objectStore;
        if (!root) {
          card = {
            id: 0,
            name: "Root Board",
            desc: "Testing",
            columns: ["TODO", "IN PROGRESS", "REVIEW"],
            cards: [[], [], []]
          };
          objectStore = kanban.beginTransaction("readwrite");
          objectStore.add(card);
          root = {
            root: 0,
            cards: [card]
          };
        }
        return kanban.drawBoard(root);
      });
    };
    return request.onupgradeneeded = function(event, recursed) {
      var db, error, objectStore;
      db = event.target.result;
      db.onerror = dberror;
      try {
        objectStore = db.createObjectStore("boards", {
          keyPath: "id",
          autoIncrement: true
        });
      } catch (_error) {
        error = _error;
        if (!recursed) {
          db.deleteObjectStore("boards");
          request.onupgradeneeded(event, true);
        }
        return;
      }
      return objectStore.createIndex("name", "name", {
        unique: false
      });
    };
  };

}).call(this);