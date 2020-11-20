// MARK: - Game

Game.main() // `@main` does not work yet: https://bugs.swift.org/browse/SR-12683
class Game {

    private let playerCellState: BoardCellState
    private let aiCellState: BoardCellState

    private(set) var isOver = false
    private(set) var currentState: State {
        didSet {
            isOver = currentState.isTerminal
        }
    }

    init(playerIsFirst: Bool) {
        self.playerCellState = playerIsFirst ? .cross : .circle
        self.aiCellState = playerIsFirst ? .circle : .cross
        self.currentState = .init()

        if !playerIsFirst {
            makeAiMove()
        }
    }

    func makePlayerMove(at coordinates: Coordinate) {
        guard !isOver else { return }
        guard currentState[coordinates] == .empty else {
            print("ERROR: trying to move at an illegal position! Ignoring.")
            return
        }
        let action = Action(newCellState: playerCellState, cellCoordinates: coordinates)
        currentState = currentState.withAppliedAction(action)
    }

    func makeAiMove() {
        guard !isOver else { return }
        let successors = currentState.successors(forCellState: aiCellState)
        guard !successors.isEmpty else {
            isOver = true
            return
        }
        // for now just zero intelligence
        currentState = successors[0].state
    }

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

        print("Good night.")

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
}

// MARK: - Data structures extensions

extension Game.State {
    init(size: Int = 3) {
        self.board = Array(repeating: Array(repeating: .empty, count: size), count: size)
    }

    var isTerminal: Bool {
        let isFull = allCoordinates.map { self[$0] }.allSatisfy { $0 != .empty }
        guard !isFull else { return true }

        return false // TODO
    }

    func successors(
        forCellState newCellState: Game.BoardCellState
    ) -> [(action: Game.Action, state: Game.State)] {
        allCoordinates
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
        Swift.print(board.map{ row in row.map{cell in cell.rawValue}.joined(separator: "") }.joined(separator: "\n"))
    }
}
