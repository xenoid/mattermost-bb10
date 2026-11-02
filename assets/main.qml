import bb.cascades 1.3
import bb.system 1.2

NavigationPane {
    id: nav

    attachedObjects: [
        ComponentDefinition {
            id: threadDef
            source: "asset:///thread.qml"
        },
        ComponentDefinition {
            id: searchDef
            source: "asset:///search.qml"
        },
        ComponentDefinition {
            id: imageDef
            source: "asset:///image.qml"
        },
        ComponentDefinition {
            id: settingsDef
            source: "asset:///settings.qml"
        },
        ComponentDefinition {
            id: notifyDef
            source: "asset:///channelnotify.qml"
        },
        ComponentDefinition {
            id: membersDef
            source: "asset:///members.qml"
        },
        ComponentDefinition {
            id: channelTextDef
            source: "asset:///channeltext.qml"
        },
        SystemToast {
            id: toast
        },
        SystemDialog {
            id: leaveDialog
            property string leaveId: ""
            title: qsTr("Leave channel")
            body: qsTr("You can join again later.")
            confirmButton.label: qsTr("Leave")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.leaveChannel(leaveId)
            }
        },
        SystemDialog {
            id: archiveDialog
            property string archiveId: ""
            title: qsTr("Archive channel")
            body: qsTr("Nobody can post in it afterwards.")
            confirmButton.label: qsTr("Archive")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.archiveChannel(archiveId)
            }
        },
        SystemListDialog {
            id: reactDialog
            title: qsTr("React")
            dismissOnSelection: true
            onFinished: {
                if (value == SystemUiResult.ItemSelection && selectedIndices.length > 0)
                    _mm.toggleReaction(reactPost, reactNames[selectedIndices[0]])
            }
        },
        SystemListDialog {
            id: teamDialog
            title: qsTr("Team")
            dismissOnSelection: true
            onFinished: {
                if (value == SystemUiResult.ItemSelection && selectedIndices.length > 0)
                    _mm.selectTeam(teamIds[selectedIndices[0]])
            }
        },
        SystemPrompt {
            id: mfaPrompt
            title: qsTr("One-time code")
            body: qsTr("Code from the authenticator app")
            inputField.inputMode: SystemUiInputMode.Default
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Sign in")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.submitMfa(inputFieldTextEntry())
                else
                    _mm.cancelMfa()
            }
        }
    ]

    property string reactPost: ""
    property variant reactNames: []
    property variant teamIds: []
    property string pendingInbox: ""
    property string pendingInboxName: ""

    function showInbox() {
        var id = pendingInbox
        var name = pendingInboxName
        if (id == "")
            return
        pendingInbox = ""
        pendingInboxName = ""
        var page = nav.make(threadDef)
        if (!page)
            return
        page.navPane = nav
        nav.push(page)
        _mm.openChannel(id, name)
    }

    // Kopfzeile oder Zweck eines Kanals in einer eigenen Seite bearbeiten.
    function openChannelText(channelId, field, current) {
        var page = make(channelTextDef)
        if (!page)
            return
        page.channelId = channelId
        page.field = field
        page.current = current ? current : ""
        page.navPane = nav
        nav.push(page)
    }

    // Seite erzeugen; bei QML-Fehlern den Text sichtbar machen statt still zu scheitern.
    function make(def) {
        var page = def.createObject()
        if (!page) {
            console.log("QML: " + def.errorMessage())
            toast.body = def.errorMessage()
            toast.show()
        }
        return page
    }

    function showTeams() {
        var rows = _mm.teamChoices()
        var n = (rows && rows.length) ? rows.length : 0
        var ids = []
        var names = []
        for (var i = 0; i < n; ++i) {
            ids.push(String(rows[i].id))
            names.push(String(rows[i].name))
        }
        teamDialog.clearList()
        for (var j = 0; j < names.length; ++j)
            teamDialog.appendItem(names[j])
        teamIds = ids
        if (n > 0)
            teamDialog.show()
    }

    onPopTransitionEnded: {
        if (page && page.saveDraft)
            page.saveDraft()
        if (page && page.dropSignals)
            page.dropSignals()
        nav.peekEnabled = true
        if (page && page.objectName == "thread")
            _mm.closeChannel()
        else if (page && page.objectName == "replies")
            _mm.closeThread()
        if (page)
            page.destroy()
        if (pendingInbox != "") {
            if (nav.count() > 1)
                nav.pop()
            else
                showInbox()
        }
    }

    peekEnabled: true

    Page {
        actionBarVisibility: ChromeVisibility.Hidden

        titleBar: TitleBar {
            title: !_mm.loggedIn ? qsTr("Mattermost") : (_mm.teamName == "" ? qsTr("Mattermost") : _mm.teamName)
        }

        Container {
            background: Color.White
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill
            layout: StackLayout {
                orientation: LayoutOrientation.TopToBottom
            }

            StatusBanner {
            }

            // ------------------------------------------------ Anmeldung
            Container {
                visible: !_mm.loggedIn
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 32
                rightPadding: 32
                topPadding: 24
                layout: StackLayout {
                    orientation: LayoutOrientation.TopToBottom
                }

                Container {
                    layout: StackLayout {
                        orientation: LayoutOrientation.LeftToRight
                    }
                    bottomMargin: 20
                    ImageView {
                        imageSource: "asset:///logo.png"
                        preferredWidth: 96
                        preferredHeight: 96
                        verticalAlignment: VerticalAlignment.Center
                        rightMargin: 20
                    }
                    Container {
                        verticalAlignment: VerticalAlignment.Center
                        Label {
                            text: qsTr("Mattermost")
                            textStyle.color: Color.create("#1544a8")
                            textStyle.fontSize: FontSize.XLarge
                            textStyle.fontWeight: FontWeight.Bold
                        }
                        Label {
                            text: qsTr("Sign in to a server")
                            textStyle.color: Color.create("#6b747d")
                            textStyle.fontSize: FontSize.Small
                        }
                    }
                }
                TextField {
                    id: serverField
                    hintText: qsTr("Server, for example https://chat.example.com")
                    text: _mm.serverUrl
                    inputMode: TextFieldInputMode.Url
                    input.submitKey: SubmitKey.Next
                }
                TextField {
                    id: userField
                    hintText: qsTr("Name or email")
                    text: _mm.username
                    topMargin: 6
                    input.submitKey: SubmitKey.Next
                }
                TextField {
                    id: passField
                    hintText: qsTr("Password")
                    inputMode: TextFieldInputMode.Password
                    topMargin: 6
                    input.submitKey: SubmitKey.Go
                    input.onSubmitted: _mm.login(serverField.text, userField.text, passField.text)
                }
                Button {
                    text: qsTr("Sign in")
                    color: Color.create("#1c58d9")
                    horizontalAlignment: HorizontalAlignment.Fill
                    topMargin: 20
                    onClicked: _mm.login(serverField.text, userField.text, passField.text)
                }
                Label {
                    text: qsTr("Forgot password?")
                    horizontalAlignment: HorizontalAlignment.Center
                    topMargin: 16
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1c58d9")
                    textStyle.fontSize: FontSize.Small
                    gestureHandlers: [
                        TapHandler {
                            onTapped: {
                                // Der Link öffnet die Zurücksetzen-Seite des eingetragenen Servers im Browser.
                                var server = serverField.text.trim().replace(/\/+$/, "")
                                if (server.indexOf("http") == 0)
                                    _mm.openLink(server + "/reset_password")
                            }
                        }
                    ]
                }
            }

            // ------------------------------------------------ Kanalliste
            Container {
                visible: _mm.loggedIn
                horizontalAlignment: HorizontalAlignment.Fill
                verticalAlignment: VerticalAlignment.Fill
                layoutProperties: StackLayoutProperties {
                    spaceQuota: 1
                }
                layout: StackLayout {
                    orientation: LayoutOrientation.TopToBottom
                }

                Container {
                    background: Color.White
                    horizontalAlignment: HorizontalAlignment.Fill
                    leftPadding: 16
                    rightPadding: 16
                    topPadding: 10
                    bottomPadding: 10

                    Container {
                        background: Color.create("#eceff2")
                        horizontalAlignment: HorizontalAlignment.Fill
                        layout: StackLayout {
                            orientation: LayoutOrientation.LeftToRight
                        }
                        ImageView {
                            imageSource: _mm.iconSearch
                            preferredWidth: 40
                            preferredHeight: 40
                            verticalAlignment: VerticalAlignment.Center
                            leftMargin: 16
                        }
                        TextField {
                            id: searchField
                            hintText: qsTr("Search messages")
                            backgroundVisible: false
                            input.submitKey: SubmitKey.Search
                            verticalAlignment: VerticalAlignment.Center
                            layoutProperties: StackLayoutProperties {
                                spaceQuota: 1
                            }
                            input.onSubmitted: {
                                var query = searchField.text.trim()
                                if (query == "")
                                    return
                                var page = nav.make(searchDef)
                                if (!page)
                                    return
                                nav.push(page)
                                _mm.search(query)
                                searchField.text = ""
                            }
                        }
                    }
                }

                ListView {
                    id: channelList
                    property bool showPreview: true
                    scrollRole: ScrollRole.Main
                    horizontalAlignment: HorizontalAlignment.Fill
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                    dataModel: ArrayDataModel {
                        id: channelModel
                    }
                    function itemType(data, indexPath) {
                        if (data && data.type)
                            return data.type
                        return "channel"
                    }
                    function openNotify(channelId, title) {
                        var page = nav.make(notifyDef)
                        if (!page)
                            return
                        page.channelId = channelId
                        page.channelTitle = title
                        page.load()
                        nav.push(page)
                    }
                    function openMembers(channelId, title, kind) {
                        var page = nav.make(membersDef)
                        if (!page)
                            return
                        page.channelId = channelId
                        page.channelTitle = title
                        page.canManage = kind == "O" || kind == "P"
                        page.load()
                        nav.push(page)
                    }
                    listItemComponents: [
                        ListItemComponent {
                            type: "header"
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
                                        textFormat: TextFormat.Plain
                                        verticalAlignment: VerticalAlignment.Center
                                        textStyle.color: Color.create("#6b747d")
                                        textStyle.fontSize: FontSize.XSmall
                                        textStyle.fontWeight: FontWeight.Bold
                                    }
                                }
                            }
                        },
                        ListItemComponent {
                            type: "channel"
                            CustomListItem {
                                id: channelItem
                                dividerVisible: true
                                contextActions: [
                                    ActionSet {
                                        title: ListItemData.title
                                        ActionItem {
                                            title: qsTr("Notifications")
                                            onTriggered: channelItem.ListItem.view.openNotify(ListItemData.channelId, ListItemData.title)
                                        }
                                        ActionItem {
                                            title: qsTr("Members")
                                            onTriggered: channelItem.ListItem.view.openMembers(ListItemData.channelId, ListItemData.title, ListItemData.kind)
                                        }
                                        ActionItem {
                                            title: qsTr("Leave channel")
                                            enabled: ListItemData.kind == "O" || ListItemData.kind == "P"
                                            onTriggered: {
                                                leaveDialog.leaveId = ListItemData.channelId
                                                leaveDialog.show()
                                            }
                                        }
                                        ActionItem {
                                            title: qsTr("Archive channel")
                                            enabled: ListItemData.kind == "O" || ListItemData.kind == "P"
                                            onTriggered: {
                                                archiveDialog.archiveId = ListItemData.channelId
                                                archiveDialog.show()
                                            }
                                        }
                                        ActionItem {
                                            title: qsTr("Edit header")
                                            enabled: ListItemData.kind == "O" || ListItemData.kind == "P"
                                            onTriggered: nav.openChannelText(ListItemData.channelId, "header", ListItemData.header)
                                        }
                                        ActionItem {
                                            title: qsTr("Edit purpose")
                                            enabled: ListItemData.kind == "O" || ListItemData.kind == "P"
                                            onTriggered: nav.openChannelText(ListItemData.channelId, "purpose", ListItemData.purpose)
                                        }
                                    }
                                ]
                                Container {
                                    preferredHeight: 112
                                    horizontalAlignment: HorizontalAlignment.Fill
                                    leftPadding: 20
                                    rightPadding: 20
                                    layout: StackLayout {
                                        orientation: LayoutOrientation.LeftToRight
                                    }

                                    Container {
                                        preferredWidth: 76
                                        preferredHeight: 76
                                        verticalAlignment: VerticalAlignment.Center
                                        layout: DockLayout {
                                        }
                                        ImageView {
                                            imageSource: ListItemData.tile
                                            preferredWidth: 76
                                            preferredHeight: 76
                                            scalingMethod: ScalingMethod.AspectFill
                                        }
                                        Label {
                                            visible: ListItemData.avatar == "" && ListItemData.initial != ""
                                            text: ListItemData.initial
                                            textFormat: TextFormat.Plain
                                            horizontalAlignment: HorizontalAlignment.Center
                                            verticalAlignment: VerticalAlignment.Center
                                            textStyle.color: Color.White
                                            textStyle.fontSize: FontSize.Large
                                            textStyle.fontWeight: FontWeight.Bold
                                        }
                                        ImageView {
                                            visible: ListItemData.avatar != ""
                                            imageSource: ListItemData.avatar
                                            preferredWidth: 76
                                            preferredHeight: 76
                                            scalingMethod: ScalingMethod.AspectFill
                                        }
                                    }

                                    Container {
                                        leftMargin: 20
                                        verticalAlignment: VerticalAlignment.Center
                                        layoutProperties: StackLayoutProperties {
                                            spaceQuota: 1
                                        }
                                        Label {
                                            text: ListItemData.title
                                            textFormat: TextFormat.Plain
                                            textStyle.color: Color.create("#1b1f23")
                                            textStyle.fontSize: FontSize.Medium
                                            textStyle.fontWeight: ListItemData.unread > 0 ? FontWeight.Bold : FontWeight.W500
                                        }
                                        Label {
                                            visible: ListItemData.subtitle != "" && channelItem.ListItem.view.showPreview
                                            text: ListItemData.subtitle
                                            textFormat: TextFormat.Plain
                                            textStyle.color: Color.create("#6b747d")
                                            textStyle.fontSize: FontSize.XSmall
                                        }
                                    }

                                    Container {
                                        leftMargin: 12
                                        verticalAlignment: VerticalAlignment.Center
                                        Label {
                                            text: ListItemData.when
                                            textFormat: TextFormat.Plain
                                            horizontalAlignment: HorizontalAlignment.Right
                                            textStyle.color: Color.create(ListItemData.unread > 0 ? "#1c58d9" : "#6b747d")
                                            textStyle.fontSize: FontSize.XSmall
                                            textStyle.fontWeight: ListItemData.unread > 0 ? FontWeight.Bold : FontWeight.Default
                                        }
                                        Container {
                                            horizontalAlignment: HorizontalAlignment.Right
                                            preferredHeight: 40
                                            topMargin: 4
                                            layout: DockLayout {
                                            }
                                            ImageView {
                                                visible: ListItemData.mentions > 0
                                                imageSource: ListItemData.badge
                                                preferredWidth: 40
                                                preferredHeight: 40
                                                horizontalAlignment: HorizontalAlignment.Right
                                                verticalAlignment: VerticalAlignment.Center
                                            }
                                            Label {
                                                visible: ListItemData.mentions > 0
                                                text: "" + ListItemData.mentions
                                                textFormat: TextFormat.Plain
                                                horizontalAlignment: HorizontalAlignment.Center
                                                verticalAlignment: VerticalAlignment.Center
                                                textStyle.color: Color.White
                                                textStyle.fontSize: FontSize.XXSmall
                                                textStyle.fontWeight: FontWeight.Bold
                                            }
                                            ImageView {
                                                visible: ListItemData.mentions == 0 && ListItemData.unread > 0
                                                imageSource: ListItemData.badge
                                                preferredWidth: 24
                                                preferredHeight: 24
                                                horizontalAlignment: HorizontalAlignment.Right
                                                verticalAlignment: VerticalAlignment.Center
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        ListItemComponent {
                            type: "settings"
                            CustomListItem {
                                dividerVisible: false
                                Container {
                                    preferredHeight: 112
                                    horizontalAlignment: HorizontalAlignment.Fill
                                    leftPadding: 20
                                    rightPadding: 20
                                    layout: StackLayout {
                                        orientation: LayoutOrientation.LeftToRight
                                    }
                                    ImageView {
                                        imageSource: ListItemData.tile
                                        preferredWidth: 76
                                        preferredHeight: 76
                                        verticalAlignment: VerticalAlignment.Center
                                        scalingMethod: ScalingMethod.AspectFill
                                    }
                                    Container {
                                        leftMargin: 20
                                        verticalAlignment: VerticalAlignment.Center
                                        layoutProperties: StackLayoutProperties {
                                            spaceQuota: 1
                                        }
                                        Label {
                                            text: ListItemData.title
                                            textFormat: TextFormat.Plain
                                            textStyle.color: Color.create("#1b1f23")
                                            textStyle.fontSize: FontSize.Medium
                                            textStyle.fontWeight: FontWeight.W500
                                        }
                                        Label {
                                            visible: ListItemData.subtitle != ""
                                            text: ListItemData.subtitle
                                            textFormat: TextFormat.Plain
                                            textStyle.color: Color.create("#6b747d")
                                            textStyle.fontSize: FontSize.XSmall
                                        }
                                    }
                                }
                            }
                        }
                    ]
                    onTriggered: {
                        var item = channelModel.data(indexPath)
                        if (!item)
                            return
                        if (item.type == "settings") {
                            var settingsPage = nav.make(settingsDef)
                            if (!settingsPage)
                                return
                            settingsPage.navPane = nav
                            nav.push(settingsPage)
                            return
                        }
                        if (item.type != "channel")
                            return
                        var page = nav.make(threadDef)
                        if (!page)
                            return
                        page.navPane = nav
                        nav.push(page)
                        _mm.openChannel(item.channelId, item.title)
                    }
                }
            }
        }
    }

    function sameChannel(a, b) {
        return a.type == b.type && a.channelId == b.channelId && a.title == b.title
            && a.subtitle == b.subtitle && a.when == b.when && a.unread == b.unread
            && a.mentions == b.mentions && a.avatar == b.avatar && a.tile == b.tile
    }

    // Nur geänderte Zeilen ersetzen, damit die Liste beim stillen Nachladen nicht springt.
    function takeChannels(rows) {
        var data = []
        var i
        var n = (rows && rows.length) ? rows.length : 0
        for (i = 0; i < n; ++i) {
            if (rows[i].type != "settings")
                data.push(rows[i])
        }
        if (_mm.loggedIn) {
            data.push({
                type: "settings",
                title: qsTr("Settings"),
                subtitle: qsTr("Account, display, diagnostics"),
                channelId: "",
                when: "",
                unread: 0,
                mentions: 0,
                avatar: "",
                peerId: "",
                tile: _mm.iconSettings
            })
        }
        var keep = (data.length == channelModel.size())
        if (keep) {
            for (i = 0; i < data.length; ++i) {
                var cur = channelModel.data([i])
                if (!cur || cur.type != data[i].type || cur.channelId != data[i].channelId || cur.title != data[i].title) {
                    keep = false
                    break
                }
            }
        }
        if (!keep) {
            channelModel.clear()
            for (i = 0; i < data.length; ++i)
                channelModel.append(data[i])
            return
        }
        for (i = 0; i < data.length; ++i) {
            if (!sameChannel(channelModel.data([i]), data[i]))
                channelModel.replace(i, data[i])
        }
    }

    function takeAvatar(userId, path) {
        for (var i = 0; i < channelModel.size(); ++i) {
            var row = channelModel.data([i])
            if (row && row.peerId == userId && row.avatar != path) {
                row.avatar = path
                channelModel.replace(i, row)
            }
        }
    }

    function applyPreview() {
        channelList.showPreview = _mm.showPreview
    }

    onCreationCompleted: {
        applyPreview()
        _mm.prefsChanged.connect(applyPreview)
        _mm.channelsLoaded.connect(takeChannels)
        _mm.avatarReady.connect(takeAvatar)
        _mm.loggedInChanged.connect(function() {
            if (!_mm.loggedIn && nav.count() > 1)
                nav.pop()
        })
        _mm.threadRequested.connect(function(id, name, postId) {
            var page = nav.make(threadDef)
            if (!page)
                return
            page.navPane = nav
            page.focusPost = postId ? postId : ""
            nav.push(page)
            if (postId)
                _mm.openAt(id, name, postId)
            else
                _mm.openChannel(id, name)
        })
        _mm.chooseTeam.connect(function() { showTeams() })
        _mm.mfaRequired.connect(function() {
            mfaPrompt.show()
        })
        _mm.showImage.connect(function(path) {
            var page = nav.make(imageDef)
            if (!page)
                return
            page.imagePath = path
            nav.push(page)
        })
        _mm.repliesRequested.connect(function(rootId) {
            var page = nav.make(threadDef)
            if (!page)
                return
            page.navPane = nav
            page.rootId = rootId
            nav.push(page)
            _mm.openThread(rootId)
        })
        _mm.inboxRequested.connect(function(id, name) {
            if (!id)
                return
            if (_mm.channelId == id && nav.count() > 1)
                return
            pendingInbox = id
            pendingInboxName = name
            if (nav.count() > 1)
                nav.pop()
            else
                showInbox()
        })
        _mm.reactRequested.connect(function(postId) {
            reactPost = postId
            reactDialog.show()
        })
        var choices = _mm.emojiChoices()
        var names = []
        for (var n = 0; n < choices.length; ++n) {
            reactDialog.appendItem(choices[n].label)
            names.push(choices[n].name)
        }
        reactNames = names
        _mm.showCached()
    }
}
