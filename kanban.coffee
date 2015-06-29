indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB
IDBTransaction = window.IDBTransaction || window.webkitIDBTransaction || window.msIDBTransaction
IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange

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

onDragHandleMouseDown = (e) ->
    kanban.draggedElement = this.parentElement
    this.parentElement.draggable = true

onDragOver = (e) ->
    e.preventDefault() unless kanban.draggedElement is this

onDragStart = (e) ->
    setTimeout((() -> kanban.draggedElement.classList.add "dragging"), 0) if kanban.draggedElement?
    e.dataTransfer.setData('Text', this.id)

onDragEnd = (e) ->
    if this is kanban.draggedElement
        kanban.draggedElement.classList.remove "dragging"
        kanban.draggedElement = null
        this.draggable = false

onDropColumn = (e) ->
    return unless kanban.draggedElement? and this.tagName is "KB-COLUMN"
    card = e.target.closest('kb-card')
    return if card is kanban.draggedElement
    rect = if card is null
        this.getBoundingClientRect()
    else
        card.getBoundingClientRect()
    kanban.draggedElement.parentElement.removeChild(kanban.draggedElement)
    if card is null
        if e.clientY < rect.y + rect.height / 2
            card = this.getElementsByTagName("kb-card")[0]
            if card?
                this.insertBefore(kanban.draggedElement, card)
                return
            # fall through to append if the list is empty
        this.appendChild(kanban.draggedElement)
    else
        if e.clientY < rect.y + rect.height / 2
            this.insertBefore(kanban.draggedElement, card)
        else
            card = card.nextElementSibling
            if card?
                this.insertBefore(kanban.draggedElement, card)
            else
                this.appendChild(kanban.draggedElement)

toggleMinimise = (e) ->
    this.parentElement.getElementsByClassName("content")[0].classList.toggle("hidden")

addCard = (e) ->
    column = this.parentElement
    index = column.getAttribute "data-column-id"
    objectStore = kanban.beginTransaction("readwrite")
    card = {
        name: "New card",
        desc: "",
        columns: ["TODO", "IN PROGRESS", "REVIEW"],
        cards: [ [], [], [] ],
        parent: kanban.board.root
    }
    request = objectStore.add(card)
    request.onsuccess = () ->
        card.id = request.result
        kanban.board.cards[card.id] = card
        kanban.board.cards[kanban.board.root].cards[index].push(card.id)
        column.appendChild makeCard card

viewChild = (e) ->
    kanban.drawBoard parseInt this.parentElement.getAttribute "data-kb-id"

viewParent = (e) ->
    kanban.drawBoard kanban.board.cards[kanban.board.root].parent

deleteCard = (e) ->
    index = parseInt this.parentElement.getAttribute "data-kb-id"
    this.parentElement.parentElement.removeChild this.parentElement

setAttr = (elem, attr) ->
    return unless attr?
    if attr.id?
        elem.id = attr.id
    if attr.classes?
        elem.className += " " + attr.classes
    if attr.data?
        for key, value of attr.data
            do (key, value) ->
                elem.setAttribute "data-" + key, value

makeTitle = (value, attr) ->
    title = document.createElement "input"
    title.setAttribute "type", "text"
    title.className = "editable-text"
    title.value = value

    setAttr title, attr if attr?

    wrap = document.createElement "span"
    wrap.className = "title-wrap"
    wrap.appendChild title

    wrap

makeContent = (value, attr) ->
    content = document.createElement("p")
    content.className = "content"
    content.setAttribute("contenteditable", true)
    content.innerHTML = value

    setAttr content, attr if attr?

    content

makeButton = (name, handler, attr) ->
    button = document.createElement "kb-button"
    button.className = name
    button.addEventListener("click", handler, false) if handler?

    setAttr button, attr if attr?

    button

makeCard = (card) ->
    wrap = document.createElement("kb-card")
    wrap.setAttribute("data-kb-id", card.id)

    wrap.addEventListener("dragstart", onDragStart, false)
    wrap.addEventListener("dragover", onDragOver, false)
    wrap.addEventListener("dragenter", onDragOver, false)
    wrap.addEventListener("dragend", onDragEnd, false)

    drag = makeButton "drag"
    drag.addEventListener("mousedown", onDragHandleMouseDown, false)
    wrap.appendChild drag

    wrap.appendChild makeButton "minimise", toggleMinimise

    wrap.appendChild makeButton "viewboard", viewChild

    wrap.appendChild makeButton "delete", deleteCard

    wrap.appendChild makeTitle card.name, {"classes": "title"}

    wrap.appendChild makeContent card.desc, ( { classes: "hidden" } if card.minimised )

    wrap

kanban.drawBoard = (board, objectStore, recursed) ->
    if (Object.prototype.toString.call(board) is "[object Object]")
        document.body.innerHTML = "";
        main = board.cards[board.root]
        board_header = document.createElement("header")

        (board_header.appendChild makeButton "viewparent", viewParent) unless main.id is 0
        board_header.appendChild makeButton "saveboard", kanban.saveBoard

        board_header.appendChild makeTitle main.name, {id: "kb-board-title", data: {"kb-id": main.id}}
        board_header.appendChild makeContent main.desc, {id: "kb-board-desc"}

        document.body.appendChild(board_header)
        for name, index in main.columns
            do (name, index) ->
                column = document.createElement("kb-column")
                column.setAttribute "data-column-id", index

                column.appendChild makeButton "add", addCard

                column.appendChild makeTitle name, {classes: "kb-column-title"}

                column.addEventListener("dragover", onDragOver, false)
                column.addEventListener("dragenter", onDragOver, false)
                column.addEventListener("dragend", onDragEnd, false)
                column.addEventListener("drop", onDropColumn, false)

                column.appendChild makeCard board.cards[card] for card in main.cards[index]
                document.body.appendChild(column)
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
    root = kanban.board.cards[board_title.getAttribute("data-kb-id")]
    root.name = board_title.value
    root.desc = document.getElementById("kb-board-desc").innerHTML;
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
        console.log card
        objectStore.delete card
    updateCard(root, objectStore)
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
