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
                    onLayoutFrameChanged: jumpToFocus()
                },
                ListScrollStateHandler {
                    id: scrollState
                    onFirstVisibleItemChanged: jumpToFocus()
                }
            ]
            function itemType(data, indexPath) {
                if (data && data.type)
                    return data.type
                return "post"
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
                        dividerVisible: false
                        contextActions: [
                            ActionSet {
                                title: qsTr("Message")
                                ActionItem {
                                    title: qsTr("Reply")
                                    enabled: ListItemData.inThread != "1" && ListItemData.pending != "1"
                                    onTriggered: _mm.askReplies(ListItemData.threadRoot)
                                }
                                ActionItem {
                                    title: qsTr("React")
                                    enabled: ListItemData.pending != "1"
                                    onTriggered: _mm.askReact(ListItemData.id)
                                }
                                ActionItem {
                                    title: qsTr("Open image")
                                    enabled: ListItemData.imageId != "" && ListItemData.imageId != "local"
                                    onTriggered: _mm.openImage(ListItemData.imageId)
                                }
                                ActionItem {
                                    title: qsTr("Image 2")
                                    enabled: ListItemData.imageId2 != ""
                                    onTriggered: _mm.openImage(ListItemData.imageId2)
                                }
                                ActionItem {
                                    title: qsTr("Open attachment")
                                    enabled: ListItemData.attachId != "" && ListItemData.attachId != "local"
                                    onTriggered: _mm.openAttachment(ListItemData.attachId, ListItemData.attachName, ListItemData.attachMime)
                                }
                                ActionItem {
                                    title: qsTr("Attachment 2")
                                    enabled: ListItemData.attachId2 != ""
                                    onTriggered: _mm.openAttachment(ListItemData.attachId2, ListItemData.attachName2, ListItemData.attachMime2)
                                }
                                ActionItem {
                                    title: qsTr("Open link")
                                    enabled: ListItemData.link != ""
                                    onTriggered: _mm.openLink(ListItemData.link)
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
                                    content.flags: TextContentFlag.ActiveTextOff | TextContentFlag.EmoticonsOff
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
                                Label {
                                    visible: ListItemData.react != ""
                                    text: ListItemData.react
                                    textFormat: TextFormat.Plain
                                    textStyle.color: Color.create(ListItemData.reactOwn != "" ? "#1c58d9" : "#5e6770")
                                    textStyle.fontSize: FontSize.Small
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
                        Label {
                            text: ListItemData.glyph
                            textFormat: TextFormat.Plain
                            preferredWidth: 80
                            preferredHeight: 72
                            textStyle.fontSize: FontSize.XLarge
                            textStyle.color: Color.create("#1b1f23")
                            textStyle.textAlign: TextAlign.Center
                        }
                    }
                ]
                onTriggered: {
                    var item = emojiModel.data(indexPath)
                    if (item && item.glyph)
                        insertEmoji(item.glyph)
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
        if (emojiSearch.text != "")
            emojiSearch.text = ""
        else
            filterEmoji("")
    }

    function filterEmoji(query) {
        var all = _mm.emojiCatalog(query ? query : "")
        emojiModel.clear()
        var n = (all && all.length) ? all.length : 0
        for (var i = 0; i < n; ++i) {
            emojiModel.append({
                "type": "emoji",
                "glyph": all[i].glyph,
                "name": all[i].name
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
            && a.quote == b.quote && a.mark == b.mark
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
    function jumpToFocus() {
        if (focusPost == "" || focusHold)
            return
        if (postLayout.layoutFrame.height <= 0) {
            _mm.nudgeFocus()
            return
        }
        var index = focusIndex()
        // Solange die Liste leer ist, ist die Fundstelle noch unterwegs.
        // Der Zähler darf sie nicht vorher verwerfen.
        if (index < 0) {
            if (postModel.size() == 0)
                return
            focusTries = focusTries + 1
            if (focusTries > 20) {
                focusPost = ""
                focusTries = 0
                return
            }
            _mm.nudgeFocus()
            return
        }
        var visible = scrollState.firstVisibleItem
        var at = (visible && visible.length > 0) ? Number(visible[0]) : -1
        var gap = index - at
        var room = postModel.size() - 1 - at
        if (at == index || (focusTries > 0 && scrollState.atEnd && at >= 0 && gap >= 0 && room <= 8)) {
            focusPost = ""
            focusTries = 0
            return
        }
        // None ist 1. Das Enum als Argument kommt in dieser QML-Version nicht an.
        postList.scrollToItem([index], 1)
        focusTries = focusTries + 1
        if (focusTries > 20) {
            focusPost = ""
            focusTries = 0
            return
        }
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
            reload(rows, false)
            focusHold = false
            jumpToFocus()
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
        _mm.focusNudge.disconnect(jumpToFocus)
        _mm.repliesLoaded.disconnect(takeReplies)
        _mm.imageReady.disconnect(takeImage)
        _mm.avatarReady.disconnect(takeAvatar)
        _mm.sendFailed.disconnect(restoreText)
    }

    onCreationCompleted: {
        _mm.postsLoaded.connect(takePosts)
        _mm.focusNudge.connect(jumpToFocus)
        _mm.repliesLoaded.connect(takeReplies)
        _mm.imageReady.connect(takeImage)
        _mm.avatarReady.connect(takeAvatar)
        _mm.sendFailed.connect(restoreText)
    }
}
