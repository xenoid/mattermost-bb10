import bb.cascades 1.3
import bb.system 1.2

// Konto, Anzeige und Diagnose. Die Aktionsleiste trägt nur den System-Chevron.
Page {
    id: pageRoot
    objectName: "settings"
    property variant navPane: null

    titleBar: TitleBar {
        title: qsTr("Settings")
    }

    actionBarVisibility: ChromeVisibility.Default

    property variant presenceValues: ["online", "away", "dnd", "offline"]

    function presenceLabel(value) {
        if (value == "online")
            return qsTr("Online")
        if (value == "away")
            return qsTr("Away")
        if (value == "dnd")
            return qsTr("Do not disturb")
        if (value == "offline")
            return qsTr("Offline")
        return ""
    }

    function showPresence() {
        presenceDialog.clearList()
        for (var i = 0; i < presenceValues.length; ++i)
            presenceDialog.appendItem(presenceLabel(presenceValues[i]))
        presenceDialog.show()
    }

    // Zeigt das Profil, das der Server zum Benutzernamen liefert.
    function showUser(user) {
        var lines = ["@" + user.username]
        var name = (user.firstName + " " + user.lastName).trim()
        if (name != "")
            lines.push(name)
        if (user.nickname != "")
            lines.push(user.nickname)
        if (user.position != "")
            lines.push(user.position)
        if (user.email != "")
            lines.push(user.email)
        userDialog.body = lines.join("\n")
        userDialog.show()
    }

    function dropSignals() {
        _mm.userFound.disconnect(showUser)
    }

    onCreationCompleted: {
        _mm.userFound.connect(showUser)
    }

    function profileName() {
        var name = (_mm.profile.first + " " + _mm.profile.last).trim()
        return name != "" ? name : qsTr("Not set")
    }

    function editProfile(field, title, current) {
        profilePrompt.profileField = field
        profilePrompt.title = title
        profilePrompt.body = field == "name" ? qsTr("First name, then last name") : ""
        profilePrompt.inputField.defaultText = current
        profilePrompt.show()
    }

    attachedObjects: [
        SystemListDialog {
            id: presenceDialog
            title: qsTr("Status")
            dismissOnSelection: true
            onFinished: {
                if (value == SystemUiResult.ItemSelection && selectedIndices.length > 0)
                    _mm.setPresence(presenceValues[selectedIndices[0]])
            }
        },
        ComponentDefinition {
            id: mentionsDef
            source: "asset:///search.qml"
        },
        ComponentDefinition {
            id: joinTeamDef
            source: "asset:///jointeam.qml"
        },
        SystemPrompt {
            id: channelPrompt
            title: qsTr("New channel")
            body: qsTr("Channel name")
            inputField.inputMode: SystemUiInputMode.Default
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Create")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.createChannel(inputFieldTextEntry())
            }
        },
        SystemPrompt {
            id: lookupPrompt
            title: qsTr("Look up a user")
            body: qsTr("Username of the person")
            inputField.inputMode: SystemUiInputMode.Default
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Look up")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.lookupUser(inputFieldTextEntry())
            }
        },
        SystemDialog {
            id: userDialog
            title: qsTr("Profile")
            confirmButton.label: qsTr("OK")
            cancelButton.label: qsTr("Cancel")
        },
        SystemPrompt {
            id: dmPrompt
            title: qsTr("Direct message")
            body: qsTr("Username of the person")
            inputField.inputMode: SystemUiInputMode.Default
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Start")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.startDirect(inputFieldTextEntry())
            }
        },
        SystemPrompt {
            id: customPrompt
            title: qsTr("Custom status")
            body: qsTr("What is your status?")
            inputField.inputMode: SystemUiInputMode.Default
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Save")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection) {
                    var typed = inputFieldTextEntry()
                    if (typed.trim() != "")
                        _mm.setCustomStatus(_mm.customEmoji != "" ? _mm.customEmoji : "speech_balloon", typed)
                }
            }
        },
        SystemPrompt {
            id: profilePrompt
            property string profileField: ""
            inputField.inputMode: SystemUiInputMode.Default
            inputOptions: SystemUiInputOption.None
            confirmButton.label: qsTr("Save")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value != SystemUiResult.ConfirmButtonSelection)
                    return
                var typed = inputFieldTextEntry().trim()
                var first = _mm.profile.first
                var last = _mm.profile.last
                var nick = _mm.profile.nickname
                var position = _mm.profile.position
                if (profileField == "name") {
                    var cut = typed.indexOf(" ")
                    first = cut < 0 ? typed : typed.substring(0, cut)
                    last = cut < 0 ? "" : typed.substring(cut + 1).trim()
                } else if (profileField == "nickname") {
                    nick = typed
                } else {
                    position = typed
                }
                _mm.saveProfile(first, last, nick, position)
            }
        },
        SystemDialog {
            id: leaveTeamDialog
            title: qsTr("Leave team")
            body: qsTr("You will no longer see its channels here.")
            confirmButton.label: qsTr("Leave")
            cancelButton.label: qsTr("Cancel")
            onFinished: {
                if (value == SystemUiResult.ConfirmButtonSelection)
                    _mm.leaveTeam()
            }
        }
    ]

    ScrollView {
        scrollRole: ScrollRole.Main
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill

        Container {
            background: Color.White
            horizontalAlignment: HorizontalAlignment.Fill

            Container {
                background: Color.create("#f3f5f7")
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 56
                leftPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("STATUS")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                    textStyle.fontWeight: FontWeight.Bold
                }
            }

            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Label {
                    text: qsTr("Status")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1b1f23")
                    textStyle.fontSize: FontSize.Medium
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }
                Label {
                    text: presenceLabel(_mm.presence)
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.Small
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:246 onTapped"); showPresence() }
                    }
                ]
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Label {
                    text: qsTr("Custom status")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1b1f23")
                    textStyle.fontSize: FontSize.Medium
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }
                Label {
                    text: _mm.customText != "" ? _mm.customText : qsTr("Not set")
                    verticalAlignment: VerticalAlignment.Center
                    horizontalAlignment: HorizontalAlignment.Right
                    multiline: false
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.Small
                    textStyle.textAlign: TextAlign.Right
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: {
                            if (Qt.mm) Qt.mm.traceLog("tap settings.qml:283 onTapped")
                            customPrompt.inputField.defaultText = _mm.customText
                            customPrompt.show()
                        }
                    }
                ]
            }
            Container {
                visible: _mm.customText != ""
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("Clear custom status")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#d6322e")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:307 onTapped"); _mm.clearCustomStatus() }
                    }
                ]
            }

            Container {
                background: Color.create("#f3f5f7")
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 56
                leftPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("PROFILE")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                    textStyle.fontWeight: FontWeight.Bold
                }
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Label {
                    text: qsTr("Name")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1b1f23")
                    textStyle.fontSize: FontSize.Medium
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }
                Label {
                    text: profileName()
                    verticalAlignment: VerticalAlignment.Center
                    horizontalAlignment: HorizontalAlignment.Right
                    multiline: false
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.Small
                    textStyle.textAlign: TextAlign.Right
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:361 onTapped"); editProfile("name", qsTr("Name"), (_mm.profile.first + " " + _mm.profile.last).trim()) }
                    }
                ]
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Label {
                    text: qsTr("Nickname")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1b1f23")
                    textStyle.fontSize: FontSize.Medium
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }
                Label {
                    text: _mm.profile.nickname != "" ? _mm.profile.nickname : qsTr("Not set")
                    verticalAlignment: VerticalAlignment.Center
                    horizontalAlignment: HorizontalAlignment.Right
                    multiline: false
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.Small
                    textStyle.textAlign: TextAlign.Right
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:398 onTapped"); editProfile("nickname", qsTr("Nickname"), _mm.profile.nickname) }
                    }
                ]
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Label {
                    text: qsTr("Position")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1b1f23")
                    textStyle.fontSize: FontSize.Medium
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }
                Label {
                    text: _mm.profile.position != "" ? _mm.profile.position : qsTr("Not set")
                    verticalAlignment: VerticalAlignment.Center
                    horizontalAlignment: HorizontalAlignment.Right
                    multiline: false
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.Small
                    textStyle.textAlign: TextAlign.Right
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:435 onTapped"); editProfile("position", qsTr("Position"), _mm.profile.position) }
                    }
                ]
            }

            Container {
                background: Color.create("#f3f5f7")
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 56
                leftPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("MESSAGES")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                    textStyle.fontWeight: FontWeight.Bold
                }
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("New direct message")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1c58d9")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:472 onTapped"); dmPrompt.show() }
                    }
                ]
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("Look up a user")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1c58d9")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:492 onTapped"); lookupPrompt.show() }
                    }
                ]
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("Recent mentions")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1c58d9")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: {
                            if (Qt.mm) Qt.mm.traceLog("tap settings.qml:512 onTapped")
                            if (!navPane)
                                return
                            var page = navPane.make(mentionsDef)
                            if (!page)
                                return
                            page.heading = qsTr("Recent mentions")
                            navPane.push(page)
                            _mm.searchMentions()
                        }
                    }
                ]
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("Saved messages")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1c58d9")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: {
                            if (Qt.mm) Qt.mm.traceLog("tap settings.qml:541 onTapped")
                            if (!navPane)
                                return
                            var page = navPane.make(mentionsDef)
                            if (!page)
                                return
                            page.heading = qsTr("Saved messages")
                            navPane.push(page)
                            _mm.openSaved()
                        }
                    }
                ]
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("New channel")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1c58d9")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:570 onTapped"); channelPrompt.show() }
                    }
                ]
            }

            Container {
                background: Color.create("#f3f5f7")
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 56
                leftPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("ACCOUNT")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                    textStyle.fontWeight: FontWeight.Bold
                }
            }

            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("Refresh")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1c58d9")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:608 onTapped"); _mm.refresh() }
                    }
                ]
            }
            Container {
                visible: _mm.teamCount > 1
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Label {
                    text: qsTr("Switch team")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1b1f23")
                    textStyle.fontSize: FontSize.Medium
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                }
                Label {
                    text: _mm.teamName
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.Small
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: {
                            if (Qt.mm) Qt.mm.traceLog("tap settings.qml:640 onTapped")
                            if (navPane)
                                navPane.showTeams()
                        }
                    }
                ]
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("Join a team")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1c58d9")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: {
                            if (Qt.mm) Qt.mm.traceLog("tap settings.qml:663 onTapped")
                            if (!navPane)
                                return
                            var page = navPane.make(joinTeamDef)
                            if (!page)
                                return
                            navPane.push(page)
                            page.load()
                        }
                    }
                ]
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("Log out")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#d6322e")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:691 onTapped"); _mm.logout() }
                    }
                ]
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 88
                leftPadding: 20
                rightPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("Leave team")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#d6322e")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: { if (Qt.mm) Qt.mm.traceLog("tap settings.qml:711 onTapped"); leaveTeamDialog.show() }
                    }
                ]
            }

            Container {
                background: Color.create("#f3f5f7")
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 56
                leftPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("DISPLAY")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                    textStyle.fontWeight: FontWeight.Bold
                }
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 20
                rightPadding: 20
                topPadding: 16
                bottomPadding: 16
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Container {
                    verticalAlignment: VerticalAlignment.Center
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                    Label {
                        text: qsTr("Channel preview")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#1b1f23")
                        textStyle.fontSize: FontSize.Medium
                    }
                    Label {
                        text: qsTr("Purpose or topic under the name")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#6b747d")
                        textStyle.fontSize: FontSize.XSmall
                    }
                }
                ToggleButton {
                    verticalAlignment: VerticalAlignment.Center
                    checked: _mm.showPreview
                    onCheckedChanged: {
                        if (_mm.showPreview != checked)
                            _mm.showPreview = checked
                    }
                }
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 20
                rightPadding: 20
                topPadding: 16
                bottomPadding: 16
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Container {
                    verticalAlignment: VerticalAlignment.Center
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                    Label {
                        text: qsTr("24-hour clock")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#1b1f23")
                        textStyle.fontSize: FontSize.Medium
                    }
                    Label {
                        text: qsTr("Hours and minutes on messages")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#6b747d")
                        textStyle.fontSize: FontSize.XSmall
                    }
                }
                ToggleButton {
                    verticalAlignment: VerticalAlignment.Center
                    checked: _mm.clock24
                    onCheckedChanged: {
                        if (_mm.clock24 != checked)
                            _mm.clock24 = checked
                    }
                }
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 20
                rightPadding: 20
                topPadding: 16
                bottomPadding: 16
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Container {
                    verticalAlignment: VerticalAlignment.Center
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                    Label {
                        text: qsTr("Show images")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#1b1f23")
                        textStyle.fontSize: FontSize.Medium
                    }
                    Label {
                        text: qsTr("Pictures inside the message")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#6b747d")
                        textStyle.fontSize: FontSize.XSmall
                    }
                }
                ToggleButton {
                    verticalAlignment: VerticalAlignment.Center
                    checked: _mm.showImages
                    onCheckedChanged: {
                        if (_mm.showImages != checked)
                            _mm.showImages = checked
                    }
                }
            }

            Container {
                background: Color.create("#f3f5f7")
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 56
                leftPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("NOTIFICATIONS")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                    textStyle.fontWeight: FontWeight.Bold
                }
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 20
                rightPadding: 20
                topPadding: 16
                bottomPadding: 16
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Container {
                    verticalAlignment: VerticalAlignment.Center
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                    Label {
                        text: qsTr("Hub alerts")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#1b1f23")
                        textStyle.fontSize: FontSize.Medium
                    }
                    Label {
                        text: qsTr("Unread channels in the hub")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#6b747d")
                        textStyle.fontSize: FontSize.XSmall
                    }
                }
                ToggleButton {
                    verticalAlignment: VerticalAlignment.Center
                    checked: _mm.notifyHub
                    onCheckedChanged: {
                        if (_mm.notifyHub != checked)
                            _mm.notifyHub = checked
                    }
                }
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 20
                rightPadding: 20
                topPadding: 16
                bottomPadding: 16
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Container {
                    verticalAlignment: VerticalAlignment.Center
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                    Label {
                        text: qsTr("Mentions only")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#1b1f23")
                        textStyle.fontSize: FontSize.Medium
                    }
                    Label {
                        text: qsTr("Skip channels that are only unread")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#6b747d")
                        textStyle.fontSize: FontSize.XSmall
                    }
                }
                ToggleButton {
                    verticalAlignment: VerticalAlignment.Center
                    checked: _mm.notifyMentions
                    onCheckedChanged: {
                        if (_mm.notifyMentions != checked)
                            _mm.notifyMentions = checked
                    }
                }
            }

            Container {
                background: Color.create("#f3f5f7")
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 56
                leftPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: qsTr("DIAGNOSTICS")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                    textStyle.fontWeight: FontWeight.Bold
                }
            }
            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 20
                rightPadding: 20
                topPadding: 16
                bottomPadding: 16
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                Container {
                    verticalAlignment: VerticalAlignment.Center
                    layoutProperties: StackLayoutProperties {
                        spaceQuota: 1
                    }
                    Label {
                        text: qsTr("Protocol log")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#1b1f23")
                        textStyle.fontSize: FontSize.Medium
                    }
                    Label {
                        text: qsTr("Step and HTTP status in the system log")
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#6b747d")
                        textStyle.fontSize: FontSize.XSmall
                    }
                }
                ToggleButton {
                    verticalAlignment: VerticalAlignment.Center
                    checked: _mm.debugLog
                    onCheckedChanged: {
                        if (_mm.debugLog != checked)
                            _mm.debugLog = checked
                    }
                }
            }

            Container {
                horizontalAlignment: HorizontalAlignment.Fill
                leftPadding: 20
                rightPadding: 20
                topPadding: 8
                bottomPadding: 28
                Label {
                    text: qsTr("Version %1").arg(_mm.appVersion)
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#1b1f23")
                    textStyle.fontSize: FontSize.Small
                }
                Label {
                    text: _mm.serverUrl
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                    multiline: true
                }
                Label {
                    text: _mm.username
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                }
                Label {
                    text: _mm.teamName == "" ? qsTr("No team") : _mm.teamName
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                }
                Label {
                    text: _mm.trustReady ? qsTr("Trust store ready") : qsTr("Trust store missing")
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create(_mm.trustReady ? "#6b747d" : "#d6322e")
                    textStyle.fontSize: FontSize.XSmall
                }
                Label {
                    text: _mm.status == "" ? qsTr("Status idle") : _mm.status
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                    multiline: true
                }
            }
        }
    }
}
