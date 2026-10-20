import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: msgRoot
    width: ListView.view ? ListView.view.width : 600
    height: mainCol.implicitHeight

    property var relayController
    property var theme
    property bool previewCollapsed: false
    signal nickClicked(string nick)

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        // Day Divider Banner when date changes
        Item {
            visible: model.date_header.length > 0
            Layout.fillWidth: true
            height: visible ? 36 : 0

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: theme.borderSubtle
            }

            Rectangle {
                anchors.centerIn: parent
                implicitWidth: dateLbl.implicitWidth + 20
                height: 22
                radius: 11
                color: theme.bgElevated
                border.color: theme.borderSubtle

                Text {
                    id: dateLbl
                    anchors.centerIn: parent
                    text: model.date_header
                    color: theme.textMuted
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        // Message Row Container
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: rowContent.implicitHeight + (model.is_grouped ? 6 : 14)
            color: {
                if (model.matches_search) return "#362e14"
                if (model.is_highlight) return theme.bgHighlightRow
                if (rowHover.hovered) return "#12151f"
                return "transparent"
            }

            // Left accent bar for highlights or search matches
            Rectangle {
                visible: model.is_highlight || model.matches_search
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                color: model.matches_search ? theme.statusWarning : theme.badgeHighlight
            }

            RowLayout {
                id: rowContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                anchors.topMargin: model.is_grouped ? 3 : 8
                spacing: 12

                // Left Gutter: Avatar badge on first message in burst, or hover timestamp on grouped lines
                Item {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: model.is_grouped || model.is_system ? 18 : 34
                    Layout.alignment: Qt.AlignTop

                    // Avatar Circle for ungrouped normal message
                    Rectangle {
                        visible: !model.is_grouped && !model.is_system && !model.is_action
                        width: 34
                        height: 34
                        radius: 9
                        color: Qt.rgba(0.14, 0.17, 0.24, 1.0)
                        border.color: model.nick_color
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: model.prefix_plain.length > 0 ? model.prefix_plain.substring(0, 2).toUpperCase() : "•"
                            color: model.nick_color
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: msgRoot.nickClicked(model.prefix_plain)
                        }
                    }

                    // Hover timestamp for grouped messages or system messages
                    Text {
                        visible: (model.is_grouped && rowHover.hovered) || model.is_system || model.is_action
                        anchors.centerIn: parent
                        text: model.time_str
                        color: theme.textMuted
                        font.pixelSize: 10
                        font.family: theme.fontMono
                    }
                }

                // Right Column: Header (nick + role + time) + Message Body + Optional Image Preview
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 3

                    // Sender Header (only shown on first message of a group)
                    RowLayout {
                        visible: !model.is_grouped && !model.is_system && !model.is_action
                        spacing: 6

                        // Role badge (@ / +)
                        Rectangle {
                            visible: model.role_badge.length > 0
                            width: 16
                            height: 16
                            radius: 4
                            color: model.role_badge === "@" ? "#2b2347" : "#1c312c"

                            Text {
                                anchors.centerIn: parent
                                text: model.role_badge
                                color: model.role_badge === "@" ? "#c084fc" : "#4ade80"
                                font.pixelSize: 10
                                font.bold: true
                                font.family: theme.fontMono
                            }
                        }

                        // Sender Nickname
                        Text {
                            text: model.prefix_plain
                            color: model.nick_color
                            font.pixelSize: 13
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: msgRoot.nickClicked(model.prefix_plain)
                            }
                        }

                        // Timestamp
                        Text {
                            text: model.time_str
                            color: theme.textMuted
                            font.pixelSize: 11
                            font.family: theme.fontMono
                        }

                        // Highlight badge
                        Rectangle {
                            visible: model.is_highlight
                            height: 16
                            implicitWidth: hlText.implicitWidth + 10
                            radius: 8
                            color: theme.badgeHighlight

                            Text {
                                id: hlText
                                anchors.centerIn: parent
                                text: "MENTION"
                                color: "#ffffff"
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }
                    }

                    // Message Text Body
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (model.is_action) {
                                return "<i>* " + model.styled_text + "</i>"
                            }
                            return model.styled_text
                        }
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        color: {
                            if (model.is_system) return theme.textMuted
                            if (model.is_action) return theme.accentCyan
                            return theme.textPrimary
                        }
                        font.pixelSize: model.is_system ? Math.max(10, theme.baseFontSize - 2) : theme.baseFontSize
                        font.family: theme.fontSans
                        lineHeight: 1.25
                        onLinkActivated: function(link) {
                            Qt.openUrlExternally(link)
                        }
                    }

                    // Native QtQuick Image Preview Card (for direct image links)
                    Rectangle {
                        visible: relayController.show_media_previews && model.image_url.length > 0 && !msgRoot.previewCollapsed
                        Layout.topMargin: 6
                        width: Math.min(380, parent.width)
                        height: imgPreview.status === Image.Ready ? Math.min(240, imgPreview.implicitHeight * (width / Math.max(1, imgPreview.implicitWidth))) + 32 : 34
                        radius: 8
                        color: theme.bgElevated
                        border.color: theme.borderSubtle
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                color: theme.bgSecondary

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10

                                    Text {
                                        Layout.fillWidth: true
                                        text: model.image_url
                                        color: theme.textSecondary
                                        font.pixelSize: 11
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        text: "Hide"
                                        color: theme.textMuted
                                        font.pixelSize: 11
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: msgRoot.previewCollapsed = true
                                        }
                                    }
                                }
                            }

                            Image {
                                id: imgPreview
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                source: relayController.show_media_previews ? model.image_url : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally(model.image_url)
                                }
                            }
                        }
                    }
                }
            }

            HoverHandler { id: rowHover }
        }
    }
}
