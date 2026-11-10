import { Controller } from "@hotwired/stimulus"

// One card for the whole page, so a row can show it without being clipped by its pane.
let portal
let owner
let showTimer

function sharedPortal() {
  if (portal) return portal

  portal = document.createElement("div")
  portal.className = "employee-card-portal"
  portal.hidden = true
  document.body.appendChild(portal)
  window.addEventListener("scroll", (event) => {
    if (portal.contains(event.target)) return
    closePortal()
  }, true)
  window.addEventListener("resize", closePortal)
  return portal
}

function closePortal() {
  clearTimeout(showTimer)
  if (!portal) return

  portal.hidden = true
  portal.replaceChildren()
  owner = null
}

function place(anchor) {
  const card = portal.getBoundingClientRect()
  const gap = 8
  let left = anchor.right + gap
  if (left + card.width > window.innerWidth - gap) left = anchor.left - card.width - gap
  left = Math.max(gap, left)
  let top = anchor.top
  const height = card.height
  if (top + height > window.innerHeight - gap) top = Math.max(gap, window.innerHeight - height - gap)
  portal.style.left = `${left}px`
  portal.style.top = `${top}px`
}

export default class extends Controller {
  static targets = [ "source" ]

  connect() {
    this.onEnter = (event) => this.scheduleShow(event)
    this.onLeave = () => this.scheduleHide()
    this.element.addEventListener("mouseenter", this.onEnter)
    this.element.addEventListener("mouseleave", this.onLeave)
    this.element.addEventListener("focusin", this.onEnter)
    this.element.addEventListener("focusout", this.onLeave)
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.onEnter)
    this.element.removeEventListener("mouseleave", this.onLeave)
    this.element.removeEventListener("focusin", this.onEnter)
    this.element.removeEventListener("focusout", this.onLeave)
    if (owner === this) closePortal()
  }

  scheduleShow(event) {
    if (event.buttons) return

    clearTimeout(showTimer)
    owner = this
    showTimer = setTimeout(() => {
      if (owner !== this) return
      this.open()
    }, 150)
  }

  scheduleHide() {
    if (owner !== this) return

    closePortal()
  }

  open() {
    const node = sharedPortal()
    node.replaceChildren(this.sourceTarget.content.cloneNode(true))
    node.hidden = false
    place(this.element.getBoundingClientRect())
  }
}
