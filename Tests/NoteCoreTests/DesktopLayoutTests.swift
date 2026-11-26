import CoreGraphics
import NoteCore
import Testing

struct DesktopLayoutTests {
    let screen = CGRect(x: -1920, y: 42, width: 1920, height: 1030)
    let size = CGSize(width: 280, height: 152)

    @Test func placementSurvivesNegativeDisplayOriginsAndRounding() {
        let p = Placement(display: "left", x: 0.21, y: 0.67)
        let frame = DesktopLayout.frame(for: p, size: size, in: screen)
        let result = DesktopLayout.placement(of: frame, in: screen, display: "left")
        #expect(abs(result.x - p.x) < 0.002)
        #expect(abs(result.y - p.y) < 0.002)
        #expect(screen.contains(frame))
    }

    @Test func freeSpotAvoidsExistingNotes() {
        var frames: [CGRect] = []
        for _ in 0..<8 {
            let p = DesktopLayout.freeSpot(size: size, screen: screen, display: "test", occupied: frames)
            let next = DesktopLayout.frame(for: p, size: size, in: screen)
            #expect(frames.allSatisfy { !$0.intersects(next) })
            frames.append(next)
        }
    }

    @Test func invalidPositionAndOversizedNoteRemainReachable() {
        let small = CGRect(x: 10, y: -50, width: 100, height: 90)
        let p = Placement(display: "smaller", x: 30, y: -2)
        #expect(DesktopLayout.frame(for: p, size: size, in: small) == small)
    }
}
