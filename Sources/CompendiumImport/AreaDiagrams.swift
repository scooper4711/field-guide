import FieldGuideKit
import Foundation

/// One diagram of the Areas entry: an area's common sizes, nested on one grid.
struct AreaDiagram: Sendable {
    /// What starts the area: grid corners, or a creature's space with its size letter.
    enum Origin: Sendable {
        case corners([Corner])
        case creature(letter: String, square: GridSquare, space: Int)
    }

    /// A grid corner an area starts from, with the label shown to its left, if any.
    struct Corner: Sendable {
        var square: GridSquare
        var label = ""
    }

    /// A line's slope: `down` squares for every `across`, and how the diagram labels it.
    struct Slope: Sendable {
        var across: Int
        var down: Int
        var label: String
    }

    var title: String
    var caption: String
    var sizes: [Int]
    var origin: Origin
    var squares: @Sendable (Int) -> Set<GridSquare>

    static let corner = Origin.corners([Corner(square: GridSquare(column: 0, row: 0))])
    static let medium = creature("M", column: 0, row: 0, space: 1)
    static let emanationSizes = [5, 10, 15, 20, 30]
    static let reachSizes = [5, 10, 15]
    static let coneSizes = [15, 30, 60]
    static let large = creature("L", column: 0, row: 0, space: 2)

    static let all = [
        AreaDiagram(title: "Burst", caption: "From a corner of a square, within range.", sizes: emanationSizes,
                    origin: corner) { AreaGeometry.burst(feet: $0) },
        AreaDiagram(title: "Emanation, Medium or smaller creature",
                    caption: "From every side of the creature's space.", sizes: emanationSizes, origin: medium) {
            AreaGeometry.emanation(feet: $0, space: 1)
        },
        AreaDiagram(title: "Reach, Medium or smaller creature",
                    caption: "As an emanation, except that 10-foot reach reaches 2 squares diagonally.",
                    sizes: reachSizes, origin: medium) { AreaGeometry.reach(feet: $0, space: 1) },
        AreaDiagram(title: "Emanation, Large creature", caption: "From every side of the creature's space.",
                    sizes: emanationSizes, origin: large) { AreaGeometry.emanation(feet: $0, space: 2) },
        AreaDiagram(title: "Reach, Large creature",
                    caption: "As an emanation, except that 10-foot reach reaches 2 squares diagonally.",
                    sizes: reachSizes, origin: large) { AreaGeometry.reach(feet: $0, space: 2) },
        AreaDiagram(title: "Emanation, Huge creature", caption: "From every side of the creature's space.",
                    sizes: emanationSizes, origin: creature("H", column: 0, row: 0, space: 3)) {
            AreaGeometry.emanation(feet: $0, space: 3)
        },
        AreaDiagram(title: "Cone, orthogonal", caption: "From the middle of one side of the creature's space.",
                    sizes: coneSizes, origin: creature("M", column: 0, row: -1, space: 1)) {
            AreaGeometry.orthogonalCone(feet: $0)
        },
        AreaDiagram(title: "Cone, diagonal", caption: "From a corner of the creature's space.", sizes: coneSizes,
                    origin: creature("M", column: -1, row: -1, space: 1)) {
            AreaGeometry.diagonalCone(feet: $0)
        },
        AreaDiagram(title: "Line", caption: "From a corner of a square, at five slopes.", sizes: lineSizes,
                    origin: .corners(lineCorners)) { lineSquares(feet: $0) }
    ]

    static func creature(_ letter: String, column: Int, row: Int, space: Int) -> Origin {
        .creature(letter: letter, square: GridSquare(column: column, row: row), space: space)
    }

    static let lineSizes = [30, 60]
    /// The Line diagram's lines, shallowest first, so each can start soon after the one above.
    static let lineSlopes = [Slope(across: 1, down: 0, label: "Straight"),
                             Slope(across: 3, down: 1, label: "3 across, 1 down"),
                             Slope(across: 2, down: 1, label: "2 across, 1 down"),
                             Slope(across: 3, down: 2, label: "3 across, 2 down"),
                             Slope(across: 1, down: 1, label: "Diagonal")]
    /// The row each line starts on.
    static let lineRows = AreaGeometry.packedRows(lineSlopes.map {
        AreaGeometry.line(feet: lineSizes.max() ?? 0, across: $0.across, down: $0.down)
    })
    /// Where each line starts, labeled with its slope.
    static let lineCorners = zip(lineSlopes, lineRows).map { slope, row in
        Corner(square: GridSquare(column: 0, row: row), label: slope.label)
    }

    /// The squares of every line at `feet`, each shifted down to its row.
    static func lineSquares(feet: Int) -> Set<GridSquare> {
        var squares = Set<GridSquare>()
        for (slope, row) in zip(lineSlopes, lineRows) {
            squares.formUnion(AreaGeometry.line(feet: feet, across: slope.across, down: slope.down)
                .map { GridSquare(column: $0.column, row: $0.row + row) })
        }
        return squares
    }
}

/// The GM Screen's Areas entry for each system, drawn from the rules as inline SVG.
struct AreaDiagrams {
    typealias Bounds = (columns: Range<Int>, rows: Range<Int>)

    var diagrams = AreaDiagram.all
    static let squareSize = 16
    /// The space left of the grid for the lines' labels, in the drawing's units.
    static let labelMargin = 6 * squareSize
    /// How many times larger than the drawing's units the diagrams are shown.
    static let displayScale = 2

    func rows() -> [EntryRow] {
        GameSystem.allCases.map(row(for:))
    }

    private func row(for system: GameSystem) -> EntryRow {
        let html = "<header class=\"entry-header\"><div><h1>Areas</h1><p class=\"subtitle\">Playing the Game</p></div>"
            + "</header><section class=\"description\"><p>Every second diagonal square counts as 10 feet. Each "
            + "size has its own color, from the smallest outward.</p>"
            + diagrams.map(Self.figure).joined() + "</section>"
        return EntryRow(
            id: "fieldguide.\(system.rawValue).areas", system: system, category: .gmScreen, name: "Areas",
            level: nil, subtitle: "Playing the Game", image: "", facets: [.section: ["Playing the Game"]],
            html: html, text: "Areas emanation burst cone line diagrams", traitSlugs: []
        )
    }

    static func figure(_ diagram: AreaDiagram) -> String {
        "<figure class=\"area\"><figcaption><strong>\(HTML.escape(diagram.title)).</strong> "
            + "\(HTML.escape(diagram.caption))</figcaption>\(svg(diagram))\(key(diagram))</figure>"
    }

    /// Each square shaded by the smallest size that covers it, the grid over them, then the origin.
    static func svg(_ diagram: AreaDiagram) -> String {
        let shaded = shading(diagram)
        let bounds = gridBounds(Set(shaded.keys), origin: diagram.origin)
        let squares = shaded.sorted { ($0.key.row, $0.key.column) < ($1.key.row, $1.key.column) }
            .map { rect($0.key, size: 1, in: bounds, class: "area-\($0.value)") }
        let gridWidth = bounds.columns.count * squareSize, height = bounds.rows.count * squareSize
        let margin = labels(diagram.origin, in: bounds).isEmpty ? 0 : labelMargin
        let width = gridWidth + margin
        // Every diagram shows its squares at the same size, up to the page's width.
        let maximumWidth = min(width * displayScale, 480)
        return "<svg class=\"area-grid\" style=\"max-width: \(maximumWidth)px\" viewBox=\"0 0 \(width) \(height)\" "
            + "role=\"img\" aria-label=\"\(HTML.escape(diagram.title))\"><g transform=\"translate(\(margin) 0)\">"
            + squares.joined() + gridLines(width: gridWidth, height: height) + outlines(diagram, in: bounds)
            + originMarks(diagram.origin, in: bounds) + labels(diagram.origin, in: bounds) + "</g></svg>"
    }

    /// The smallest size, as its place in the list counting from 1, that covers each square.
    static func shading(_ diagram: AreaDiagram) -> [GridSquare: Int] {
        var levels: [GridSquare: Int] = [:]
        for (index, feet) in diagram.sizes.enumerated().reversed() {
            diagram.squares(feet).forEach { levels[$0] = index + 1 }
        }
        return levels
    }

    static func key(_ diagram: AreaDiagram) -> String {
        "<ul class=\"area-key\">" + diagram.sizes.enumerated().map { index, feet in
            "<li><span class=\"swatch area-\(index + 1)\"></span>\(feet) feet</li>"
        }.joined() + "</ul>"
    }

    /// The squares shown: every shaded one and the creature's space, with one square of margin.
    private static func gridBounds(_ squares: Set<GridSquare>, origin: AreaDiagram.Origin) -> Bounds {
        var all = squares
        if case let .creature(_, square, space) = origin {
            all.insert(square)
            all.insert(GridSquare(column: square.column + space - 1, row: square.row + space - 1))
        }
        let columns = all.map(\.column), rows = all.map(\.row)
        return ((columns.min() ?? 0) - 1..<(columns.max() ?? 0) + 2, (rows.min() ?? 0) - 1..<(rows.max() ?? 0) + 2)
    }

    private static func rect(_ square: GridSquare, size: Int, in bounds: Bounds, class name: String) -> String {
        let (left, top) = position(of: square, in: bounds)
        return "<rect class=\"\(name)\" x=\"\(left)\" y=\"\(top)\" width=\"\(size * squareSize)\" "
            + "height=\"\(size * squareSize)\"/>"
    }

    /// The top left corner of a square, in the drawing's units.
    private static func position(of square: GridSquare, in bounds: Bounds) -> (x: Int, y: Int) {
        ((square.column - bounds.columns.lowerBound) * squareSize, (square.row - bounds.rows.lowerBound) * squareSize)
    }

    /// Each size's outline in its own color, the largest first so the smaller ones draw over shared edges.
    /// Each is clipped to its own squares, so it lies inside its size and never overlaps a neighbor's at a corner.
    static func outlines(_ diagram: AreaDiagram, in bounds: Bounds) -> String {
        let name = diagram.title.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: "-")
        return diagram.sizes.enumerated().reversed().map { index, feet in
            let squares = diagram.squares(feet), tone = index + 1
            let clip = "area-\(name)-\(tone)"
            return "<clipPath id=\"\(clip)\"><path d=\"\(fill(squares, in: bounds))\"/></clipPath>"
                + "<g clip-path=\"url(#\(clip))\">\(outline(squares, in: bounds, tone: tone))</g>"
        }.joined()
    }

    /// A path covering the squares, for clipping.
    static func fill(_ squares: Set<GridSquare>, in bounds: Bounds) -> String {
        squares.sorted { ($0.row, $0.column) < ($1.row, $1.column) }.map { square in
            let (left, top) = position(of: square, in: bounds)
            return "M\(left) \(top)h\(squareSize)v\(squareSize)h-\(squareSize)z"
        }.joined()
    }

    /// A path along every edge where a square of the area meets one outside it, colored by `tone`.
    static func outline(_ squares: Set<GridSquare>, in bounds: Bounds, tone: Int) -> String {
        let size = squareSize
        let edges = squares.sorted { ($0.row, $0.column) < ($1.row, $1.column) }.flatMap { square in
            let (left, top) = position(of: square, in: bounds)
            func isOutside(_ column: Int, _ row: Int) -> Bool {
                !squares.contains(GridSquare(column: square.column + column, row: square.row + row))
            }
            return [(isOutside(0, -1), "M\(left) \(top)h\(size)"), (isOutside(0, 1), "M\(left) \(top + size)h\(size)"),
                    (isOutside(-1, 0), "M\(left) \(top)v\(size)"), (isOutside(1, 0), "M\(left + size) \(top)v\(size)")]
                .filter(\.0).map(\.1)
        }
        return "<path class=\"outline outline-\(tone)\" d=\"\(edges.joined())\"/>"
    }

    private static func gridLines(width: Int, height: Int) -> String {
        let columns = stride(from: 0, through: width, by: squareSize).map { "M\($0) 0V\(height)" }
        let rows = stride(from: 0, through: height, by: squareSize).map { "M0 \($0)H\(width)" }
        return "<path class=\"grid\" d=\"\((columns + rows).joined())\"/>"
    }

    /// Each labeled corner's label, ending just left of its dot, in the margin.
    private static func labels(_ origin: AreaDiagram.Origin, in bounds: Bounds) -> String {
        guard case let .corners(corners) = origin else { return "" }
        return corners.filter { !$0.label.isEmpty }.map { corner in
            let point = position(of: corner.square, in: bounds)
            return "<text class=\"line-label\" x=\"\(point.x - 7)\" y=\"\(point.y + 3)\">"
                + "\(HTML.escape(corner.label))</text>"
        }.joined()
    }

    private static func originMarks(_ origin: AreaDiagram.Origin, in bounds: Bounds) -> String {
        switch origin {
        case let .corners(corners):
            return corners.map { corner in
                let point = position(of: corner.square, in: bounds)
                return "<circle class=\"origin\" cx=\"\(point.x)\" cy=\"\(point.y)\" r=\"4\"/>"
            }.joined()
        case let .creature(letter, square, space):
            let (left, top) = position(of: square, in: bounds)
            let middle = space * squareSize / 2
            return rect(square, size: space, in: bounds, class: "creature")
                + "<text class=\"creature\" x=\"\(left + middle)\" y=\"\(top + middle)\">\(letter)</text>"
        }
    }
}
