import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sidebar
    color: theme.bgSecondary

    property var relayController
    property var theme
    signal openConnectionRequested()
    signal openServerManagerRequested()
    signal openQuickSwitcherRequested()
    signal openSettingsRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top App Brand & Quick Switcher Trigger
        Rectangle {
            Layout.fillWidth: true
            height: 54
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 10

                Rectangle {
                    width: 28
                    height: 28
                    radius: 7
                    color: theme.accentPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "W"
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "WeeChat"
                        color: theme.textPrimary
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: relayController.server_version.length > 0 ? relayController.server_version : "Relay Client"
                        color: theme.textMuted
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Hotlist Jump Button (when unread exists)
                Rectangle {
                    visible: relayController.total_unread_count > 0
                    height: 24
                    implicitWidth: hotJumpRow.implicitWidth + 12
                    radius: 12
                    color: relayController.total_highlight_count > 0 ? theme.badgeHighlight : theme.accentPrimary

                    RowLayout {
                        id: hotJumpRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "⚡ " + relayController.total_unread_count
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: relayController.select_next_unread_buffer()
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

        // Quick Filter / Ctrl+K Trigger Bar
        Item {
            Layout.fillWidth: true
            height: 46

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 8
                anchors.bottomMargin: 6
                radius: 8
                color: theme.bgInput
                border.color: filterInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "⌕"
                        color: theme.textMuted
                        font.pixelSize: 14
                    }

                    TextInput {
                        id: filterInput
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: theme.textPrimary
                        font.pixelSize: 12
                        selectByMouse: true
                        onTextChanged: relayController.filter_buffers(text)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Filter buffers..."
                            color: theme.textMuted
                            font.pixelSize: 12
                            visible: filterInput.text.length === 0 && !filterInput.activeFocus
                        }
                    }

                    Rectangle {
                        width: 44
                        height: 18
                        radius: 4
                        color: theme.bgElevated
                        border.color: theme.borderSubtle

                        Text {
                            anchors.centerIn: parent
                            text: "Ctrl+K"
                            color: theme.textMuted
                            font.pixelSize: 10
                            font.family: theme.fontMono
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sidebar.openQuickSwitcherRequested()
                        }
                    }
                }
            }
        }

        // Buffer ListView grouped by IRC Server
        ListView {
            id: bufferList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: relayController.buffer_model
            spacing: 2
            topMargin: 4
            bottomMargin: 8

            section.property: "server_name"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
                width: bufferList.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: section.toUpperCase()
                    color: theme.textMuted
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 0.8
                }
            }

            delegate: Item {
                width: bufferList.width
                height: 32

                Rectangle {
                    id: rowBg
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    radius: 7
                    color: model.is_active
                        ? theme.bgActive
                        : (rowHover.hovered ? theme.bgHover : "transparent")

                    // Left active indicator pill
                    Rectangle {
                        visible: model.is_active
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 16
                        radius: 2
                        color: theme.accentPrimary
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6

                        // Buffer number
                        Text {
                            text: model.number
                            color: theme.textMuted
                            font.pixelSize: 11
                            font.family: theme.fontMono
                            Layout.preferredWidth: 16
                        }

                        // Buffer icon prefix
                        Text {
                            text: {
                                if (model.buffer_type === "channel") return "#"
                                if (model.buffer_type === "private") return "●"
                                if (model.buffer_type === "server") return "⇄"
                                return "◈"
                            }
                            color: {
                                if (model.highlight_count > 0) return theme.badgeHighlight
                                if (model.buffer_type === "private") return theme.statusOnline
                                if (model.is_active) return theme.accentCyan
                                return theme.textMuted
                            }
                            font.pixelSize: 12
                            font.bold: true
                        }

                        // Buffer short name
                        Text {
                            Layout.fillWidth: true
                            text: model.short_name.startsWith("#") ? model.short_name.substring(1) : model.short_name
                            color: {
                                if (model.is_active || model.unread_count > 0 || model.highlight_count > 0)
                                    return theme.textPrimary
                                return theme.textSecondary
                            }
                            font.pixelSize: 13
                            font.bold: model.is_active || model.unread_count > 0 || model.highlight_count > 0
                            elide: Text.ElideRight
                        }

                        // Unread / Highlight Pill Badge
                        Rectangle {
                            visible: model.unread_count > 0 || model.highlight_count > 0
                            height: 18
                            implicitWidth: Math.max(18, badgeText.implicitWidth + 10)
                            radius: 9
                            color: model.highlight_count > 0 ? theme.badgeHighlight : theme.badgeUnread

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: model.highlight_count > 0 ? model.highlight_count : model.unread_count
                                color: "#ffffff"
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }

                    HoverHandler { id: rowHover }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton) {
                                relayController.close_buffer(model.ptr)
                            } else {
                                relayController.select_buffer(model.ptr)
                            }
                        }
                    }
                }
            }
        }

        // Bottom Connection Status Footer
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: theme.bgElevated

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: theme.borderSubtle
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Rectangle {
                    width: 9
                    height: 9
                    radius: 5
                    color: {
                        if (relayController.connection_state === "Connected") return theme.statusOnline
                        if (relayController.connection_state === "Error") return theme.statusError
                        return theme.statusWarning
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: relayController.connection_state
                        color: theme.textPrimary
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Text {
                        text: relayController.connection_state === "Connected"
                            ? (relayController.saved_host + ":" + relayController.saved_port + " • " + relayController.latency_ms + "ms")
                            : relayController.status_detail
                        color: theme.textMuted
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    implicitWidth: connBtnLabel.implicitWidth + 16
                    height: 28
                    radius: 6
                    color: footerConnHover.hovered ? theme.bgHover : theme.bgSecondary
                    border.color: theme.borderSubtle
                    border.width: 1

                    Text {
                        id: connBtnLabel
                        anchors.centerIn: parent
                        text: "Servers"
                        color: theme.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    HoverHandler { id: footerConnHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sidebar.openServerManagerRequested()
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    color: footerSettingsHover.hovered ? theme.bgHover : theme.bgSecondary
                    border.color: theme.borderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        color: theme.textPrimary
                        font.pixelSize: 13
                    }

                    HoverHandler { id: footerSettingsHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sidebar.openSettingsRequested()
                    }
                }
            }
        }
    }

    // Right border divider
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: theme.borderSubtle
    }
}
