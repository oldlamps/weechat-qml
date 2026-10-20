import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: settingsModal
    anchors.fill: parent
    color: "#cc090b10"
    visible: false
    z: 110

    property var relayController
    property var theme

    MouseArea {
        anchors.fill: parent
        onClicked: settingsModal.visible = false
    }

    Rectangle {
        id: card
        width: 620
        height: Math.min(parent.height - 60, 680)
        anchors.centerIn: parent
        radius: 14
        color: theme.bgElevated
        border.color: theme.borderSubtle
        border.width: 1

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 36
                    height: 36
                    radius: 9
                    color: theme.accentPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        color: "#ffffff"
                        font.pixelSize: 18
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Preferences & Appearance"
                        color: theme.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                        font.family: theme.fontSans
                    }

                    Text {
                        text: "Configure client themes, typography, display defaults, and relay behavior"
                        color: theme.textSecondary
                        font.pixelSize: 12
                        font.family: theme.fontSans
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: closeHover.hovered ? theme.bgHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: theme.textSecondary
                        font.pixelSize: 14
                    }

                    HoverHandler { id: closeHover }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: settingsModal.visible = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.borderSubtle
            }

            // Scrollable Settings Content
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: card.width - 48
                    spacing: 20

                    // SECTION 1: THEMES & APPEARANCE
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "THEME & COLOR PALETTE"
                            color: theme.accentCyan
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 0.8
                        }

                        // Theme Grid (9 curated themes)
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing: 8
                            columnSpacing: 8

                            Repeater {
                                model: theme.availableThemes

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: 48
                                    radius: 8
                                    color: isSelected ? theme.bgActive : (thHover.hovered ? theme.bgHover : theme.bgSecondary)
                                    border.color: isSelected ? theme.borderFocus : theme.borderSubtle
                                    border.width: isSelected ? 2 : 1

                                    property bool isSelected: theme.activeThemeName === modelData

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        // Theme Accent Preview Dot
                                        Rectangle {
                                            width: 14
                                            height: 14
                                            radius: 7
                                            color: {
                                                switch(modelData) {
                                                    case "Catppuccin Mocha": return "#cba6f7";
                                                    case "Tokyo Night": return "#7aa2f7";
                                                    case "Nord": return "#88c0d0";
                                                    case "Dracula": return "#bd93f9";
                                                    case "Gruvbox Dark": return "#fe8019";
                                                    case "Solarized Dark": return "#268bd2";
                                                    case "Cyberpunk / Neon": return "#f72585";
                                                    case "Monokai Pro": return "#ffd866";
                                                    case "GitHub Dark": return "#2ea043";
                                                    default: return "#6366f1";
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData
                                            color: isSelected ? theme.textPrimary : theme.textSecondary
                                            font.pixelSize: 12
                                            font.bold: isSelected
                                            elide: Text.ElideRight
                                        }
                                    }

                                    HoverHandler { id: thHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            relayController.set_theme(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.borderSubtle
                    }

                    // SECTION 2: CHAT & TYPOGRAPHY DEFAULTS
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "CHAT & TYPOGRAPHY"
                            color: theme.accentCyan
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 0.8
                        }

                        // Font Size Slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Text {
                                text: "Message Font Size"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                Layout.preferredWidth: 160
                            }

                            Slider {
                                id: fontSlider
                                Layout.fillWidth: true
                                from: 11
                                to: 20
                                stepSize: 1
                                value: relayController.font_size > 0 ? relayController.font_size : 13
                                onMoved: {
                                    relayController.set_font_size(Math.round(value))
                                }
                            }

                            Text {
                                text: (relayController.font_size > 0 ? relayController.font_size : theme.baseFontSize) + " px"
                                color: theme.accentCyan
                                font.pixelSize: 13
                                font.bold: true
                                font.family: theme.fontMono
                                Layout.preferredWidth: 50
                            }
                        }

                        // Timestamp Format Selector
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Text {
                                text: "Timestamp Format"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                Layout.preferredWidth: 160
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: [
                                        { label: "HH:MM", pattern: "%H:%M" },
                                        { label: "HH:MM:SS", pattern: "%H:%M:%S" },
                                        { label: "12-Hour (am/pm)", pattern: "%I:%M %P" }
                                    ]

                                    delegate: Rectangle {
                                        height: 30
                                        implicitWidth: tsLbl.implicitWidth + 20
                                        radius: 6
                                        property bool isSelected: relayController.timestamp_format === modelData.pattern
                                        color: isSelected ? theme.bgActive : (tsHover.hovered ? theme.bgHover : theme.bgSecondary)
                                        border.color: isSelected ? theme.borderFocus : theme.borderSubtle

                                        Text {
                                            id: tsLbl
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: isSelected ? theme.textPrimary : theme.textSecondary
                                            font.pixelSize: 11
                                            font.bold: isSelected
                                        }

                                        HoverHandler { id: tsHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: relayController.set_timestamp_format(modelData.pattern)
                                        }
                                    }
                                }
                            }
                        }

                        // Initial History Lines to Fetch on Buffer Switch
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Text {
                                text: "Initial History Lines"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                Layout.preferredWidth: 160
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: [50, 100, 150, 250, 500]

                                    delegate: Rectangle {
                                        height: 30
                                        implicitWidth: linesLbl.implicitWidth + 20
                                        radius: 6
                                        property bool isSelected: relayController.initial_lines_fetch === modelData
                                        color: isSelected ? theme.bgActive : (linesHover.hovered ? theme.bgHover : theme.bgSecondary)
                                        border.color: isSelected ? theme.borderFocus : theme.borderSubtle

                                        Text {
                                            id: linesLbl
                                            anchors.centerIn: parent
                                            text: modelData.toString()
                                            color: isSelected ? theme.textPrimary : theme.textSecondary
                                            font.pixelSize: 11
                                            font.bold: isSelected
                                        }

                                        HoverHandler { id: linesHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: relayController.set_initial_lines_fetch(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.borderSubtle
                    }

                    // SECTION 3: RELAY & NOTIFICATION TOGGLES
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "BEHAVIOR & NOTIFICATIONS"
                            color: theme.accentCyan
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 0.8
                        }

                        // Desktop Notifications Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 42
                            radius: 8
                            color: notifHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14

                                Text {
                                    text: "Desktop Notifications (Freedesktop / DBus on highlights & DMs)"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }

                                Switch {
                                    id: notifSwitch
                                    checked: relayController.desktop_notifications
                                    onToggled: relayController.set_desktop_notifications(checked)
                                }
                            }

                            HoverHandler { id: notifHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.x < notifSwitch.x || mouse.x > notifSwitch.x + notifSwitch.width) {
                                        notifSwitch.toggle()
                                    }
                                }
                            }
                        }

                        // Inline Image / Media Previews Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 42
                            radius: 8
                            color: mediaHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14

                                Text {
                                    text: "Inline Media Previews (Render collapsible previews for direct images)"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }

                                Switch {
                                    id: mediaSwitch
                                    checked: relayController.show_media_previews
                                    onToggled: relayController.set_show_media_previews(checked)
                                }
                            }

                            HoverHandler { id: mediaHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.x < mediaSwitch.x || mouse.x > mediaSwitch.x + mediaSwitch.width) {
                                        mediaSwitch.toggle()
                                    }
                                }
                            }
                        }

                        // Join / Part / Quit Event Noise Filter Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 42
                            radius: 8
                            color: jpqHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14

                                Text {
                                    text: "Show Join / Part / Quit Status Events by Default"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }

                                Switch {
                                    id: jpqSwitch
                                    checked: relayController.show_join_part_quit
                                    onToggled: relayController.set_show_join_part_quit(checked)
                                }
                            }

                            HoverHandler { id: jpqHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.x < jpqSwitch.x || mouse.x > jpqSwitch.x + jpqSwitch.width) {
                                        jpqSwitch.toggle()
                                    }
                                }
                            }
                        }

                        // Auto Reconnect Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 42
                            radius: 8
                            color: autoRecHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14

                                Text {
                                    text: "Auto-reconnect when connection drops"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }

                                Switch {
                                    id: autoRecSwitch
                                    checked: relayController.auto_reconnect
                                    onToggled: relayController.set_auto_reconnect(checked)
                                }
                            }

                            HoverHandler { id: autoRecHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.x < autoRecSwitch.x || mouse.x > autoRecSwitch.x + autoRecSwitch.width) {
                                        autoRecSwitch.toggle()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Footer / Done Button
            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                Rectangle {
                    height: 38
                    implicitWidth: 110
                    radius: 8
                    color: doneHover.hovered ? theme.accentHover : theme.accentPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "Done"
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    HoverHandler { id: doneHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsModal.visible = false
                    }
                }
            }
        }
    }
}
