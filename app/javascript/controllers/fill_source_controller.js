import { Controller } from "@hotwired/stimulus"

// The venue tree is the source. Shift extends a range. Option toggles a person onto the selection.
export default class extends Controller {
  static targets = [ "group", "addButton", "removeButton", "memberList" ]
  static values = { addUrl: String, removeUrl: String, processId: String }

  connect() {
    this.restore()
    this.refresh()
    this.reapply = () => this.afterRefresh()
    document.addEventListener("turbo:morph", this.reapply)
    document.addEventListener("turbo:render", this.reapply)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.reapply)
    document.removeEventListener("turbo:render", this.reapply)
  }

  afterRefresh() {
    requestAnimationFrame(() => {
      if (!this.element.isConnected) return

      this.restore()
      this.refresh()
    })
  }

  toggle(event) {
    const node = event.currentTarget.closest(".tree-node")
    const list = node?.querySelector(":scope > ul")
    if (!list) return

    const open = list.hidden
    list.hidden = !open
    event.currentTarget.textContent = open ? "−" : "+"
    event.currentTarget.setAttribute("aria-expanded", open ? "true" : "false")
    const name = event.currentTarget.dataset.label || "list"
    event.currentTarget.setAttribute("aria-label", `${open ? "Collapse" : "Expand"} ${name}`)
    this.remember()
  }

  chooseGroup(event) {
    const group = this.groupTargets.find((item) => item.dataset.group === String(event.params.group))
    if (!group) return

    this.clearMembers()
    this.clear()
    const people = [ ...group.children ]
    people.forEach((row) => this.select(row))
    this.anchor = people[0] || null
    this.syncGroups()
    this.refresh()
  }

  choose(event) {
    if (event.target.closest("button, a, input, form")) return

    const row = event.currentTarget
    const people = this.people()
    this.clearMembers()

    if (event.shiftKey && this.anchor && people.includes(this.anchor)) {
      event.preventDefault()
      const start = people.indexOf(this.anchor)
      const end = people.indexOf(row)
      this.clear()
      const [ from, to ] = [ start, end ].sort((left, right) => left - right)
      people.slice(from, to + 1).forEach((item) => this.select(item))
    } else if (event.altKey) {
      row.classList.toggle("is-selected")
      row.setAttribute("aria-selected", row.classList.contains("is-selected") ? "true" : "false")
      this.anchor = row
    } else {
      this.clear()
      this.select(row)
      this.anchor = row
    }
    this.syncGroups()
    this.refresh()
  }

  chooseMember(event) {
    if (event.target.closest("button, a, input, form")) return

    const row = event.currentTarget
    const rows = [ ...this.memberListTarget.children ]

    if (event.shiftKey && this.memberAnchor && rows.includes(this.memberAnchor)) {
      event.preventDefault()
      const start = rows.indexOf(this.memberAnchor)
      const end = rows.indexOf(row)
      this.clear()
      this.clearMembers()
      const [ from, to ] = [ start, end ].sort((left, right) => left - right)
      rows.slice(from, to + 1).forEach((item) => this.select(item))
    } else if (event.altKey) {
      this.clear()
      row.classList.toggle("is-selected")
      row.setAttribute("aria-selected", row.classList.contains("is-selected") ? "true" : "false")
      this.memberAnchor = row
    } else {
      this.clear()
      this.clearMembers()
      this.select(row)
      this.memberAnchor = row
    }
    this.syncGroups()
    this.refresh()
  }

  async add() {
    const seen = new Set()
    const ids = []
    this.people().forEach((row) => {
      if (!row.classList.contains("is-selected")) return
      const id = row.dataset.employeeId
      if (seen.has(id)) return

      seen.add(id)
      ids.push(id)
    })
    if (!ids.length) return

    const body = new URLSearchParams()
    ids.forEach((id) => body.append("employee_ids[]", id))
    await fetch(this.addUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        Accept: "text/html"
      },
      body,
      redirect: "manual"
    })
    window.Turbo.visit(window.location.href)
  }

  async remove() {
    const selected = [ ...this.memberListTarget.querySelectorAll(":scope > li.is-selected") ]
    const pending = selected.filter((row) => row.dataset.pending === "true")
    const staying = selected.filter((row) => row.dataset.pending !== "true").map((row) => row.dataset.name)
    if (staying.length) {
      const verb = staying.length === 1 ? "has" : "have"
      window.alert(`${staying.join(", ")} ${verb} already been asked and will stay on the list.`)
    }
    if (!pending.length) return

    const body = new URLSearchParams()
    pending.forEach((row) => body.append("ids[]", row.dataset.sortableId))
    await fetch(this.removeUrlValue, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        Accept: "text/html"
      },
      body,
      redirect: "manual"
    })
    window.Turbo.visit(window.location.href)
  }

  refresh() {
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = this.people().every((row) => !row.classList.contains("is-selected"))
    }
    if (this.hasRemoveButtonTarget) {
      const selected = this.hasMemberListTarget && this.memberListTarget.querySelector(":scope > li.is-selected")
      this.removeButtonTarget.disabled = !selected
    }
    this.remember()
  }

  restore() {
    const saved = this.read()
    if (!saved) return

    this.groupTargets.forEach((group) => {
      const state = saved.groups?.[group.dataset.group]
      if (!state) return

      group.hidden = state.hidden
      const twist = group.parentElement?.querySelector(".tree-twist")
      if (twist) {
        const name = twist.dataset.label || "list"
        twist.textContent = state.hidden ? "+" : "−"
        twist.setAttribute("aria-expanded", state.hidden ? "false" : "true")
        twist.setAttribute("aria-label", `${state.hidden ? "Expand" : "Collapse"} ${name}`)
      }
      ;[ ...group.children ].forEach((row) => {
        const on = (state.selected || []).includes(row.dataset.employeeId)
        row.classList.toggle("is-selected", on)
        row.setAttribute("aria-selected", on ? "true" : "false")
      })
    })
    if (this.hasMemberListTarget && saved.members) {
      ;[ ...this.memberListTarget.children ].forEach((row) => {
        const on = saved.members.includes(row.dataset.sortableId)
        row.classList.toggle("is-selected", on)
        row.setAttribute("aria-selected", on ? "true" : "false")
      })
    }
    this.syncGroups()
  }

  remember() {
    if (!this.hasProcessIdValue) return

    const groups = {}
    this.groupTargets.forEach((group) => {
      groups[group.dataset.group] = {
        hidden: group.hidden,
        selected: [ ...group.children ].filter((row) => row.classList.contains("is-selected")).map((row) => row.dataset.employeeId)
      }
    })
    const members = this.hasMemberListTarget
      ? [ ...this.memberListTarget.children ].filter((row) => row.classList.contains("is-selected")).map((row) => row.dataset.sortableId)
      : []
    sessionStorage.setItem(this.storageKey(), JSON.stringify({ groups, members }))
  }

  read() {
    try {
      return JSON.parse(sessionStorage.getItem(this.storageKey()) || "null")
    } catch {
      return null
    }
  }

  storageKey() {
    return `fill-source:${this.processIdValue}`
  }

  people() {
    return this.groupTargets.flatMap((group) => [ ...group.children ])
  }

  syncGroups() {
    this.groupTargets.forEach((group) => {
      const people = [ ...group.children ]
      const on = people.length > 0 && people.every((row) => row.classList.contains("is-selected"))
      group.parentElement?.querySelector(".fill-branch-name")?.classList.toggle("is-selected", on)
    })
  }

  select(row) {
    row.classList.add("is-selected")
    row.setAttribute("aria-selected", "true")
  }

  clearMembers() {
    if (!this.hasMemberListTarget) return

    this.memberListTarget.querySelectorAll(":scope > li.is-selected").forEach((row) => {
      row.classList.remove("is-selected")
      row.setAttribute("aria-selected", "false")
    })
  }

  clear() {
    this.people().forEach((row) => {
      row.classList.remove("is-selected")
      row.setAttribute("aria-selected", "false")
    })
    this.element.querySelectorAll(".fill-branch-name.is-selected").forEach((button) => {
      button.classList.remove("is-selected")
    })
  }
}
