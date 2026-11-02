import bb.cascades 1.3

// Schmaler Hinweisstreifen: grau beim Laden, rot bei Fehlern. Unsichtbar ohne Status.
Container {
    id: banner
    property bool busy: _mm.status.length > 0 && _mm.status.charAt(_mm.status.length - 1) == "\u2026"

    visible: _mm.status != ""
    horizontalAlignment: HorizontalAlignment.Fill
    background: Color.create(busy ? "#eef1f4" : "#fbe9e7")
    leftPadding: 20
    rightPadding: 20
    topPadding: 8
    bottomPadding: 8

    Label {
        text: _mm.status
        multiline: true
        textFormat: TextFormat.Plain
        textStyle.fontSize: FontSize.Small
        textStyle.color: Color.create(banner.busy ? "#a2aab1" : "#8a1f17")
    }
}
