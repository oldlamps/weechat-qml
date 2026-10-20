import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: nickDrawer
    color: theme.bgSecondary

    property var relayController
    property var theme
    property string selectedNick: ""

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

        // Selected Nick Quick-Action Bar (appears when clicking a user)
        Rectangle {
            visible: nickDrawer.selectedNick.length > 0
            Layout.fillWidth: true
            height: visible ? 72 : 0
            color: theme.bgElevated

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: nickDrawer.selectedNick
                        color: theme.textPrimary
                        font.pixelSize: 12
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "✕"
                        color: theme.textMuted
                        font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent
                            onClicked: nickDrawer.selectedNick = ""
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 5
                        color: theme.accentPrimary
                        Text {
                            anchors.centerIn: parent
                            text: "@Mention"
                            color: "#ffffff"
                            font.pixelSize: 10
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                nickDrawer.mentionNickRequested(nickDrawer.selectedNick)
                                nickDrawer.selectedNick = ""
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 5
                        color: theme.bgHover
                        border.color: theme.borderSubtle
                        Text {
                            anchors.centerIn: parent
                            text: "Query"
                            color: theme.textPrimary
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                relayController.open_query_with_nick(nickDrawer.selectedNick)
                                nickDrawer.selectedNick = ""
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 5
                        color: theme.bgHover
                        border.color: theme.borderSubtle
                        Text {
                            anchors.centerIn: parent
                            text: "Whois"
                            color: theme.textPrimary
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                relayController.whois_nick(nickDrawer.selectedNick)
                                nickDrawer.selectedNick = ""
                            }
                        }
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
                    color: nickDrawer.selectedNick === model.name
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
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (nickDrawer.selectedNick === model.name) {
                                nickDrawer.selectedNick = ""
                            } else {
                                nickDrawer.selectedNick = model.name
                            }
                        }
                        onDoubleClicked: {
                            nickDrawer.mentionNickRequested(model.name)
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }
    }
}
