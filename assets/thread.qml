import bb.cascades 1.3
import bb.system 1.2

// Unterhaltung ohne Aktionsleiste. Zurück ist der Wisch nach rechts.
// Ist die Emoji-Tafel offen, ist der Wisch aus, der Smiley schließt sie zuerst.
// Anhang und Emoji sitzen an der Eingabe. Plus öffnet die Seite „Senden“.
Page {
    id: pageRoot
    objectName: "thread"
    property string rootId: ""
    property bool forceEnd: false
    property variant navPane: null
    property string heldPath: ""
    property string heldName: ""
    property bool heldImage: false
    property string focusPost: ""
    property string markedPost: ""
    property int focusTries: 0
    property bool focusHold: false
    property bool focusSent: false

    onRootIdChanged: objectName = rootId == "" ? "thread" : "replies"

    // Keine Titelleiste und keine Aktionsleiste. Die Eingabe sitzt am unteren Rand.
    titleBar: TitleBar {
        visibility: ChromeVisibility.Hidden
    }

    actionBarVisibility: ChromeVisibility.Hidden

    // Falls die Plattform den Zurück-Pfad trotzdem auslöst: erst die Tafel, dann die Seite.
    paneProperties: NavigationPaneProperties {
        backButton: ActionItem {
            title: qsTr("Back")
            onTriggered: goBack()
        }
    }

    attachedObjects: [
        ComponentDefinition {
            id: attachDef
            source: "asset:///attach.qml"
        }
    ]

    Container {
        background: Color.White
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        layout: StackLayout {
            orientation: LayoutOrientation.TopToBottom
        }

        StatusBanner {
        }

        Label {
            visible: rootId == "" && _mm.hasOlder
            text: qsTr("Older messages")
            horizontalAlignment: HorizontalAlignment.Center
            topMargin: 8
            bottomMargin: 4
            textStyle.color: Color.create("#1c58d9")
            textStyle.fontSize: FontSize.Small
            gestureHandlers: [
                TapHandler {
                    onTapped: _mm.loadOlder()
                }
            ]
        }
        Label {
            visible: rootId == "" && _mm.hasNewer
            text: qsTr("Newer messages")
            horizontalAlignment: HorizontalAlignment.Center
            topMargin: 4
            bottomMargin: 4
            textStyle.color: Color.create("#1c58d9")
            textStyle.fontSize: FontSize.Small
            gestureHandlers: [
                TapHandler {
                    onTapped: _mm.loadNewer()
                }
            ]
        }

            ListView {
            id: postList
            scrollRole: ScrollRole.Main
            // Ohne den Puffer springt None, bevor die Zeilenhöhen stehen.
            bufferedScrollingEnabled: true
            horizontalAlignment: HorizontalAlignment.Fill
            layoutProperties: StackLayoutProperties {
                spaceQuota: 1
            }
            dataModel: ArrayDataModel {
                id: postModel
            }
            attachedObjects: [
                LayoutUpdateHandler {
                    id: postLayout
                    onLayoutFrameChanged: jumpToFocus(false)
                },
                ListScrollStateHandler {
                    id: scrollState
                    onFirstVisibleItemChanged: jumpToFocus(false)
                }
            ]
            function itemType(data, indexPath) {
                if (data && data.type)
                    return data.type
                return "post"
            }
            function askReact(postId) {
                _mm.askReact(postId)
            }
            function toggleReact(postId, name) {
                _mm.toggleReaction(postId, name)
            }
            function askReplies(rootId) {
                _mm.askReplies(rootId)
            }
            function openImage(imageId) {
                _mm.openImage(imageId)
            }
            function openAttachment(fileId, name, mime) {
                _mm.openAttachment(fileId, name, mime)
            }
            function openLink(url) {
                _mm.openLink(url)
            }
            function openRow(item) {
                if (!item || item.type != "post" || item.pending == "1")
                    return
                if (item.imageId && item.imageId.length > 0 && item.imageId != "local")
                    _mm.openImage(item.imageId)
                else if (item.attachId && item.attachId.length > 0 && item.attachId != "local")
                    _mm.openAttachment(item.attachId, item.attachName, item.attachMime)
                else if (item.link && item.link.length > 0)
                    _mm.openLink(item.link)
                else if (item.inThread != "1" && item.threadRoot && (item.threadMark || item.isReply))
                    _mm.askReplies(item.threadRoot)
            }
            listItemComponents: [
                ListItemComponent {
                    type: "day"
                    CustomListItem {
                        dividerVisible: false
                        highlightAppearance: HighlightAppearance.None
                        Container {
                            horizontalAlignment: HorizontalAlignment.Fill
                            preferredHeight: 56
                            background: Color.create("#f3f5f7")
                            layout: DockLayout {
                            }
                            Label {
                                text: ListItemData.title
                                textFormat: TextFormat.Plain
                                horizontalAlignment: HorizontalAlignment.Center
                                verticalAlignment: VerticalAlignment.Center
                                textStyle.color: Color.create("#6b747d")
                                textStyle.fontSize: FontSize.XSmall
                                textStyle.fontWeight: FontWeight.Bold
                            }
                        }
                    }
                },
                ListItemComponent {
                    type: "post"
                    CustomListItem {
                        id: postItem
                        dividerVisible: false
                        contextActions: [
                            ActionSet {
                                title: qsTr("Message")
                                ActionItem {
                                    title: qsTr("Reply")
                                    enabled: ListItemData.inThread != "1" && ListItemData.pending != "1"
                                    onTriggered: postItem.ListItem.view.askReplies(ListItemData.threadRoot)
                                }
                                ActionItem {
                                    title: qsTr("React")
                                    enabled: ListItemData.pending != "1"
                                    onTriggered: postItem.ListItem.view.askReact(ListItemData.id)
                                }
                                ActionItem {
                                    title: qsTr("Open image")
                                    enabled: ListItemData.imageId != "" && ListItemData.imageId != "local"
                                    onTriggered: postItem.ListItem.view.openImage(ListItemData.imageId)
                                }
                                ActionItem {
                                    title: qsTr("Image 2")
                                    enabled: ListItemData.imageId2 != ""
                                    onTriggered: postItem.ListItem.view.openImage(ListItemData.imageId2)
                                }
                                ActionItem {
                                    title: qsTr("Open attachment")
                                    enabled: ListItemData.attachId != "" && ListItemData.attachId != "local"
                                    onTriggered: postItem.ListItem.view.openAttachment(ListItemData.attachId, ListItemData.attachName, ListItemData.attachMime)
                                }
                                ActionItem {
                                    title: qsTr("Attachment 2")
                                    enabled: ListItemData.attachId2 != ""
                                    onTriggered: postItem.ListItem.view.openAttachment(ListItemData.attachId2, ListItemData.attachName2, ListItemData.attachMime2)
                                }
                                ActionItem {
                                    title: qsTr("Open link")
                                    enabled: ListItemData.link != ""
                                    onTriggered: postItem.ListItem.view.openLink(ListItemData.link)
                                }
                            }
                        ]
                        Container {
                            horizontalAlignment: HorizontalAlignment.Fill
                            leftPadding: 16
                            rightPadding: 16
                            topPadding: ListItemData.grouped ? 2 : 16
                            bottomPadding: 4
                            background: ListItemData.mark == "1" ? Color.create("#e7eefc") : Color.create("#ffffff")
                            layout: StackLayout {
                                orientation: LayoutOrientation.LeftToRight
                            }

                            Container {
                                visible: ListItemData.mark == "1"
                                preferredWidth: ListItemData.mark == "1" ? 6 : 0
                                background: Color.create("#1c58d9")
                                verticalAlignment: VerticalAlignment.Fill
                                rightMargin: ListItemData.mark == "1" ? 10 : 0
                            }

                            // Profilbild links, bei Folgenachrichten derselben Person leer
                            Container {
                                preferredWidth: 68
                                layout: DockLayout {
                                }
                                Container {
                                    visible: !ListItemData.grouped
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
                            }

                            Container {
                                leftMargin: 12
                                layoutProperties: StackLayoutProperties {
                                    spaceQuota: 1
                                }

                                Container {
                                    visible: !ListItemData.grouped
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
                                        textStyle.color: Color.create(ListItemData.mine ? "#1544a8" : "#1b1f23")
                                        textStyle.fontSize: FontSize.Small
                                        textStyle.fontWeight: FontWeight.Bold
                                    }
                                    Label {
                                        text: ListItemData.whenTime
                                        textFormat: TextFormat.Plain
                                        verticalAlignment: VerticalAlignment.Center
                                        textStyle.color: Color.create("#8a929a")
                                        textStyle.fontSize: FontSize.XSmall
                                    }
                                }

                                Label {
                                    visible: ListItemData.quote != ""
                                    text: ListItemData.quote
                                    textFormat: TextFormat.Plain
                                    multiline: true
                                    autoSize.maxLineCount: 1
                                    textStyle.color: Color.create("#6b747d")
                                    textStyle.fontSize: FontSize.XSmall
                                    textStyle.fontStyle: FontStyle.Italic
                                }

                                Label {
                                    visible: ListItemData.message != ""
                                    text: ListItemData.message
                                    textFormat: TextFormat.Html
                                    content.flags: TextContentFlag.ActiveText | TextContentFlag.EmoticonsOff
                                    multiline: true
                                    horizontalAlignment: HorizontalAlignment.Fill
                                }

                                Container {
                                    visible: ListItemData.imageId != ""
                                    topMargin: 8
                                    preferredWidth: ListItemData.imgW
                                    preferredHeight: ListItemData.imgH
                                    background: Color.create("#eceff2")
                                    layout: DockLayout {
                                    }
                                    Label {
                                        visible: ListItemData.imagePath == ""
                                        text: qsTr("Image loading")
                                        textFormat: TextFormat.Plain
                                        horizontalAlignment: HorizontalAlignment.Center
                                        verticalAlignment: VerticalAlignment.Center
                                        textStyle.color: Color.create("#8a929a")
                                        textStyle.fontSize: FontSize.XSmall
                                    }
                                    ImageView {
                                        visible: ListItemData.imagePath != ""
                                        imageSource: ListItemData.imagePath
                                        preferredWidth: ListItemData.imgW
                                        preferredHeight: ListItemData.imgH
                                        scalingMethod: ScalingMethod.AspectFit
                                    }
                                }
                                Label {
                                    visible: ListItemData.extraImages != ""
                                    text: ListItemData.extraImages
                                    textFormat: TextFormat.Plain
                                    textStyle.color: Color.create("#1c58d9")
                                    textStyle.fontSize: FontSize.XSmall
                                }

                                Container {
                                    visible: ListItemData.attachId != ""
                                    topMargin: 8
                                    horizontalAlignment: HorizontalAlignment.Fill
                                    background: Color.create("#eef2fc")
                                    leftPadding: 16
                                    rightPadding: 16
                                    topPadding: 10
                                    bottomPadding: 10
                                    Label {
                                        text: ListItemData.attachName
                                        textFormat: TextFormat.Plain
                                        textStyle.color: Color.create("#1544a8")
                                        textStyle.fontSize: FontSize.Small
                                        textStyle.fontWeight: FontWeight.Bold
                                    }
                                    Label {
                                        text: ListItemData.attachInfo + " \u00b7 zum \u00d6ffnen tippen"
                                        textFormat: TextFormat.Plain
                                        textStyle.color: Color.create("#6b747d")
                                        textStyle.fontSize: FontSize.XSmall
                                    }
                                }

                                Label {
                                    visible: ListItemData.threadMark != ""
                                    text: ListItemData.threadMark
                                    textFormat: TextFormat.Plain
                                    textStyle.color: Color.create("#1c58d9")
                                    textStyle.fontSize: FontSize.XSmall
                                    textStyle.fontWeight: FontWeight.Bold
                                }
                                Container {
                                    visible: ListItemData.r0 != ""
                                    topMargin: 8
                                    layout: GridLayout {
                                        columnCount: 4
                                    }
                                    Container {
                                        visible: ListItemData.r0 != ""
                                        background: Color.create(ListItemData.ro0 == "1" ? "#e7eefc" : "#f3f5f7")
                                        leftPadding: 10
                                        rightPadding: 10
                                        topPadding: 4
                                        bottomPadding: 4
                                        leftMargin: 4
                                        topMargin: 4
                                        touchPropagationMode: TouchPropagationMode.None
                                        layout: StackLayout {
                                            orientation: LayoutOrientation.LeftToRight
                                        }
                                        ImageView {
                                            visible: ListItemData.ri0 != ""
                                            imageSource: ListItemData.ri0
                                            preferredWidth: 36
                                            preferredHeight: 36
                                            scalingMethod: ScalingMethod.AspectFit
                                            verticalAlignment: VerticalAlignment.Center
                                        }
                                        Label {
                                            visible: ListItemData.ri0 == ""
                                            text: ListItemData.rg0 != "" ? ListItemData.rg0 : ListItemData.r0
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.Small
                                            textStyle.color: Color.create(ListItemData.ro0 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        Label {
                                            text: ListItemData.rn0
                                            leftMargin: 6
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.XSmall
                                            textStyle.color: Color.create(ListItemData.ro0 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        gestureHandlers: [
                                            TapHandler {
                                                onTapped: postItem.ListItem.view.toggleReact(ListItemData.id, ListItemData.r0)
                                            }
                                        ]
                                    }
                                    Container {
                                        visible: ListItemData.r1 != ""
                                        background: Color.create(ListItemData.ro1 == "1" ? "#e7eefc" : "#f3f5f7")
                                        leftPadding: 10
                                        rightPadding: 10
                                        topPadding: 4
                                        bottomPadding: 4
                                        leftMargin: 4
                                        topMargin: 4
                                        touchPropagationMode: TouchPropagationMode.None
                                        layout: StackLayout {
                                            orientation: LayoutOrientation.LeftToRight
                                        }
                                        ImageView {
                                            visible: ListItemData.ri1 != ""
                                            imageSource: ListItemData.ri1
                                            preferredWidth: 36
                                            preferredHeight: 36
                                            scalingMethod: ScalingMethod.AspectFit
                                            verticalAlignment: VerticalAlignment.Center
                                        }
                                        Label {
                                            visible: ListItemData.ri1 == ""
                                            text: ListItemData.rg1 != "" ? ListItemData.rg1 : ListItemData.r1
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.Small
                                            textStyle.color: Color.create(ListItemData.ro1 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        Label {
                                            text: ListItemData.rn1
                                            leftMargin: 6
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.XSmall
                                            textStyle.color: Color.create(ListItemData.ro1 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        gestureHandlers: [
                                            TapHandler {
                                                onTapped: postItem.ListItem.view.toggleReact(ListItemData.id, ListItemData.r1)
                                            }
                                        ]
                                    }
                                    Container {
                                        visible: ListItemData.r2 != ""
                                        background: Color.create(ListItemData.ro2 == "1" ? "#e7eefc" : "#f3f5f7")
                                        leftPadding: 10
                                        rightPadding: 10
                                        topPadding: 4
                                        bottomPadding: 4
                                        leftMargin: 4
                                        topMargin: 4
                                        touchPropagationMode: TouchPropagationMode.None
                                        layout: StackLayout {
                                            orientation: LayoutOrientation.LeftToRight
                                        }
                                        ImageView {
                                            visible: ListItemData.ri2 != ""
                                            imageSource: ListItemData.ri2
                                            preferredWidth: 36
                                            preferredHeight: 36
                                            scalingMethod: ScalingMethod.AspectFit
                                            verticalAlignment: VerticalAlignment.Center
                                        }
                                        Label {
                                            visible: ListItemData.ri2 == ""
                                            text: ListItemData.rg2 != "" ? ListItemData.rg2 : ListItemData.r2
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.Small
                                            textStyle.color: Color.create(ListItemData.ro2 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        Label {
                                            text: ListItemData.rn2
                                            leftMargin: 6
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.XSmall
                                            textStyle.color: Color.create(ListItemData.ro2 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        gestureHandlers: [
                                            TapHandler {
                                                onTapped: postItem.ListItem.view.toggleReact(ListItemData.id, ListItemData.r2)
                                            }
                                        ]
                                    }
                                    Container {
                                        visible: ListItemData.r3 != ""
                                        background: Color.create(ListItemData.ro3 == "1" ? "#e7eefc" : "#f3f5f7")
                                        leftPadding: 10
                                        rightPadding: 10
                                        topPadding: 4
                                        bottomPadding: 4
                                        leftMargin: 4
                                        topMargin: 4
                                        touchPropagationMode: TouchPropagationMode.None
                                        layout: StackLayout {
                                            orientation: LayoutOrientation.LeftToRight
                                        }
                                        ImageView {
                                            visible: ListItemData.ri3 != ""
                                            imageSource: ListItemData.ri3
                                            preferredWidth: 36
                                            preferredHeight: 36
                                            scalingMethod: ScalingMethod.AspectFit
                                            verticalAlignment: VerticalAlignment.Center
                                        }
                                        Label {
                                            visible: ListItemData.ri3 == ""
                                            text: ListItemData.rg3 != "" ? ListItemData.rg3 : ListItemData.r3
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.Small
                                            textStyle.color: Color.create(ListItemData.ro3 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        Label {
                                            text: ListItemData.rn3
                                            leftMargin: 6
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.XSmall
                                            textStyle.color: Color.create(ListItemData.ro3 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        gestureHandlers: [
                                            TapHandler {
                                                onTapped: postItem.ListItem.view.toggleReact(ListItemData.id, ListItemData.r3)
                                            }
                                        ]
                                    }
                                    Container {
                                        visible: ListItemData.r4 != ""
                                        background: Color.create(ListItemData.ro4 == "1" ? "#e7eefc" : "#f3f5f7")
                                        leftPadding: 10
                                        rightPadding: 10
                                        topPadding: 4
                                        bottomPadding: 4
                                        leftMargin: 4
                                        topMargin: 4
                                        touchPropagationMode: TouchPropagationMode.None
                                        layout: StackLayout {
                                            orientation: LayoutOrientation.LeftToRight
                                        }
                                        ImageView {
                                            visible: ListItemData.ri4 != ""
                                            imageSource: ListItemData.ri4
                                            preferredWidth: 36
                                            preferredHeight: 36
                                            scalingMethod: ScalingMethod.AspectFit
                                            verticalAlignment: VerticalAlignment.Center
                                        }
                                        Label {
                                            visible: ListItemData.ri4 == ""
                                            text: ListItemData.rg4 != "" ? ListItemData.rg4 : ListItemData.r4
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.Small
                                            textStyle.color: Color.create(ListItemData.ro4 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        Label {
                                            text: ListItemData.rn4
                                            leftMargin: 6
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.XSmall
                                            textStyle.color: Color.create(ListItemData.ro4 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        gestureHandlers: [
                                            TapHandler {
                                                onTapped: postItem.ListItem.view.toggleReact(ListItemData.id, ListItemData.r4)
                                            }
                                        ]
                                    }
                                    Container {
                                        visible: ListItemData.r5 != ""
                                        background: Color.create(ListItemData.ro5 == "1" ? "#e7eefc" : "#f3f5f7")
                                        leftPadding: 10
                                        rightPadding: 10
                                        topPadding: 4
                                        bottomPadding: 4
                                        leftMargin: 4
                                        topMargin: 4
                                        touchPropagationMode: TouchPropagationMode.None
                                        layout: StackLayout {
                                            orientation: LayoutOrientation.LeftToRight
                                        }
                                        ImageView {
                                            visible: ListItemData.ri5 != ""
                                            imageSource: ListItemData.ri5
                                            preferredWidth: 36
                                            preferredHeight: 36
                                            scalingMethod: ScalingMethod.AspectFit
                                            verticalAlignment: VerticalAlignment.Center
                                        }
                                        Label {
                                            visible: ListItemData.ri5 == ""
                                            text: ListItemData.rg5 != "" ? ListItemData.rg5 : ListItemData.r5
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.Small
                                            textStyle.color: Color.create(ListItemData.ro5 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        Label {
                                            text: ListItemData.rn5
                                            leftMargin: 6
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.XSmall
                                            textStyle.color: Color.create(ListItemData.ro5 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        gestureHandlers: [
                                            TapHandler {
                                                onTapped: postItem.ListItem.view.toggleReact(ListItemData.id, ListItemData.r5)
                                            }
                                        ]
                                    }
                                    Container {
                                        visible: ListItemData.r6 != ""
                                        background: Color.create(ListItemData.ro6 == "1" ? "#e7eefc" : "#f3f5f7")
                                        leftPadding: 10
                                        rightPadding: 10
                                        topPadding: 4
                                        bottomPadding: 4
                                        leftMargin: 4
                                        topMargin: 4
                                        touchPropagationMode: TouchPropagationMode.None
                                        layout: StackLayout {
                                            orientation: LayoutOrientation.LeftToRight
                                        }
                                        ImageView {
                                            visible: ListItemData.ri6 != ""
                                            imageSource: ListItemData.ri6
                                            preferredWidth: 36
                                            preferredHeight: 36
                                            scalingMethod: ScalingMethod.AspectFit
                                            verticalAlignment: VerticalAlignment.Center
                                        }
                                        Label {
                                            visible: ListItemData.ri6 == ""
                                            text: ListItemData.rg6 != "" ? ListItemData.rg6 : ListItemData.r6
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.Small
                                            textStyle.color: Color.create(ListItemData.ro6 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        Label {
                                            text: ListItemData.rn6
                                            leftMargin: 6
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.XSmall
                                            textStyle.color: Color.create(ListItemData.ro6 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        gestureHandlers: [
                                            TapHandler {
                                                onTapped: postItem.ListItem.view.toggleReact(ListItemData.id, ListItemData.r6)
                                            }
                                        ]
                                    }
                                    Container {
                                        visible: ListItemData.r7 != ""
                                        background: Color.create(ListItemData.ro7 == "1" ? "#e7eefc" : "#f3f5f7")
                                        leftPadding: 10
                                        rightPadding: 10
                                        topPadding: 4
                                        bottomPadding: 4
                                        leftMargin: 4
                                        topMargin: 4
                                        touchPropagationMode: TouchPropagationMode.None
                                        layout: StackLayout {
                                            orientation: LayoutOrientation.LeftToRight
                                        }
                                        ImageView {
                                            visible: ListItemData.ri7 != ""
                                            imageSource: ListItemData.ri7
                                            preferredWidth: 36
                                            preferredHeight: 36
                                            scalingMethod: ScalingMethod.AspectFit
                                            verticalAlignment: VerticalAlignment.Center
                                        }
                                        Label {
                                            visible: ListItemData.ri7 == ""
                                            text: ListItemData.rg7 != "" ? ListItemData.rg7 : ListItemData.r7
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.Small
                                            textStyle.color: Color.create(ListItemData.ro7 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        Label {
                                            text: ListItemData.rn7
                                            leftMargin: 6
                                            textFormat: TextFormat.Plain
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.fontSize: FontSize.XSmall
                                            textStyle.color: Color.create(ListItemData.ro7 == "1" ? "#1c58d9" : "#5e6770")
                                        }
                                        gestureHandlers: [
                                            TapHandler {
                                                onTapped: postItem.ListItem.view.toggleReact(ListItemData.id, ListItemData.r7)
                                            }
                                        ]
                                    }
                                    Label {
                                        visible: ListItemData.rmore != ""
                                        text: ListItemData.rmore
                                        textFormat: TextFormat.Plain
                                        verticalAlignment: VerticalAlignment.Center
                                        textStyle.color: Color.create("#5e6770")
                                        textStyle.fontSize: FontSize.XSmall
                                    }
                                }
                                Container {
                                    visible: ListItemData.imageId2 != ""
                                    topMargin: 8
                                    preferredWidth: ListItemData.imgW2
                                    preferredHeight: ListItemData.imgH2
                                    background: Color.create("#eceff2")
                                    layout: DockLayout {
                                    }
                                    ImageView {
                                        visible: ListItemData.imagePath2 != ""
                                        imageSource: ListItemData.imagePath2
                                        preferredWidth: ListItemData.imgW2
                                        preferredHeight: ListItemData.imgH2
                                        scalingMethod: ScalingMethod.AspectFit
                                    }
                                }
                                Container {
                                    visible: ListItemData.attachId2 != ""
                                    topMargin: 8
                                    horizontalAlignment: HorizontalAlignment.Fill
                                    background: Color.create("#eef2fc")
                                    leftPadding: 16
                                    rightPadding: 16
                                    topPadding: 10
                                    bottomPadding: 10
                                    Label {
                                        text: ListItemData.attachName2
                                        textFormat: TextFormat.Plain
                                        textStyle.color: Color.create("#1544a8")
                                        textStyle.fontSize: FontSize.Small
                                        textStyle.fontWeight: FontWeight.Bold
                                    }
                                    Label {
                                        text: ListItemData.attachInfo2 + " \u00b7 wischen zum \u00d6ffnen"
                                        textFormat: TextFormat.Plain
                                        textStyle.color: Color.create("#6b747d")
                                        textStyle.fontSize: FontSize.XSmall
                                    }
                                }
                            }
                        }
                    }
                }
            ]
            onTriggered: {
                openRow(postModel.data(indexPath))
            }
        }

        // ------------------------------------------------ Emoji, klappt über der Eingabe auf
        Container {
            id: emojiPanel
            visible: false
            preferredHeight: 420
            minHeight: 420
            maxHeight: 420
            background: Color.create("#f4f6f8")
            horizontalAlignment: HorizontalAlignment.Fill
            layout: StackLayout {
                orientation: LayoutOrientation.TopToBottom
            }
            Container {
                preferredHeight: 1
                background: Color.create("#dfe3e7")
                horizontalAlignment: HorizontalAlignment.Fill
            }
            TextField {
                id: emojiSearch
                hintText: qsTr("Search emoji")
                leftMargin: 12
                rightMargin: 12
                topMargin: 8
                bottomMargin: 4
                onTextChanging: filterEmoji(text)
            }
            ListView {
                id: emojiList
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 340
                dataModel: ArrayDataModel {
                    id: emojiModel
                }
                layout: FlowListLayout {
                    headerMode: ListHeaderMode.None
                    orientation: LayoutOrientation.TopToBottom
                }
                function itemType(data, indexPath) {
                    return "emoji"
                }
                listItemComponents: [
                    ListItemComponent {
                        type: "emoji"
                        Container {
                            preferredWidth: 80
                            preferredHeight: 72
                            layout: DockLayout {
                            }
                            ImageView {
                                visible: ListItemData.image != ""
                                imageSource: ListItemData.image
                                preferredWidth: 64
                                preferredHeight: 64
                                horizontalAlignment: HorizontalAlignment.Center
                                verticalAlignment: VerticalAlignment.Center
                                scalingMethod: ScalingMethod.AspectFit
                            }
                            Label {
                                visible: ListItemData.image == ""
                                text: ListItemData.glyph != "" ? ListItemData.glyph : ListItemData.name
                                textFormat: TextFormat.Plain
                                horizontalAlignment: HorizontalAlignment.Center
                                verticalAlignment: VerticalAlignment.Center
                                textStyle.fontSize: ListItemData.glyph != "" ? FontSize.XLarge : FontSize.XSmall
                                textStyle.color: Color.create("#1b1f23")
                                textStyle.textAlign: TextAlign.Center
                            }
                        }
                    }
                ]
                onTriggered: {
                    var item = emojiModel.data(indexPath)
                    if (!item)
                        return
                    if (item.glyph)
                        insertEmoji(item.glyph)
                    else if (item.name)
                        insertEmoji(":" + item.name + ":")
                }
            }
        }

        // ------------------------------------------------ Eingabe
        Container {
            background: Color.White
            horizontalAlignment: HorizontalAlignment.Fill
            Container {
                preferredHeight: 1
                background: Color.create("#dfe3e7")
                horizontalAlignment: HorizontalAlignment.Fill
            }
            Container {
                visible: heldPath != ""
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 12
                rightPadding: 12
                topPadding: 8
                bottomPadding: 8
                background: Color.create("#f4f6f8")
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Container {
                    verticalAlignment: VerticalAlignment.Center
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                    layout: StackLayout {
                        orientation: LayoutOrientation.LeftToRight
                    }
                    ImageView {
                        visible: heldImage
                        imageSource: heldPath.indexOf("://") < 0 ? ("file://" + heldPath) : heldPath
                        preferredWidth: 88
                        preferredHeight: 88
                        scalingMethod: ScalingMethod.AspectFit
                        verticalAlignment: VerticalAlignment.Center
                    }
                    Label {
                        visible: !heldImage
                        text: heldName
                        textFormat: TextFormat.Plain
                        verticalAlignment: VerticalAlignment.Center
                        textStyle.color: Color.create("#1b1f23")
                        textStyle.fontSize: FontSize.Small
                    }
                }
                Label {
                    text: qsTr("Remove")
                    verticalAlignment: VerticalAlignment.Center
                    leftMargin: 12
                    textStyle.color: Color.create("#1c58d9")
                    textStyle.fontSize: FontSize.Small
                    gestureHandlers: [
                        TapHandler {
                            onTapped: clearHeld()
                        }
                    ]
                }
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 6
                rightPadding: 8
                topPadding: 6
                bottomPadding: 6
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                ImageButton {
                    defaultImageSource: _mm.iconPlus
                    preferredWidth: 72
                    preferredHeight: 72
                    verticalAlignment: VerticalAlignment.Center
                    onClicked: openSend()
                }
                ImageButton {
                    defaultImageSource: _mm.iconEmoji
                    preferredWidth: 72
                    preferredHeight: 72
                    verticalAlignment: VerticalAlignment.Center
                    onClicked: toggleEmoji()
                }
                TextField {
                    id: composer
                    hintText: rootId == "" ? qsTr("Write a message") : qsTr("Write a reply")
                    verticalAlignment: VerticalAlignment.Center
                    input.submitKey: SubmitKey.Send
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                    input.onSubmitted: send()
                    onFocusedChanged: {
                        if (focused)
                            emojiPanel.visible = false
                        syncPeek()
                    }
                }
                ImageButton {
                    defaultImageSource: _mm.iconSend
                    preferredWidth: 84
                    preferredHeight: 84
                    verticalAlignment: VerticalAlignment.Center
                    leftMargin: 8
                    onClicked: send()
                }
            }
        }
    }

    function syncPeek() {
        if (navPane)
            navPane.peekEnabled = !emojiPanel.visible
    }

    function goBack() {
        if (emojiPanel.visible) {
            emojiPanel.visible = false
            syncPeek()
            return
        }
        if (navPane)
            navPane.pop()
    }

    function fileLabel(path) {
        var p = path
        if (p.indexOf("file://") == 0)
            p = p.substring(7)
        try {
            p = decodeURIComponent(p)
        } catch (e) {
        }
        var cut = p.lastIndexOf("/")
        return cut >= 0 ? p.substring(cut + 1) : p
    }

    function holdFile(source) {
        var staged = _mm.stageFile(source)
        if (!staged || staged.length == 0)
            return false
        if (heldPath != "")
            _mm.dropStaged(heldPath)
        heldPath = staged
        heldName = fileLabel(source)
        heldImage = _mm.fileIsImage(staged)
        composer.focused = true
        return true
    }

    function clearHeld() {
        if (heldPath != "")
            _mm.dropStaged(heldPath)
        heldPath = ""
        heldName = ""
        heldImage = false
    }

    function consumeCaption() {
        composer.text = ""
    }

    function openSend() {
        emojiPanel.visible = false
        syncPeek()
        if (!navPane)
            return
        var page = attachDef.createObject()
        if (!page)
            return
        page.navPane = navPane
        page.host = pageRoot
        page.caption = composer.text
        page.replyRoot = rootId
        navPane.push(page)
    }

    function toggleEmoji() {
        if (emojiPanel.visible) {
            emojiPanel.visible = false
            syncPeek()
            return
        }
        emojiPanel.visible = true
        syncPeek()
        _mm.loadCustomEmoji()
        if (emojiSearch.text != "")
            emojiSearch.text = ""
        else
            filterEmoji("")
    }

    function onCustomEmoji() {
        if (emojiPanel.visible)
            filterEmoji(emojiSearch.text)
    }

    function filterEmoji(query) {
        var all = _mm.emojiCatalog(query ? query : "")
        emojiModel.clear()
        var n = (all && all.length) ? all.length : 0
        for (var i = 0; i < n; ++i) {
            emojiModel.append({
                "type": "emoji",
                "glyph": all[i].glyph ? all[i].glyph : "",
                "name": all[i].name ? all[i].name : "",
                "image": all[i].image ? all[i].image : ""
            })
        }
    }

    function insertEmoji(glyph) {
        composer.text = composer.text + glyph
    }

    function send() {
        var text = composer.text.trim()
        if (text == "" && heldPath == "")
            return
        forceEnd = true
        if (heldPath != "") {
            if (!_mm.attachFile(heldPath, text, rootId, heldName))
                return
            heldPath = ""
            heldName = ""
            heldImage = false
        } else if (rootId == "") {
            _mm.sendMessage(text)
        } else {
            _mm.sendReply(rootId, text)
        }
        composer.text = ""
    }

    function restoreText(text) {
        if (composer.text == "")
            composer.text = text
    }

    function samePost(a, b) {
        return a.type == b.type && a.rev == b.rev && a.imagePath == b.imagePath
            && a.imagePath2 == b.imagePath2 && a.react == b.react && a.pending == b.pending
            && a.avatar == b.avatar && a.title == b.title && a.grouped == b.grouped
            && a.quote == b.quote && a.mark == b.mark && a.message == b.message
    }

    function reload(rows, stickEnd) {
        postModel.clear()
        for (var i = 0; i < rows.length; ++i)
            postModel.append(rows[i])
        if (stickEnd && rows.length > 0)
            postList.scrollToPosition(1, 1)
    }

    function focusIndex() {
        for (var i = 0; i < postModel.size(); ++i) {
            var row = postModel.data([i])
            if (row && row.id == focusPost)
                return i
        }
        return -1
    }

    // Während reload() feuert das Layout für jede Zeile. Das darf den
    // Sprung nicht verbrauchen, bevor die Liste steht. atEnd ist direkt
    // nach dem Aufbau oft schon wahr. Nur wenn unten kein Platz mehr ist,
    // bleibt die Fundstelle stehen.
    function onFocusNudge() {
        jumpToFocus(true)
    }

    function jumpToFocus(fromTimer) {
        if (focusPost == "" || focusHold)
            return
        if (postLayout.layoutFrame.height <= 0) {
            _mm.nudgeFocus()
            return
        }
        var index = focusIndex()
        // Solange die Liste leer ist, ist die Fundstelle noch unterwegs.
        if (index < 0) {
            if (!fromTimer) {
                _mm.nudgeFocus()
                return
            }
            if (postModel.size() == 0)
                return
            focusTries = focusTries + 1
            if (focusTries > 20) {
                focusPost = ""
                focusTries = 0
                focusSent = false
                return
            }
            _mm.nudgeFocus()
            return
        }
        var visible = scrollState.firstVisibleItem
        var at = (visible && visible.length > 0) ? Number(visible[0]) : -1
        var gap = index - at
        var room = postModel.size() - 1 - at
        if (at == index || (focusSent && scrollState.atEnd && at >= 0 && gap >= 0 && room <= 8)) {
            focusPost = ""
            focusTries = 0
            focusSent = false
            return
        }
        // None wartet, bis die Zeilen im Puffer sind. Ein weiterer Aufruf
        // fängt die Übertragung neu an. Nur der erste Sprung und ein Nachschlag.
        if (!focusSent) {
            postList.scrollToItem([index], 1)
            focusSent = true
            _mm.nudgeFocus()
            return
        }
        if (!fromTimer)
            return
        focusTries = focusTries + 1
        if (focusTries > 16) {
            focusPost = ""
            focusTries = 0
            focusSent = false
            return
        }
        if (focusTries == 8)
            focusSent = false
        _mm.nudgeFocus()
    }

    // Neue Zeilen anhängen, geänderte ersetzen. Nur ans Ende springen,
    // wenn man schon unten war oder gerade selbst gesendet hat.
    function takeReplies(rows) {
        if (rootId == "")
            return
        applyRows(rows)
    }

    function takePosts(rows) {
        if (rootId != "")
            return
        applyRows(rows)
    }

    function withMark(rows) {
        if (markedPost == "")
            return rows
        for (var k = 0; k < rows.length; ++k) {
            if (rows[k] && rows[k].id == markedPost)
                rows[k].mark = "1"
        }
        return rows
    }

    function applyRows(rows) {
        if (focusPost != "")
            markedPost = focusPost
        rows = withMark(rows)
        var size = postModel.size()
        if (focusPost != "") {
            focusHold = true
            focusTries = 0
            focusSent = false
            reload(rows, false)
            focusHold = false
            jumpToFocus(false)
            return
        }
        if (size == 0 || rows.length == 0) {
            reload(rows, true)
            return
        }
        var firstId = postModel.data([0]).id
        var lastId = postModel.data([size - 1]).id
        var firstPos = -1
        var lastPos = -1
        var i
        for (i = 0; i < rows.length; ++i) {
            if (firstPos < 0 && rows[i].id == firstId)
                firstPos = i
            if (rows[i].id == lastId)
                lastPos = i
        }
        if (firstPos < 0 || lastPos < firstPos || lastPos - firstPos + 1 != size) {
            reload(rows, true)
            return
        }
        for (i = firstPos - 1; i >= 0; --i)
            postModel.insert(0, rows[i])
        for (i = firstPos; i <= lastPos; ++i) {
            var cur = postModel.data([i])
            if (!cur || cur.id != rows[i].id) {
                reload(rows, true)
                return
            }
            if (!samePost(cur, rows[i]))
                postModel.replace(i, rows[i])
        }
        var follow = scrollState.atEnd || forceEnd
        var added = false
        for (i = lastPos + 1; i < rows.length; ++i) {
            postModel.append(rows[i])
            added = true
        }
        if (added && follow) {
            postList.scrollToPosition(1, 2)
            forceEnd = false
        }
    }

    function takeImage(fileId, path) {
        for (var i = 0; i < postModel.size(); ++i) {
            var row = postModel.data([i])
            if (row && row.imageId == fileId && row.imagePath != path) {
                row.imagePath = path
                postModel.replace(i, row)
            }
            if (row && row.imageId2 == fileId && row.imagePath2 != path) {
                row.imagePath2 = path
                postModel.replace(i, row)
            }
        }
    }

    function takeEmoji(name, path) {
        for (var i = 0; i < postModel.size(); ++i) {
            var row = postModel.data([i])
            if (!row)
                continue
            var changed = false
            for (var s = 0; s < 8; ++s) {
                var key = "r" + s
                var img = "ri" + s
                if (row[key] == name && row[img] != path) {
                    row[img] = path
                    row["rg" + s] = ""
                    changed = true
                }
            }
            if (changed)
                postModel.replace(i, row)
        }
        if (!emojiPanel.visible)
            return
        for (var e = 0; e < emojiModel.size(); ++e) {
            var chip = emojiModel.data([e])
            if (chip && chip.name == name && chip.image != path) {
                chip.image = path
                emojiModel.replace(e, chip)
            }
        }
    }

    function takeAvatar(userId, path) {
        for (var i = 0; i < postModel.size(); ++i) {
            var row = postModel.data([i])
            if (row && row.userId == userId && row.avatar != path) {
                row.avatar = path
                postModel.replace(i, row)
            }
        }
    }

    function dropSignals() {
        clearHeld()
        _mm.postsLoaded.disconnect(takePosts)
        _mm.focusNudge.disconnect(onFocusNudge)
        _mm.repliesLoaded.disconnect(takeReplies)
        _mm.imageReady.disconnect(takeImage)
        _mm.emojiReady.disconnect(takeEmoji)
        _mm.customEmojiChanged.disconnect(onCustomEmoji)
        _mm.avatarReady.disconnect(takeAvatar)
        _mm.sendFailed.disconnect(restoreText)
    }

    onCreationCompleted: {
        _mm.postsLoaded.connect(takePosts)
        _mm.focusNudge.connect(onFocusNudge)
        _mm.repliesLoaded.connect(takeReplies)
        _mm.imageReady.connect(takeImage)
        _mm.emojiReady.connect(takeEmoji)
        _mm.customEmojiChanged.connect(onCustomEmoji)
        _mm.avatarReady.connect(takeAvatar)
        _mm.sendFailed.connect(restoreText)
    }
}
