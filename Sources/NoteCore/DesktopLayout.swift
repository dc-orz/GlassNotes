import CoreGraphics
import Foundation

public enum DesktopLayout {
    // Normalised top-left positions keep the entire note within a display's usable frame.
    public static func frame(for p: Placement, size: CGSize, in screen: CGRect) -> CGRect {
        let size = CGSize(width: min(size.width, screen.width), height: min(size.height, screen.height))
        let x = screen.minX + min(1, max(0, p.x)) * (screen.width - size.width)
        let top = screen.maxY - min(1, max(0, p.y)) * (screen.height - size.height)
        return CGRect(origin: CGPoint(x: x.rounded(), y: (top - size.height).rounded()), size: size)
    }

    public static func placement(of frame: CGRect, in screen: CGRect, display: String) -> Placement {
        let x = (frame.minX - screen.minX) / max(1, screen.width - frame.width)
        let y = (screen.maxY - frame.maxY) / max(1, screen.height - frame.height)
        return Placement(display: display, x: min(1, max(0, x)), y: min(1, max(0, y)))
    }

    public static func freeSpot(size: CGSize, screen: CGRect, display: String, occupied: [CGRect]) -> Placement {
        var best = Placement(display: display, x: 0.08, y: 0.1)
        var bestArea = CGFloat.infinity
        for row in 0..<7 {
            for column in 0..<8 {
                let point = Placement(
                    display: display, x: 0.04 + Double(column) * 0.13,
                    y: 0.05 + Double(row) * 0.15)
                let candidate = frame(for: point, size: size, in: screen).insetBy(dx: -8, dy: -8)
                let area = occupied.reduce(CGFloat.zero) { total, other in
                    let overlap = candidate.intersection(other)
                    return total + (overlap.isNull ? 0 : overlap.width * overlap.height)
                }
                if area == 0 { return point }
                if area < bestArea {
                    best = point
                    bestArea = area
                }
            }
        }
        return best
    }
}
