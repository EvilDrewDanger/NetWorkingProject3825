import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["status", "players"]
  static values = { code: String }

  connect() {
    this.version = -1
    this.subscription = consumer.subscriptions.create(
      { channel: "FriendRoomChannel", code: this.codeValue },
      {
        connected: () => {
          this.statusTarget.textContent = "Connected to room."
          this.subscription.perform("sync")
        },
        disconnected: () => {
          this.playersTarget.replaceChildren()
          this.statusTarget.textContent = "Disconnected. Trying to reconnect..."
        },
        rejected: () => {
          this.playersTarget.replaceChildren()
          this.statusTarget.textContent = "Room unavailable. Return to Play a Friend to host or join again."
        },
        received: room => this.renderRoom(room)
      }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  renderRoom(room) {
    if (room.version < this.version) return
    this.version = room.version
    this.playersTarget.replaceChildren()

    room.players.forEach(player => {
      const item = document.createElement("li")
      item.textContent = `${player.name} — ${player.online ? "connected" : "disconnected"}`
      this.playersTarget.appendChild(item)
    })

    if (room.players.length < 2) {
      const item = document.createElement("li")
      item.textContent = "Waiting for a friend..."
      this.playersTarget.appendChild(item)
    }
  }
}
