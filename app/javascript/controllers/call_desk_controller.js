import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "row", "box", "selectAll", "panel", "slotFields", "createSummary", "addSlots", "processCard", "processDetail", "clearSelection" ]
  static values = { callId: String }

  connect() {
    this.selected = this.restored()
    this.paint()
    this.reapply = () => this.afterRefresh()
    document.addEventListener("turbo:morph", this.reapply)
    document.addEventListener("turbo:render", this.reapply)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.reapply)
    document.removeEventListener("turbo:render", this.reapply)
  }

  // A live remorph writes the server HTML, which has no selection. Put it back.
  afterRefresh() {
    requestAnimationFrame(() => {
      if (!this.element.isConnected) return

      this.selected = this.restored()
      this.paint()
    })
  }

  choose(event) {
    if (event.target.closest("button, a, input, select, textarea, form, .drag-handle")) return

    this.toggleId(event.currentTarget.dataset.slotId)
  }

  cancelAssignment(event) {
    event.preventDefault()
    event.stopPropagation()
    const message = event.currentTarget.dataset.message
    if (message && !window.confirm(message)) return

    event.currentTarget.closest("form").requestSubmit()
  }

  toggleBox(event) {
    event.stopPropagation()
    this.toggleId(event.currentTarget.closest("[data-call-desk-target='row']").dataset.slotId)
  }

  toggleAll(event) {
    const on = event.target.checked
    this.selected = {
      kind: on ? this.kindFrom(this.rowTargets.map((row) => row.dataset.slotId)) : null,
      ids: on ? this.rowTargets.map((row) => row.dataset.slotId) : []
    }
    this.paint()
  }

  pick(event) {
    const row = this.rowTargets.find((item) => item.dataset.kind === event.params.kind)
    if (!row) return

    const group = (row.dataset.group || "").split(",").filter(Boolean)
    const ids = group.length ? group : [ row.dataset.slotId ]
    const on = this.selected.kind === row.dataset.kind && ids.every((id) => this.selected.ids.includes(id))
    this.selected = on ? { kind: null, ids: [] } : { kind: row.dataset.kind, ids }
    this.paint()
  }

  clear() {
    this.selected = { kind: null, ids: [] }
    this.paint()
  }

  saveLabel(event) {
    event.target.form.requestSubmit()
  }

  paint() {
    this.rowTargets.forEach((row) => {
      const on = this.selected.ids.includes(row.dataset.slotId)
      row.classList.toggle("is-selected", on)
      row.setAttribute("aria-selected", on ? "true" : "false")
      const box = row.querySelector("[data-call-desk-target='box']")
      if (box) box.checked = on
    })

    if (this.hasSelectAllTarget) {
      const total = this.rowTargets.length
      const count = this.selected.ids.length
      this.selectAllTarget.checked = total > 0 && count === total
      this.selectAllTarget.indeterminate = count > 0 && count < total
    }

    this.panelTargets.forEach((panel) => {
      panel.hidden = !this.panelVisible(panel)
    })

    if (this.hasAddSlotsTarget) {
      this.addSlotsTargets.forEach((form) => {
        form.hidden = this.openIds().length === 0
      })
    }

    this.processDetailTargets.forEach((detail) => {
      detail.hidden = this.selected.kind !== `fill:${detail.dataset.processId}`
    })
    this.processCardTargets.forEach((card) => {
      card.classList.toggle("is-open", this.selected.kind === `fill:${card.dataset.processId}`)
    })
    if (this.hasClearSelectionTarget) this.clearSelectionTarget.disabled = !this.selected.kind && this.selected.ids.length === 0

    if (this.hasSlotFieldsTarget) {
      const ids = this.openIds()
      this.slotFieldsTargets.forEach((fields) => {
        fields.replaceChildren()
        ids.forEach((id) => {
          const input = document.createElement("input")
          input.type = "hidden"
          input.name = "call_slot_ids[]"
          input.value = id
          fields.appendChild(input)
        })
      })
      if (this.hasCreateSummaryTarget) {
        const names = ids.map((id) => this.rowTargets.find((row) => row.dataset.slotId === id)?.dataset.label).filter(Boolean)
        this.createSummaryTarget.textContent = names.join(", ")
      }
    }
    this.remember()
  }

  toggleId(slotId) {
    const ids = this.selected.ids.includes(slotId)
      ? this.selected.ids.filter((id) => id !== slotId)
      : this.selected.ids.concat(slotId)
    this.selected = { kind: this.kindFrom(ids), ids }
    this.paint()
  }

  kindFrom(ids) {
    if (!ids.length) return null

    const kinds = ids.map((id) => this.rowTargets.find((row) => row.dataset.slotId === id)?.dataset.kind).filter(Boolean)
    if (kinds.every((kind) => kind === "open")) return "open"
    if (kinds.length === 1 && kinds[0].startsWith("fill:")) return kinds[0]
    if (kinds.length === 1 && kinds[0].startsWith("assigned:")) return kinds[0]
    if (kinds.every((kind) => kind.startsWith("fill:") && kind === kinds[0])) return kinds[0]
    return "mixed"
  }

  openIds() {
    return this.selected.ids.filter((id) => {
      const row = this.rowTargets.find((item) => item.dataset.slotId === id)
      return row?.dataset.kind === "open"
    })
  }

  restored() {
    const saved = this.read()
    if (!saved?.ids?.length && !saved?.kind) return { kind: null, ids: [] }

    if (saved.kind?.startsWith("fill:")) {
      const row = this.rowTargets.find((item) => item.dataset.kind === saved.kind)
      if (!row) return { kind: null, ids: [] }

      const group = (row.dataset.group || "").split(",").filter(Boolean)
      return { kind: saved.kind, ids: group.length ? group : [ row.dataset.slotId ] }
    }

    const ids = (saved.ids || []).map(String).filter((id) => this.rowTargets.some((row) => row.dataset.slotId === id))
    return { kind: this.kindFrom(ids), ids }
  }

  remember() {
    if (!this.selected.kind && !this.selected.ids.length) {
      sessionStorage.removeItem(this.storageKey())
      return
    }
    sessionStorage.setItem(this.storageKey(), JSON.stringify(this.selected))
  }

  read() {
    try {
      return JSON.parse(sessionStorage.getItem(this.storageKey()) || "null")
    } catch {
      return null
    }
  }

  storageKey() {
    return `call-desk:${this.callIdValue}`
  }

  panelVisible(panel) {
    const name = panel.dataset.panel
    if (!this.selected.kind || this.selected.kind === "mixed") {
      if (name === "summary") return true
      if (name === "create") return this.openIds().length > 0
      return false
    }
    if (this.selected.kind === "open") return name === "summary" || name === "create"
    if (this.selected.kind.startsWith("fill:")) return name === "summary"
    if (this.selected.kind.startsWith("assigned:")) return name === "assignment" && panel.dataset.slotId === this.selected.ids[0]

    return false
  }
}
