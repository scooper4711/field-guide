import FieldGuideKit
import Testing
@testable import CompendiumImport

@Suite struct AreaGeometryTests {
    /// The squares as rows of `#` and `.`, from the top left of the given range.
    func picture(_ squares: Set<GridSquare>, columns: ClosedRange<Int>, rows: ClosedRange<Int>) -> [String] {
        rows.map { row in String(columns.map { squares.contains(GridSquare(column: $0, row: row)) ? "#" : "." }) }
    }

    @Test func everySecondDiagonalCountsDouble() {
        #expect(AreaGeometry.distance(across: 1, down: 1) == 5)
        #expect(AreaGeometry.distance(across: 2, down: 2) == 15)
        #expect(AreaGeometry.distance(across: 4, down: 1) == 20)
    }

    @Test func burstsSpreadFromACorner() {
        #expect(AreaGeometry.burst(feet: 5).count == 4)
        #expect(picture(AreaGeometry.burst(feet: 10), columns: -2...1, rows: -2...1)
                == [".##.", "####", "####", ".##."])
        #expect(AreaGeometry.burst(feet: 30).count == 96)
    }

    @Test func emanationsSpreadFromTheCreaturesSpace() {
        #expect(AreaGeometry.emanation(feet: 5, space: 1).count == 9)
        #expect(picture(AreaGeometry.emanation(feet: 10, space: 1), columns: -2...2, rows: -2...2)
                == [".###.", "#####", "#####", "#####", ".###."])
        #expect(AreaGeometry.emanation(feet: 10, space: 2).count == 32)
    }

    @Test func conesSpreadOrthogonallyAndDiagonally() {
        #expect(picture(AreaGeometry.orthogonalCone(feet: 15), columns: -1...1, rows: 0...2) == [".#.", "###", "###"])
        #expect(AreaGeometry.orthogonalCone(feet: 30).count == 26)
        #expect(picture(AreaGeometry.diagonalCone(feet: 15), columns: 0...2, rows: 0...2) == ["###", "##.", "#.."])
        #expect(AreaGeometry.diagonalCone(feet: 30).count == 24)
    }

    @Test func linesTakeTheSquaresTheyCross() {
        #expect(picture(AreaGeometry.line(feet: 30, across: 1, down: 0), columns: 0...6, rows: -1...0)
                == [".......", "######."])
        #expect(picture(AreaGeometry.line(feet: 30, across: 2, down: 1), columns: 0...4, rows: 0...2)
                == ["##...", "..##.", "....#"])
        #expect(AreaGeometry.line(feet: 30, across: 1, down: 1).count == 4)
    }
}

@Suite struct AreaDiagramTests {
    @Test func eachSystemGetsTheDrawnDiagrams() throws {
        let rows = AreaDiagrams().rows()
        #expect(rows.map(\.id) == ["fieldguide.pf2e.areas", "fieldguide.sf2e.areas"])
        let row = try #require(rows.first)
        #expect(row.category == .gmScreen && row.facets == [.section: ["Playing the Game"]] && row.image.isEmpty)
        #expect(row.html.components(separatedBy: "<svg").count - 1 == AreaDiagram.all.count)
        #expect(row.html.contains("<strong>Cone, diagonal.</strong>") && !row.html.contains("<img"))
    }

    @Test func squaresTakeTheSmallestSizeCoveringThem() throws {
        let burst = try #require(AreaDiagram.all.first)
        let levels = AreaDiagrams.shading(burst)
        #expect(levels[GridSquare(column: 0, row: 0)] == 1)
        #expect(levels[GridSquare(column: 1, row: 0)] == 2)
        #expect(levels[GridSquare(column: 5, row: 0)] == 5)
        #expect(AreaDiagrams.key(burst).contains("<span class=\"swatch area-5\"></span>30 feet"))
        #expect([1, 2, 3].map { AreaDiagrams.tone($0, of: 3) } == [1, 3, 5])
        #expect([1, 2].map { AreaDiagrams.tone($0, of: 2) } == [1, 5])
        #expect(AreaDiagrams.tone(1, of: 1) == 1)
    }

    @Test func outlinesFollowTheAreasEdge() {
        let square: Set = [GridSquare(column: 0, row: 0)]
        let bounds = (columns: 0..<1, rows: 0..<1)
        #expect(AreaDiagrams.outline(square, in: bounds, tone: 2)
                == "<path class=\"outline outline-2\" d=\"M0 0h16M0 16h16M0 0v16M16 0v16\"/>")
        let pair: Set = [GridSquare(column: 0, row: 0), GridSquare(column: 1, row: 0)]
        let edges = AreaDiagrams.outline(pair, in: (columns: 0..<2, rows: 0..<1), tone: 1).components(separatedBy: "M")
        #expect(edges.count - 1 == 6)
        let burst = AreaDiagram.all[0]
        let svg = AreaDiagrams.svg(burst)
        #expect((1...5).allSatisfy { svg.contains("class=\"outline outline-\($0)\"") })
        #expect(svg.range(of: "outline-5")!.lowerBound < svg.range(of: "outline-1")!.lowerBound)
        #expect(svg.contains("<clipPath id=\"area-burst-1\"><path d=\""))
        #expect(svg.contains("clip-path=\"url(#area-burst-1)\""))
        let corner = AreaDiagrams.fill([GridSquare(column: 0, row: 0)], in: (columns: 0..<1, rows: 0..<1))
        #expect(corner == "M0 0h16v16h-16z")
    }

    @Test func originsAreMarked() throws {
        let line = try #require(AreaDiagram.all.last)
        #expect(AreaDiagrams.svg(line).components(separatedBy: "class=\"origin\"").count - 1 == 3)
        let large = AreaDiagram.all[2]
        #expect(AreaDiagrams.svg(large).contains("width=\"32\" height=\"32\"/><text class=\"creature\""))
        #expect(AreaDiagrams.svg(large).contains(">L</text>"))
    }
}
