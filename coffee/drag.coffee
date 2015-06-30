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
