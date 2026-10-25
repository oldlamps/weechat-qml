import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: serverManagerModal
    anchors.fill: parent
    color: "#cc090b10"
    visible: false
    z: 105

    property var relayController
    property var theme

    // Internal state for profile editor
    property bool isEditing: false
    property string editId: ""
    property string editName: ""
    property string editHost: "localhost"
    property int editPort: 9000
    property bool editUseTls: false
    property bool editVerifyTls: true
    property bool editSavePassword: true
    property bool editAutoConnect: false
    property string editTotp: ""
    property string editPassword: ""

    function openManager() {
        isEditing = false
        serverManagerModal.visible = true
    }

    function openAddServer() {
        editId = ""
        editName = "New Relay Server"
        editHost = "localhost"
        editPort = 9000
        editUseTls = false
        editVerifyTls = true
        editSavePassword = true
        editAutoConnect = false
        editTotp = ""
        editPassword = ""
        isEditing = true
    }

    function openEditServer(model) {
        editId = model.id
        editName = model.name
        editHost = model.host
        editPort = model.port
        editUseTls = model.use_tls
        editVerifyTls = model.verify_tls
        editSavePassword = model.save_password
        editAutoConnect = model.auto_connect
        editTotp = model.totp
        editPassword = relayController.get_saved_password_for_server(model.id)
        isEditing = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!serverManagerModal.isEditing) {
                serverManagerModal.visible = false
            }
        }
    }

    Rectangle {
        id: card
        width: 640
        height: Math.min(parent.height - 60, 680)
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
                onClicked: {
                    if (serverManagerModal.isEditing) {
                        serverManagerModal.isEditing = false
                    } else {
                        serverManagerModal.visible = false
                    }
                }
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
                spacing: 12

                Rectangle {
                    width: 36
                    height: 36
                    radius: 9
                    color: theme.accentPrimary

                    Text {
                        anchors.centerIn: parent
                        text: "⇄"
                        color: "#ffffff"
                        font.pixelSize: 20
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: serverManagerModal.isEditing ? (serverManagerModal.editId.length > 0 ? "Edit Server Profile" : "Add Server Profile") : "Server Manager"
                        color: theme.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                        font.family: theme.fontSans
                    }

                    Text {
                        text: serverManagerModal.isEditing ? "Credentials stored securely in system keychain (KWallet / Secret Service)" : "Manage saved WeeChat Relay connections and credentials"
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
            }

            // VIEW 1: SERVER LIST VIEW
            ColumnLayout {
                visible: !serverManagerModal.isEditing
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "SAVED RELAY SERVERS"
                        color: theme.accentCyan
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 0.8
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        height: 30
                        implicitWidth: addBtnLbl.implicitWidth + 20
                        radius: 6
                        color: addHover.hovered ? theme.accentHover : theme.accentPrimary

                        Text {
                            id: addBtnLbl
                            anchors.centerIn: parent
                            text: "+ Add Server"
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        HoverHandler { id: addHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: serverManagerModal.openAddServer()
                        }
                    }
                }

                // Servers ListView
                ListView {
                    id: serverListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: relayController.server_model
                    spacing: 8

                    delegate: Rectangle {
                        width: serverListView.width
                        height: 72
                        radius: 10
                        color: model.is_active ? theme.bgActive : (sRowHover.hovered ? theme.bgHover : theme.bgSecondary)
                        border.color: model.is_active ? theme.borderFocus : theme.borderSubtle
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 12

                            // Status circle
                            Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: {
                                    if (model.is_active && relayController.connection_state === "Connected") return theme.statusOnline
                                    if (model.is_active && relayController.connection_state === "Connecting") return theme.statusWarning
                                    return theme.textMuted
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 8

                                    Text {
                                        text: model.name
                                        color: theme.textPrimary
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    // Auto-connect badge
                                    Rectangle {
                                        visible: model.auto_connect
                                        height: 16
                                        implicitWidth: autoLbl.implicitWidth + 8
                                        radius: 4
                                        color: theme.bgElevated
                                        border.color: theme.borderSubtle
                                        Text {
                                            id: autoLbl
                                            anchors.centerIn: parent
                                            text: "Auto"
                                            color: theme.textSecondary
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }

                                    // Keyring badge
                                    Rectangle {
                                        visible: model.has_saved_password
                                        height: 16
                                        implicitWidth: keyLbl.implicitWidth + 8
                                        radius: 4
                                        color: theme.isDark ? "#1c2e28" : "#dcfce7"
                                        Text {
                                            id: keyLbl
                                            anchors.centerIn: parent
                                            text: "🔑 Saved"
                                            color: theme.statusOnline
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }
                                }

                                Text {
                                    text: (model.use_tls ? "tls://" : "tcp://") + model.host + ":" + model.port
                                    color: theme.textMuted
                                    font.pixelSize: 11
                                    font.family: theme.fontMono
                                }
                            }

                            // Action buttons: Connect / Edit / Delete
                            RowLayout {
                                spacing: 6

                                // Connect Button
                                Rectangle {
                                    height: 30
                                    implicitWidth: connActionLbl.implicitWidth + 18
                                    radius: 6
                                    color: (model.is_active && relayController.connection_state === "Connected")
                                        ? theme.bgElevated
                                        : (connActionHover.hovered ? theme.accentHover : theme.accentPrimary)

                                    Text {
                                        id: connActionLbl
                                        anchors.centerIn: parent
                                        text: (model.is_active && relayController.connection_state === "Connected") ? "Connected" : "Connect"
                                        color: (model.is_active && relayController.connection_state === "Connected") ? theme.statusOnline : "#ffffff"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    HoverHandler { id: connActionHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !(model.is_active && relayController.connection_state === "Connected")
                                        onClicked: {
                                            relayController.connect_server_profile(model.id, "")
                                            serverManagerModal.visible = false
                                        }
                                    }
                                }

                                // Edit Button
                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 6
                                    color: editHover.hovered ? theme.bgActive : theme.bgElevated
                                    border.color: theme.borderSubtle

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✎"
                                        color: theme.textSecondary
                                        font.pixelSize: 13
                                    }

                                    HoverHandler { id: editHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: serverManagerModal.openEditServer(model)
                                    }
                                }

                                // Delete Button
                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: 6
                                    color: delHover.hovered ? (theme.isDark ? "#3a151b" : "#fee2e2") : theme.bgElevated
                                    border.color: theme.borderSubtle

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🗑"
                                        color: delHover.hovered ? theme.statusError : theme.textMuted
                                        font.pixelSize: 12
                                    }

                                    HoverHandler { id: delHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: relayController.delete_server_profile(model.id)
                                    }
                                }
                            }
                        }

                        HoverHandler { id: sRowHover }
                    }
                }
            }

            // VIEW 2: SERVER PROFILE EDITOR
            ScrollView {
                visible: serverManagerModal.isEditing
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: card.width - 48
                    spacing: 16

                    // Profile Name
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "PROFILE NAME"
                            color: theme.textSecondary
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: 8
                            color: theme.bgInput
                            border.color: nameInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                            border.width: 1

                            TextInput {
                                id: nameInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.textPrimary
                                font.pixelSize: 14
                                text: serverManagerModal.editName
                                onTextChanged: serverManagerModal.editName = text
                            }
                        }
                    }

                    // Host and Port
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
                                border.color: hostInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                                border.width: 1

                                TextInput {
                                    id: hostInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: theme.textPrimary
                                    font.pixelSize: 14
                                    font.family: theme.fontMono
                                    text: serverManagerModal.editHost
                                    onTextChanged: serverManagerModal.editHost = text
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.preferredWidth: 120
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
                                border.color: portInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                                border.width: 1

                                TextInput {
                                    id: portInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: theme.textPrimary
                                    font.pixelSize: 14
                                    font.family: theme.fontMono
                                    text: serverManagerModal.editPort.toString()
                                    onTextChanged: {
                                        var p = parseInt(text)
                                        if (!isNaN(p)) serverManagerModal.editPort = p
                                    }
                                }
                            }
                        }
                    }

                    // Password Input
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
                            border.color: pwdInput.activeFocus ? theme.borderFocus : theme.borderSubtle
                            border.width: 1

                            TextInput {
                                id: pwdInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: theme.textPrimary
                                font.pixelSize: 14
                                font.family: theme.fontMono
                                echoMode: TextInput.Password
                                text: serverManagerModal.editPassword
                                onTextChanged: serverManagerModal.editPassword = text
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Enter relay password..."
                                color: theme.textMuted
                                font.pixelSize: 12
                                visible: pwdInput.text.length === 0 && !pwdInput.activeFocus
                            }
                        }
                    }

                    // Security Toggles
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Remember Password securely in system keychain
                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: 8
                            color: saveHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: serverManagerModal.editSavePassword ? theme.accentPrimary : theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: "Save password securely in system keychain (KWallet / Secret Service)"
                                    color: theme.textPrimary
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }

                                Switch {
                                    checked: serverManagerModal.editSavePassword
                                    onToggled: serverManagerModal.editSavePassword = checked
                                }
                            }

                            HoverHandler { id: saveHover }
                        }

                        // Auto-connect on launch
                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: 8
                            color: autoHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: serverManagerModal.editAutoConnect ? theme.accentPrimary : theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: "Automatically connect to this server on application startup"
                                    color: theme.textPrimary
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }

                                Switch {
                                    checked: serverManagerModal.editAutoConnect
                                    onToggled: serverManagerModal.editAutoConnect = checked
                                }
                            }

                            HoverHandler { id: autoHover }
                        }

                        // TLS Socket
                        Rectangle {
                            Layout.fillWidth: true
                            height: 38
                            radius: 8
                            color: tlsHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: serverManagerModal.editUseTls ? theme.accentPrimary : theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: "Use TLS socket connection (tls.weechat)"
                                    color: theme.textPrimary
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }

                                Switch {
                                    checked: serverManagerModal.editUseTls
                                    onToggled: serverManagerModal.editUseTls = checked
                                }
                            }

                            HoverHandler { id: tlsHover }
                        }

                        // Verify Certificate
                        Rectangle {
                            visible: serverManagerModal.editUseTls
                            Layout.fillWidth: true
                            height: 38
                            radius: 8
                            color: certHover.hovered ? theme.bgHover : theme.bgSecondary
                            border.color: theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: "Verify TLS Certificate (disable for self-signed certificates)"
                                    color: theme.textPrimary
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }

                                Switch {
                                    checked: serverManagerModal.editVerifyTls
                                    onToggled: serverManagerModal.editVerifyTls = checked
                                }
                            }

                            HoverHandler { id: certHover }
                        }
                    }

                    // Save / Cancel row in editor
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 10

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            height: 38
                            implicitWidth: 90
                            radius: 8
                            color: theme.bgSecondary
                            border.color: theme.borderSubtle

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: theme.textSecondary
                                font.pixelSize: 13
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: serverManagerModal.isEditing = false
                            }
                        }

                        Rectangle {
                            height: 38
                            implicitWidth: 120
                            radius: 8
                            color: saveBtnHover.hovered ? theme.accentHover : theme.accentPrimary

                            Text {
                                anchors.centerIn: parent
                                text: "Save Profile"
                                color: "#ffffff"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            HoverHandler { id: saveBtnHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    relayController.save_server_profile(
                                        serverManagerModal.editId,
                                        serverManagerModal.editName,
                                        serverManagerModal.editHost,
                                        serverManagerModal.editPort,
                                        serverManagerModal.editPassword,
                                        serverManagerModal.editUseTls,
                                        serverManagerModal.editVerifyTls,
                                        serverManagerModal.editSavePassword,
                                        serverManagerModal.editAutoConnect,
                                        serverManagerModal.editTotp
                                    )
                                    serverManagerModal.isEditing = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
