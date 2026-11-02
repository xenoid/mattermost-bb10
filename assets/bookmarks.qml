import bb.cascades 1.3

// Lesezeichen eines Kanals, nur lesen. Ein Tipp öffnet den Link im Browser.
Page {
    id: pageRoot
    objectName: "bookmarks"
    property string channelId: ""
    property string channelTitle: ""
    property bool empty: false

    titleBar: TitleBar {
        title: qsTr("Bookmarks") + " · " + pageRoot.channelTitle
    }

    actionBarVisibility: ChromeVisibility.Compact

    function load() {
        resultModel.clear()
        empty = false
        _mm.loadBookmarks(channelId)
    }

    function takeRows(rows) {
        resultModel.clear()
        for (var i = 0; i < rows.length; ++i)
            resultModel.append(rows[i])
        empty = rows.length == 0
    }

    function dropSignals() {
        _mm.bookmarksLoaded.disconnect(takeRows)
    }

    onCreationCompleted: {
        _mm.bookmarksLoaded.connect(takeRows)
    }

    Container {
        background: Color.White
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        layout: DockLayout {
        }

        Label {
            visible: pageRoot.empty
            text: qsTr("No bookmarks")
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
                return "mark"
            }
            listItemComponents: [
                ListItemComponent {
                    type: "mark"
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
                                textFormat: TextFormat.Plain
                                textStyle.color: Color.create("#8a929a")
                                textStyle.fontSize: FontSize.XSmall
                            }
                        }
                    }
                }
            ]

            onTriggered: {
                _mm.traceLog("tap bookmarks.qml onTriggered")
                var item = resultModel.data(indexPath)
                if (item && item.url != "")
                    _mm.openLink(item.url)
            }
        }
    }
}
