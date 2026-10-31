import bb.cascades 1.3

// Konto, Anzeige und Diagnose. Die Aktionsleiste trägt nur den System-Chevron.
Page {
    id: pageRoot
    objectName: "settings"
    property variant navPane: null

    titleBar: TitleBar {
        title: qsTr("Settings")
    }

    actionBarVisibility: ChromeVisibility.Default

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
                        onTapped: _mm.refresh()
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
                    text: qsTr("Log out")
                    verticalAlignment: VerticalAlignment.Center
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#d6322e")
                    textStyle.fontSize: FontSize.Medium
                }
                gestureHandlers: [
                    TapHandler {
                        onTapped: _mm.logout()
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
