indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB
IDBTransaction = window.IDBTransaction || window.webkitIDBTransaction || window.msIDBTransaction
IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange

@import dom
@import drag
@import buttons

kanban = {
    db: null,
    board: null,
    draggedElement: null
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

updateCard = (card, objectStore, callback) ->
    throw "Usage: updateCard(card, [objectStore])" unless card?
    throw "Board must have a name" unless card.name?
    objectStore ?= kanban.beginTransaction("readwrite")
    request = objectStore.put(card)
    request.onsuccess = callback

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

kanban.drawBoard = (board, objectStore, recursed) ->
    if (Object.prototype.toString.call(board) is "[object Object]")
        main = board.cards[board.root]
        kanban.DOM.title.value = main.name
        kanban.DOM.title.setAttribute "data-kb-id", main.id
        kanban.DOM.desc.innerHTML = main.desc
        kanban.DOM.buttons.view_parent.classList.toggle("hidden", main.id is 0)
        kanban.DOM.wrapper.innerHTML = ""
        
        kanban.board = board
        for name, index in main.columns
            do (name, index) ->
                kanban.DOM.wrapper.appendChild makeColumn name, main.cards[index]
        undefined
    else unless recursed
        board ?= 0
        objectStore ?= kanban.beginTransaction()
        kanban.loadBoard(board, (brd) ->
            kanban.drawBoard(brd, objectStore, true))
    else
        throw "Failed to load the board"

kanban.saveBoard = () ->
    root = kanban.board.cards[kanban.board.root]
    root.name = kanban.DOM.title.value
    root.desc = document.getElementById("kb-board-desc").innerHTML;
    root.columns = []
    delete_cards = new Set
    delete_cards.add card for card in column for column in root.cards
    objectStore = kanban.beginTransaction("readwrite")
    # update columns
    for column, index in document.body.getElementsByTagName("kb-column")
        do (column, index) ->
            root.columns[index] = column.getElementsByClassName("kb-column-title")[0].value
            root.cards[index] = (
                for card in column.getElementsByTagName("kb-card")
                    do (card) ->
                        # update cards
                        card_id = parseInt card.getAttribute "data-kb-id"
                        if card_id is NaN
                            return kanban.error "Invalid card id: " + card_id
                        delete_cards.delete card_id
                        content = card.getElementsByClassName("content")[0]
                        kanban.board.cards[card_id].name = card.getElementsByClassName("title")[0].value
                        kanban.board.cards[card_id].minimised = content.classList.contains("hidden")
                        kanban.board.cards[card_id].desc = content.innerHTML
                        updateCard(kanban.board.cards[card_id], objectStore)
                        card_id
            )
    delete_cards.forEach (card) ->
        objectStore.delete card
    updateCard(root, objectStore)
    undefined

unless indexedDB
    kanban.error("Your browser doesn't support a stable version of IndexedDB.")

window.onload = () ->
    initBoard()
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
