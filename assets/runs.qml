import bb.cascades 1.3

// Playbook-Runs. Ohne runId die Liste der laufenden Runs, mit runId die Aufgaben dieses Runs.
// Ein Tipp auf eine Aufgabe hakt sie ab oder öffnet sie wieder.
Page {
    id: pageRoot
    objectName: "runs"
    property string runId: ""
    property string runTitle: ""
    property variant navPane: null
    property bool empty: false

    titleBar: TitleBar {
        title: pageRoot.runId == "" ? qsTr("Playbook runs") : pageRoot.runTitle
    }

    actionBarVisibility: ChromeVisibility.Compact

    attachedObjects: [
        ComponentDefinition {
            id: runDef
            source: "asset:///runs.qml"
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

    function dropSignals() {
        _mm.runsLoaded.disconnect(takeRuns)
    }

    onCreationCompleted: {
        _mm.runsLoaded.connect(takeRuns)
    }

    Container {
        background: Color.White
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
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
