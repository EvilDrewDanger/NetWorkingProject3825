import consumer from "./consumer"

const gameSubscription = consumer.subscriptions.create(
  {
    channel: "GameChannel"
  },
  {
  connected() {
    // Called when the subscription is ready for use on the server
      console.log("Connected to GameChannel")
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
    console.log("Disconnected from GameChannel")
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    const messages = document.getElementById("messages")

      if (!messages) return

      const messageElement = document.createElement("p")
      messageElement.textContent =
        `${data.sender}: ${data.message}`

      messages.appendChild(messageElement)
    }
  }
)


window.gameSubscription = gameSubscription
