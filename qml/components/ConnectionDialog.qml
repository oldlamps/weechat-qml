import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: connModal
    anchors.fill: parent
    color: "#cc090b10"
    visible: false
    z: 100

    property var relayController
    property var theme

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (relayController.connection_state === "Connected") {
                connModal.visible = false
            }
        }
    }

    Rectangle {
        id: card
        width: 460
        height: contentCol.implicitHeight + 56
        anchors.centerIn: parent
        radius: 14
        color: theme.bgElevated
        border.color: theme.borderSubtle
        border.width: 1

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 28
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 40
                    height: 40
                    radius: 10
                    color: theme.accentPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "W"
                        color: "#ffffff"
                        font.pixelSize: 20
                        font.bold: true
                        font.family: theme.fontSans
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Connect to WeeChat Relay"
                        color: theme.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                        font.family: theme.fontSans
                    }

                    Text {
                        text: "Native binary TCP / TLS socket protocol"
                        color: theme.textSecondary
                        font.pixelSize: 12
                        font.family: theme.fontSans
                    }
                }

                Rectangle {
                    visible: relayController.connection_state === "Connected"
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
                        onClicked: connModal.visible = false
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.borderSubtle
            }

            // Host and Port row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "RELAY HOST"
                        color: theme.textSecondary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: 8
                        color: theme.bgInput
                        border.color: hostField.activeFocus ? theme.borderFocus : theme.borderSubtle
                        border.width: 1

                        TextInput {
                            id: hostField
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: theme.textPrimary
                            font.pixelSize: 14
                            font.family: theme.fontMono
                            selectByMouse: true
                            text: relayController.saved_host
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 110
                    spacing: 6

                    Text {
                        text: "PORT"
                        color: theme.textSecondary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: 8
                        color: theme.bgInput
                        border.color: portField.activeFocus ? theme.borderFocus : theme.borderSubtle
                        border.width: 1

                        TextInput {
                            id: portField
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: theme.textPrimary
                            font.pixelSize: 14
                            font.family: theme.fontMono
                            selectByMouse: true
                            text: relayController.saved_port.toString()
                        }
                    }
                }
            }

            // Password field
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "RELAY PASSWORD"
                    color: theme.textSecondary
                    font.pixelSize: 11
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 8
                    color: theme.bgInput
                    border.color: passwordField.activeFocus ? theme.borderFocus : theme.borderSubtle
                    border.width: 1

                    TextInput {
                        id: passwordField
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: theme.textPrimary
                        font.pixelSize: 14
                        font.family: theme.fontMono
                        echoMode: TextInput.Password
                        selectByMouse: true
                        onAccepted: connectBtn.triggerConnect()
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Negotiated via PBKDF2 / SHA-512 handshake"
                        color: theme.textMuted
                        font.pixelSize: 12
                        visible: passwordField.text.length === 0 && !passwordField.activeFocus
                    }
                }
            }

            // TLS & TOTP row
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    height: 34
                    Layout.fillWidth: true
                    radius: 8
                    color: tlsToggleArea.containsMouse ? theme.bgHover : theme.bgInput
                    border.color: useTlsCheck.checked ? theme.accentPrimary : theme.borderSubtle
                    border.width: 1

                    property bool checked: relayController.saved_use_tls
                    id: useTlsCheck

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 4
                            color: useTlsCheck.checked ? theme.accentPrimary : "transparent"
                            border.color: useTlsCheck.checked ? theme.accentPrimary : theme.textMuted

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#ffffff"
                                font.pixelSize: 11
                                visible: useTlsCheck.checked
                            }
                        }

                        Text {
                            text: "Use TLS (tls.weechat)"
                            color: theme.textPrimary
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: tlsToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: useTlsCheck.checked = !useTlsCheck.checked
                    }
                }

                Rectangle {
                    id: verifyTlsCheck
                    height: 34
                    Layout.fillWidth: true
                    radius: 8
                    opacity: useTlsCheck.checked ? 1.0 : 0.4
                    color: verifyToggleArea.containsMouse ? theme.bgHover : theme.bgInput
                    border.color: checked && useTlsCheck.checked ? theme.accentPrimary : theme.borderSubtle
                    border.width: 1

                    property bool checked: relayController.saved_verify_tls

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 4
                            color: verifyTlsCheck.checked ? theme.accentPrimary : "transparent"
                            border.color: verifyTlsCheck.checked ? theme.accentPrimary : theme.textMuted

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#ffffff"
                                font.pixelSize: 11
                                visible: verifyTlsCheck.checked
                            }
                        }

                        Text {
                            text: "Verify Certificate"
                            color: theme.textPrimary
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: verifyToggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: useTlsCheck.checked
                        onClicked: verifyTlsCheck.checked = !verifyTlsCheck.checked
                    }
                }
            }

            // Error banner if connection failed
            Rectangle {
                Layout.fillWidth: true
                visible: relayController.error_message.length > 0
                implicitHeight: errText.implicitHeight + 20
                radius: 8
                color: "#2d1219"
                border.color: theme.statusError
                border.width: 1

                Text {
                    id: errText
                    anchors.fill: parent
                    anchors.margins: 10
                    text: relayController.error_message
                    color: "#fda4af"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }

            // Action Button
            Rectangle {
                id: connectBtn
                Layout.fillWidth: true
                height: 40
                radius: 8
                color: connHover.hovered ? theme.accentHover : theme.accentPrimary

                function triggerConnect() {
                    var p = parseInt(portField.text)
                    if (isNaN(p) || p <= 0) p = 9000
                    relayController.connect_to_relay(
                        hostField.text,
                        p,
                        passwordField.text,
                        useTlsCheck.checked,
                        verifyTlsCheck.checked,
                        ""
                    )
                    connModal.visible = false
                }

                Text {
                    anchors.centerIn: parent
                    text: "Connect to Server"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }

                HoverHandler { id: connHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: connectBtn.triggerConnect()
                }
            }
        }
    }
}
