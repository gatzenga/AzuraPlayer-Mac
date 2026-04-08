import AppKit

func createMenuBarIcon() -> NSImage {
    let size = CGSize(width: 22, height: 22)

    let image = NSImage(size: size, flipped: false) { _ in
        NSColor.controlTextColor.setStroke()
        NSColor.controlTextColor.setFill()

        // Hexagon (Outline)
        drawHexagon(center: CGPoint(x: 11, y: 11), radius: 9.0, strokeWidth: 1.2)

        // Doppelnote (groß, dominant)
        drawDoubleNote()

        return true
    }

    image.isTemplate = true
    return image
}

private func drawHexagon(center: CGPoint, radius: CGFloat, strokeWidth: CGFloat) {
    let path = NSBezierPath()
    for i in 0..<6 {
        let angle = CGFloat(i) * (.pi / 3.0) + (.pi / 6.0)
        let x = center.x + radius * cos(angle)
        let y = center.y + radius * sin(angle)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
        else       { path.line(to: CGPoint(x: x, y: y)) }
    }
    path.close()
    path.lineWidth = strokeWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

private func drawDoubleNote() {
    // Beam: breites umgekehrtes U mit dickem Balken oben
    // Linker Stem bei x≈7, Rechter Stem bei x≈17
    // Balken oben von y≈17 bis y≈19 (mit Rundung)

    let stemW: CGFloat = 2.8         // Stem-Breite (dick!)
    let beamH: CGFloat = 2.8         // Balken-Höhe

    let leftX:  CGFloat = 7.0        // Linker Stem Mitte
    let rightX: CGFloat = 16.5       // Rechter Stem Mitte

    let stemBottomLeft:  CGFloat = 7.5   // Unterkante linker Stem
    let stemBottomRight: CGFloat = 9.0   // Unterkante rechter Stem (höher)
    let beamTop:         CGFloat = 19.0  // Oberkante Balken
    let beamBottom:      CGFloat = beamTop - beamH

    // Gesamtform: Wie ein "n" aber eckig mit runden Ecken oben
    // Als ein einziger Path: Balken + beide Stems
    let notePath = NSBezierPath()
    let r: CGFloat = 1.4  // Rundungsradius oben

    // Starte links unten am linken Stem
    notePath.move(to: CGPoint(x: leftX - stemW/2, y: stemBottomLeft))
    // Hoch zum Balken links
    notePath.line(to: CGPoint(x: leftX - stemW/2, y: beamBottom - r))
    // Runde Ecke oben-links
    notePath.appendArc(
        withCenter: CGPoint(x: leftX - stemW/2 + r, y: beamBottom - r),
        radius: r, startAngle: 180, endAngle: 90, clockwise: true
    )
    // Balken oben links → rechts (leicht schräg)
    notePath.line(to: CGPoint(x: rightX + stemW/2 - r, y: beamTop - r))
    // Runde Ecke oben-rechts
    notePath.appendArc(
        withCenter: CGPoint(x: rightX + stemW/2 - r, y: beamTop - r - r),
        radius: r, startAngle: 90, endAngle: 0, clockwise: true
    )
    // Rechter Stem runter
    notePath.line(to: CGPoint(x: rightX + stemW/2, y: stemBottomRight))
    // Rechter Stem rüber (Innen)
    notePath.line(to: CGPoint(x: rightX - stemW/2, y: stemBottomRight))
    // Hoch zur Balken-Unterseite rechts
    notePath.line(to: CGPoint(x: rightX - stemW/2, y: beamBottom))
    // Balken Unterseite rechts → links
    notePath.line(to: CGPoint(x: leftX + stemW/2, y: beamBottom - beamH * 0.15))
    // Linker Stem Innen runter
    notePath.line(to: CGPoint(x: leftX + stemW/2, y: stemBottomLeft))
    notePath.close()
    notePath.fill()

    // Linker Notenkopf (groß, ragt raus)
    fillOval(center: CGPoint(x: 6.5, y: 6.5), w: 6.0, h: 4.5)

    // Rechter Notenkopf (etwas kleiner)
    fillOval(center: CGPoint(x: 15.5, y: 8.5), w: 5.0, h: 3.8)
}

private func fillOval(center: CGPoint, w: CGFloat, h: CGFloat) {
    let rect = CGRect(x: center.x - w/2, y: center.y - h/2, width: w, height: h)
    NSBezierPath(ovalIn: rect).fill()
}
