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
    property string savedCustomBrowser: ""
    property string themeFilter: "all" // "all", "dark", "light"

    MouseArea {
        anchors.fill: parent
        onClicked: settingsModal.visible = false
    }

    Rectangle {
        id: card
        width: Math.min(parent.width - 80, 720)
        height: Math.min(parent.height - 80, 700)
        anchors.centerIn: parent
        radius: 14
        color: theme.bgElevated
        border.color: theme.borderSubtle
        border.width: 1

        MouseArea {
            anchors.fill: parent
        }

        // Top-Right Close Button
        Rectangle {
            id: closeBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 16
            anchors.rightMargin: 16
            width: 32
            height: 32
            radius: 8
            z: 20
            color: closeHover.hovered ? theme.bgHover : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeHover.hovered ? theme.textPrimary : theme.textSecondary
                font.pixelSize: 15
                font.bold: true
            }

            HoverHandler { id: closeHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: settingsModal.visible = false
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            spacing: 14

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 36
                spacing: 14

                Rectangle {
                    width: 38
                    height: 38
                    radius: 10
                    color: theme.accentPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        color: theme.bgPrimary
                        font.pixelSize: 18
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

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
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.borderSubtle
                opacity: 0.7
            }

            // Scrollable Settings Content
            ScrollView {
                id: settingsScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                Item {
                    id: scrollContentWrapper
                    width: settingsScrollView.availableWidth
                    implicitHeight: settingsContentLayout.implicitHeight + 36

                    ColumnLayout {
                        id: settingsContentLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 16
                        anchors.rightMargin: 26
                        anchors.topMargin: 12
                        spacing: 24

                    // SECTION 1: THEMES & APPEARANCE
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "THEME & COLOR PALETTE"
                                color: theme.accentCyan
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 0.8
                                Layout.fillWidth: true
                            }

                            // Theme Type Filter Pills (All / Dark / Light)
                            RowLayout {
                                spacing: 4

                                Repeater {
                                    model: [
                                        { key: "all", label: "All (" + theme.availableThemes.length + ")" },
                                        { key: "dark", label: "🌙 Dark (" + theme.darkThemes.length + ")" },
                                        { key: "light", label: "☀️ Light (" + theme.lightThemes.length + ")" }
                                    ]

                                    delegate: Rectangle {
                                        height: 24
                                        implicitWidth: filterTxt.implicitWidth + 14
                                        radius: 12
                                        property bool isCurrent: settingsModal.themeFilter === modelData.key
                                        color: isCurrent ? theme.accentPrimary : (filtHover.hovered ? theme.bgHover : theme.bgSecondary)
                                        border.color: isCurrent ? theme.borderFocus : theme.borderSubtle

                                        Text {
                                            id: filterTxt
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: isCurrent ? theme.bgPrimary : theme.textSecondary
                                            font.pixelSize: 10
                                            font.bold: isCurrent
                                        }

                                        HoverHandler { id: filtHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: settingsModal.themeFilter = modelData.key
                                        }
                                    }
                                }
                            }
                        }

                        // Theme Grid (15 curated themes: 9 dark, 6 light)
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing: 10
                            columnSpacing: 10

                            Repeater {
                                model: {
                                    if (settingsModal.themeFilter === "dark") return theme.darkThemes
                                    if (settingsModal.themeFilter === "light") return theme.lightThemes
                                    return theme.availableThemes
                                }

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    height: 52
                                    radius: 8
                                    color: isSelected ? theme.bgActive : (thHover.hovered ? theme.bgHover : theme.bgSecondary)
                                    border.color: isSelected ? theme.borderFocus : theme.borderSubtle
                                    border.width: isSelected ? 2 : 1

                                    property bool isSelected: theme.activeThemeName === modelData

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10

                                        // Theme Accent Preview Dot
                                        Rectangle {
                                            width: 16
                                            height: 16
                                            radius: 8
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
                                                    case "Catppuccin Latte": return "#8839ef";
                                                    case "GitHub Light": return "#0969da";
                                                    case "Solarized Light": return "#268bd2";
                                                    case "Tokyo Night Day": return "#34548a";
                                                    case "Nord Light": return "#5e81ac";
                                                    case "Gruvbox Light": return "#af3a03";
                                                    default: return "#6366f1";
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            RowLayout {
                                                spacing: 4
                                                Layout.fillWidth: true

                                                Text {
                                                    Layout.fillWidth: true
                                                    Layout.minimumWidth: 0
                                                    text: modelData
                                                    color: isSelected ? theme.textPrimary : theme.textSecondary
                                                    font.pixelSize: 11
                                                    font.bold: isSelected
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    text: theme.isThemeDark(modelData) ? "🌙" : "☀️"
                                                    font.pixelSize: 9
                                                    opacity: 0.6
                                                }
                                            }
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

                        // Chat View Layout Mode Selector (Modern vs Compact Classic IRC)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            // Modern View Card
                            Rectangle {
                                id: modernViewCard
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 66
                                radius: 8
                                property bool isSelected: !relayController.classic_mode
                                color: modernViewCard.isSelected ? theme.bgActive : (modViewHover.hovered ? theme.bgHover : theme.bgSecondary)
                                border.color: modernViewCard.isSelected ? theme.borderFocus : theme.borderSubtle
                                border.width: modernViewCard.isSelected ? 2 : 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Text {
                                        text: "💬"
                                        font.pixelSize: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: 3

                                        RowLayout {
                                            spacing: 8
                                            Text {
                                                text: "Modern View"
                                                color: modernViewCard.isSelected ? theme.textPrimary : theme.textSecondary
                                                font.pixelSize: 13
                                                font.bold: true
                                            }

                                            Rectangle {
                                                visible: modernViewCard.isSelected
                                                height: 16
                                                implicitWidth: actvModTxt.implicitWidth + 10
                                                radius: 8
                                                color: theme.accentPrimary

                                                Text {
                                                    id: actvModTxt
                                                    anchors.centerIn: parent
                                                    text: "ACTIVE"
                                                    color: theme.bgPrimary
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                            }
                                        }

                                        Text {
                                            text: "Avatars, sender headers, inline rich media"
                                            color: theme.textMuted
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                HoverHandler { id: modViewHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: relayController.set_classic_mode(false)
                                }
                            }

                            // Compact Classic IRC Card
                            Rectangle {
                                id: classicViewCard
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                height: 66
                                radius: 8
                                property bool isSelected: relayController.classic_mode
                                color: classicViewCard.isSelected ? theme.bgActive : (classicViewHover.hovered ? theme.bgHover : theme.bgSecondary)
                                border.color: classicViewCard.isSelected ? theme.borderFocus : theme.borderSubtle
                                border.width: classicViewCard.isSelected ? 2 : 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Text {
                                        text: "📟"
                                        font.pixelSize: 22
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: 3

                                        RowLayout {
                                            spacing: 8
                                            Text {
                                                text: "Compact Classic IRC"
                                                color: classicViewCard.isSelected ? theme.textPrimary : theme.textSecondary
                                                font.pixelSize: 13
                                                font.bold: true
                                            }

                                            Rectangle {
                                                visible: classicViewCard.isSelected
                                                height: 16
                                                implicitWidth: actvClasTxt.implicitWidth + 10
                                                radius: 8
                                                color: theme.accentPrimary

                                                Text {
                                                    id: actvClasTxt
                                                    anchors.centerIn: parent
                                                    text: "ACTIVE"
                                                    color: theme.bgPrimary
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                            }
                                        }

                                        Text {
                                            text: "Dense single-line layout, aligned nicks, monospace"
                                            color: theme.textMuted
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                HoverHandler { id: classicViewHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: relayController.set_classic_mode(true)
                                }
                            }
                        }

                        // Font Size Slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Text {
                                text: "Message Font Size"
                                color: theme.textPrimary
                                font.pixelSize: 13
                                Layout.preferredWidth: 175
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
                                Layout.preferredWidth: 175
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
                                        height: 32
                                        implicitWidth: tsLbl.implicitWidth + 24
                                        radius: 7
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
                                Layout.preferredWidth: 175
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: [50, 100, 150, 250, 500]

                                    delegate: Rectangle {
                                        height: 32
                                        implicitWidth: linesLbl.implicitWidth + 24
                                        radius: 7
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
                            height: 48
                            radius: 8
                            color: notifHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "Desktop Notifications (Freedesktop / DBus on highlights & DMs)"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                }

                                Switch {
                                    id: notifSwitch
                                    checked: relayController.desktop_notifications
                                }
                            }

                            HoverHandler { id: notifHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: relayController.toggle_desktop_notifications()
                            }
                        }

                        // Alternating Message Row Colors Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 8
                            color: zebraToggleHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "Alternating Message Row Colors (Subtle zebra striping for improved chat readability)"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                }

                                Switch {
                                    id: zebraToggleSwitch
                                    checked: relayController.alternating_row_colors
                                }
                            }

                            HoverHandler { id: zebraToggleHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: relayController.toggle_alternating_row_colors()
                            }
                        }

                        // Inline Image / Media Previews Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 8
                            color: mediaHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "Inline Media Previews (Render collapsible previews for direct images)"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                }

                                Switch {
                                    id: mediaSwitch
                                    checked: relayController.show_media_previews
                                }
                            }

                            HoverHandler { id: mediaHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: relayController.toggle_media_previews()
                            }
                        }

                        // Join / Part / Quit Event Noise Filter Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 8
                            color: jpqHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "Show Join / Part / Quit Status Events by Default"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                }

                                Switch {
                                    id: jpqSwitch
                                    checked: relayController.show_join_part_quit
                                }
                            }

                            HoverHandler { id: jpqHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: relayController.toggle_join_part_quit()
                            }
                        }

                        // Auto-Save WeeChat Filters on Change (/save)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 8
                            color: autoSaveFilterHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "Auto-save WeeChat Filters on Change (/save)"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                }

                                Switch {
                                    id: autoSaveFilterSwitch
                                    checked: relayController.auto_save_weechat_filters
                                }
                            }

                            HoverHandler { id: autoSaveFilterHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: relayController.set_auto_save_weechat_filters(!relayController.auto_save_weechat_filters)
                            }
                        }

                        // Auto Reconnect Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 8
                            color: autoRecHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "Auto-reconnect when connection drops"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                }

                                Switch {
                                    id: autoRecSwitch
                                    checked: relayController.auto_reconnect
                                }
                            }

                            HoverHandler { id: autoRecHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: relayController.toggle_auto_reconnect()
                            }
                        }

                        // Confirm on Quit Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 8
                            color: quitConfirmHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "Prompt for confirmation before quitting (Ctrl+Q)"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                }

                                Switch {
                                    id: quitConfirmSwitch
                                    checked: relayController.confirm_on_quit
                                }
                            }

                            HoverHandler { id: quitConfirmHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: relayController.toggle_confirm_on_quit()
                            }
                        }

                        // Close to System Tray Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 48
                            radius: 8
                            color: closeToTrayHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "Close window to system tray instead of quitting"
                                    color: theme.textPrimary
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    elide: Text.ElideRight
                                }

                                Switch {
                                    id: closeToTraySwitch
                                    checked: relayController.close_to_tray
                                }
                            }

                            HoverHandler { id: closeToTrayHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: relayController.toggle_close_to_tray()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: theme.borderSubtle
                    }

                    // SECTION 4: WEB BROWSER
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "WEB BROWSER"
                            color: theme.accentCyan
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 0.8
                        }

                        // Use Custom Browser Toggle
                        Rectangle {
                            Layout.fillWidth: true
                            height: 52
                            radius: 8
                            color: customBrowserHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 2

                                    Text {
                                        text: "Use custom web browser"
                                        color: theme.textPrimary
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "When unchecked, links open in your Linux system default browser"
                                        color: theme.textMuted
                                        font.pixelSize: 11
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        elide: Text.ElideRight
                                    }
                                }

                                Switch {
                                    id: customBrowserSwitch
                                    checked: (relayController.custom_browser || "").trim().length > 0
                                    onToggled: {
                                        if (checked) {
                                            var toRestore = (settingsModal.savedCustomBrowser && settingsModal.savedCustomBrowser.trim().length > 0)
                                                ? settingsModal.savedCustomBrowser.trim()
                                                : "firefox"
                                            relayController.set_custom_browser(toRestore)
                                            browserCmdInput.text = toRestore
                                        } else {
                                            if (relayController.custom_browser.trim().length > 0) {
                                                settingsModal.savedCustomBrowser = relayController.custom_browser.trim()
                                            }
                                            relayController.set_custom_browser("")
                                            browserCmdInput.text = ""
                                        }
                                    }
                                }
                            }

                            HoverHandler { id: customBrowserHover }
                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 60
                                cursorShape: Qt.PointingHandCursor
                                onClicked: customBrowserSwitch.toggle()
                            }
                        }

                        // Custom Command Input Box & Test Button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            opacity: customBrowserSwitch.checked ? 1.0 : 0.45

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                height: 42
                                radius: 8
                                color: theme.bgInput
                                border.color: (browserCmdInput.activeFocus && customBrowserSwitch.checked) ? theme.borderFocus : theme.borderSubtle
                                border.width: 1

                                TextInput {
                                    id: browserCmdInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: customBrowserSwitch.checked ? theme.textPrimary : theme.textMuted
                                    font.pixelSize: 13
                                    font.family: theme.fontMono
                                    text: relayController.custom_browser
                                    selectByMouse: true
                                    enabled: customBrowserSwitch.checked
                                    onTextEdited: {
                                        settingsModal.savedCustomBrowser = text
                                        relayController.set_custom_browser(text)
                                    }
                                }

                                Connections {
                                    target: relayController
                                    function onPreferences_changed() {
                                        if (!browserCmdInput.activeFocus) {
                                            browserCmdInput.text = relayController.custom_browser
                                        }
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: customBrowserSwitch.checked
                                        ? "Enter browser binary (e.g. firefox, /usr/bin/brave, flatpak run ...)"
                                        : "Using Linux system default browser"
                                    color: theme.textMuted
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    visible: browserCmdInput.text.length === 0 && !browserCmdInput.activeFocus
                                }
                            }

                            // Test Button
                            Rectangle {
                                height: 42
                                implicitWidth: testBtnText.implicitWidth + 28
                                radius: 8
                                color: testHover.hovered ? theme.bgHover : theme.bgSecondary
                                border.color: theme.borderSubtle
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        id: testBtnText
                                        text: "Test ↗"
                                        color: theme.textPrimary
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                HoverHandler { id: testHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        relayController.open_url("https://weechat.org")
                                    }
                                }
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
                opacity: 0.7
            }

            // Footer / Done Button
            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                Rectangle {
                    height: 40
                    implicitWidth: 120
                    radius: 8
                    color: doneHover.hovered ? theme.accentHover : theme.accentPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "Done"
                        color: theme.bgPrimary
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
