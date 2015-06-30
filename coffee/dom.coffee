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
