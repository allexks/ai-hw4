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
                1...game.currentState.board.count ~= row &&
                1...game.currentState.board[row-1].count ~= col
            else { continue }

            game.makePlayerMove(at: .init(rowIndex: row - 1, colIndex: col - 1))
            game.currentState.print()

            if game.isOver { break }

            print("AI move...")
            game.makeAiMove()
            game.currentState.print()
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

    // MARK: - AI

    func makeAiMove() {
        guard !isOver else { return }
        let successors = currentState.successors(forCellState: aiCellState)
        guard !successors.isEmpty else {
            isOver = true
            return
        }

        currentState = currentState.successors(forCellState: aiCellState)
            .map { (state: $0.state, score: minScore(state: $0.state)) }
            .sorted { $0.score > $1.score }
            .first?.state ?? currentState
    }

    private func minScore(state: State) -> WinScore {
        guard !state.isTerminal else {
            return state.score(for: aiCellState)
        }

        var minScore: WinScore = .win
        for successor in state.successors(forCellState: playerCellState) {
            minScore = min(minScore, maxScore(state: successor.state))
        }
        return minScore
    }

    private func maxScore(state: State) -> WinScore {
        guard !state.isTerminal else {
            return state.score(for: aiCellState)
        }

        var maxScore: WinScore = .loss
        for successor in state.successors(forCellState: aiCellState) {
            maxScore = max(maxScore, minScore(state: successor.state))
        }
        return maxScore
    }
}

// MARK: - Data structures

extension Game {
    enum BoardCellState: String {
        case empty = "-"
        case cross = "X"
        case circle = "O"
    }

    struct State {
        let board: [[BoardCellState]]
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
}

// MARK: - Data structures extensions

extension Game.State {
    init(size: Int = 3) {
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
    }

    private var isFull: Bool {
        allCoordinates.map { self[$0] }.allSatisfy { $0 != .empty }
    }

    var isTerminal: Bool {
        isFull || winningCellState != nil
    }

    var winningCellState: Game.BoardCellState? {
        let size = board.count
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

    func score(for desiredWinningCellState: Game.BoardCellState) -> Game.WinScore {
        guard let winningCellState = winningCellState else {
            return .draw
        }

        return winningCellState == desiredWinningCellState ? .win : .loss
    }

    func successors(
        forCellState newCellState: Game.BoardCellState
    ) -> [(action: Game.Action, state: Game.State)] {
        guard !isTerminal else { return [] }
        return allCoordinates
            .filter { self[$0] == .empty }
            .map { Game.Action(newCellState: newCellState, cellCoordinates: $0) }
            .map { (action: $0, state: self.withAppliedAction($0)) }
    }

    func withAppliedAction(_ action: Game.Action) -> Game.State {
        var newBoard = board
        let coord = action.cellCoordinates
        newBoard[coord.rowIndex][coord.colIndex] = action.newCellState
        return .init(board: newBoard)
    }

    subscript(_ coordinate: Game.Coordinate) -> Game.BoardCellState {
        board[coordinate.rowIndex][coordinate.colIndex]
    }

    private var allCoordinates: [Game.Coordinate] {
        Array(0..<board.count).map { row in
            Array(0..<board[row].count).map { col in
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