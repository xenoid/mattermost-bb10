import bb.cascades 1.3

Page {
    objectName: "search"
    property bool empty: false

    titleBar: TitleBar {
        title: qsTr("Search")
    }

    actionBarVisibility: ChromeVisibility.Compact

    Container {
        background: Color.White
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        layout: DockLayout {
        }

        Label {
            visible: empty
            text: qsTr("No results")
            horizontalAlignment: HorizontalAlignment.Center
            verticalAlignment: VerticalAlignment.Center
            textStyle.color: Color.create("#8a929a")
        }

        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill
            layout: StackLayout {
                orientation: LayoutOrientation.TopToBottom
            }

            StatusBanner {
            }

            ListView {
                id: resultList
                scrollRole: ScrollRole.Main
                horizontalAlignment: HorizontalAlignment.Fill
                layoutProperties: StackLayoutProperties {
                    spaceQuota: 1
                }
                dataModel: ArrayDataModel {
                    id: resultModel
                }
                function itemType(data, indexPath) {
                    return "result"
                }
                listItemComponents: [
                    ListItemComponent {
                        type: "result"
                        CustomListItem {
                            dividerVisible: true
                            Container {
                                horizontalAlignment: HorizontalAlignment.Fill
                                leftPadding: 20
                                rightPadding: 20
                                topPadding: 14
                                bottomPadding: 14
                                layout: StackLayout {
                                    orientation: LayoutOrientation.LeftToRight
                                }

                                Container {
                                    preferredWidth: 64
                                    preferredHeight: 64
                                    layout: DockLayout {
                                    }
                                    ImageView {
                                        imageSource: ListItemData.disc
                                        preferredWidth: 64
                                        preferredHeight: 64
                                        scalingMethod: ScalingMethod.AspectFill
                                    }
                                    Label {
                                        visible: ListItemData.avatar == ""
                                        text: ListItemData.initial
                                        textFormat: TextFormat.Plain
                                        horizontalAlignment: HorizontalAlignment.Center
                                        verticalAlignment: VerticalAlignment.Center
                                        textStyle.color: Color.White
                                        textStyle.fontSize: FontSize.Medium
                                        textStyle.fontWeight: FontWeight.Bold
                                    }
                                    ImageView {
                                        visible: ListItemData.avatar != ""
                                        imageSource: ListItemData.avatar
                                        preferredWidth: 64
                                        preferredHeight: 64
                                        scalingMethod: ScalingMethod.AspectFill
                                    }
                                }

                                Container {
                                    leftMargin: 14
                                    layoutProperties: StackLayoutProperties {
                                        spaceQuota: 1
                                    }
                                    Container {
                                        horizontalAlignment: HorizontalAlignment.Fill
                                        layout: StackLayout {
                                            orientation: LayoutOrientation.LeftToRight
                                        }
                                        Label {
                                            text: ListItemData.title
                                            textFormat: TextFormat.Plain
                                            layoutProperties: StackLayoutProperties {
                                                spaceQuota: 1
                                            }
                                            textStyle.color: Color.create("#1b1f23")
                                            textStyle.fontSize: FontSize.Small
                                            textStyle.fontWeight: FontWeight.Bold
                                        }
                                        Label {
                                            text: ListItemData.whenFull
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.color: Color.create("#8a929a")
                                            textStyle.fontSize: FontSize.XSmall
                                        }
                                    }
                                    Label {
                                        text: ListItemData.channelTitle
                                        textFormat: TextFormat.Plain
                                        textStyle.color: Color.create("#1c58d9")
                                        textStyle.fontSize: FontSize.XSmall
                                        textStyle.fontWeight: FontWeight.Bold
                                    }
                                    Label {
                                        text: ListItemData.message
                                        textFormat: TextFormat.Html
                                        multiline: true
                                        autoSize.maxLineCount: 3
                                        textStyle.fontSize: FontSize.Small
                                    }
                                }
                            }
                        }
                    }
                ]
                onTriggered: {
                    var item = resultModel.data(indexPath)
                    if (!item || !item.channelId)
                        return
                    _mm.openFromSearch(item.channelId, item.channelTitle, item.id)
                }
            }
        }
    }

    function takeRows(rows) {
        resultModel.clear()
        for (var i = 0; i < rows.length; ++i)
            resultModel.append(rows[i])
        empty = rows.length == 0
    }

    function takeAvatar(userId, path) {
        for (var i = 0; i < resultModel.size(); ++i) {
            var row = resultModel.data([i])
            if (row && row.userId == userId && row.avatar != path) {
                row.avatar = path
                resultModel.replace(i, row)
            }
        }
    }

    function dropSignals() {
        _mm.searchLoaded.disconnect(takeRows)
        _mm.avatarReady.disconnect(takeAvatar)
    }

    onCreationCompleted: {
        _mm.searchLoaded.connect(takeRows)
        _mm.avatarReady.connect(takeAvatar)
    }
}
