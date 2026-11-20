
document.addEventListener("turbo:load", () => {
  const input = document.getElementById("message-input")
  const button = document.getElementById("send-button")
  const status = document.getElementById("connection-status")

  if (!input || !button) return

  const checkConnection = () => {
    if (window.gameSubscription?.consumer?.connection?.isOpen()) {
      status.textContent = "Connected"
    } else {
      status.textContent = "Connecting..."
    }
  }

  checkConnection()

  button.addEventListener("click", () => {
    const message = input.value.trim()

    if (!message) return

    if (!window.gameSubscription) {
      alert("Not connected to the game server.")
      return
    }

    window.gameSubscription.perform("send_message", {
      message: message
    })

    input.value = ""
  })
})
