indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB
IDBTransaction = window.IDBTransaction || window.webkitIDBTransaction || window.msIDBTransaction
IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange

kanban = {
    db: null,
    board: null,
    internal: {}
}
window.kanban = kanban

kanban.error = (message) ->
    kanban = {}
    document.body.innerHTML = "<div id='error'>" + message + "</div>"

kanban.beginTransaction = (mode) ->
    transaction = kanban.db.transaction("boards", mode)
    return transaction.objectStore("boards")

kanban.reset = () ->
    indexedDB.deleteDatabase("kanban")

kanban.updateCard = (card, objectStore, callback) ->
    throw "Usage: updateCard(card, [objectStore])" unless card?
    throw "Board must have a name" unless card.name?
    objectStore ?= kanban.beginTransaction("readwrite")
    request = objectStore.put(card)
    request.onsuccess = callback

kanban.addBoard = (parent, json, objectStore) ->
    throw "Usage: addBoard(parent, json, [objectStore])" unless parent? and json?
    throw "Board must have a name" unless json.name?
    objectStore ?= kanban.beginTransaction("readwrite")
    json.columns ?= ["TODO", "IN PROGRESS", "REVIEW"]
    json.cards ?= [ [], [], [] ]
    request = objectStore.add(json)
    request.onsuccess = () ->
        kanban.loadCard(parent, objectStore, (parentBoard) ->
            parentBoard.cards[0].push(request.result)
            update = objectStore.put(parentBoard)
            update.onsuccess = () -> kanban.drawBoard(parent))

kanban.loadCard = (id, objectStore, callback) ->
    if (Object.prototype.toString.call(objectStore) is "[object Function]")
        [callback, objectStore] = [objectStore, callback]
    throw "Usage: loadCard(id, [objectStore], [callback])" unless id?
    objectStore ?= kanban.beginTransaction()
    request = objectStore.get(id)
    request.onsuccess = () ->
        board = request.result;
        if (callback)
            callback(board);
        else
            console.log(board);

kanban.loadBoard = (id, objectStore, callback) ->
    if (Object.prototype.toString.call(objectStore) is "[object Function]")
        [callback, objectStore] = [objectStore, callback]
    id ?= 0;
    objectStore ?= kanban.beginTransaction();
    board = {
        root: id,
        cards: []
    }
    outstanding = 0;
    setCard =
        if callback?
            (index, card) ->
                this.cards[index] = card
                if (--outstanding is 0)
                    callback(board)
        else
            (index, card) -> 
                this.cards[index] = card
    kanban.loadCard(id, objectStore, ((root) ->
        if (!root)
            return callback?()
        this.cards[id] = root
        if (callback)
            outstanding += column.length for column in root.cards
            callback(this) if (outstanding is 0)
        (kanban.loadCard(card, objectStore, setCard.bind(this, card)) unless this.cards[card]) for card in column for column in root.cards
        undefined
    ).bind(board))
    board

kanban.internal.drawCard = (card) ->
    wrap = document.createElement("div")
    wrap.className = "kb-card";
    wrap.setAttribute("data-kb-id", card.id)

    title = document.createElement("input")
    title.className = "title editable-text"
    title.setAttribute("type", "text")
    title.value = card.name

    content = document.createElement("p")
    content.className = "content"
    content.setAttribute("contenteditable", true)
    content.innerHTML = card.desc

    wrap.appendChild(title)
    wrap.appendChild(content)

    wrap

kanban.drawBoard = (board, objectStore, recursed) ->
    if (Object.prototype.toString.call(board) is "[object Object]")
        document.body.innerHTML = "";
        main = board.cards[board.root]
        board_header = document.createElement("header")
        board_title = document.createElement("input")
        board_title.id = "kb-board-title"
        board_title.className = "editable-text"
        board_title.setAttribute("type", "text")
        board_title.setAttribute("data-kb-id", main.id)
        board_title.value = main.name
        board_header.appendChild(board_title)
        board_desc = document.createElement("p")
        board_desc.id = "kb-board-desc"
        board_desc.setAttribute("contenteditable", true)
        board_desc.innerHTML = main.desc
        board_header.appendChild(board_desc)
        document.body.appendChild(board_header)
        for column, index in main.columns
            do (column, index) ->
                section = document.createElement("section")
                column_title = document.createElement("input")
                column_title.className = "kb-column-title editable-text"
                column_title.setAttribute("type", "text")
                column_title.value = column;
                section.appendChild column_title
                section.appendChild kanban.internal.drawCard board.cards[card] for card in main.cards[index]
                document.body.appendChild(section)
        kanban.board = board
        undefined
    else unless recursed
        board ?= 0
        objectStore ?= kanban.beginTransaction()
        kanban.loadBoard(board, (brd) ->
            kanban.drawBoard(brd, objectStore, true))
    else
        throw "Failed to load the board"

kanban.saveBoard = () ->
    board_title = document.getElementById("kb-board-title");
    board = kanban.board.cards[board_title.getAttribute("data-kb-id")]
    board.name = board_title.value
    board.desc = document.getElementById("kb-board-desc").innerHTML;
    objectStore = kanban.beginTransaction("readwrite")
    for column, index in document.body.getElementsByTagName("section")
        do (column, index) ->
            board.columns[index] = column.getElementsByClassName("kb-column-title")[0].value
            board.cards[index] = (
                for card in column.getElementsByClassName("kb-card")
                    do (card) ->
                        card_id = parseInt card.getAttribute "data-kb-id"
                        if card_id is NaN
                            return kanban.error "Invalid card id: " + card_id
                        kanban.board.cards[card_id].name = card.getElementsByClassName("title")[0].value
                        kanban.board.cards[card_id].desc = card.getElementsByClassName("content")[0].innerHTML
                        kanban.updateCard(kanban.board.cards[card_id], objectStore)
                        card_id
            )
    kanban.updateCard(board, objectStore)
    undefined

unless indexedDB
    kanban.error("Your browser doesn't support a stable version of IndexedDB.")

window.onload = () ->
    request = indexedDB.open("kanban", 20);
    dberror = (event) ->
        kanban.error("Database error: " + event.target.errorCode);
    request.onerror = kanban.error.bind(undefined, "Error opening database");
    request.onsuccess = (event) ->
        kanban.db = event.target.result
        kanban.db.onerror = dberror
        kanban.loadBoard(0, (root) ->
            unless (root)
                card = {
                    id: 0,
                    name: "Root Board",
                    desc: "Testing",
                    columns: ["TODO", "IN PROGRESS", "REVIEW"],
                    cards: [ [], [], [] ]
                }
                objectStore = kanban.beginTransaction("readwrite")
                objectStore.add(card)
                root = {
                    root: 0,
                    cards: [ card ]
                }
            kanban.drawBoard(root))
    request.onupgradeneeded = (event, recursed) ->
        db = event.target.result
        db.onerror = dberror
        try
            objectStore = db.createObjectStore("boards", {keyPath: "id", autoIncrement: true})
        catch error
            unless recursed
                db.deleteObjectStore("boards")
                request.onupgradeneeded(event, true)
            return
        objectStore.createIndex("name", "name", {unique: false})
