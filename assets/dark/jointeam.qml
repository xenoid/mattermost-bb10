import bb.cascades 1.3
import bb.system 1.2

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

    attachedObjects: [
        SystemPrompt {
            id: invitePrompt
            title: qsTr("Invite link")
            body: qsTr("Paste the team invite link.")
            inputField.inputMode: SystemUiInputMode.Url
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Join")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.joinTeamByInvite(inputFieldTextEntry())
            }
        }
    ]

    Container {
        background: Color.create("#16191d")
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        layout: DockLayout {
        }

        Label {
            visible: empty
            text: qsTr("No teams to join")
            horizontalAlignment: HorizontalAlignment.Center
            verticalAlignment: VerticalAlignment.Center
            textStyle.color: Color.create("#80898f")
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
                                textStyle.color: Color.create("#e6e9ec")
                                textStyle.fontSize: FontSize.Small
                                textStyle.fontWeight: FontWeight.Bold
                            }
                            Label {
                                text: ListItemData.subtitle
                                visible: ListItemData.subtitle != ""
                                textFormat: TextFormat.Plain
                                textStyle.color: Color.create("#80898f")
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

        Label {
            text: qsTr("Join with an invite link")
            horizontalAlignment: HorizontalAlignment.Center
            verticalAlignment: VerticalAlignment.Bottom
            bottomMargin: 30
            textFormat: TextFormat.Plain
            textStyle.color: Color.create("#6b9bf2")
            textStyle.fontSize: FontSize.Medium
            gestureHandlers: [
                TapHandler {
                    onTapped: { _mm.traceLog("tap jointeam invite"); invitePrompt.show() }
                }
            ]
        }
    }
}
