import bb.cascades 1.3

// Konto, Anzeige und Diagnose. Die Aktionsleiste trägt nur den System-Chevron.
Page {
    id: pageRoot
    objectName: "settings"
    property variant navPane: null

    titleBar: TitleBar {
        title: "Einstellungen"
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
                    text: "KONTO"
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
                    text: "Aktualisieren"
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
                    text: "Team wechseln"
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
                    text: "Abmelden"
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
                    text: "ANZEIGE"
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
                        text: "Kanalvorschau"
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#1b1f23")
                        textStyle.fontSize: FontSize.Medium
                    }
                    Label {
                        text: "Zweck oder Thema unter dem Namen"
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
                background: Color.create("#f3f5f7")
                horizontalAlignment: HorizontalAlignment.Fill
                preferredHeight: 56
                leftPadding: 20
                layout: DockLayout {
                }
                Label {
                    text: "DIAGNOSE"
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
                        text: "Protokoll"
                        textFormat: TextFormat.Plain
                        textStyle.color: Color.create("#1b1f23")
                        textStyle.fontSize: FontSize.Medium
                    }
                    Label {
                        text: "Schritt und HTTP-Status ins Systemlog"
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
                    text: "Version " + _mm.appVersion
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
                    text: _mm.teamName == "" ? "kein Team" : _mm.teamName
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                }
                Label {
                    text: _mm.trustReady ? "Vertrauensspeicher bereit" : "Vertrauensspeicher fehlt"
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create(_mm.trustReady ? "#6b747d" : "#d6322e")
                    textStyle.fontSize: FontSize.XSmall
                }
                Label {
                    text: _mm.status == "" ? "Status ruhig" : _mm.status
                    textFormat: TextFormat.Plain
                    textStyle.color: Color.create("#6b747d")
                    textStyle.fontSize: FontSize.XSmall
                    multiline: true
                }
            }
        }
    }
}
