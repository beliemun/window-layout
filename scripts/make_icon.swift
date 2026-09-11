// 앱 아이콘 생성: macOS 스타일 둥근 사각형 배경 위에 2×2 그리드.
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS 아이콘 표준 여백(약 10%)을 둔 둥근 사각형
let inset: CGFloat = size * 0.1
let bg = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
                      xRadius: size * 0.2, yRadius: size * 0.2)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.01), blur: size * 0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
bg.fill()
ctx.restoreGState()

let gradient = NSGradient(colors: [NSColor(calibratedWhite: 0.20, alpha: 1), NSColor(calibratedWhite: 0.09, alpha: 1)])!
gradient.draw(in: bg, angle: -90)

// 2×2 셀
let gridInset = size * 0.24
let gap = size * 0.045
let area = NSRect(x: gridInset, y: gridInset, width: size - gridInset * 2, height: size - gridInset * 2)
let cellW = (area.width - gap) / 2
let cellH = (area.height - gap) / 2
let cellGradient = NSGradient(colors: [NSColor(calibratedRed: 0.42, green: 0.62, blue: 1.0, alpha: 1),
                                       NSColor(calibratedRed: 0.20, green: 0.44, blue: 0.95, alpha: 1)])!
for row in 0..<2 {
    for col in 0..<2 {
        let rect = NSRect(x: area.minX + CGFloat(col) * (cellW + gap),
                          y: area.minY + CGFloat(row) * (cellH + gap),
                          width: cellW, height: cellH)
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.05, yRadius: size * 0.05)
        cellGradient.draw(in: path, angle: -90)
    }
}
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
