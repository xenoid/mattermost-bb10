import bb.cascades 1.3

// Offene Teams, denen der Nutzer noch nicht angehört. Ein Tipp tritt dem Team bei.
Page {
    id: pageRoot
    objectName: "jointeam"
    property bool empty: false

    titleBar: TitleBar {
        title: qsTr("Join a team")
    }

    actionBarVisibility: ChromeVisibility.Compact

    function load() {
        resultModel.clear()
        empty = false
        _mm.loadOpenTeams()
    }

    function takeRows(rows) {
        resultModel.clear()
        for (var i = 0; i < rows.length; ++i)
            resultModel.append(rows[i])
        empty = rows.length == 0
    }

    function dropSignals() {
        _mm.openTeamsLoaded.disconnect(takeRows)
    }

    onCreationCompleted: {
        _mm.openTeamsLoaded.connect(takeRows)
    }

    Container {
        background: Color.White
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        layout: DockLayout {
        }

        Label {
            visible: empty
            text: qsTr("No teams to join")
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
                return "team"
            }
            listItemComponents: [
                ListItemComponent {
                    type: "team"
                    CustomListItem {
                        dividerVisible: true
                        Container {
                            horizontalAlignment: HorizontalAlignment.Fill
                            leftPadding: 20
                            rightPadding: 20
                            topPadding: 14
                            bottomPadding: 14
                            layout: StackLayout {
                                orientation: LayoutOrientation.TopToBottom
                            }
                            Label {
                                text: ListItemData.title
                                textFormat: TextFormat.Plain
                                textStyle.color: Color.create("#1b1f23")
                                textStyle.fontSize: FontSize.Small
                                textStyle.fontWeight: FontWeight.Bold
                            }
                            Label {
                                text: ListItemData.subtitle
                                visible: ListItemData.subtitle != ""
                                textFormat: TextFormat.Plain
                                textStyle.color: Color.create("#8a929a")
                                textStyle.fontSize: FontSize.XSmall
                            }
                        }
                    }
                }
            ]

            onTriggered: {
                if (Qt.mm) Qt.mm.traceLog("tap jointeam.qml:94 onTriggered")
                var item = resultModel.data(indexPath)
                if (item && item.id)
                    _mm.joinTeam(item.id)
            }
        }
    }
}
