import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: quitConfirmModal
    anchors.fill: parent
    color: "#cc090b10"
    visible: false
    z: 120

    property var relayController
    property var theme
    property bool dontAskAgain: false

    signal quitConfirmed()

    function openDialog() {
        dontAskAgain = false
        visible = true
        card.forceActiveFocus()
    }

    function closeModal() {
        visible = false
    }

    function executeQuit() {
        if (dontAskAgain && relayController) {
            relayController.set_confirm_on_quit(false)
        }
        visible = false
        quitConfirmed()
    }

    // Dismiss on clicking backdrop outside the card
    MouseArea {
        anchors.fill: parent
        onClicked: quitConfirmModal.closeModal()
    }

    Rectangle {
        id: card
        width: 440
        height: 230
        anchors.centerIn: parent
        radius: 14
        color: theme.bgElevated
        border.color: theme.borderSubtle
        border.width: 1

        focus: quitConfirmModal.visible

        Keys.onEscapePressed: function(event) {
            event.accepted = true
            quitConfirmModal.closeModal()
        }

        Keys.onReturnPressed: function(event) {
            event.accepted = true
            quitConfirmModal.executeQuit()
        }

        Keys.onEnterPressed: function(event) {
            event.accepted = true
            quitConfirmModal.executeQuit()
        }

        // Prevent click through to backdrop
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
                onClicked: quitConfirmModal.closeModal()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 32
                spacing: 14

                Rectangle {
                    width: 40
                    height: 40
                    radius: 10
                    color: Qt.alpha(theme.statusError, 0.16)
                    border.color: Qt.alpha(theme.statusError, 0.35)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "⏻"
                        color: theme.statusError
                        font.pixelSize: 20
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "Quit WeeChat QML"
                        color: theme.textPrimary
                        font.pixelSize: 17
                        font.bold: true
                        font.family: theme.fontSans
                    }

                    Text {
                        text: "Are you sure you want to disconnect and exit?"
                        color: theme.textSecondary
                        font.pixelSize: 13
                        font.family: theme.fontSans
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // "Don't ask again" option
            Rectangle {
                Layout.fillWidth: true
                height: 34
                radius: 6
                color: checkHover.hovered ? theme.bgHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 10

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 4
                        color: quitConfirmModal.dontAskAgain ? theme.accentPrimary : theme.bgInput
                        border.color: quitConfirmModal.dontAskAgain ? theme.accentPrimary : theme.borderSubtle
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: theme.bgPrimary
                            font.pixelSize: 12
                            font.bold: true
                            visible: quitConfirmModal.dontAskAgain
                        }
                    }

                    Text {
                        text: "Don't ask for confirmation next time"
                        color: theme.textSecondary
                        font.pixelSize: 12
                        font.family: theme.fontSans
                        Layout.fillWidth: true
                    }
                }

                HoverHandler { id: checkHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: quitConfirmModal.dontAskAgain = !quitConfirmModal.dontAskAgain
                }
            }

            Item { Layout.fillHeight: true }

            // Action Buttons Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                // Cancel Button
                Rectangle {
                    height: 36
                    implicitWidth: 90
                    radius: 8
                    color: cancelHover.hovered ? theme.bgHover : theme.bgSecondary
                    border.color: theme.borderSubtle
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: theme.textPrimary
                        font.pixelSize: 13
                        font.bold: true
                    }

                    HoverHandler { id: cancelHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: quitConfirmModal.closeModal()
                    }
                }

                // Quit Button
                Rectangle {
                    id: quitConfirmBtn
                    height: 36
                    implicitWidth: 90
                    radius: 8
                    color: quitHover.hovered ? Qt.darker(theme.statusError, 1.15) : theme.statusError

                    Text {
                        anchors.centerIn: parent
                        text: "Quit"
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    HoverHandler { id: quitHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: quitConfirmModal.executeQuit()
                    }
                }
            }
        }
    }
}
