import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: headerBar
    height: 54
    color: theme.bgSecondary

    property var relayController
    property var theme
    property bool showBufferSidebar: true
    property bool showNickSidebar: true
    property bool showSearchBar: false

    signal toggleBufferSidebar()
    signal toggleNickSidebar()
    signal openSettingsRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 10

            // Toggle Left Sidebar Button
            Rectangle {
                width: 30
                height: 30
                radius: 6
                color: leftToggleHover.hovered ? theme.bgHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "☰"
                    color: showBufferSidebar ? theme.textPrimary : theme.textMuted
                    font.pixelSize: 15
                }

                HoverHandler { id: leftToggleHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: headerBar.toggleBufferSidebar()
                }
            }

            // Channel / Buffer Name & Server Pill
            RowLayout {
                spacing: 8

                Text {
                    text: relayController.active_buffer_name.length > 0 ? relayController.active_buffer_name : "No Buffer"
                    color: theme.textPrimary
                    font.pixelSize: 16
                    font.bold: true

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: headerContextMenu.popup()
                    }
                }

                Rectangle {
                    visible: relayController.active_buffer_server.length > 0
                    height: 20
                    implicitWidth: srvLabel.implicitWidth + 12
                    radius: 5
                    color: theme.bgElevated
                    border.color: theme.borderSubtle

                    Text {
                        id: srvLabel
                        anchors.centerIn: parent
                        text: relayController.active_buffer_server
                        color: theme.accentCyan
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                // Close Buffer Button
                Rectangle {
                    visible: relayController.active_buffer_ptr.length > 0 && relayController.active_buffer_type !== "core"
                    width: 20
                    height: 20
                    radius: 4
                    color: closeBufHover.hovered ? theme.bgHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeBufHover.hovered ? theme.badgeHighlight : theme.textMuted
                        font.pixelSize: 11
                    }

                    HoverHandler { id: closeBufHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: relayController.close_buffer("")
                    }
                }
            }

            // Vertical separator
            Rectangle {
                width: 1
                height: 18
                color: theme.borderSubtle
                visible: relayController.active_buffer_topic.length > 0
            }

            // Channel Topic
            Text {
                Layout.fillWidth: true
                text: relayController.active_buffer_topic
                textFormat: Text.StyledText
                color: theme.textSecondary
                font.pixelSize: 12
                elide: Text.ElideRight
                maximumLineCount: 1
                onLinkActivated: function(link) { relayController.open_url(link) }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: headerContextMenu.popup()
                }
            }

            // In-Buffer Search Box (when active)
            Rectangle {
                visible: headerBar.showSearchBar
                width: 210
                height: 30
                radius: 6
                color: theme.bgInput
                border.color: searchInput.activeFocus ? theme.borderFocus : theme.borderSubtle

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: theme.textPrimary
                        font.pixelSize: 12
                        selectByMouse: true
                        onTextChanged: relayController.search_in_buffer(text)
                    }

                    Text {
                        visible: searchInput.text.length > 0
                        text: relayController.search_match_count + " hits"
                        color: theme.accentCyan
                        font.pixelSize: 10
                    }

                    Text {
                        text: "✕"
                        color: theme.textMuted
                        font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                searchInput.text = ""
                                relayController.search_in_buffer("")
                                headerBar.showSearchBar = false
                            }
                        }
                    }
                }
            }

            // Search Toggle Button
            Rectangle {
                width: 30
                height: 30
                radius: 6
                color: headerBar.showSearchBar ? theme.bgActive : (searchHover.hovered ? theme.bgHover : "transparent")

                Text {
                    anchors.centerIn: parent
                    text: "⌕"
                    color: headerBar.showSearchBar ? theme.accentCyan : theme.textSecondary
                    font.pixelSize: 15
                }

                HoverHandler { id: searchHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        headerBar.showSearchBar = !headerBar.showSearchBar
                        if (headerBar.showSearchBar) {
                            searchInput.forceActiveFocus()
                        } else {
                            searchInput.text = ""
                            relayController.search_in_buffer("")
                        }
                    }
                }
            }

            // Join/Part/Quit Filter Pill Toggle
            Rectangle {
                height: 28
                implicitWidth: jpqLabel.implicitWidth + 16
                radius: 6
                color: relayController.show_join_part_quit ? theme.bgActive : (jpqHover.hovered ? theme.bgHover : theme.bgElevated)
                border.color: relayController.show_join_part_quit ? theme.accentPrimary : theme.borderSubtle

                Text {
                    id: jpqLabel
                    anchors.centerIn: parent
                    text: relayController.show_join_part_quit ? "Events: Shown" : "Events: Filtered"
                    color: relayController.show_join_part_quit ? theme.textPrimary : theme.textSecondary
                    font.pixelSize: 11
                }

                HoverHandler { id: jpqHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: relayController.toggle_join_part_quit()
                }
            }

            // Media Preview Toggle
            Rectangle {
                height: 28
                implicitWidth: mediaLabel.implicitWidth + 16
                radius: 6
                color: relayController.show_media_previews ? theme.bgActive : (mediaHover.hovered ? theme.bgHover : theme.bgElevated)
                border.color: relayController.show_media_previews ? theme.accentPrimary : theme.borderSubtle

                Text {
                    id: mediaLabel
                    anchors.centerIn: parent
                    text: "Media"
                    color: relayController.show_media_previews ? theme.textPrimary : theme.textSecondary
                    font.pixelSize: 11
                }

                HoverHandler { id: mediaHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: relayController.toggle_media_previews()
                }
            }

            // Settings Cog Button
            Rectangle {
                width: 30
                height: 30
                radius: 6
                color: settingsHover.hovered ? theme.bgHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "⚙"
                    color: theme.textSecondary
                    font.pixelSize: 15
                }

                HoverHandler { id: settingsHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: headerBar.openSettingsRequested()
                }
            }

            // View Mode Toggle Button (Modern vs Compact Classic IRC)
            Rectangle {
                width: 30
                height: 30
                radius: 6
                color: relayController.classic_mode ? theme.bgActive : (viewModeHover.hovered ? theme.bgHover : "transparent")

                Text {
                    anchors.centerIn: parent
                    text: relayController.classic_mode ? "📟" : "💬"
                    font.pixelSize: 13
                }

                HoverHandler { id: viewModeHover }
                ToolTip.visible: viewModeHover.hovered
                ToolTip.delay: 500
                ToolTip.text: relayController.classic_mode ? "Compact Classic IRC View (click for Modern)" : "Modern View (click for Compact Classic IRC)"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: relayController.toggle_classic_mode()
                }
            }

            // Nicklist Sidebar Toggle Button
            Rectangle {
                visible: relayController.active_buffer_type === "channel"
                height: 28
                implicitWidth: nickToggleRow.implicitWidth + 16
                radius: 6
                color: showNickSidebar ? theme.bgActive : (nickToggleHover.hovered ? theme.bgHover : theme.bgElevated)
                border.color: showNickSidebar ? theme.accentPrimary : theme.borderSubtle

                RowLayout {
                    id: nickToggleRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "👥"
                        font.pixelSize: 11
                        color: theme.textPrimary
                    }

                    Text {
                        text: relayController.active_buffer_nick_count
                        color: theme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                HoverHandler { id: nickToggleHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: headerBar.toggleNickSidebar()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.borderSubtle
        }
    }

    Menu {
        id: headerContextMenu
        topPadding: 6
        bottomMargin: 6
        leftPadding: 6
        rightPadding: 6

        background: Rectangle {
            implicitWidth: 200
            color: theme.bgElevated
            border.color: theme.borderSubtle
            border.width: 1
            radius: 8
        }

        MenuItem {
            id: copyTopicItem
            visible: relayController.active_buffer_topic.length > 0
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "📌"; font.pixelSize: 12 }
                Text {
                    text: "Copy Topic"
                    color: copyTopicItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: copyTopicItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                relayController.copy_to_clipboard(relayController.active_buffer_topic)
            }
        }

        MenuItem {
            id: copyChanItem
            visible: relayController.active_buffer_name.length > 0
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "#"; font.pixelSize: 13; font.bold: true; color: theme.accentCyan }
                Text {
                    text: "Copy Channel Name"
                    color: copyChanItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: copyChanItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                relayController.copy_to_clipboard(relayController.active_buffer_name)
            }
        }
    }
}
