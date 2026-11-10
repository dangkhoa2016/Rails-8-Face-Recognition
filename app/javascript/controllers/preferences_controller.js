import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  connect() {
    this.element.querySelectorAll("select").forEach((select) => {
      select.dataset.savedValue = select.value
    })
  }

  async submit(event) {
    const select = event.currentTarget
    const previousValue = select.dataset.savedValue
    const changedTheme = select.name === "theme"
    // Read the form before disabling the select; disabled inputs are omitted.
    const body = new URLSearchParams(new FormData(this.element))

    if (changedTheme) document.documentElement.dataset.theme = select.value
    select.disabled = true

    try {
      const response = await fetch(this.element.action, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body
      })
      if (response.status !== 204 || response.redirected) throw new Error("Preference save failed")

      select.dataset.savedValue = select.value
      if (select.name === "locale") {
        // Locale requires server-rendered translations. Refresh the current URL
        // via Turbo Morph instead of submitting a redirecting HTML form.
        document.documentElement.lang = select.value
        Turbo.visit(window.location.href, { action: "replace" })
      }
    } catch (error) {
      select.value = previousValue
      if (changedTheme) document.documentElement.dataset.theme = previousValue
      if (select.name === "locale") document.documentElement.lang = previousValue
      console.error("Could not save display preference", error)
    } finally {
      select.disabled = false
    }
  }
}
