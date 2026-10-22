import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: inputRoot
    height: 62
    color: theme.bgSecondary

    property var relayController
    property var theme
    property var inputHistory: []
    property int historyIndex: -1

    signal pageUpRequested()
    signal pageDownRequested()
    signal homeRequested()
    signal endRequested()
    signal quitRequested()
    signal closeWindowRequested()
    signal quickSwitcherRequested()

    function insertMention(nick) {
        if (nick.length === 0) return
        if (chatInput.text.length === 0) {
            chatInput.text = nick + ": "
        } else {
            chatInput.text = chatInput.text + " @" + nick + " "
        }
        chatInput.cursorPosition = chatInput.text.length
        chatInput.forceActiveFocus()
    }

    function focusInput() {
        chatInput.forceActiveFocus()
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: theme.borderSubtle
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10

        // Input Box Container
        Rectangle {
            Layout.fillWidth: true
            height: 40
            radius: 9
            color: theme.bgInput
            border.color: chatInput.activeFocus ? theme.borderFocus : theme.borderSubtle
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                // Channel prompt pill
                Text {
                    text: relayController.active_buffer_name.length > 0 ? relayController.active_buffer_name : ">"
                    color: theme.accentCyan
                    font.pixelSize: 12
                    font.bold: true
                    font.family: theme.fontMono
                }

                Rectangle {
                    width: 1
                    height: 16
                    color: theme.borderSubtle
                }

                TextInput {
                    id: chatInput
                    Layout.fillWidth: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.textPrimary
                    font.pixelSize: 14
                    font.family: theme.fontSans
                    selectByMouse: true
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Message " + (relayController.active_buffer_name.length > 0 ? relayController.active_buffer_name : "buffer") + " or type /command (Tab to complete)"
                        color: theme.textMuted
                        font.pixelSize: 13
                        visible: chatInput.text.length === 0 && !chatInput.activeFocus
                    }

                    Keys.onTabPressed: function(event) {
                        if (event.modifiers & Qt.ControlModifier) {
                            event.accepted = true
                            if (event.modifiers & Qt.ShiftModifier) {
                                relayController.select_previous_buffer()
                            } else {
                                relayController.select_next_buffer()
                            }
                            return
                        }
                        event.accepted = true
                        var completed = relayController.complete_input(chatInput.text, chatInput.cursorPosition)
                        chatInput.text = completed
                        chatInput.cursorPosition = chatInput.text.length
                    }

                    Keys.onPressed: function(event) {
                        // Unread channel jumping: Ctrl+U and Alt+A (bypasses readline delete kill-line backward)
                        if (((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_U) ||
                            ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_A)) {
                            event.accepted = true
                            relayController.select_next_unread_buffer()
                            return
                        }
                        // Quit application: Ctrl+Q
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Q) {
                            event.accepted = true
                            inputRoot.quitRequested()
                            return
                        }
                        // Close window / to tray: Ctrl+W
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_W) {
                            event.accepted = true
                            inputRoot.closeWindowRequested()
                            return
                        }
                        // Quick Switcher: Ctrl+K (bypasses readline delete kill-line forward)
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_K) {
                            event.accepted = true
                            inputRoot.quickSwitcherRequested()
                            return
                        }
                        // Buffer navigation: Ctrl+PageDown / Ctrl+PageUp
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_PageDown) {
                            event.accepted = true
                            relayController.select_next_buffer()
                            return
                        }
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_PageUp) {
                            event.accepted = true
                            relayController.select_previous_buffer()
                            return
                        }

                        if (event.key === Qt.Key_PageUp) {
                            event.accepted = true
                            inputRoot.pageUpRequested()
                        } else if (event.key === Qt.Key_PageDown) {
                            event.accepted = true
                            inputRoot.pageDownRequested()
                        } else if (event.key === Qt.Key_Home && (event.modifiers & Qt.ControlModifier || chatInput.text.length === 0)) {
                            event.accepted = true
                            inputRoot.homeRequested()
                        } else if (event.key === Qt.Key_End && (event.modifiers & Qt.ControlModifier || chatInput.text.length === 0)) {
                            event.accepted = true
                            inputRoot.endRequested()
                        }
                    }

                    Keys.onUpPressed: function(event) {
                        if (inputRoot.inputHistory.length > 0) {
                            event.accepted = true
                            if (inputRoot.historyIndex < inputRoot.inputHistory.length - 1) {
                                inputRoot.historyIndex++
                            }
                            chatInput.text = inputRoot.inputHistory[inputRoot.inputHistory.length - 1 - inputRoot.historyIndex]
                            chatInput.cursorPosition = chatInput.text.length
                        }
                    }

                    Keys.onDownPressed: function(event) {
                        if (inputRoot.historyIndex > 0) {
                            event.accepted = true
                            inputRoot.historyIndex--
                            chatInput.text = inputRoot.inputHistory[inputRoot.inputHistory.length - 1 - inputRoot.historyIndex]
                            chatInput.cursorPosition = chatInput.text.length
                        } else if (inputRoot.historyIndex === 0) {
                            event.accepted = true
                            inputRoot.historyIndex = -1
                            chatInput.text = ""
                        }
                    }

                    onAccepted: sendBtn.submitMessage()
                }
            }
        }

        // Send Button
        Rectangle {
            id: sendBtn
            width: 74
            height: 40
            radius: 9
            color: chatInput.text.trim().length > 0
                ? (sendHover.hovered ? theme.accentHover : theme.accentPrimary)
                : theme.bgElevated

            function submitMessage() {
                var msg = chatInput.text
                if (msg.trim().length === 0) return
                inputRoot.inputHistory.push(msg)
                inputRoot.historyIndex = -1
                relayController.send_input(msg)
                chatInput.text = ""
            }

            Text {
                anchors.centerIn: parent
                text: "Send"
                color: chatInput.text.trim().length > 0 ? "#ffffff" : theme.textMuted
                font.pixelSize: 13
                font.bold: true
            }

            HoverHandler { id: sendHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sendBtn.submitMessage()
            }
        }
    }
}
