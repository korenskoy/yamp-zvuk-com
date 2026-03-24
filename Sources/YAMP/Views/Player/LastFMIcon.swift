import SwiftUI

struct LastFMIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        // Original viewBox: 0 0 512 512
        let sx = w / 512
        let sy = h / 512

        var path = Path()

        path.move(to: CGPoint(x: 308.214 * sx, y: 337.861 * sy))
        path.addLine(to: CGPoint(x: 302.551 * sx, y: 324.797 * sy))
        path.addLine(to: CGPoint(x: 253.93 * sx, y: 209.107 * sy))
        path.addCurve(
            to: CGPoint(x: 152.732 * sx, y: 140.506 * sy),
            control1: CGPoint(x: 237.874 * sx, y: 168.176 * sy),
            control2: CGPoint(x: 197.845 * sx, y: 140.506 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 42.156 * sx, y: 256.03 * sy),
            control1: CGPoint(x: 91.689 * sx, y: 140.506 * sy),
            control2: CGPoint(x: 42.156 * sx, y: 192.212 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 152.732 * sx, y: 371.523 * sy),
            control1: CGPoint(x: 42.156 * sx, y: 319.786 * sy),
            control2: CGPoint(x: 91.689 * sx, y: 371.523 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 250.794 * sx, y: 309.516 * sy),
            control1: CGPoint(x: 195.35 * sx, y: 371.523 * sy),
            control2: CGPoint(x: 232.336 * sx, y: 346.359 * sy)
        )
        path.addLine(to: CGPoint(x: 270.462 * sx, y: 356.845 * sy))
        path.addCurve(
            to: CGPoint(x: 152.733 * sx, y: 415.0 * sy),
            control1: CGPoint(x: 242.586 * sx, y: 392.371 * sy),
            control2: CGPoint(x: 200.164 * sx, y: 415.0 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 0.5 * sx, y: 256.031 * sy),
            control1: CGPoint(x: 68.645 * sx, y: 415.0 * sy),
            control2: CGPoint(x: 0.5 * sx, y: 343.886 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 152.731 * sx, y: 96.998 * sy),
            control1: CGPoint(x: 0.5 * sx, y: 168.197 * sy),
            control2: CGPoint(x: 68.645 * sx, y: 96.998 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 293.472 * sx, y: 195.091 * sy),
            control1: CGPoint(x: 216.177 * sx, y: 96.998 * sy),
            control2: CGPoint(x: 267.427 * sx, y: 132.359 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 343.306 * sx, y: 315.46 * sy),
            control1: CGPoint(x: 295.418 * sx, y: 199.956 * sy),
            control2: CGPoint(x: 320.988 * sx, y: 262.346 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 407.082 * sx, y: 371.483 * sy),
            control1: CGPoint(x: 357.094 * sx, y: 348.316 * sy),
            control2: CGPoint(x: 368.843 * sx, y: 370.138 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 470.331 * sx, y: 318.835 * sy),
            control1: CGPoint(x: 444.523 * sx, y: 372.808 * sy),
            control2: CGPoint(x: 470.331 * sx, y: 348.999 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 417.506 * sx, y: 270.793 * sy),
            control1: CGPoint(x: 470.331 * sx, y: 289.385 * sy),
            control2: CGPoint(x: 450.631 * sx, y: 282.293 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 327.198 * sx, y: 180.392 * sy),
            control1: CGPoint(x: 357.963 * sx, y: 250.307 * sy),
            control2: CGPoint(x: 327.198 * sx, y: 229.728 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 409.493 * sx, y: 100.187 * sy),
            control1: CGPoint(x: 327.198 * sx, y: 132.277 * sy),
            control2: CGPoint(x: 358.501 * sx, y: 100.187 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 483.249 * sx, y: 146.356 * sy),
            control1: CGPoint(x: 442.63 * sx, y: 100.187 * sy),
            control2: CGPoint(x: 466.655 * sx, y: 115.611 * sy)
        )
        path.addLine(to: CGPoint(x: 450.631 * sx, y: 163.726 * sy))
        path.addCurve(
            to: CGPoint(x: 407.661 * sx, y: 138.726 * sy),
            control1: CGPoint(x: 438.396 * sx, y: 145.817 * sy),
            control2: CGPoint(x: 424.866 * sx, y: 138.726 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 366.721 * sx, y: 179.191 * sy),
            control1: CGPoint(x: 383.727 * sx, y: 138.726 * sy),
            control2: CGPoint(x: 366.721 * sx, y: 156.107 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 434.069 * sx, y: 230.37 * sy),
            control1: CGPoint(x: 366.721 * sx, y: 211.996 * sy),
            control2: CGPoint(x: 394.816 * sx, y: 216.933 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 511.5 * sx, y: 320.171 * sy),
            control1: CGPoint(x: 486.935 * sx, y: 248.351 * sy),
            control2: CGPoint(x: 511.5 * sx, y: 268.899 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 409.494 * sx, y: 413.181 * sy),
            control1: CGPoint(x: 511.5 * sx, y: 374.031 * sy),
            control2: CGPoint(x: 467.268 * sx, y: 413.264 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 308.214 * sx, y: 337.861 * sy),
            control1: CGPoint(x: 356.256 * sx, y: 412.942 * sy),
            control2: CGPoint(x: 327.861 * sx, y: 385.769 * sy)
        )
        path.closeSubpath()

        return path
    }
}
