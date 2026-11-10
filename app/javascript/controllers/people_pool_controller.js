import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "query", "skill", "level", "person", "template", "list", "note" ]
  static values = { lockDrag: Boolean }
  static outlets = [ "sortable" ]

  connect() {
    this.mode = "venue"
  }

  filter() {
    const query = this.queryTarget.value.trim().toLowerCase()
    const skillId = this.hasSkillTarget ? this.skillTarget.value : ""
    const minimum = Number(this.hasLevelTarget ? this.levelTarget.value : 1) || 1

    this.personTargets.forEach((person) => {
      const levels = this.levels(person)
      const skillOk = skillId === "" || (levels[skillId] || 0) >= minimum
      person.hidden = !(this.name(person).includes(query) && skillOk)
    })

    this.templateTargets.forEach((item) => {
      item.hidden = query.length > 0 && !this.name(item).includes(query)
    })

    this.refreshDrag()
  }

  sort(event) {
    this.mode = event.params.by
    this.element.querySelectorAll("[data-people-pool-by-param]").forEach((button) => {
      button.classList.toggle("is-active", button === event.currentTarget)
    })
    const skillId = this.hasSkillTarget ? this.skillTarget.value : ""
    const people = this.personTargets.slice().sort((left, right) => {
      if (this.mode === "name") return this.name(left).localeCompare(this.name(right))
      if (this.mode === "level") {
        return this.rank(right, skillId) - this.rank(left, skillId) || this.name(left).localeCompare(this.name(right))
      }
      return Number(left.dataset.venueOrder) - Number(right.dataset.venueOrder)
    })
    people.forEach((person) => this.listTarget.appendChild(person))
    this.refreshDrag()
  }

  refreshDrag() {
    const locked = this.lockDragValue && (this.mode !== "venue" || this.filtering())
    if (this.hasNoteTarget) this.noteTarget.hidden = !locked
    if (this.lockDragValue && this.hasSortableOutlet) this.sortableOutlet.setEnabled(!locked)
  }

  filtering() {
    const query = this.hasQueryTarget && this.queryTarget.value.trim() !== ""
    const skill = this.hasSkillTarget && this.skillTarget.value !== ""
    const level = this.hasLevelTarget && Number(this.levelTarget.value) > 1
    return query || skill || level
  }

  levels(person) {
    if (!person.dataset.levels) return {}

    return JSON.parse(person.dataset.levels)
  }

  rank(person, skillId) {
    const levels = this.levels(person)
    if (skillId) return levels[skillId] || 0

    const values = Object.values(levels)
    return values.length ? Math.max(...values) : 0
  }

  name(person) {
    return (person.dataset.name || "").toLowerCase()
  }
}
