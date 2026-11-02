import bb.cascades 1.3
import bb.cascades.pickers 1.0

// Anhang wie in den BlackBerry-Messengern: eigene Seite, zurück per Chevron.
// Nur was der Client wirklich schickt. Bild und Datei.
Page {
    objectName: "attach"
    property variant navPane: null
    property variant host: null
    property string caption: ""
    property string replyRoot: ""

    titleBar: TitleBar {
        title: qsTr("Send")
    }

    actionBarVisibility: ChromeVisibility.Default

    attachedObjects: [
        FilePicker {
            id: picturePicker
            type: FileType.Picture
            mode: FilePickerMode.Picker
            title: qsTr("Image")
            onFileSelected: chosen(selectedFiles)
        },
        FilePicker {
            id: docPicker
            type: FileType.Document
            mode: FilePickerMode.Picker
            title: qsTr("File")
            onFileSelected: chosen(selectedFiles)
        }
    ]

    Container {
        background: Color.White
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        topPadding: 12

        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            preferredHeight: 100
            layout: StackLayout {
                orientation: LayoutOrientation.LeftToRight
            }
            gestureHandlers: [
                TapHandler {
                    onTapped: { if (Qt.mm) Qt.mm.traceLog("tap attach.qml:50 onTapped"); picturePicker.open() }
                }
            ]
            Container {
                preferredWidth: 8
                preferredHeight: 48
                background: Color.create("#1c58d9")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
            }
            Label {
                text: qsTr("Image")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
                textStyle.fontSize: FontSize.Large
                textStyle.color: Color.create("#1b1f23")
            }
        }

        Container {
            preferredHeight: 1
            background: Color.create("#e6eaee")
            horizontalAlignment: HorizontalAlignment.Fill
        }

        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            preferredHeight: 100
            layout: StackLayout {
                orientation: LayoutOrientation.LeftToRight
            }
            gestureHandlers: [
                TapHandler {
                    onTapped: { if (Qt.mm) Qt.mm.traceLog("tap attach.qml:83 onTapped"); docPicker.open() }
                }
            ]
            Container {
                preferredWidth: 8
                preferredHeight: 48
                background: Color.create("#6b747d")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
            }
            Label {
                text: qsTr("File")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
                textStyle.fontSize: FontSize.Large
                textStyle.color: Color.create("#1b1f23")
            }
        }

        Container {
            preferredHeight: 1
            background: Color.create("#e6eaee")
            horizontalAlignment: HorizontalAlignment.Fill
        }

        // Priorität gilt für die nächste Nachricht im Kanal. Antworten haben keine Priorität.
        Container {
            visible: replyRoot == ""
            horizontalAlignment: HorizontalAlignment.Fill
            preferredHeight: 100
            layout: StackLayout {
                orientation: LayoutOrientation.LeftToRight
            }
            gestureHandlers: [
                TapHandler {
                    onTapped: { _mm.traceLog("tap attach.qml important"); _mm.setNextPriority("important"); if (navPane) navPane.pop() }
                }
            ]
            Container {
                preferredWidth: 8
                preferredHeight: 48
                background: Color.create("#b9822a")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
            }
            Label {
                text: qsTr("Send as important")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
                textStyle.fontSize: FontSize.Large
                textStyle.color: Color.create("#1b1f23")
            }
        }

        Container {
            visible: replyRoot == ""
            horizontalAlignment: HorizontalAlignment.Fill
            preferredHeight: 100
            layout: StackLayout {
                orientation: LayoutOrientation.LeftToRight
            }
            gestureHandlers: [
                TapHandler {
                    onTapped: { _mm.traceLog("tap attach.qml urgent"); _mm.setNextPriority("urgent"); if (navPane) navPane.pop() }
                }
            ]
            Container {
                preferredWidth: 8
                preferredHeight: 48
                background: Color.create("#d6322e")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
            }
            Label {
                text: qsTr("Send as urgent")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
                textStyle.fontSize: FontSize.Large
                textStyle.color: Color.create("#1b1f23")
            }
        }
    }

    function chosen(files) {
        if (!files || files.length == 0)
            return
        if (!host || !host.holdFile(files[0]))
            return
        if (navPane)
            navPane.pop()
    }
}
