import { Controller } from "@hotwired/stimulus"

// The details pane is hidden until a fill is selected, so scrolling on connect
// can hit a zero-height box. Scroll again once the log is actually on screen.
export default class extends Controller {
  connect() {
    this.hidden = this.element.clientHeight === 0
    this.scroll()
    this.observer = new ResizeObserver(() => {
      const hidden = this.element.clientHeight === 0
      if (this.hidden && !hidden) this.scroll()
      this.hidden = hidden
    })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  scroll() {
    requestAnimationFrame(() => {
      if (!this.element.isConnected) return

      this.element.scrollTop = this.element.scrollHeight
    })
  }
}
