import bb.cascades 1.3

// Bildansicht auf schwarzem Grund. Zwei Finger vergrößern, Wischen verschiebt.
Page {
    objectName: "image"
    property string imagePath

    titleBar: TitleBar {
        title: "Bild"
    }

    actionBarVisibility: ChromeVisibility.Compact

    Container {
        background: Color.Black
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        layout: DockLayout {
        }

        ScrollView {
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill
            scrollViewProperties {
                scrollMode: ScrollMode.Both
                pinchToZoomEnabled: true
                minContentScale: 1.0
                maxContentScale: 5.0
            }
            Container {
                layout: DockLayout {
                }
                preferredWidth: 720
                preferredHeight: 600
                ImageView {
                    imageSource: imagePath
                    scalingMethod: ScalingMethod.AspectFit
                    preferredWidth: 720
                    preferredHeight: 600
                    horizontalAlignment: HorizontalAlignment.Center
                    verticalAlignment: VerticalAlignment.Center
                }
            }
        }
    }
}
