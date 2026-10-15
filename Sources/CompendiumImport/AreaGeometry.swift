import Foundation

/// A grid square, by column and row; square (0, 0) has the grid corner (0, 0) at its top left.
struct GridSquare: Hashable, Sendable {
    var column: Int
    var row: Int
}

/// The squares an area covers, measured as the rules measure distance: every second diagonal counts as 10 feet.
enum AreaGeometry {
    static let feetPerSquare = 5

    /// The feet moved to cover `across` squares one way and `down` the other: diagonals first, every second one
    /// counting double.
    static func distance(across: Int, down: Int) -> Int {
        (max(across, down) + min(across, down) / 2) * feetPerSquare
    }

    /// A burst from the grid corner (0, 0).
    static func burst(feet: Int) -> Set<GridSquare> {
        let reach = feet / feetPerSquare
        return squares(in: -reach..<reach, -reach..<reach) { square in
            distance(across: steps(square.column), down: steps(square.row)) <= feet
        }
    }

    /// An emanation from a creature filling the squares (0, 0) to (`space` - 1, `space` - 1), its space included.
    static func emanation(feet: Int, space: Int) -> Set<GridSquare> {
        let reach = feet / feetPerSquare
        func beyond(_ index: Int) -> Int { index < 0 ? -index : max(0, index - space + 1) }
        return squares(in: -reach..<(space + reach), -reach..<(space + reach)) { square in
            distance(across: beyond(square.column), down: beyond(square.row)) <= feet
        }
    }

    /// A creature's reach: an emanation, except that 10-foot reach takes every square within 2, corners too.
    static func reach(feet: Int, space: Int) -> Set<GridSquare> {
        guard feet == 2 * feetPerSquare else { return emanation(feet: feet, space: space) }
        return squares(in: -2..<(space + 2), -2..<(space + 2)) { _ in true }
    }

    /// A cone from the grid corner (0, 0), spreading right and down: the quarter of a burst.
    static func diagonalCone(feet: Int) -> Set<GridSquare> {
        burst(feet: feet).filter { $0.column >= 0 && $0.row >= 0 }
    }

    /// A cone from the middle of the top edge of square (0, 0), spreading down from it: a square counts when its
    /// column is no farther out than its row.
    static func orthogonalCone(feet: Int) -> Set<GridSquare> {
        let reach = feet / feetPerSquare
        return squares(in: -reach..<(reach + 1), 0..<reach) { square in
            abs(square.column) <= square.row
                && distance(across: abs(square.column), down: square.row + 1) <= feet
        }
    }

    /// A line from the grid corner (0, 0) heading `across` right for every `down`: the squares the ray passes
    /// through that a burst of the same size covers.
    static func line(feet: Int, across: Int, down: Int) -> Set<GridSquare> {
        let reach = burst(feet: feet)
        let length = Double(feet / feetPerSquare) * 2
        let step = 0.01 / Double(max(across, down))
        // Nudged off the grid lines so a straight line fills the row below it, not both.
        return Set(stride(from: step, to: length, by: step).map { travel in
            GridSquare(column: Int((Double(across) * travel + 1e-6).rounded(.down)),
                       row: Int((Double(down) * travel + 1e-6).rounded(.down)))
        }).intersection(reach)
    }

    /// The row each line starts on, stacked in order: the first row where none of its squares is beside (or
    /// diagonal to) a square of the lines above, so a clear square always separates them.
    static func packedRows(_ lines: [Set<GridSquare>]) -> [Int] {
        var taken = Set<GridSquare>(), rows: [Int] = [], row = 0
        for line in lines {
            while line.contains(where: { isBeside(GridSquare(column: $0.column, row: $0.row + row), taken) }) {
                row += 1
            }
            rows.append(row)
            taken.formUnion(line.map { GridSquare(column: $0.column, row: $0.row + row) })
        }
        return rows
    }

    /// Whether `square` or any of the eight squares around it is in `taken`.
    private static func isBeside(_ square: GridSquare, _ taken: Set<GridSquare>) -> Bool {
        for column in -1...1 {
            for row in -1...1 where taken.contains(GridSquare(column: square.column + column, row: square.row + row)) {
                return true
            }
        }
        return false
    }

    /// The squares moved, from the corner (0, 0), to cover square `index` along one axis.
    private static func steps(_ index: Int) -> Int {
        index < 0 ? -index : index + 1
    }

    private static func squares(in columns: Range<Int>, _ rows: Range<Int>,
                                where isIncluded: (GridSquare) -> Bool) -> Set<GridSquare> {
        Set(columns.flatMap { column in rows.map { GridSquare(column: column, row: $0) } }.filter(isIncluded))
    }
}
