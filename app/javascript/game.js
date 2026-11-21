document.addEventListener("turbo:load", () => {
  const cells = Array.from(document.querySelectorAll(".game-cell"))
  const turnMessage = document.getElementById("turn-message")
  const resetButton = document.getElementById("reset-game")

  if (cells.length !== 9 || !turnMessage || !resetButton) return

  // Prevent duplicate event listeners
  if (resetButton.dataset.initialized) return
  resetButton.dataset.initialized = "true"

  let board = Array(9).fill("")
  let gameOver = false

  const winningCombinations = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6]
  ]

  // Check whether either player has won
  function checkWinner() {
    for (const [a, b, c] of winningCombinations) {
      if (
        board[a] &&
        board[a] === board[b] &&
        board[a] === board[c]
      ) {
        return board[a]
      }
    }

    return null
  }

  function finishGame(winner) {
    gameOver = true

    if (winner === "X") {
      turnMessage.textContent = "You win!"
    } else if (winner === "O") {
      turnMessage.textContent = "Computer wins!"
    } else {
      turnMessage.textContent = "It's a draw!"
    }

    cells.forEach(cell => cell.disabled = true)
  }

  // Update the board displayed in the browser
  function updateBoard() {
    cells.forEach((cell, index) => {
      cell.textContent = board[index]
      cell.disabled = gameOver || board[index] !== ""
    })
  }

  // Find a winning or blocking move for the computer
  function findWinningMove(mark) {
    for (let i = 0; i < 9; i++) {
      if (board[i] !== "") continue

      board[i] = mark
      const wins = checkWinner()
      board[i] = ""

      if (wins === mark) return i
    }

    return null
  }

  // Simple computer opponent
  function computerMove() {
    let move = findWinningMove("O")

    // Block the player's winning move
    if (move === null) {
      move = findWinningMove("X")
    }

    // Prefer the center
    if (move === null && board[4] === "") {
      move = 4
    }

    // Prefer corners
    if (move === null) {
      const corners = [0, 2, 6, 8]
        .filter(i => board[i] === "")

      if (corners.length > 0) {
        move = corners[Math.floor(Math.random() * corners.length)]
      }
    }

    // Otherwise choose any available square
    if (move === null) {
      const available = board
        .map((value, index) => value === "" ? index : null)
        .filter(index => index !== null)

      if (available.length > 0) {
        move = available[Math.floor(Math.random() * available.length)]
      }
    }

    if (move === null) {
      finishGame(null)
      return
    }

    board[move] = "O"
    updateBoard()

    const winner = checkWinner()

    if (winner) {
      finishGame(winner)
    } else if (board.every(cell => cell !== "")) {
      finishGame(null)
    } else {
      turnMessage.textContent = "Your turn (X)"
    }
  }

  // Player clicks a square
  cells.forEach((cell, index) => {
    cell.addEventListener("click", () => {
      if (gameOver || board[index] !== "") return

      board[index] = "X"
      updateBoard()

      const winner = checkWinner()

      if (winner) {
        finishGame(winner)
        return
      }

      if (board.every(cell => cell !== "")) {
        finishGame(null)
        return
      }

      turnMessage.textContent = "Computer's turn (O)"

      computerMove()
    })
  })

  // Reset the game
  resetButton.addEventListener("click", () => {
    board = Array(9).fill("")
    gameOver = false

    updateBoard()
    turnMessage.textContent = "Your turn (X)"
  })

  updateBoard()
})