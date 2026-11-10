import { Controller } from "@hotwired/stimulus"

// Text matches a name or a note. Every skill chip has to match too.
export default class extends Controller {
  static targets = [ "query", "chips", "menu", "category", "skill", "person", "list", "sortButton" ]

  connect() {
    this.filters = []
    this.column = "venue"
    this.direction = "asc"
    this.closeOnOutside = (event) => {
      if (!this.element.contains(event.target)) this.menuTarget.hidden = true
    }
    window.addEventListener("click", this.closeOnOutside)
  }

  disconnect() {
    window.removeEventListener("click", this.closeOnOutside)
  }

  toggleMenu() {
    this.menuTarget.hidden = !this.menuTarget.hidden
  }

  openCategory(event) {
    const id = String(event.params.category)
    this.categoryTargets.forEach((panel) => {
      panel.hidden = panel.dataset.category !== id
    })
    this.skillTargets.forEach((panel) => { panel.hidden = true })
  }

  openSkill(event) {
    const id = String(event.params.skill)
    this.skillTargets.forEach((panel) => {
      panel.hidden = panel.dataset.skill !== id
    })
  }

  addSkill(event) {
    const id = String(event.params.skillId)
    this.filters = this.filters.filter((filter) => filter.id !== id)
    this.filters.push({ id, level: Number(event.params.level), label: event.params.label })
    this.menuTarget.hidden = true
    this.renderChips()
    this.filter()
  }

  removeSkill(id) {
    this.filters = this.filters.filter((filter) => filter.id !== String(id))
    this.renderChips()
    this.filter()
  }

  clear() {
    this.queryTarget.value = ""
    this.filters = []
    this.renderChips()
    this.filter()
  }

  filter() {
    const query = this.queryTarget.value.trim().toLowerCase()
    this.personTargets.forEach((person) => {
      const haystack = `${person.dataset.name || ""} ${person.dataset.notes || ""}`.toLowerCase()
      const textOk = query === "" || haystack.includes(query)
      const levels = JSON.parse(person.dataset.levels || "{}")
      const skillsOk = this.filters.every((filter) => (Number(levels[filter.id]) || 0) >= filter.level)
      const hide = !(textOk && skillsOk)
      person.hidden = hide
      if (hide) {
        person.classList.remove("is-selected")
        person.removeAttribute("aria-selected")
      }
    })
    this.dispatch("filtered")
  }

  sort(event) {
    const column = event.params.column
    this.direction = this.column === column && this.direction === "asc" ? "desc" : "asc"
    this.column = column
    this.sortButtonTargets.forEach((button) => {
      const on = button.dataset.listSearchColumnParam === column
      button.classList.toggle("is-asc", on && this.direction === "asc")
      button.classList.toggle("is-desc", on && this.direction === "desc")
      button.setAttribute("aria-sort", on ? (this.direction === "asc" ? "ascending" : "descending") : "none")
    })

    const factor = this.direction === "asc" ? 1 : -1
    const people = this.personTargets.slice().sort((left, right) => factor * this.compare(left, right))
    people.forEach((person) => this.listTarget.appendChild(person))
  }

  compare(left, right) {
    if (this.column === "name") return (left.dataset.name || "").localeCompare(right.dataset.name || "")
    if (this.column === "skills") {
      const level = Number(left.dataset.skillLevel) - Number(right.dataset.skillLevel)
      if (level) return level
      return (left.dataset.skills || "").localeCompare(right.dataset.skills || "")
    }
    return Number(left.dataset.venueOrder) - Number(right.dataset.venueOrder)
  }

  renderChips() {
    this.chipsTarget.replaceChildren()
    this.filters.forEach((filter) => {
      const chip = document.createElement("span")
      chip.className = "list-chip"
      const label = document.createElement("span")
      label.textContent = `${filter.label} ≥ ${filter.level}`
      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "list-chip-x"
      remove.setAttribute("aria-label", `Remove ${filter.label}`)
      remove.textContent = "×"
      remove.addEventListener("click", () => this.removeSkill(filter.id))
      chip.append(label, remove)
      this.chipsTarget.append(chip)
    })
  }
}
