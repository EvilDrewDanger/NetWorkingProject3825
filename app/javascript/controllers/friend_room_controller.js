import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["status", "players", "gameStatus", "error", "cell", "rematch", "rematchStatus"]
  static values = { code: String, playerSlot: Number }

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
          this.disableGame()
        },
        rejected: () => {
          this.playersTarget.replaceChildren()
          this.statusTarget.textContent = "Room unavailable. Return to Play a Friend to host or join again."
          this.disableGame()
        },
        received: message => {
          if (message.error) {
            this.errorTarget.textContent = message.error
          } else {
            this.errorTarget.textContent = ""
            this.renderRoom(message)
          }
        }
      }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  play(event) {
    this.errorTarget.textContent = ""
    if (!this.subscription.perform("play", { index: Number(event.currentTarget.dataset.index) })) {
      this.errorTarget.textContent = "Unable to send your move. Check your connection."
    }
  }

  requestRematch() {
    this.errorTarget.textContent = ""
    if (!this.subscription.perform("request_rematch")) {
      this.errorTarget.textContent = "Unable to request a rematch. Check your connection."
    }
  }

  disableGame() {
    this.cellTargets.forEach(cell => { cell.disabled = true })
    this.rematchTarget.disabled = true
    this.gameStatusTarget.textContent = "Game paused while disconnected."
  }

  renderRoom(room) {
    if (room.version < this.version) return
    this.version = room.version
    this.playersTarget.replaceChildren()

    room.players.forEach(player => {
      const item = document.createElement("li")
      item.textContent = `${player.name} (${player.mark}) — ${player.online ? "connected" : "disconnected"}`
      this.playersTarget.appendChild(item)
    })

    if (room.players.length < 2) {
      const item = document.createElement("li")
      item.textContent = "Waiting for a friend..."
      this.playersTarget.appendChild(item)
    }

    const player = room.players[this.playerSlotValue]
    const bothConnected = room.players.length === 2 && room.players.every(entry => entry.online)
    const canPlay = bothConnected && !room.result && room.turn === player.mark

    this.cellTargets.forEach((cell, index) => {
      const mark = room.board[index]
      cell.textContent = mark || ""
      cell.setAttribute("aria-label", `Square ${index + 1}${mark ? `: ${mark}` : ": empty"}`)
      cell.disabled = !canPlay || Boolean(mark)
    })

    if (room.result === "draw") {
      this.gameStatusTarget.textContent = "It's a draw!"
    } else if (room.result) {
      this.gameStatusTarget.textContent = room.result === player.mark ? "You win!" : "Your friend wins!"
    } else if (room.players.length < 2) {
      this.gameStatusTarget.textContent = `You are ${player.mark}. Waiting for a friend.`
    } else if (!bothConnected) {
      this.gameStatusTarget.textContent = "Game paused. Waiting for both players to connect."
    } else {
      this.gameStatusTarget.textContent = room.turn === player.mark
        ? `Your turn (${player.mark}).`
        : `Your friend's turn (${room.turn}).`
    }

    this.rematchTarget.hidden = !room.result
    this.rematchTarget.disabled = !room.result || !bothConnected || player.rematch_requested
    if (!room.result) {
      this.rematchStatusTarget.textContent = ""
    } else if (!bothConnected) {
      this.rematchStatusTarget.textContent = "Both players must be connected to request a rematch."
    } else if (player.rematch_requested) {
      this.rematchStatusTarget.textContent = "Waiting for your friend to agree to a rematch."
    } else if (room.players.some(entry => entry.rematch_requested)) {
      this.rematchStatusTarget.textContent = "Your friend requested a rematch."
    } else {
      this.rematchStatusTarget.textContent = ""
    }
  }
}
