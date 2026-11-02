import bb.cascades 1.3
import bb.system 1.2

// Playbook-Runs. Ohne runId die Liste der laufenden Runs, mit runId die Aufgaben dieses Runs.
// Ein Tipp auf eine Aufgabe hakt sie ab oder öffnet sie wieder. Oben stehen die Aktionen.
Page {
    id: pageRoot
    objectName: "runs"
    property string runId: ""
    property string runTitle: ""
    property variant navPane: null
    property bool empty: false
    property variant bookIds: []
    property variant bookTitles: []
    property string chosenBook: ""

    titleBar: TitleBar {
        title: pageRoot.runId == "" ? qsTr("Playbook runs") : pageRoot.runTitle
    }

    actionBarVisibility: ChromeVisibility.Compact

    attachedObjects: [
        ComponentDefinition {
            id: runDef
            source: "asset:///runs.qml"
        },
        SystemListDialog {
            id: bookDialog
            title: qsTr("Start a run")
            dismissOnSelection: true
            onFinished: {
                if (value != SystemUiResult.ItemSelection || selectedIndices.length == 0)
                    return
                var i = selectedIndices[0]
                pageRoot.chosenBook = pageRoot.bookIds[i]
                namePrompt.inputField.defaultText = pageRoot.bookTitles[i]
                namePrompt.show()
            }
        },
        SystemPrompt {
            id: namePrompt
            title: qsTr("Name of the run")
            inputField.inputMode: SystemUiInputMode.Default
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Start")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.startRun(pageRoot.chosenBook, inputFieldTextEntry())
            }
        },
        SystemPrompt {
            id: textPrompt
            property string mode: ""
            inputField.inputMode: SystemUiInputMode.Default
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Save")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value != SystemUiResult.ConfirmButtonSelection)
                    return
                var text = inputFieldTextEntry()
                if (textPrompt.mode == "status")
                    _mm.postRunStatus(pageRoot.runId, text)
                else if (textPrompt.mode == "name") {
                    _mm.updateRun(pageRoot.runId, "name", text)
                    if (text != "")
                        pageRoot.runTitle = text
                } else if (textPrompt.mode == "summary")
                    _mm.updateRun(pageRoot.runId, "summary", text)
            }
        },
        SystemDialog {
            id: finishDialog
            title: qsTr("Finish run")
            body: qsTr("The run ends for all participants.")
            confirmButton.label: qsTr("Finish")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection) {
                    _mm.finishRun(pageRoot.runId)
                    if (pageRoot.navPane)
                        pageRoot.navPane.pop()
                }
            }
        }
    ]

    function load() {
        resultModel.clear()
        empty = false
        if (runId == "")
            _mm.loadRuns()
        else
            takeTasks()
    }

    function fill(rows) {
        resultModel.clear()
        for (var i = 0; i < rows.length; ++i)
            resultModel.append(rows[i])
        empty = rows.length == 0
    }

    function takeTasks() {
        fill(_mm.runTasks(runId))
    }

    function takeRuns(rows) {
        if (runId == "")
            fill(rows)
        else
            takeTasks()
    }

    function takeBooks(rows) {
        if (runId != "")
            return
        var ids = []
        var titles = []
        bookDialog.clearList()
        for (var i = 0; i < rows.length; ++i) {
            ids.push(String(rows[i].id))
            titles.push(String(rows[i].title))
            bookDialog.appendItem(rows[i].title)
        }
        bookIds = ids
        bookTitles = titles
        if (rows.length > 0)
            bookDialog.show()
    }

    function askText(mode, title, current) {
        textPrompt.mode = mode
        textPrompt.title = title
        textPrompt.inputField.defaultText = current
        textPrompt.show()
    }

    function dropSignals() {
        _mm.runsLoaded.disconnect(takeRuns)
        _mm.playbooksLoaded.disconnect(takeBooks)
    }

    onCreationCompleted: {
        _mm.runsLoaded.connect(takeRuns)
        _mm.playbooksLoaded.connect(takeBooks)
    }

    Container {
        background: Color.White
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        layout: StackLayout {
            orientation: LayoutOrientation.TopToBottom
        }

        // Aktionen: in der Liste ein Run starten, im Run Status, Name, Zusammenfassung und Ende.
        Container {
            visible: pageRoot.runId == ""
            horizontalAlignment: HorizontalAlignment.Fill
            preferredHeight: 88
            leftPadding: 20
            layout: DockLayout {
            }
            Label {
                text: qsTr("Start a run")
                verticalAlignment: VerticalAlignment.Center
                textFormat: TextFormat.Plain
                textStyle.color: Color.create("#1c58d9")
                textStyle.fontSize: FontSize.Medium
            }
            gestureHandlers: [
                TapHandler {
                    onTapped: { _mm.traceLog("tap runs.qml start"); _mm.loadPlaybooks() }
                }
            ]
        }
        Container {
            visible: pageRoot.runId != ""
            horizontalAlignment: HorizontalAlignment.Fill
            leftPadding: 20
            rightPadding: 20
            topPadding: 8
            bottomPadding: 8
            layout: StackLayout {
                orientation: LayoutOrientation.LeftToRight
            }
            Label {
                text: qsTr("Status")
                textFormat: TextFormat.Plain
                textStyle.color: Color.create("#1c58d9")
                textStyle.fontSize: FontSize.Small
                layoutProperties: StackLayoutProperties {
                    spaceQuota: 1
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { _mm.traceLog("tap runs.qml status"); pageRoot.askText("status", qsTr("Status update"), "") }
                    }
                ]
            }
            Label {
                text: qsTr("Rename")
                textFormat: TextFormat.Plain
                textStyle.color: Color.create("#1c58d9")
                textStyle.fontSize: FontSize.Small
                layoutProperties: StackLayoutProperties {
                    spaceQuota: 1
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { _mm.traceLog("tap runs.qml rename"); pageRoot.askText("name", qsTr("Name of the run"), pageRoot.runTitle) }
                    }
                ]
            }
            Label {
                text: qsTr("Summary")
                textFormat: TextFormat.Plain
                textStyle.color: Color.create("#1c58d9")
                textStyle.fontSize: FontSize.Small
                layoutProperties: StackLayoutProperties {
                    spaceQuota: 1
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { _mm.traceLog("tap runs.qml summary"); pageRoot.askText("summary", qsTr("Summary"), _mm.runField(pageRoot.runId, "summary")) }
                    }
                ]
            }
            Label {
                text: qsTr("Finish")
                textFormat: TextFormat.Plain
                textStyle.color: Color.create("#d6322e")
                textStyle.fontSize: FontSize.Small
                gestureHandlers: [
                    TapHandler {
                        onTapped: { _mm.traceLog("tap runs.qml finish"); finishDialog.show() }
                    }
                ]
            }
        }

        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill
            layoutProperties: StackLayoutProperties {
                spaceQuota: 1
            }
            layout: DockLayout {
            }

            Label {
                visible: pageRoot.empty
                text: pageRoot.runId == "" ? qsTr("No running playbooks") : qsTr("No tasks")
                horizontalAlignment: HorizontalAlignment.Center
                verticalAlignment: VerticalAlignment.Center
                textStyle.color: Color.create("#8a929a")
            }

            ListView {
                horizontalAlignment: HorizontalAlignment.Fill
                verticalAlignment: VerticalAlignment.Fill
                scrollRole: ScrollRole.Main
                dataModel: ArrayDataModel {
                    id: resultModel
                }
                function itemType(data, indexPath) {
                    return data.type
                }
                listItemComponents: [
                    ListItemComponent {
                        type: "run"
                        CustomListItem {
                            dividerVisible: true
                            Container {
                                horizontalAlignment: HorizontalAlignment.Fill
                                leftPadding: 20
                                rightPadding: 20
                                topPadding: 14
                                bottomPadding: 14
                                Label {
                                    text: ListItemData.title
                                    textFormat: TextFormat.Plain
                                    textStyle.color: Color.create("#1b1f23")
                                    textStyle.fontSize: FontSize.Small
                                    textStyle.fontWeight: FontWeight.Bold
                                }
                                Label {
                                    text: ListItemData.subtitle
                                    textFormat: TextFormat.Plain
                                    textStyle.color: Color.create("#8a929a")
                                    textStyle.fontSize: FontSize.XSmall
                                }
                            }
                        }
                    },
                    ListItemComponent {
                        type: "head"
                        CustomListItem {
                            dividerVisible: false
                            highlightAppearance: HighlightAppearance.None
                            Container {
                                background: Color.create("#f3f5f7")
                                horizontalAlignment: HorizontalAlignment.Fill
                                preferredHeight: 56
                                leftPadding: 20
                                layout: DockLayout {
                                }
                                Label {
                                    text: ListItemData.title
                                    verticalAlignment: VerticalAlignment.Center
                                    textFormat: TextFormat.Plain
                                    textStyle.color: Color.create("#6b747d")
                                    textStyle.fontSize: FontSize.XSmall
                                    textStyle.fontWeight: FontWeight.Bold
                                }
                            }
                        }
                    },
                    ListItemComponent {
                        type: "task"
                        CustomListItem {
                            dividerVisible: true
                            Container {
                                horizontalAlignment: HorizontalAlignment.Fill
                                leftPadding: 20
                                rightPadding: 20
                                topPadding: 12
                                bottomPadding: 12
                                layout: StackLayout {
                                    orientation: LayoutOrientation.LeftToRight
                                }
                                Label {
                                    text: ListItemData.done ? "✓" : (ListItemData.skipped ? "–" : "○")
                                    verticalAlignment: VerticalAlignment.Center
                                    textStyle.color: Color.create(ListItemData.done ? "#2e7d32" : "#6b747d")
                                    textStyle.fontSize: FontSize.Large
                                    textStyle.fontWeight: FontWeight.Bold
                                }
                                Label {
                                    text: ListItemData.title
                                    multiline: true
                                    verticalAlignment: VerticalAlignment.Center
                                    leftMargin: 16
                                    textFormat: TextFormat.Plain
                                    textStyle.color: Color.create(ListItemData.done ? "#8a929a" : "#1b1f23")
                                    textStyle.fontSize: FontSize.Small
                                    layoutProperties: StackLayoutProperties {
                                        spaceQuota: 1
                                    }
                                }
                            }
                        }
                    }
                ]

                onTriggered: {
                    _mm.traceLog("tap runs.qml onTriggered")
                    var item = resultModel.data(indexPath)
                    if (!item)
                        return
                    if (item.type == "run" && pageRoot.navPane) {
                        var page = pageRoot.navPane.make(runDef)
                        if (!page)
                            return
                        page.runId = item.id
                        page.runTitle = item.title
                        page.navPane = pageRoot.navPane
                        page.load()
                        pageRoot.navPane.push(page)
                    } else if (item.type == "task") {
                        _mm.toggleTask(pageRoot.runId, item.checklist, item.item, item.done)
                    }
                }
            }
        }
    }
}
