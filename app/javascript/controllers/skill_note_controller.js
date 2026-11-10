import { Controller } from "@hotwired/stimulus"

// One note is open at a time. Leaving it saves; Escape puts the old text back.
export default class extends Controller {
  static targets = [ "text", "form", "input" ]

  connect() {
    this.onOpen = (event) => {
      if (event.detail !== this) this.revert()
    }
    window.addEventListener("skill-note:open", this.onOpen)
  }

  disconnect() {
    window.removeEventListener("skill-note:open", this.onOpen)
  }

  open() {
    window.dispatchEvent(new CustomEvent("skill-note:open", { detail: this }))
    this.editing = true
    this.textTarget.hidden = true
    this.formTarget.hidden = false
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  revert() {
    if (!this.editing) return

    this.editing = false
    this.inputTarget.value = this.inputTarget.defaultValue
    this.formTarget.hidden = true
    this.textTarget.hidden = false
  }

  key(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.revert()
    } else if (event.key === "Enter") {
      event.preventDefault()
      this.commit()
    }
  }

  commit() {
    if (!this.editing || this.saving) return
    if (this.inputTarget.value === this.inputTarget.defaultValue) {
      this.revert()
      return
    }

    this.saving = true
    this.formTarget.requestSubmit()
  }
}
