import { Controller } from "@hotwired/stimulus"

// The menu is fixed so the slot table's overflow does not clip it.
export default class extends Controller {
  static targets = [ "button", "menu", "query", "option", "empty", "id", "label", "browse", "results", "flyout" ]
  static values = { current: String, warning: String }

  connect() {
    this.outside = (event) => {
      if (!this.element.contains(event.target) && !this.menuTarget.contains(event.target)) this.close()
    }
    this.onKey = (event) => {
      if (event.key === "Escape") this.close()
    }
  }

  disconnect() {
    this.close()
  }

  toggle(event) {
    event.stopPropagation()
    if (this.menuTarget.hidden) this.open()
    else this.close()
  }

  filter() {
    const query = this.queryTarget.value.trim().toLowerCase()
    const searching = query.length > 0

    if (this.hasBrowseTarget) this.browseTarget.hidden = searching
    if (this.hasResultsTarget) this.resultsTarget.hidden = !searching
    if (searching) this.hideFlyouts()

    let shown = 0
    this.optionTargets.forEach((option) => {
      const inResults = this.hasResultsTarget && this.resultsTarget.contains(option)
      if (searching) {
        const match = inResults && (option.dataset.name || option.textContent).toLowerCase().includes(query)
        option.hidden = !match
        if (match) shown += 1
      } else {
        option.hidden = false
        if (!inResults) shown += 1
      }
    })
    this.emptyTarget.hidden = shown > 0
  }

  search(event) {
    if (event.key === "Enter") event.preventDefault()
  }

  showFlyout(event) {
    const flyout = event.currentTarget.closest(".assign-flyout")
    if (!flyout) return

    this.flyoutTargets.forEach((item) => {
      const on = item === flyout
      item.classList.toggle("is-open", on)
      const menu = item.querySelector(".assign-flyout-menu")
      const button = item.querySelector(".assign-flyout-button")
      if (menu) menu.hidden = !on
      if (button) button.setAttribute("aria-expanded", on ? "true" : "false")
      if (on && menu && button) this.placeFlyout(button, menu)
    })
  }

  hideFlyout(event) {
    const flyout = event.currentTarget.closest(".assign-flyout")
    if (!flyout || flyout.contains(event.relatedTarget)) return

    this.closeFlyout(flyout)
  }

  choose(event) {
    const id = String(event.params.id)
    if (id === this.currentValue) {
      this.close()
      return
    }
    if (this.warningValue && !window.confirm(this.warningValue)) {
      this.close()
      return
    }

    this.idTarget.value = id
    this.element.closest("form").requestSubmit()
  }

  open() {
    this.menuTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.queryTarget.value = ""
    this.filter()
    this.place()
    this.queryTarget.focus()
    document.addEventListener("click", this.outside)
    document.addEventListener("keydown", this.onKey)
  }

  close() {
    if (!this.hasMenuTarget || this.menuTarget.hidden) return

    this.hideFlyouts()
    this.menuTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.outside)
    document.removeEventListener("keydown", this.onKey)
  }

  place() {
    const box = this.buttonTarget.getBoundingClientRect()
    this.menuTarget.style.top = `${box.bottom + 4}px`
    this.menuTarget.style.left = `${box.left}px`
    this.menuTarget.style.width = `${Math.max(box.width, 220)}px`
  }

  hideFlyouts() {
    this.flyoutTargets.forEach((item) => this.closeFlyout(item))
  }

  closeFlyout(flyout) {
    flyout.classList.remove("is-open")
    const menu = flyout.querySelector(".assign-flyout-menu")
    const button = flyout.querySelector(".assign-flyout-button")
    if (menu) menu.hidden = true
    if (button) button.setAttribute("aria-expanded", "false")
  }

  placeFlyout(button, menu) {
    const box = button.getBoundingClientRect()
    const width = 280
    const gap = 2
    let left = box.right - gap
    if (left + width > window.innerWidth - 8) left = box.left - width + gap
    let top = box.top
    const height = Math.min(menu.scrollHeight || 320, window.innerHeight - 16)
    if (top + height > window.innerHeight - 8) top = Math.max(8, window.innerHeight - height - 8)
    menu.style.top = `${top}px`
    menu.style.left = `${left}px`
    menu.style.width = `${width}px`
  }
}
