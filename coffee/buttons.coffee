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

