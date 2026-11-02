import bb.cascades 1.3
import bb.system 1.2
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
        SystemListDialog {
            id: rewriteDialog
            title: qsTr("Rewrite with AI")
            dismissOnSelection: true
            onCreationCompleted: {
                appendItem(qsTr("Shorten"))
                appendItem(qsTr("Elaborate"))
                appendItem(qsTr("Improve writing"))
                appendItem(qsTr("Fix spelling"))
                appendItem(qsTr("Simplify"))
            }
            onFinished: {
                if (value != SystemUiResult.ItemSelection || selectedIndices.length == 0)
                    return
                var actions = ["shorten", "elaborate", "improve_writing", "fix_spelling", "simplify"]
                _mm.rewriteDraft(caption, actions[selectedIndices[0]], replyRoot)
                if (navPane)
                    navPane.pop()
            }
        },
        SystemPrompt {
            id: schedulePrompt
            title: qsTr("Send later")
            body: qsTr("Time like 18:30, or minutes like 45")
            inputField.inputMode: SystemUiInputMode.Default
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Schedule")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection && _mm.setNextSchedule(inputFieldTextEntry()) && navPane)
                    navPane.pop()
            }
        },
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
        background: Color.create("#16191d")
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
                background: Color.create("#6b9bf2")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
            }
            Label {
                text: qsTr("Image")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
                textStyle.fontSize: FontSize.Large
                textStyle.color: Color.create("#e6e9ec")
            }
        }

        Container {
            preferredHeight: 1
            background: Color.create("#30353b")
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
                background: Color.create("#9aa3ab")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
            }
            Label {
                text: qsTr("File")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
                textStyle.fontSize: FontSize.Large
                textStyle.color: Color.create("#e6e9ec")
            }
        }

        Container {
            preferredHeight: 1
            background: Color.create("#30353b")
            horizontalAlignment: HorizontalAlignment.Fill
        }

        // KI-Umformulierung des Entwurfs (braucht Agents auf dem Server).
        Container {
            visible: caption != ""
            horizontalAlignment: HorizontalAlignment.Fill
            preferredHeight: 100
            layout: StackLayout {
                orientation: LayoutOrientation.LeftToRight
            }
            gestureHandlers: [
                TapHandler {
                    onTapped: { _mm.traceLog("tap attach.qml rewrite"); rewriteDialog.show() }
                }
            ]
            Container {
                preferredWidth: 8
                preferredHeight: 48
                background: Color.create("#6b9bf2")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
            }
            Label {
                text: qsTr("Rewrite with AI")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
                textStyle.fontSize: FontSize.Large
                textStyle.color: Color.create("#e6e9ec")
            }
        }

        // Sprachnachricht: erster Tipp startet, zweiter beendet und hängt die Datei an.
        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            preferredHeight: 100
            layout: StackLayout {
                orientation: LayoutOrientation.LeftToRight
            }
            gestureHandlers: [
                TapHandler {
                    onTapped: {
                        _mm.traceLog("tap attach.qml voice recording=" + _mm.recording)
                        if (!_mm.recording) {
                            _mm.startRecording()
                            return
                        }
                        var path = _mm.stopRecording()
                        if (path != "")
                            chosen([path])
                    }
                }
            ]
            Container {
                preferredWidth: 8
                preferredHeight: 48
                background: Color.create(_mm.recording ? "#d6322e" : "#2e7d32")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
            }
            Label {
                text: _mm.recording ? qsTr("Recording… tap to stop and attach") : qsTr("Record voice message")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
                textStyle.fontSize: FontSize.Large
                textStyle.color: Color.create(_mm.recording ? "#d6322e" : "#e6e9ec")
            }
        }

        Container {
            preferredHeight: 1
            background: Color.create("#30353b")
            horizontalAlignment: HorizontalAlignment.Fill
        }

        // Später senden: die nächste Nachricht im Kanal geht zur gewählten Zeit raus (Server ab 10.3).
        Container {
            visible: replyRoot == ""
            horizontalAlignment: HorizontalAlignment.Fill
            preferredHeight: 100
            layout: StackLayout {
                orientation: LayoutOrientation.LeftToRight
            }
            gestureHandlers: [
                TapHandler {
                    onTapped: { _mm.traceLog("tap attach.qml schedule"); schedulePrompt.show() }
                }
            ]
            Container {
                preferredWidth: 8
                preferredHeight: 48
                background: Color.create("#6a4fb3")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
            }
            Label {
                text: qsTr("Send later")
                verticalAlignment: VerticalAlignment.Center
                leftMargin: 32
                textStyle.fontSize: FontSize.Large
                textStyle.color: Color.create("#e6e9ec")
            }
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
                textStyle.color: Color.create("#e6e9ec")
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
                textStyle.color: Color.create("#e6e9ec")
            }
        }
    }

    // Verlässt man die Seite während der Aufnahme, endet sie ohne Anhang.
    function dropSignals() {
        if (_mm.recording)
            _mm.stopRecording()
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
