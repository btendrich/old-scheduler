import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Dropping a person or a list posts to the same actions as the add buttons.
// Reordering posts the new id order. A name or skill sort never reaches this.
export default class extends Controller {
  static values = {
    url: String,
    addEmployeeUrl: String,
    addTemplateUrl: String,
    group: String,
    pull: { type: String, default: "false" },
    put: { type: Boolean, default: false },
    sort: { type: Boolean, default: true }
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      handle: ".drag-handle",
      draggable: "[data-draggable]",
      ghostClass: "sortable-ghost",
      group: {
        name: this.groupValue || "list",
        pull: this.pullValue === "clone" ? "clone" : this.pullValue === "true",
        put: this.putValue
      },
      sort: this.sortValue,
      onStart: () => {
        this.startIds = [ ...this.element.querySelectorAll(":scope > [data-sortable-id]") ].map((row) => row.dataset.sortableId)
      },
      onEnd: (event) => this.ended(event),
      onAdd: (event) => this.added(event.item)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  setEnabled(enabled) {
    this.sortable.option("disabled", !enabled)
  }

  ended(event) {
    if (event.from !== event.to || event.oldIndex === event.newIndex) return

    const move = new CustomEvent("sortable:move", {
      bubbles: true,
      cancelable: true,
      detail: { oldIndex: event.oldIndex, newIndex: event.newIndex, startIds: this.startIds || [] }
    })
    this.element.dispatchEvent(move)
    if (!move.defaultPrevented) this.persist()
  }

  async added(item) {
    const employeeId = item.dataset.employeeId
    const templateId = item.dataset.templateId
    item.remove()

    const body = new URLSearchParams()
    let url = ""
    if (employeeId && this.addEmployeeUrlValue) {
      url = this.addEmployeeUrlValue
      body.set("employee_id", employeeId)
    } else if (templateId && this.addTemplateUrlValue) {
      url = this.addTemplateUrlValue
      body.set("template_list_id", templateId)
    }
    if (!url) return

    await this.submit(url, body)
    window.Turbo.visit(window.location.href)
  }

  async persist() {
    if (!this.urlValue) return

    const body = new URLSearchParams()
    this.element.querySelectorAll(":scope > [data-sortable-id]").forEach((row) => {
      body.append("ids[]", row.dataset.sortableId)
    })
    const response = await this.submit(this.urlValue, body, "PATCH")
    if (!response.ok) {
      window.Turbo.visit(window.location.href)
      return
    }

    this.element.querySelectorAll("[data-slot-index]").forEach((cell, index) => {
      cell.textContent = String(index + 1)
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
