import { Controller } from "@hotwired/stimulus"

// Cable refreshes every signed-in page. The poll is the health check and the
// fallback when a message is missed. Two failed pulses lock the page; the
// pulse keeps going and reloads when the server answers again.
export default class extends Controller {
  static targets = [ "warning" ]
  static values = {
    url: String,
    revision: String,
    interval: { type: Number, default: 5000 }
  }

  connect() {
    this.failures = 0
    this.lost = false
    this.poll()
    this.timer = window.setInterval(() => this.poll(), this.intervalValue)
    this.onOffline = () => this.disconnectWarning()
    this.onOnline = () => this.poll()
    window.addEventListener("offline", this.onOffline)
    window.addEventListener("online", this.onOnline)
  }

  disconnect() {
    window.clearInterval(this.timer)
    window.removeEventListener("offline", this.onOffline)
    window.removeEventListener("online", this.onOnline)
    this.abort?.abort()
  }

  async poll() {
    this.abort?.abort()
    this.abort = new AbortController()
    const timeout = window.setTimeout(() => this.abort.abort(), this.intervalValue + 3000)

    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin",
        signal: this.abort.signal
      })
      window.clearTimeout(timeout)
      const json = response.headers.get("content-type")?.includes("application/json")
      if (!response.ok || (this.hasRevisionValue && !json)) {
        this.noteFailure()
        return
      }
      if (this.lost) {
        this.reload()
        return
      }
      if (!json) {
        this.failures = 0
        return
      }

      const data = await response.json()
      this.failures = 0
      if (data.revision && this.hasRevisionValue && data.revision !== this.revisionValue) {
        this.revisionValue = data.revision
        this.refreshPage()
      } else if (data.revision) {
        this.revisionValue = data.revision
      }
    } catch {
      window.clearTimeout(timeout)
      this.noteFailure()
    }
  }

  noteFailure() {
    if (this.lost) return

    this.failures += 1
    if (this.failures >= 2) this.disconnectWarning()
  }

  disconnectWarning() {
    this.lost = true
    if (this.hasWarningTarget) this.warningTarget.hidden = false
  }

  refreshPage() {
    if (this.lost) return

    window.Turbo?.visit(window.location.href, { action: "replace" })
  }

  reload() {
    window.location.reload()
  }
}
