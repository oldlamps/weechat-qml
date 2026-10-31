import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: switcherOverlay
    anchors.fill: parent
    color: "#bb090b10"
    visible: false
    z: 95

    property var relayController
    property var theme

    function openModal() {
        switcherOverlay.visible = true
        queryInput.text = ""
        relayController.filter_buffers("")
        var activeIdx = relayController.active_buffer_filtered_index()
        if (activeIdx >= 0) {
            switcherList.currentIndex = activeIdx
            switcherList.positionViewAtIndex(activeIdx, ListView.Center)
            Qt.callLater(function() {
                if (switcherOverlay.visible) {
                    switcherList.positionViewAtIndex(switcherList.currentIndex, ListView.Center)
                }
            })
        } else {
            switcherList.currentIndex = 0
            if (switcherList.count > 0) {
                switcherList.positionViewAtIndex(0, ListView.Beginning)
            }
        }
        queryInput.forceActiveFocus()
    }

    function closeModal() {
        queryInput.text = ""
        relayController.filter_buffers("")
        switcherOverlay.visible = false
    }

    function activateSelection() {
        if (switcherList.count === 0) return
        var idx = Math.max(0, Math.min(switcherList.currentIndex, switcherList.count - 1))
        if (relayController.select_buffer_by_filtered_index(idx)) {
            switcherOverlay.closeModal()
            return
        }
        var item = switcherList.itemAtIndex(idx)
        if (item && item.itemPtr) {
            relayController.select_buffer(item.itemPtr)
            switcherOverlay.closeModal()
        } else if (switcherList.currentItem && switcherList.currentItem.itemPtr) {
            relayController.select_buffer(switcherList.currentItem.itemPtr)
            switcherOverlay.closeModal()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: switcherOverlay.closeModal()
    }

    Rectangle {
        width: 540
        height: 420
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 70
        radius: 12
        color: theme.bgElevated
        border.color: theme.borderFocus
        border.width: 1

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Top Search Input Bar
            Rectangle {
                Layout.fillWidth: true
                height: 52
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Text {
                        text: "⚡"
                        color: theme.accentCyan
                        font.pixelSize: 16
                    }

                    TextInput {
                        id: queryInput
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: theme.textPrimary
                        font.pixelSize: 15
                        selectByMouse: true

                        onTextChanged: {
                            relayController.filter_buffers(text)
                            if (text.length === 0) {
                                var activeIdx = relayController.active_buffer_filtered_index()
                                if (activeIdx >= 0) {
                                    switcherList.currentIndex = activeIdx
                                    switcherList.positionViewAtIndex(activeIdx, ListView.Center)
                                    return
                                }
                            }
                            switcherList.currentIndex = 0
                            if (switcherList.count > 0) {
                                switcherList.positionViewAtIndex(0, ListView.Beginning)
                            }
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                                if (event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) {
                                    event.accepted = true
                                    if (event.key === Qt.Key_Down) {
                                        if (switcherList.count > 0) {
                                            if (switcherList.currentIndex < switcherList.count - 1) {
                                                switcherList.currentIndex++
                                            } else {
                                                switcherList.currentIndex = 0
                                            }
                                            switcherList.positionViewAtIndex(switcherList.currentIndex, ListView.Contain)
                                        }
                                    } else {
                                        if (switcherList.count > 0) {
                                            if (switcherList.currentIndex > 0) {
                                                switcherList.currentIndex--
                                            } else {
                                                switcherList.currentIndex = switcherList.count - 1
                                            }
                                            switcherList.positionViewAtIndex(switcherList.currentIndex, ListView.Contain)
                                        }
                                    }
                                }
                            }
                        }

                        Keys.onTabPressed: function(event) {
                            event.accepted = true
                            if (switcherList.count > 0) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    if (switcherList.currentIndex > 0) {
                                        switcherList.currentIndex--
                                    } else {
                                        switcherList.currentIndex = switcherList.count - 1
                                    }
                                } else {
                                    if (switcherList.currentIndex < switcherList.count - 1) {
                                        switcherList.currentIndex++
                                    } else {
                                        switcherList.currentIndex = 0
                                    }
                                }
                                switcherList.positionViewAtIndex(switcherList.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onEscapePressed: function(event) {
                            event.accepted = true
                            switcherOverlay.closeModal()
                        }

                        Keys.onDownPressed: function(event) {
                            event.accepted = true
                            if (switcherList.count > 0) {
                                if (switcherList.currentIndex < switcherList.count - 1) {
                                    switcherList.currentIndex++
                                } else {
                                    switcherList.currentIndex = 0
                                }
                                switcherList.positionViewAtIndex(switcherList.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onUpPressed: function(event) {
                            event.accepted = true
                            if (switcherList.count > 0) {
                                if (switcherList.currentIndex > 0) {
                                    switcherList.currentIndex--
                                } else {
                                    switcherList.currentIndex = switcherList.count - 1
                                }
                                switcherList.positionViewAtIndex(switcherList.currentIndex, ListView.Contain)
                            }
                        }

                        Keys.onReturnPressed: function(event) {
                            event.accepted = true
                            switcherOverlay.activateSelection()
                        }

                        Keys.onEnterPressed: function(event) {
                            event.accepted = true
                            switcherOverlay.activateSelection()
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Type to search buffers... (↑↓ to navigate, Enter to select)"
                            color: theme.textMuted
                            font.pixelSize: 13
                            visible: queryInput.text.length === 0
                        }
                    }

                    Rectangle {
                        width: 36
                        height: 20
                        radius: 4
                        color: theme.bgSecondary
                        border.color: theme.borderSubtle

                        Text {
                            anchors.centerIn: parent
                            text: "ESC"
                            color: theme.textMuted
                            font.pixelSize: 10
                            font.family: theme.fontMono
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

            // Matching Buffers List with full keyboard navigation
            ListView {
                id: switcherList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: relayController.buffer_model
                topMargin: 6
                bottomMargin: 6
                spacing: 2
                highlightMoveDuration: 0
                highlightMoveVelocity: -1
                keyNavigationWraps: true

                section.property: "server_name"
                section.criteria: ViewSection.FullString
                section.delegate: Item {
                    width: switcherList.width
                    height: 24

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: section.toUpperCase()
                                color: theme.accentCyan
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 0.8
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: theme.borderSubtle
                                opacity: 0.5
                            }
                        }
                    }
                }

                delegate: Item {
                    id: delegateItem
                    width: switcherList.width
                    height: 38
                    property string itemPtr: model.ptr
                    readonly property bool isSelected: ListView.isCurrentItem

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        radius: 7
                        color: delegateItem.isSelected ? theme.bgActive : (swHover.hovered ? theme.bgHover : "transparent")
                        border.color: delegateItem.isSelected ? theme.accentPrimary : "transparent"
                        border.width: delegateItem.isSelected ? 1 : 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            // Number pill
                            Rectangle {
                                width: 22
                                height: 20
                                radius: 4
                                color: delegateItem.isSelected ? theme.accentPrimary : theme.bgElevated

                                Text {
                                    anchors.centerIn: parent
                                    text: model.number
                                    color: delegateItem.isSelected ? "#ffffff" : theme.textMuted
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: theme.fontMono
                                }
                            }

                            // Buffer icon
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
                                    return theme.accentCyan
                                }
                                font.pixelSize: 12
                                font.bold: true
                            }

                            // Short name
                            Text {
                                text: model.short_name
                                color: delegateItem.isSelected ? "#ffffff" : theme.textPrimary
                                font.pixelSize: 14
                                font.bold: true
                            }

                            // Server tag
                            Text {
                                text: model.server_name
                                color: delegateItem.isSelected ? theme.accentCyan : theme.textMuted
                                font.pixelSize: 11
                            }

                            // Current channel indicator badge
                            Rectangle {
                                visible: model.is_active
                                height: 16
                                implicitWidth: curText.implicitWidth + 8
                                radius: 4
                                color: delegateItem.isSelected ? Qt.alpha("#ffffff", 0.2) : Qt.alpha(theme.accentCyan, 0.15)
                                border.color: delegateItem.isSelected ? Qt.alpha("#ffffff", 0.4) : Qt.alpha(theme.accentCyan, 0.35)
                                border.width: 1

                                Text {
                                    id: curText
                                    anchors.centerIn: parent
                                    text: "current"
                                    color: delegateItem.isSelected ? "#ffffff" : theme.accentCyan
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }

                            // Title topic snippet
                            Text {
                                Layout.fillWidth: true
                                text: model.title
                                color: theme.textMuted
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            // Unread / Highlight Badge
                            Rectangle {
                                visible: model.unread_count > 0 || model.highlight_count > 0
                                height: 18
                                implicitWidth: Math.max(18, swBadge.implicitWidth + 10)
                                radius: 9
                                color: model.highlight_count > 0 ? theme.badgeHighlight : theme.badgeUnread

                                Text {
                                    id: swBadge
                                    anchors.centerIn: parent
                                    text: model.highlight_count > 0 ? model.highlight_count : model.unread_count
                                    color: "#ffffff"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }

                        HoverHandler { id: swHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                switcherList.currentIndex = index
                                switcherOverlay.activateSelection()
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }

            // Keyboard hints footer
            Rectangle {
                Layout.fillWidth: true
                height: 28
                color: theme.bgSecondary

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: theme.borderSubtle
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 16

                    Text {
                        text: "↑↓ Navigate"
                        color: theme.textMuted
                        font.pixelSize: 11
                    }

                    Text {
                        text: "↵ Select"
                        color: theme.textMuted
                        font.pixelSize: 11
                    }

                    Text {
                        text: "ESC Close"
                        color: theme.textMuted
                        font.pixelSize: 11
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: switcherList.count + " buffers"
                        color: theme.accentCyan
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
