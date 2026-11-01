import bb.cascades 1.3

// Mitglieder eines Kanals. Nur die Liste: Hinzufügen und Entfernen fehlen noch.
Page {
    id: pageRoot
    objectName: "members"
    property string channelId: ""
    property string channelTitle: ""
    property bool empty: false

    titleBar: TitleBar {
        title: channelTitle
    }

    actionBarVisibility: ChromeVisibility.Compact

    function load() {
        resultModel.clear()
        empty = false
        _mm.loadMembers(channelId)
    }

    function takeRows(rows) {
        resultModel.clear()
        for (var i = 0; i < rows.length; ++i)
            resultModel.append(rows[i])
        empty = rows.length == 0
    }

    function dropSignals() {
        _mm.membersLoaded.disconnect(takeRows)
    }

    onCreationCompleted: {
        _mm.membersLoaded.connect(takeRows)
    }

    Container {
        background: Color.White
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        layout: DockLayout {
        }

        Label {
            visible: empty
            text: qsTr("No members")
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
                return "member"
            }
            listItemComponents: [
                ListItemComponent {
                    type: "member"
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
        }
    }
}
