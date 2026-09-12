import Testing
@testable import TrekEngine

@Suite("Course math")
struct CourseTests {
    @Test("Integer courses map to the compass")
    func integerVectors() {
        #expect(Course.vector(1) == Vector(dRow: 0, dCol: 1))
        #expect(Course.vector(3) == Vector(dRow: -1, dCol: 0))
        #expect(Course.vector(5) == Vector(dRow: 0, dCol: -1))
        #expect(Course.vector(7) == Vector(dRow: 1, dCol: 0))
        #expect(Course.vector(9) == Vector(dRow: 0, dCol: 1))
    }

    @Test("Fractional course interpolates between neighbours")
    func fractionalVector() {
        let v = Course.vector(1.5)
        #expect(v.dRow == -0.5)
        #expect(v.dCol == 1)
    }

    @Test("Course validation")
    func validation() {
        #expect(Course.normalized(9) == 1)
        #expect(Course.normalized(0) == nil)
        #expect(Course.normalized(9.1) == nil)
        #expect(Course.normalized(-2) == nil)
        #expect(Course.normalized(4.25) == 4.25)
    }

    @Test("Heading round-trips every integer course")
    func headingRoundTrip() {
        let origin = SectorPosition(row: 4, col: 4)
        for course in 1...8 {
            let v = Course.vector(Double(course))
            let target = SectorPosition(row: origin.row + Int(v.dRow) * 2, col: origin.col + Int(v.dCol) * 2)
            let data = Course.heading(from: origin, to: target)
            #expect(data.course == Double(course), "course \(course)")
        }
    }

    @Test("Heading matches the listing's worked cases")
    func headingMatchesListing() {
        // (5,5) -> (3,7): X=2, A=2, |A|<=|X| -> 1 + 2/2 = 2
        #expect(Course.heading(from: SectorPosition(row: 5, col: 5), to: SectorPosition(row: 3, col: 7)).course == 2)
        // (5,5) -> (2,6): X=1, A=3 -> 1 + ((3-1)+3)/3 = 2.666...
        let steep = Course.heading(from: SectorPosition(row: 5, col: 5), to: SectorPosition(row: 2, col: 6))
        #expect(abs(steep.course - (1 + 5.0 / 3.0)) < 1e-9)
        // Directly right but one row down: 9 - 1/7 -> wraps under 9
        let shallow = Course.heading(from: SectorPosition(row: 1, col: 1), to: SectorPosition(row: 2, col: 8))
        #expect(abs(shallow.course - (9 - 1.0 / 7.0)) < 1e-9)
        #expect(abs(shallow.distance - 50.0.squareRoot()) < 1e-9)
    }

    @Test("Same point yields no heading")
    func samePoint() {
        let data = Course.heading(from: SectorPosition(row: 2, col: 2), to: SectorPosition(row: 2, col: 2))
        #expect(data.course == 0)
        #expect(data.distance == 0)
    }
}
