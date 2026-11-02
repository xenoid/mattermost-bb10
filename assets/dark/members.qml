import bb.cascades 1.3
import bb.system 1.2

// Mitglieder eines Kanals. Hinzufügen per Benutzername, Entfernen per Tipp und Bestätigung.
Page {
    id: pageRoot
    objectName: "members"
    property string channelId: ""
    property string channelTitle: ""
    property bool canManage: false
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

    attachedObjects: [
        SystemPrompt {
            id: addPrompt
            title: qsTr("Add member")
            body: qsTr("Username of the member")
            inputField.inputMode: SystemUiInputMode.Default
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Add")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.addMember(pageRoot.channelId, inputFieldTextEntry())
            }
        },
        SystemDialog {
            id: removeDialog
            property string removeId: ""
            title: qsTr("Remove member")
            body: qsTr("Remove this member from the channel?")
            confirmButton.label: qsTr("Remove")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.removeMember(pageRoot.channelId, removeDialog.removeId)
            }
        }
    ]

    Container {
        background: Color.create("#16191d")
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        layout: StackLayout {
            orientation: LayoutOrientation.TopToBottom
        }

        Container {
            visible: pageRoot.canManage
            horizontalAlignment: HorizontalAlignment.Fill
            preferredHeight: 88
            leftPadding: 20
            rightPadding: 20
            layout: DockLayout {
            }
            Label {
                text: qsTr("Add member")
                verticalAlignment: VerticalAlignment.Center
                textFormat: TextFormat.Plain
                textStyle.color: Color.create("#6b9bf2")
                textStyle.fontSize: FontSize.Medium
            }
            gestureHandlers: [
                TapHandler {
                    onTapped: { if (Qt.mm) Qt.mm.traceLog("tap members.qml:93 onTapped"); addPrompt.show() }
                }
            ]
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
                text: qsTr("No members")
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
                    if (Qt.mm) Qt.mm.traceLog("tap members.qml:158 onTriggered")
                    var item = resultModel.data(indexPath)
                    if (item && item.userId && pageRoot.canManage) {
                        removeDialog.removeId = item.userId
                        removeDialog.show()
                    }
                }
            }
        }
    }
}
