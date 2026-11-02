import bb.cascades 1.3

// Kopfzeile oder Zweck eines Kanals bearbeiten. Sichern schickt den Text an den Server.
Page {
    id: pageRoot
    objectName: "channeltext"
    property string channelId: ""
    property string field: "header"
    property string current: ""
    property variant navPane: null

    titleBar: TitleBar {
        title: pageRoot.field == "header" ? qsTr("Channel header") : qsTr("Channel purpose")
    }

    actionBarVisibility: ChromeVisibility.Compact

    Container {
        background: Color.White
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        layout: StackLayout {
            orientation: LayoutOrientation.TopToBottom
        }

        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            leftPadding: 20
            rightPadding: 20
            topPadding: 20
            bottomPadding: 20
            layout: DockLayout {
            }
            TextField {
                id: editor
                text: pageRoot.current
                horizontalAlignment: HorizontalAlignment.Fill
                verticalAlignment: VerticalAlignment.Center
            }
        }

        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            preferredHeight: 88
            leftPadding: 20
            rightPadding: 20
            layout: DockLayout {
            }
            Label {
                text: qsTr("Save")
                verticalAlignment: VerticalAlignment.Center
                textFormat: TextFormat.Plain
                textStyle.color: Color.create("#1c58d9")
                textStyle.fontSize: FontSize.Medium
            }
            gestureHandlers: [
                TapHandler {
                    onTapped: {
                        _mm.traceLog("tap channeltext.qml:58 onTapped")
                        _mm.traceLog("channeltext save field=" + pageRoot.field + " channel=" + pageRoot.channelId + " text=" + editor.text)
                        _mm.setChannelText(pageRoot.channelId, pageRoot.field, editor.text)
                        if (pageRoot.navPane)
                            pageRoot.navPane.pop()
                    }
                }
            ]
        }
    }
}
