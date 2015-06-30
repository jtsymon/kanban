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

moveCard = (e) ->
    card = e.target.closest('kb-card')
    return if card is kanban.draggedElement
    if card is null
        rect = this.getBoundingClientRect()
        if e.clientY < rect.y + rect.height / 2
            card = this.getElementsByTagName("kb-card")[0]
            if card?
                this.insertBefore(kanban.draggedElement, card)
                return
            # fall through to append if the list is empty
        this.appendChild(kanban.draggedElement)
    else
        rect = card.getBoundingClientRect()
        if e.clientY < rect.y + rect.height / 2
            this.insertBefore(kanban.draggedElement, card)
        else
            card = card.nextElementSibling
            if card?
                this.insertBefore(kanban.draggedElement, card)
            else
                this.appendChild(kanban.draggedElement)

moveColumn = (e) ->
    return if this is kanban.draggedElement
    rect = this.getBoundingClientRect()
    if e.clientX < rect.x + rect.width / 2
        this.parentElement.insertBefore kanban.draggedElement, this
    else if this.nextElementSibling?
        this.parentElement.insertBefore kanban.draggedElement, this.nextElementSibling
    else
        this.parentElement.appendChild kanban.draggedElement

onDropColumn = (e) ->
    return unless kanban.draggedElement? and this.tagName is "KB-COLUMN"
    if kanban.draggedElement.tagName is "KB-CARD"
        moveCard.call this, e
    else if kanban.draggedElement.tagName is "KB-COLUMN"
        moveColumn.call this, e


toggleMinimise = (e) ->
    this.parentElement.getElementsByClassName("content")[0].classList.toggle("hidden")

addCard = (e) ->
    column = this.parentElement
    index = Array.prototype.indexOf.call(document.body.getElementsByTagName("kb-column"), column)
    objectStore = kanban.beginTransaction("readwrite")
    card = {
        name: "New card",
        desc: "",
        columns: ["TODO", "IN PROGRESS", "REVIEW"],
        cards: [ [], [], [] ],
        parent: kanban.board.root
    }
    # Add it to the database now to avoid problems
    request = objectStore.add(card)
    request.onsuccess = () ->
        card.id = request.result
        kanban.board.cards[card.id] = card
        kanban.board.cards[kanban.board.root].cards[index].push(card.id)
        column.appendChild makeCard card

addColumn = (e) ->
    kanban.DOM.wrapper.appendChild makeColumn "New Column"

deleteColumn = (e) ->
    column = this.parentElement
    children = column.getElementsByTagName("kb-card").length
    if children is 0 or confirm("Column has " + children + " card(s)\nDelete anyway?")
        column.parentElement.removeChild column

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

makeTitle = (attr) ->
    title = document.createElement "input"
    title.setAttribute "type", "text"
    title.className = "editable-text"

    if attr?
        title.value = attr.value if attr.value?

        setAttr title, attr

    wrap = document.createElement "span"
    wrap.className = "title-wrap"
    wrap.appendChild title

    wrap

makeContent = (attr) ->
    content = document.createElement("p")
    content.className = "content"
    content.setAttribute("contenteditable", true)

    if attr?
        content.innerHTML = attr.value if attr.value?

        setAttr content, attr

    content

makeButton = (icon_name, handler, attr) ->
    button = document.createElement "kb-button"
    button.addEventListener("click", handler, false) if handler?

    setAttr button, attr if attr?

    icon = document.createElement "i"
    icon.className = "fa fa-" + icon_name

    button.appendChild icon

    button

makeCard = (card) ->
    wrap = document.createElement("kb-card")
    wrap.setAttribute("data-kb-id", card.id)

    wrap.addEventListener("dragstart", onDragStart, false)
    wrap.addEventListener("dragover", onDragOver, false)
    wrap.addEventListener("dragenter", onDragOver, false)
    wrap.addEventListener("dragend", onDragEnd, false)

    drag = makeButton "arrows"
    drag.addEventListener("mousedown", onDragHandleMouseDown, false)
    wrap.appendChild drag

    wrap.appendChild makeButton "ellipsis-h", toggleMinimise

    wrap.appendChild makeButton "eye", viewChild

    wrap.appendChild makeButton "remove", deleteCard

    wrap.appendChild makeTitle {value: card.name, classes: "title"}

    wrap.appendChild makeContent { value: card.desc, classes: "hidden" if card.minimised }

    wrap

makeColumn = (name, cards) ->
    column = document.createElement("kb-column")

    drag = makeButton "arrows"
    drag.addEventListener("mousedown", onDragHandleMouseDown, false)
    column.appendChild drag
    column.appendChild makeButton "plus", addCard
    column.appendChild makeButton "remove", deleteColumn

    column.appendChild makeTitle {value: name, classes: "kb-column-title"}

    column.addEventListener("dragstart", onDragStart, false)
    column.addEventListener("dragover", onDragOver, false)
    column.addEventListener("dragenter", onDragOver, false)
    column.addEventListener("dragend", onDragEnd, false)
    column.addEventListener("drop", onDropColumn, false)

    column.appendChild makeCard kanban.board.cards[card] for card in cards if cards?

    column


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

initBoard = () ->
    document.body.innerHTML = "";
    board_header = document.createElement "header"
    
    kanban.DOM = {
        buttons: {
            save_board: makeButton "save", kanban.saveBoard, {id: "kb-board-save"}
            add_column: makeButton "plus", addColumn, {id: "kb-column-add"}
            view_parent: makeButton "arrow-up", viewParent, {id: "kb-board-parent"}
        }
        title: makeTitle({id: "kb-board-title"}).firstElementChild
        desc: makeContent {id: "kb-board-desc"}
        wrapper: document.createElement "section"
    }
    board_header.appendChild button for name, button of kanban.DOM.buttons
    board_header.appendChild kanban.DOM.title.parentElement
    board_header.appendChild kanban.DOM.desc

    document.body.appendChild board_header

    kanban.DOM.wrapper.id = "kb-column-wrap"

    document.body.appendChild kanban.DOM.wrapper

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
