import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: nickDrawer
    color: theme.bgSecondary

    property var relayController
    property var theme

    signal mentionNickRequested(string nick)

    // Left border divider
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: theme.borderSubtle
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 1
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14

                Text {
                    text: "CHANNEL USERS"
                    color: theme.textSecondary
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.7
                    Layout.fillWidth: true
                }

                Rectangle {
                    height: 18
                    implicitWidth: cntText.implicitWidth + 10
                    radius: 9
                    color: theme.bgElevated

                    Text {
                        id: cntText
                        anchors.centerIn: parent
                        text: relayController.active_buffer_nick_count
                        color: theme.textPrimary
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: theme.borderSubtle
            }
        }

        // Nicklist ListView with Mode Sections (OPERATORS, VOICED, USERS)
        ListView {
            id: nickListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: relayController.nick_model
            spacing: 1
            topMargin: 4
            bottomMargin: 8

            section.property: "group_label"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
                width: nickListView.width
                height: 26

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    text: section
                    color: theme.textMuted
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 0.6
                }
            }

            delegate: Item {
                width: nickListView.width
                height: 28

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    radius: 6
                    color: (nickContextMenu.visible && nickContextMenu.targetNick === model.name)
                        ? theme.bgActive
                        : (nickRowHover.hovered ? theme.bgHover : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        // Mode Prefix (@ / +)
                        Text {
                            visible: model.prefix.length > 0
                            text: model.prefix
                            color: model.prefix === "@" ? "#c084fc" : "#4ade80"
                            font.pixelSize: 11
                            font.bold: true
                            font.family: theme.fontMono
                        }

                        // Colored Dot if no prefix
                        Rectangle {
                            visible: model.prefix.length === 0
                            width: 6
                            height: 6
                            radius: 3
                            color: model.color
                        }

                        // Nickname
                        Text {
                            Layout.fillWidth: true
                            text: model.name
                            color: model.color
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler { id: nickRowHover }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                nickContextMenu.targetNick = model.name
                                nickContextMenu.targetPrefix = model.prefix
                                nickContextMenu.popup()
                            } else {
                                nickDrawer.mentionNickRequested(model.name)
                            }
                        }
                        onDoubleClicked: function(mouse) {
                            if (mouse.button === Qt.LeftButton) {
                                relayController.open_query_with_nick(model.name)
                            }
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }
    }

    // Right-Click Context Menu for Channel Users
    Menu {
        id: nickContextMenu
        property string targetNick: ""
        property string targetPrefix: ""
        topPadding: 6
        bottomPadding: 6
        leftPadding: 6
        rightPadding: 6

        background: Rectangle {
            implicitWidth: 200
            color: theme.bgElevated
            border.color: theme.borderSubtle
            border.width: 1
            radius: 8
        }

        // Header showing user name and role badge
        MenuItem {
            enabled: false
            contentItem: RowLayout {
                spacing: 8
                Text {
                    text: nickContextMenu.targetPrefix.length > 0 ? nickContextMenu.targetPrefix : "👤"
                    font.pixelSize: 12
                    font.bold: true
                    color: nickContextMenu.targetPrefix === "@" ? "#c084fc" : (nickContextMenu.targetPrefix === "+" ? "#4ade80" : theme.accentCyan)
                }
                Text {
                    text: nickContextMenu.targetNick
                    color: theme.textPrimary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            background: Item {}
        }

        MenuSeparator {
            contentItem: Rectangle {
                implicitWidth: parent.width
                implicitHeight: 1
                color: theme.borderSubtle
            }
        }

        // Mention Nick
        MenuItem {
            id: mentionItem
            contentItem: RowLayout {
                spacing: 8
                Text { text: "💬"; font.pixelSize: 12 }
                Text {
                    text: "Mention " + nickContextMenu.targetNick
                    color: mentionItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: mentionItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (nickContextMenu.targetNick.length > 0) {
                    nickDrawer.mentionNickRequested(nickContextMenu.targetNick)
                }
            }
        }

        // Direct Message / Query
        MenuItem {
            id: queryItem
            contentItem: RowLayout {
                spacing: 8
                Text { text: "✉️"; font.pixelSize: 12 }
                Text {
                    text: "Direct Message (/query)"
                    color: queryItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: queryItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (nickContextMenu.targetNick.length > 0) {
                    relayController.open_query_with_nick(nickContextMenu.targetNick)
                }
            }
        }

        // Whois User Info
        MenuItem {
            id: whoisItem
            contentItem: RowLayout {
                spacing: 8
                Text { text: "ℹ️"; font.pixelSize: 12 }
                Text {
                    text: "User Info (/whois)"
                    color: whoisItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: whoisItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (nickContextMenu.targetNick.length > 0) {
                    relayController.whois_nick(nickContextMenu.targetNick)
                }
            }
        }

        // Mute / Unmute Nickname Filter
        MenuItem {
            id: muteNickItem
            visible: relayController.is_valid_nick_for_mute(nickContextMenu.targetNick)
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text {
                    text: relayController.is_nick_muted(nickContextMenu.targetNick) ? "🔊" : "🔇"
                    font.pixelSize: 12
                }
                Text {
                    text: relayController.is_nick_muted(nickContextMenu.targetNick)
                        ? "Unmute " + nickContextMenu.targetNick
                        : "Mute " + nickContextMenu.targetNick + " (/filter)"
                    color: muteNickItem.highlighted
                        ? (relayController.is_nick_muted(nickContextMenu.targetNick) ? theme.accentCyan : theme.badgeHighlight)
                        : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: muteNickItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (nickContextMenu.targetNick.length > 0) {
                    relayController.toggle_mute_nick(nickContextMenu.targetNick)
                }
            }
        }

        MenuSeparator {
            contentItem: Rectangle {
                implicitWidth: parent.width
                implicitHeight: 1
                color: theme.borderSubtle
            }
        }

        // Copy Nickname
        MenuItem {
            id: copyNickItem
            contentItem: RowLayout {
                spacing: 8
                Text { text: "📋"; font.pixelSize: 12 }
                Text {
                    text: "Copy Nickname"
                    color: copyNickItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: copyNickItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (nickContextMenu.targetNick.length > 0) {
                    relayController.copy_to_clipboard(nickContextMenu.targetNick)
                }
            }
        }

        MenuSeparator {
            visible: relayController.active_buffer_is_operator
            contentItem: Rectangle {
                implicitWidth: parent.width
                implicitHeight: 1
                color: theme.borderSubtle
            }
        }

        // Operator mode (+o / -o)
        MenuItem {
            id: opActionItem
            visible: relayController.active_buffer_is_operator
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "🛡️"; font.pixelSize: 12 }
                Text {
                    text: nickContextMenu.targetPrefix === "@" ? "Take Operator (-o)" : "Give Operator (+o)"
                    color: opActionItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: opActionItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (nickContextMenu.targetNick.length > 0) {
                    var mode = nickContextMenu.targetPrefix === "@" ? "-o" : "+o"
                    relayController.send_input("/mode " + relayController.active_buffer_name + " " + mode + " " + nickContextMenu.targetNick)
                }
            }
        }

        // Voice mode (+v / -v)
        MenuItem {
            id: voiceActionItem
            visible: relayController.active_buffer_is_operator
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "🎤"; font.pixelSize: 12 }
                Text {
                    text: nickContextMenu.targetPrefix === "+" ? "Take Voice (-v)" : "Give Voice (+v)"
                    color: voiceActionItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: voiceActionItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (nickContextMenu.targetNick.length > 0) {
                    var mode = nickContextMenu.targetPrefix === "+" ? "-v" : "+v"
                    relayController.send_input("/mode " + relayController.active_buffer_name + " " + mode + " " + nickContextMenu.targetNick)
                }
            }
        }

        // Kick user
        MenuItem {
            id: kickActionItem
            visible: relayController.active_buffer_is_operator
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "👢"; font.pixelSize: 12 }
                Text {
                    text: "Kick from Channel"
                    color: kickActionItem.highlighted ? theme.badgeHighlight : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: kickActionItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (nickContextMenu.targetNick.length > 0) {
                    relayController.send_input("/kick " + nickContextMenu.targetNick)
                }
            }
        }

        // Ban user
        MenuItem {
            id: banActionItem
            visible: relayController.active_buffer_is_operator
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "🚫"; font.pixelSize: 12 }
                Text {
                    text: "Ban from Channel"
                    color: banActionItem.highlighted ? theme.badgeHighlight : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: banActionItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (nickContextMenu.targetNick.length > 0) {
                    relayController.send_input("/ban " + nickContextMenu.targetNick)
                }
            }
        }
    }
}
