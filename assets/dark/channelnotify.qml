import bb.cascades 1.3

// Benachrichtigungen eines Kanals. „Standard“ übernimmt die globale Einstellung.
Page {
    id: pageRoot
    objectName: "channelnotify"
    property string channelId: ""
    property string channelTitle: ""
    property string pushValue: "default"
    property string desktopValue: "default"
    property string markValue: "all"

    function load() {
        var prefs = _mm.channelNotify(channelId)
        pushValue = prefs.push ? prefs.push : "default"
        desktopValue = prefs.desktop ? prefs.desktop : "default"
        markValue = prefs.markUnread ? prefs.markUnread : "all"
        rebuild()
    }

    function addOption(key, current, value, label) {
        notifyModel.append({ type: "option", key: key, value: value, label: label,
                             selected: current == value })
    }

    // Die Liste wird aus den drei Werten neu aufgebaut, damit der Haken stimmt.
    function rebuild() {
        notifyModel.clear()
        notifyModel.append({ type: "head", title: qsTr("PUSH") })
        addOption("push", pushValue, "default", qsTr("Default"))
        addOption("push", pushValue, "all", qsTr("All messages"))
        addOption("push", pushValue, "mention", qsTr("Mentions only"))
        addOption("push", pushValue, "none", qsTr("Never"))
        notifyModel.append({ type: "head", title: qsTr("DESKTOP") })
        addOption("desktop", desktopValue, "default", qsTr("Default"))
        addOption("desktop", desktopValue, "all", qsTr("All messages"))
        addOption("desktop", desktopValue, "mention", qsTr("Mentions only"))
        addOption("desktop", desktopValue, "none", qsTr("Never"))
        notifyModel.append({ type: "head", title: qsTr("MARK AS UNREAD") })
        addOption("mark_unread", markValue, "all", qsTr("All messages"))
        addOption("mark_unread", markValue, "mention", qsTr("Mentions only"))
    }

    function choose(key, value) {
        if (key == "push")
            pushValue = value
        else if (key == "desktop")
            desktopValue = value
        else
            markValue = value
        rebuild()
        _mm.setChannelNotify(channelId, key, value)
    }

    titleBar: TitleBar {
        title: channelTitle
    }

    actionBarVisibility: ChromeVisibility.Default

    attachedObjects: [
        ArrayDataModel {
            id: notifyModel
        }
    ]

    ListView {
        id: notifyList
        scrollRole: ScrollRole.Main
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        dataModel: notifyModel

        function itemType(data, indexPath) {
            return data.type
        }

        listItemComponents: [
            ListItemComponent {
                type: "head"
                CustomListItem {
                    dividerVisible: false
                    highlightAppearance: HighlightAppearance.None
                    Container {
                        background: Color.create("#22262b")
                        horizontalAlignment: HorizontalAlignment.Fill
                        preferredHeight: 56
                        leftPadding: 20
                        layout: DockLayout {
                        }
                        Label {
                            text: ListItemData.title
                            verticalAlignment: VerticalAlignment.Center
                            textFormat: TextFormat.Plain
                            textStyle.color: Color.create("#9aa3ab")
                            textStyle.fontSize: FontSize.XSmall
                            textStyle.fontWeight: FontWeight.Bold
                        }
                    }
                }
            },
            ListItemComponent {
                type: "option"
                CustomListItem {
                    dividerVisible: true
                    Container {
                        preferredHeight: 88
                        horizontalAlignment: HorizontalAlignment.Fill
                        leftPadding: 20
                        rightPadding: 20
                        layout: DockLayout {
                        }
                        Label {
                            text: ListItemData.label
                            verticalAlignment: VerticalAlignment.Center
                            textFormat: TextFormat.Plain
                            textStyle.color: Color.create("#e6e9ec")
                            textStyle.fontSize: FontSize.Medium
                        }
                        Label {
                            text: "✓"
                            visible: ListItemData.selected
                            horizontalAlignment: HorizontalAlignment.Right
                            verticalAlignment: VerticalAlignment.Center
                            textStyle.color: Color.create("#6b9bf2")
                            textStyle.fontSize: FontSize.Large
                            textStyle.fontWeight: FontWeight.Bold
                        }
                    }
                }
            }
        ]

        onTriggered: {
            if (Qt.mm) Qt.mm.traceLog("tap channelnotify.qml:134 onTriggered")
            var item = notifyModel.data(indexPath)
            if (item && item.type == "option")
                pageRoot.choose(item.key, item.value)
        }
    }
}
