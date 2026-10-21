import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: feedRoot

    property var relayController
    property var theme
    signal mentionNickRequested(string nick)

    // Method to page scroll up from input field or hotkeys
    function scrollPageUp() {
        // Detach auto-scroll when user explicitly scrolls up
        listView.autoScroll = false
        var step = Math.max(100, listView.height * 0.75)
        listView.contentY = Math.max(-listView.topMargin, listView.contentY - step)
        listView.returnToBounds()
    }

    // Method to page scroll down
    function scrollPageDown() {
        var step = Math.max(100, listView.height * 0.75)
        var maxY = Math.max(-listView.topMargin, listView.originY + listView.contentHeight - listView.height + listView.bottomMargin)
        var targetY = listView.contentY + step

        if (targetY >= maxY - 50 || listView.atYEnd || listView.isNearBottom) {
            scrollToBottom()
        } else {
            listView.contentY = targetY
            listView.returnToBounds()
        }
    }

    // Scroll to the absolute beginning of history (Home key)
    function scrollToTop() {
        listView.autoScroll = false
        listView.positionViewAtBeginning()
        Qt.callLater(function() {
            listView.positionViewAtBeginning()
        })
    }

    // Scroll directly and firmly to the very latest message (End key or Jump Button)
    function scrollToBottom() {
        if (listView.count === 0) return
        listView.autoScroll = true
        listView.positionViewAtEnd()
        Qt.callLater(function() {
            if (listView.autoScroll && listView.count > 0) {
                listView.positionViewAtIndex(listView.count - 1, ListView.End)
                listView.positionViewAtEnd()
            }
        })
    }

    ListView {
        id: listView
        anchors.fill: parent
        clip: true
        model: relayController.message_model
        spacing: 0
        topMargin: 12
        bottomMargin: 14
        boundsBehavior: Flickable.StopAtBounds

        // Track whether user wants to follow live streaming messages
        property bool autoScroll: true
        property real previousContentY: 0

        // Reliable detection of whether user is near the bottom
        readonly property bool isNearBottom: {
            if (count === 0 || atYEnd || contentHeight <= height) return true

            // 1. Ratio check via visibleArea
            if ((visibleArea.yPosition + visibleArea.heightRatio) >= 0.985) return true

            // 2. Pixel distance check using true originY offset
            var maxY = originY + contentHeight - height + bottomMargin
            if ((maxY - contentY) <= 80) return true

            // 3. Delegate check: is the last item visible in the viewport?
            var lastItem = itemAtIndex(count - 1)
            if (lastItem) {
                var lastItemBottom = lastItem.y + lastItem.height
                var viewportBottom = contentY + height - bottomMargin
                if (lastItemBottom <= viewportBottom + 60) return true
            }

            return false
        }

        // Reliable pixel distance between current scroll position and the bottom of content
        readonly property real distanceFromBottom: {
            if (count === 0 || atYEnd || contentHeight <= height) return 0
            var maxY = originY + contentHeight - height + bottomMargin
            return Math.max(0, maxY - contentY)
        }

        // Show the Jump button ONLY when user has scrolled significantly into the backlog
        // and is not currently autoscrolling
        readonly property bool showJumpButton: {
            if (autoScroll || count === 0 || atYEnd || isNearBottom) return false
            var backlogThreshold = Math.max(350, height * 0.6)
            return distanceFromBottom > backlogThreshold
        }

        // Track scroll position changes:
        // - Scrolling DOWN to bottom: re-attaches autoScroll.
        // - Scrolling UP into history (wheel, drag, flick, keys): detaches autoScroll so user isn't pulled down.
        onContentYChanged: {
            var deltaY = contentY - previousContentY
            previousContentY = contentY

            if (atYEnd || isNearBottom) {
                autoScroll = true
            } else if (deltaY < -1 || moving || flicking || dragging) {
                if (distanceFromBottom > 80) {
                    autoScroll = false
                }
            }
        }

        // When new messages are appended to the active buffer:
        // ONLY scroll if the user was already following at the bottom!
        // If the user scrolled up to read past messages, LEAVE THEM EXACTLY WHERE THEY ARE.
        onCountChanged: {
            if (autoScroll) {
                Qt.callLater(function() {
                    if (listView.autoScroll) {
                        feedRoot.scrollToBottom()
                    }
                })
            }
        }

        // Older message loader header
        header: Item {
            width: listView.width
            height: listView.count >= 50 ? 44 : 8

            Rectangle {
                visible: listView.count >= 50
                anchors.centerIn: parent
                implicitWidth: loadMoreLbl.implicitWidth + 24
                height: 28
                radius: 14
                color: loadMoreHover.hovered ? theme.bgHover : theme.bgElevated
                border.color: theme.borderSubtle

                Text {
                    id: loadMoreLbl
                    anchors.centerIn: parent
                    text: "↑ Load older messages from WeeChat"
                    color: theme.textSecondary
                    font.pixelSize: 11
                    font.bold: true
                }

                HoverHandler { id: loadMoreHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: relayController.load_more_history()
                }
            }
        }

        delegate: MessageDelegate {
            relayController: feedRoot.relayController
            theme: feedRoot.theme
            onNickClicked: function(nick) {
                feedRoot.mentionNickRequested(nick)
            }
            onContextMenuRequested: function(targetEdit, selSnippet, plainText, senderNick, timeStr, linkUrl, isAction) {
                messageContextMenu.targetEdit = targetEdit
                messageContextMenu.selectedSnippet = selSnippet
                messageContextMenu.messageBodyText = plainText
                messageContextMenu.senderNick = senderNick
                messageContextMenu.messageTime = timeStr
                messageContextMenu.targetLink = linkUrl
                messageContextMenu.isActionMessage = isAction
                messageContextMenu.popup()
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }

    // Floating "Jump to Latest Messages" Pill
    // Appears ONLY when the user is scrolled significantly into the backlog
    Rectangle {
        id: jumpButton
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        height: 32
        implicitWidth: jumpLbl.implicitWidth + 28
        radius: 16
        color: jumpHover.hovered ? theme.accentHover : theme.accentPrimary
        border.color: theme.borderSubtle
        border.width: 1
        z: 20

        visible: opacity > 0.01
        opacity: listView.showJumpButton ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: "↓"
                color: "#ffffff"
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                id: jumpLbl
                text: "Jump to latest messages"
                color: "#ffffff"
                font.pixelSize: 12
                font.bold: true
            }
        }

        HoverHandler { id: jumpHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                feedRoot.scrollToBottom()
            }
        }
    }

    // Message Context Menu for text selection, message copying, links, etc.
    Menu {
        id: messageContextMenu

        property var targetEdit: null
        property string selectedSnippet: ""
        property string messageBodyText: ""
        property string senderNick: ""
        property string messageTime: ""
        property string targetLink: ""
        property bool isActionMessage: false

        topPadding: 6
        bottomMargin: 6
        leftPadding: 6
        rightPadding: 6

        background: Rectangle {
            implicitWidth: 230
            color: theme.bgElevated
            border.color: theme.borderSubtle
            border.width: 1
            radius: 8
        }

        MenuItem {
            id: copySelItem
            visible: messageContextMenu.selectedSnippet.length > 0
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "📋"; font.pixelSize: 12 }
                Text {
                    text: "Copy Selection"
                    color: copySelItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    text: "Ctrl+C"
                    color: theme.textMuted
                    font.family: theme.fontSans
                    font.pixelSize: 10
                }
            }
            background: Rectangle {
                color: copySelItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (messageContextMenu.selectedSnippet.length > 0) {
                    relayController.copy_to_clipboard(messageContextMenu.selectedSnippet)
                }
            }
        }

        MenuItem {
            id: copyMsgItem
            contentItem: RowLayout {
                spacing: 8
                Text { text: "💬"; font.pixelSize: 12 }
                Text {
                    text: "Copy Message"
                    color: copyMsgItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: copyMsgItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (messageContextMenu.messageBodyText.length > 0) {
                    relayController.copy_to_clipboard(messageContextMenu.messageBodyText)
                }
            }
        }

        MenuItem {
            id: copyFormattedItem
            visible: messageContextMenu.senderNick.length > 0
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "🕒"; font.pixelSize: 12 }
                Text {
                    text: "Copy with Nick & Time"
                    color: copyFormattedItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: copyFormattedItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                var formatted = ""
                if (messageContextMenu.isActionMessage) {
                    formatted = "[" + messageContextMenu.messageTime + "] * " + messageContextMenu.senderNick + " " + messageContextMenu.messageBodyText
                } else {
                    formatted = "[" + messageContextMenu.messageTime + "] <" + messageContextMenu.senderNick + "> " + messageContextMenu.messageBodyText
                }
                relayController.copy_to_clipboard(formatted)
            }
        }

        MenuSeparator {
            visible: messageContextMenu.targetLink.length > 0
            contentItem: Rectangle {
                implicitWidth: parent.width
                implicitHeight: 1
                color: theme.borderSubtle
            }
        }

        MenuItem {
            id: copyLinkItem
            visible: messageContextMenu.targetLink.length > 0
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "🔗"; font.pixelSize: 12 }
                Text {
                    text: "Copy Link Address"
                    color: copyLinkItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: copyLinkItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (messageContextMenu.targetLink.length > 0) {
                    relayController.copy_to_clipboard(messageContextMenu.targetLink)
                }
            }
        }

        MenuItem {
            id: openLinkItem
            visible: messageContextMenu.targetLink.length > 0
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "↗"; font.pixelSize: 12 }
                Text {
                    text: "Open Link in Browser"
                    color: openLinkItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: openLinkItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (messageContextMenu.targetLink.length > 0) {
                    Qt.openUrlExternally(messageContextMenu.targetLink)
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

        MenuItem {
            id: copyNickItem
            visible: messageContextMenu.senderNick.length > 0
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "👤"; font.pixelSize: 12 }
                Text {
                    text: "Copy Nick (" + messageContextMenu.senderNick + ")"
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
                if (messageContextMenu.senderNick.length > 0) {
                    relayController.copy_to_clipboard(messageContextMenu.senderNick)
                }
            }
        }

        MenuItem {
            id: mentionNickItem
            visible: messageContextMenu.senderNick.length > 0
            height: visible ? implicitHeight : 0
            contentItem: RowLayout {
                spacing: 8
                Text { text: "@"; font.pixelSize: 12; font.bold: true; color: theme.accentCyan }
                Text {
                    text: "Mention @" + messageContextMenu.senderNick
                    color: mentionNickItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
            }
            background: Rectangle {
                color: mentionNickItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (messageContextMenu.senderNick.length > 0) {
                    feedRoot.mentionNickRequested(messageContextMenu.senderNick)
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

        MenuItem {
            id: selectAllItem
            contentItem: RowLayout {
                spacing: 8
                Text { text: "📑"; font.pixelSize: 12 }
                Text {
                    text: "Select All"
                    color: selectAllItem.highlighted ? theme.textPrimary : theme.textSecondary
                    font.family: theme.fontSans
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
                Text {
                    text: "Ctrl+A"
                    color: theme.textMuted
                    font.family: theme.fontSans
                    font.pixelSize: 10
                }
            }
            background: Rectangle {
                color: selectAllItem.highlighted ? theme.bgHover : "transparent"
                radius: 4
            }
            onTriggered: {
                if (messageContextMenu.targetEdit) {
                    messageContextMenu.targetEdit.selectAll()
                    messageContextMenu.targetEdit.forceActiveFocus()
                }
            }
        }
    }

    Connections {
        target: relayController
        // When user switches to a buffer, re-enable autoScroll and firmly jump to the bottom
        function onActive_buffer_changed() {
            listView.autoScroll = true
            Qt.callLater(function() {
                feedRoot.scrollToBottom()
            })
        }
    }
}
