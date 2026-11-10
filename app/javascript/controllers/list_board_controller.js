import { Controller } from "@hotwired/stimulus"

// Shift-click selects a range in one pane. A drag of several selected names moves them as a block.
export default class extends Controller {
  static targets = [ "availableList", "memberList", "addButton", "removeButton" ]
  static values = { addUrl: String, removeUrl: String }
  static outlets = [ "sortable" ]

  connect() {
    this.refresh()
  }

  choose(event) {
    if (event.target.closest("button, a, input, form")) return

    const row = event.currentTarget
    const pane = row.parentElement
    const rows = [ ...pane.children ].filter((item) => !item.hidden)

    if (event.shiftKey && this.anchor && this.anchor.parentElement === pane && !this.anchor.hidden) {
      event.preventDefault()
      const start = rows.indexOf(this.anchor)
      const end = rows.indexOf(row)
      if (start < 0 || end < 0) return

      this.clear(pane)
      const [ from, to ] = [ start, end ].sort((left, right) => left - right)
      rows.slice(from, to + 1).forEach((item) => this.select(item))
    } else {
      this.clear(this.availableListTarget)
      this.clear(this.memberListTarget)
      this.select(row)
      this.anchor = row
    }
    this.refresh()
  }

  refresh() {
    this.addButtonTarget.disabled = this.selected(this.availableListTarget).length === 0
    this.removeButtonTarget.disabled = this.selected(this.memberListTarget).length === 0
  }

  async add() {
    const ids = this.selected(this.availableListTarget).map((row) => row.dataset.employeeId)
    if (!ids.length) return

    const body = new URLSearchParams()
    ids.forEach((id) => body.append("employee_ids[]", id))
    await this.submit(this.addUrlValue, body)
    window.Turbo.visit(window.location.href)
  }

  async remove() {
    const ids = this.selected(this.memberListTarget).map((row) => row.dataset.sortableId)
    if (!ids.length) return

    const body = new URLSearchParams()
    ids.forEach((id) => body.append("ids[]", id))
    await this.submit(this.removeUrlValue, body, "DELETE")
    window.Turbo.visit(window.location.href)
  }

  gather(event) {
    const startIds = (event.detail.startIds || []).map(String)
    const selected = this.selected(this.memberListTarget).map((row) => row.dataset.sortableId)
    const dragged = startIds[event.detail.oldIndex]
    if (!dragged || !selected.includes(dragged) || selected.length < 2) return

    event.preventDefault()
    const order = this.blockOrder(startIds, selected, event.detail.oldIndex, event.detail.newIndex)
    const rows = new Map([ ...this.memberListTarget.children ].map((row) => [ row.dataset.sortableId, row ]))
    order.forEach((id) => {
      const row = rows.get(id)
      if (row) this.memberListTarget.appendChild(row)
    })
    if (this.hasSortableOutlet) this.sortableOutlet.persist()
  }

  // The dragged name lands where it was dropped, and the rest of the selection stays in its old order around it.
  blockOrder(startIds, selected, oldIndex, newIndex) {
    const ids = startIds.map(String)
    const block = ids.filter((id) => selected.includes(id))
    const dragged = ids[oldIndex]
    const moved = ids.slice()
    moved.splice(oldIndex, 1)
    moved.splice(newIndex, 0, dragged)
    const stripped = moved.filter((id) => id === dragged || !block.includes(id))
    stripped.splice(stripped.indexOf(dragged), 1, ...block)
    return stripped
  }

  selected(pane) {
    return [ ...pane.querySelectorAll(":scope > li.is-selected") ].filter((row) => !row.hidden)
  }

  select(row) {
    row.classList.add("is-selected")
    row.setAttribute("aria-selected", "true")
  }

  clear(pane) {
    pane.querySelectorAll(":scope > li.is-selected").forEach((row) => {
      row.classList.remove("is-selected")
      row.removeAttribute("aria-selected")
    })
  }

  submit(url, body, method = "POST") {
    return fetch(url, {
      method,
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        Accept: "text/html"
      },
      body,
      redirect: "manual"
    })
  }
}
