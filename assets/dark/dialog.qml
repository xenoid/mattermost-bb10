import bb.cascades 1.3

// Interaktiver Dialog einer Integration. Die Felder kommen aus der Beschreibung des Servers,
// "Absenden" schickt die Werte zurück. Jedes Feld trägt im objectName "field:<name>:<typ>".
Page {
    id: pageRoot
    objectName: "dialog"
    property variant navPane: null
    property string heading: ""
    property string submitLabel: ""

    titleBar: TitleBar {
        title: pageRoot.heading
    }

    actionBarVisibility: ChromeVisibility.Compact

    attachedObjects: [
        ComponentDefinition {
            id: textDef
            TextField {
            }
        },
        ComponentDefinition {
            id: areaDef
            TextArea {
                preferredHeight: 200
            }
        },
        ComponentDefinition {
            id: dropDef
            DropDown {
            }
        },
        ComponentDefinition {
            id: optionDef
            Option {
            }
        },
        ComponentDefinition {
            id: checkDef
            CheckBox {
            }
        },
        ComponentDefinition {
            id: labelDef
            Label {
                multiline: true
                textFormat: TextFormat.Plain
                textStyle.color: Color.create("#9aa3ab")
                textStyle.fontSize: FontSize.Small
            }
        }
    ]

    function build(spec) {
        heading = spec.title
        submitLabel = spec.submit != "" ? spec.submit : qsTr("Submit")
        if (spec.intro != "") {
            var intro = labelDef.createObject()
            intro.text = spec.intro
            form.add(intro)
        }
        var elements = spec.elements
        for (var i = 0; i < elements.length; ++i) {
            var e = elements[i]
            var caption = labelDef.createObject()
            caption.text = e.label + (e.optional ? "" : " *")
            caption.topMargin = 16
            form.add(caption)
            var c
            if ((e.type == "select" || e.type == "radio") && e.options.length > 0) {
                c = dropDef.createObject()
                for (var k = 0; k < e.options.length; ++k) {
                    var o = optionDef.createObject()
                    o.text = e.options[k].text
                    o.value = e.options[k].value
                    o.selected = e.options[k].value == e.value
                    c.add(o)
                }
            } else if (e.type == "bool") {
                c = checkDef.createObject()
                c.checked = e.value == "true"
                c.text = e.placeholder
            } else if (e.type == "textarea") {
                c = areaDef.createObject()
                c.text = e.value
                c.hintText = e.placeholder
            } else {
                c = textDef.createObject()
                c.text = e.value
                c.hintText = e.placeholder
            }
            c.objectName = "field:" + e.name + ":" + e.type
            form.add(c)
        }
    }

    function submit() {
        var values = {}
        for (var i = 0; i < form.count(); ++i) {
            var c = form.at(i)
            if (c.objectName.indexOf("field:") != 0)
                continue
            var parts = c.objectName.split(":")
            var name = parts[1]
            var type = parts[2]
            if (type == "bool")
                values[name] = c.checked
            else if (c.selectedValue !== undefined)
                values[name] = c.selectedValue
            else
                values[name] = c.text
        }
        _mm.submitDialog(values)
    }

    function closeDialog() {
        if (navPane)
            navPane.pop()
    }

    function dropSignals() {
        _mm.dialogClosed.disconnect(closeDialog)
    }

    onCreationCompleted: {
        _mm.dialogClosed.connect(closeDialog)
    }

    ScrollView {
        horizontalAlignment: HorizontalAlignment.Fill
        verticalAlignment: VerticalAlignment.Fill
        Container {
            horizontalAlignment: HorizontalAlignment.Fill
            background: Color.create("#16191d")
            leftPadding: 20
            rightPadding: 20
            topPadding: 12
            bottomPadding: 20
            Container {
                id: form
                horizontalAlignment: HorizontalAlignment.Fill
            }
            Button {
                text: pageRoot.submitLabel
                topMargin: 24
                horizontalAlignment: HorizontalAlignment.Fill
                onClicked: { _mm.traceLog("tap dialog.qml submit"); pageRoot.submit() }
            }
        }
    }
}
