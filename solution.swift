// MARK: - Game

Game.main() // `@main` does not work yet: https://bugs.swift.org/browse/SR-12683
class Game {

    // MARK: - Entry point

    static func main() {
        print("First (crosses) or second (circles)? [x/o] ", terminator: "")
        guard let answer = readLine()?.lowercased() else { return }
        let isFirst: Bool
        if answer == "x" {
            isFirst = true
        } else if answer == "o" {
            isFirst = false
        } else {
            fatalError("Please enter a valid symbol next time ('x' or 'o')!")
        }

        let game = Game(playerIsFirst: isFirst)
        print("Beginning a new game of tic tac toe!")
        if !isFirst {
            print("AI move:")
        }
        game.currentState.print()

        while !game.isOver {
            print("Your move: [<row><col>] ", terminator: "")
            guard
                let input = readLine(),
                let first = input.first,
                let second = input.last,
                let row = Int(String(first)),
                let col = Int(String(second)),
                1...game.currentState.size ~= row &&
                1...game.currentState.size ~= col
            else { continue }

            game.makePlayerMove(at: .init(rowIndex: row - 1, colIndex: col - 1))
            game.currentState.print()

            if game.isOver { break }

            print("AI move...")
            game.makeAiMove()
            game.currentState.print()

            if game.makeLastMoveForPlayerIfNeeded() {
                print("Your last move:")
                game.currentState.print()
            }
        }

        switch game.playerWinState {
            case .win:
                print("Good game! You won!")
            case .draw:
                print("Game is a draw.")
            case .loss:
                print("Oops! You lost. :(")
        }
        print("Good night.")
    }

    // MARK: - Properties

    private let playerCellState: BoardCellState
    private let aiCellState: BoardCellState

    private(set) var isOver = false
    private(set) var playerWinState: WinScore = .draw
    private(set) var currentState: State {
        didSet {
            isOver = currentState.isTerminal
            if let winningState = currentState.winningCellState {
                playerWinState = winningState == playerCellState ? .win : .loss
            } // no need for else as default is `.draw`
        }
    }

    // MARK: - Init

    init(playerIsFirst: Bool) {
        self.playerCellState = playerIsFirst ? .cross : .circle
        self.aiCellState = playerIsFirst ? .circle : .cross
        self.currentState = .init()

        if !playerIsFirst {
            // makeAiMove()
            // optimization: the first turn is always best to be top left
            currentState = currentState.withAppliedAction(
                .init(
                    newCellState: aiCellState,
                    cellCoordinates: .init(
                        rowIndex: 0,
                        colIndex: 0
                    )
                )
            )
        }
    }

    // MARK: - Player

    func makePlayerMove(at coordinates: Coordinate) {
        guard !isOver else { return }
        guard currentState[coordinates] == .empty else {
            print("ERROR: trying to move at an illegal position! Ignoring.")
            return
        }
        let action = Action(newCellState: playerCellState, cellCoordinates: coordinates)
        currentState = currentState.withAppliedAction(action)
    }

    /// Return whether a move was made.
    func makeLastMoveForPlayerIfNeeded() -> Bool {
        guard !isOver else { return false }
        let successors = currentState.successors(forCellState: playerCellState)
        guard successors.count == 1, let finalState = successors.first?.state else { return false }
        currentState = finalState
        return true
    }

    // MARK: - AI

    func makeAiMove() {
        guard !isOver else { return }
        let successors = currentState.successors(forCellState: aiCellState)
        guard !successors.isEmpty else {
            isOver = true
            return
        }

        let depth = 0
        currentState = maxScore(
            state: currentState,
            alpha: .init(winScore: .loss, depth: depth),
            beta: .init(winScore: .win, depth: depth),
            depth: depth
        ).state
    }

    private func minScore(
        state: State, alpha: Score, beta: Score, depth: Int
    ) -> (score: Score, state: State) {
        guard !state.isTerminal else {
            return (score: state.score(for: aiCellState, depth: depth), state: state)
        }

        var minScore: Score = .init(winScore: .win, depth: depth)
        var minState = state
        var newBeta = beta
        for successor in state.successors(forCellState: playerCellState) {
            let current = maxScore(state: successor.state, alpha: alpha, beta: newBeta, depth: depth + 1)
            if current.score < minScore {
                minScore = current.score
                minState = successor.state
            }
            newBeta = min(newBeta, minScore)
            if newBeta <= alpha {
                return (score: minScore, state: minState)
            }
        }
        return (score: minScore, state: minState)
    }

    private func maxScore(
        state: State, alpha: Score, beta: Score, depth: Int
    ) -> (score: Score, state: State) {
        guard !state.isTerminal else {
            return (score: state.score(for: aiCellState, depth: depth), state: state)
        }

        var maxScore: Score = .init(winScore: .loss, depth: depth)
        var maxState = state
        var newAlpha = alpha
        for successor in state.successors(forCellState: aiCellState) {
            let current = minScore(state: successor.state, alpha: newAlpha, beta: beta, depth: depth + 1)
            if current.score > maxScore {
                maxScore = current.score
                maxState = successor.state
            }
            newAlpha = max(newAlpha, maxScore)
            if newAlpha >= beta {
                return (score: maxScore, state: maxState)
            }
        }
        return (score: maxScore, state: maxState)
    }
}

// MARK: - Data structures

extension Game {
    typealias Successor = (state: State, action: Action)

    enum BoardCellState: String {
        case empty = "-"
        case cross = "X"
        case circle = "O"
    }

    struct State {
        let size: Int
        private let board: [[BoardCellState]]
    }

    struct Coordinate {
        let rowIndex: Int
        let colIndex: Int
    }

    struct Action {
        let newCellState: BoardCellState
        let cellCoordinates: Coordinate
    }

    enum WinScore: Int {
        case win = 1
        case draw = 0
        case loss = -1
    }

    struct Score {
        let winScore: WinScore
        let depth: Int
    }
}

// MARK: - Data structures extensions

extension Game.State {
    init(size: Int = 3) {
        self.size = size
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
    }

    private var isFull: Bool {
        allCoordinates.map { self[$0] }.allSatisfy { $0 != .empty }
    }

    var isTerminal: Bool {
        isFull || winningCellState != nil
    }

    var winningCellState: Game.BoardCellState? {
        for cellState in [Game.BoardCellState]([.cross, .circle]) {
            // Horizontals
            for row in board {
                if row.allSatisfy({ $0 == cellState }) {
                    return cellState
                }
            }

            // Verticals
            for colIndex in 0..<size {
                if Array(0..<size)
                    .map({ board[$0][colIndex] })
                    .allSatisfy({ $0 == cellState }) {
                    return cellState
                }
            }

            // Main diagonal
            if Array(0..<size)
                .map({ board[$0][$0] })
                .allSatisfy({ $0 == cellState }) {
                return cellState
            }

            // Secondary diagonal
            if Array(0..<size)
                .map({ board[size - 1 - $0][$0] })
                .allSatisfy({ $0 == cellState }) {
                return cellState
            }
        }

        return nil
    }

    func score(for desiredWinningCellState: Game.BoardCellState, depth: Int) -> Game.Score {
        .init(winScore: winScore(for: desiredWinningCellState), depth: depth)
    }

    func successors(forCellState newCellState: Game.BoardCellState) -> [Game.Successor] {
        guard !isTerminal else { return [] }
        return allCoordinates
            .filter { self[$0] == .empty }
            .map { Game.Action(newCellState: newCellState, cellCoordinates: $0) }
            .map { (state: self.withAppliedAction($0), action: $0) }
    }

    func withAppliedAction(_ action: Game.Action) -> Game.State {
        var newBoard = board
        let coord = action.cellCoordinates
        newBoard[coord.rowIndex][coord.colIndex] = action.newCellState
        return .init(size: size, board: newBoard)
    }

    subscript(_ coordinate: Game.Coordinate) -> Game.BoardCellState {
        board[coordinate.rowIndex][coordinate.colIndex]
    }

    private func winScore(for desiredWinningCellState: Game.BoardCellState) -> Game.WinScore {
        guard let winningCellState = winningCellState else {
            return .draw
        }

        return winningCellState == desiredWinningCellState ? .win : .loss
    }

    private var allCoordinates: [Game.Coordinate] {
        Array(0..<size).map { row in
            Array(0..<size).map { col in
                Game.Coordinate(rowIndex: row, colIndex: col)
            }
        }.reduce([], +) // flatten to 1D array
    }

    func print() {
        Swift.print(board.map{ row in row.map{cell in cell.rawValue}.joined(separator: " ") }.joined(separator: "\n"))
    }
}

extension Game.WinScore: Comparable {
    static func < (lhs: Game.WinScore, rhs: Game.WinScore) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension Game.Score: Comparable {
    static func < (lhs: Game.Score, rhs: Game.Score) -> Bool {
        if lhs.winScore == rhs.winScore {
            return lhs.depth > rhs.depth
        }

        return lhs.winScore < rhs.winScore
    }
}