import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Item {
    id: msgRoot
    width: ListView.view ? ListView.view.width : 600
    height: mainCol.implicitHeight

    property var relayController
    property var theme
    property bool previewCollapsed: false
    property bool isInlinePlaying: false
    property string inlineStreamUrl: ""
    property string inlineAudioUrl: ""
    property bool isResolvingStream: false
    property string resolveError: ""
    property string ytTitle: ""
    property string ytAuthor: ""
    property string resolvedImageUrl: ""
    signal nickClicked(string nick)
    signal contextMenuRequested(var targetEdit, string selectedText, string plainText, string senderNick, string timeStr, string linkUrl, bool isAction)

    Connections {
        target: relayController
        function onMedia_stream_resolved(target_id, stream_url, audio_url) {
            if (target_id === model.line_ptr) {
                msgRoot.isResolvingStream = false
                msgRoot.resolveError = ""
                msgRoot.inlineStreamUrl = stream_url
                msgRoot.inlineAudioUrl = audio_url || ""
                msgRoot.isInlinePlaying = true
                inlinePlayer.play()
                if (msgRoot.inlineAudioUrl.length > 0) {
                    inlineAudioPlayer.play()
                }
            }
        }
        function onMedia_stream_error(target_id, error_msg) {
            if (target_id === model.line_ptr) {
                msgRoot.isResolvingStream = false
                msgRoot.resolveError = error_msg
            }
        }
    }

    function fetchMediaMetadata() {
        if (model.media_type === "youtube" && model.media_url.length > 0 && msgRoot.ytTitle.length === 0) {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", "https://www.youtube.com/oembed?url=" + encodeURIComponent(model.media_url) + "&format=json")
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)
                        if (data.title) msgRoot.ytTitle = data.title
                        if (data.author_name) msgRoot.ytAuthor = data.author_name
                    } catch (e) {}
                }
            }
            xhr.send()
        } else if (model.media_type === "image" && model.media_url.length > 0 && msgRoot.resolvedImageUrl.length === 0) {
            var match = model.media_url.match(/https?:\/\/([^\/]+)\/wiki\/File:([^?#]+)/i)
            if (match) {
                var domain = match[1]
                var fileTitle = decodeURIComponent(match[2])
                var apiUrl = "https://" + domain + "/w/api.php?action=query&titles=File:" + encodeURIComponent(fileTitle) + "&prop=imageinfo&iiprop=url&format=json&origin=*"
                var xhrImg = new XMLHttpRequest()
                xhrImg.open("GET", apiUrl)
                xhrImg.onreadystatechange = function() {
                    if (xhrImg.readyState === XMLHttpRequest.DONE && xhrImg.status === 200) {
                        try {
                            var res = JSON.parse(xhrImg.responseText)
                            var pages = res.query.pages
                            for (var p in pages) {
                                if (pages[p].imageinfo && pages[p].imageinfo.length > 0) {
                                    msgRoot.resolvedImageUrl = pages[p].imageinfo[0].url
                                    return
                                }
                            }
                        } catch (e) {}
                    }
                }
                xhrImg.send()
            }
        }
    }

    Component.onCompleted: fetchMediaMetadata()

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

                    // Message Text Body (Selectable with mouse highlight, copy, links)
                    TextEdit {
                        id: messageBody
                        Layout.fillWidth: true
                        readOnly: true
                        selectByMouse: true
                        cursorVisible: false
                        activeFocusOnPress: true
                        text: {
                            if (model.is_action) {
                                return "<i>* " + model.styled_text + "</i>"
                            }
                            return model.styled_text
                        }
                        textFormat: TextEdit.RichText
                        wrapMode: TextEdit.Wrap
                        color: {
                            if (model.is_system) return theme.textMuted
                            if (model.is_action) return theme.accentCyan
                            return theme.textPrimary
                        }
                        selectionColor: Qt.alpha(theme.accentPrimary, 0.35)
                        selectedTextColor: theme.textPrimary
                        font.pixelSize: model.is_system ? Math.max(10, theme.baseFontSize - 2) : theme.baseFontSize
                        font.family: theme.fontSans

                        onLinkActivated: function(link) {
                            Qt.openUrlExternally(link)
                        }

                        HoverHandler {
                            id: linkHover
                            cursorShape: messageBody.hoveredLink.length > 0 ? Qt.PointingHandCursor : Qt.IBeamCursor
                        }
                    }

                    // Direct Image Preview Card
                    Rectangle {
                        visible: relayController.show_media_previews && model.media_type === "image" && !msgRoot.previewCollapsed
                        Layout.topMargin: 6
                        Layout.preferredWidth: Math.min(420, msgRoot.width > 120 ? msgRoot.width - 100 : 420)
                        Layout.preferredHeight: {
                            if (imgPreview.status === Image.Ready) {
                                return Math.min(280, imgPreview.implicitHeight * (Layout.preferredWidth / Math.max(1, imgPreview.implicitWidth))) + 32
                            } else if (imgPreview.status === Image.Error) {
                                return 68
                            } else {
                                return 74
                            }
                        }
                        implicitWidth: Layout.preferredWidth
                        implicitHeight: Layout.preferredHeight
                        radius: 8
                        color: theme.bgElevated
                        border.color: theme.borderSubtle
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                height: 28
                                color: theme.bgSecondary

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 6

                                    Text {
                                        text: "🖼"
                                        font.pixelSize: 11
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: model.media_url.length > 0 ? model.media_url : model.image_url
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

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Loading Placeholder
                                Item {
                                    anchors.fill: parent
                                    visible: imgPreview.status === Image.Loading || (model.media_url.indexOf("/wiki/File:") !== -1 && msgRoot.resolvedImageUrl.length === 0)

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Text {
                                            text: "⏳"
                                            font.pixelSize: 12
                                        }
                                        Text {
                                            text: "Loading image preview..."
                                            color: theme.textMuted
                                            font.pixelSize: 11
                                        }
                                    }
                                }

                                // Error Placeholder
                                Item {
                                    anchors.fill: parent
                                    visible: imgPreview.status === Image.Error && !(model.media_url.indexOf("/wiki/File:") !== -1 && msgRoot.resolvedImageUrl.length === 0)

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text {
                                            text: "⚠️ Could not load image"
                                            color: theme.badgeHighlight
                                            font.pixelSize: 11
                                        }
                                        Text {
                                            text: "Open in Browser ↗"
                                            color: theme.accentCyan
                                            font.pixelSize: 11
                                            font.underline: true
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: Qt.openUrlExternally(model.media_url.length > 0 ? model.media_url : model.image_url)
                                            }
                                        }
                                    }
                                }

                                Image {
                                    id: imgPreview
                                    anchors.fill: parent
                                    source: (relayController.show_media_previews && model.media_type === "image")
                                        ? (msgRoot.resolvedImageUrl.length > 0
                                            ? msgRoot.resolvedImageUrl
                                            : (model.media_url.indexOf("/wiki/File:") !== -1 ? "" : (model.media_url.length > 0 ? model.media_url : model.image_url)))
                                        : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: status === Image.Ready

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally(msgRoot.resolvedImageUrl.length > 0 ? msgRoot.resolvedImageUrl : (model.media_url.length > 0 ? model.media_url : model.image_url))
                                    }
                                }
                            }
                        }
                    }

                    // YouTube Video Preview Card
                    Rectangle {
                        visible: relayController.show_media_previews && model.media_type === "youtube" && !msgRoot.previewCollapsed
                        Layout.topMargin: 6
                        Layout.preferredWidth: Math.min(440, msgRoot.width > 120 ? msgRoot.width - 100 : 440)
                        Layout.preferredHeight: msgRoot.isInlinePlaying ? 300 : 255
                        implicitWidth: Layout.preferredWidth
                        implicitHeight: Layout.preferredHeight
                        radius: 8
                        color: theme.bgElevated
                        border.color: theme.borderSubtle
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            // Top Header Strip
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                height: 30
                                color: theme.bgSecondary

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // YouTube Red Badge
                                    Rectangle {
                                        width: 62
                                        height: 18
                                        radius: 4
                                        color: "#cc0000"

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 3
                                            Text {
                                                text: "▶"
                                                color: "#ffffff"
                                                font.pixelSize: 8
                                            }
                                            Text {
                                                text: "YouTube"
                                                color: "#ffffff"
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: msgRoot.ytTitle.length > 0 ? msgRoot.ytTitle : model.media_url
                                        color: theme.textPrimary
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "Hide"
                                        color: theme.textMuted
                                        font.pixelSize: 11
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                msgRoot.isInlinePlaying = false
                                                msgRoot.previewCollapsed = true
                                            }
                                        }
                                    }
                                }
                            }

                            // Middle Media Area (Thumbnail or Inline Video)
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Thumbnail & Play Button Mode
                                Item {
                                    anchors.fill: parent
                                    visible: !msgRoot.isInlinePlaying

                                    Image {
                                        id: ytThumb
                                        anchors.fill: parent
                                        source: model.media_thumbnail
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        onStatusChanged: {
                                            if (status === Image.Error && source.toString().indexOf("hqdefault.jpg") !== -1 && model.media_id.length > 0) {
                                                source = "https://img.youtube.com/vi/" + model.media_id + "/mqdefault.jpg"
                                            }
                                        }
                                    }

                                    // Dark tint overlay on hover
                                    Rectangle {
                                        anchors.fill: parent
                                        color: ytThumbHover.hovered ? "#44000000" : "#22000000"
                                    }

                                    // Centered Glowing Red Play Button
                                    Rectangle {
                                        width: 56
                                        height: 38
                                        radius: 12
                                        anchors.centerIn: parent
                                        color: ytThumbHover.hovered ? "#eeff0000" : "#ccff0000"
                                        scale: ytThumbHover.hovered ? 1.08 : 1.0

                                        Behavior on scale { NumberAnimation { duration: 120 } }
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Text {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 1
                                            text: "▶"
                                            color: "#ffffff"
                                            font.pixelSize: 18
                                        }
                                    }

                                    // Channel Author Pill
                                    Rectangle {
                                        visible: msgRoot.ytAuthor.length > 0
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.leftMargin: 8
                                        anchors.bottomMargin: 8
                                        height: 20
                                        implicitWidth: ytAuthTxt.implicitWidth + 12
                                        radius: 4
                                        color: "#bb000000"

                                        Text {
                                            id: ytAuthTxt
                                            anchors.centerIn: parent
                                            text: msgRoot.ytAuthor
                                            color: "#ffffff"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }

                                    HoverHandler { id: ytThumbHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!msgRoot.isResolvingStream) {
                                                msgRoot.isResolvingStream = true
                                                msgRoot.resolveError = ""
                                                relayController.resolve_media_stream(model.media_url, model.line_ptr)
                                            }
                                        }
                                    }
                                }

                                // Inline Video Player Mode
                                Item {
                                    anchors.fill: parent
                                    visible: msgRoot.isInlinePlaying

                                    MediaPlayer {
                                        id: inlinePlayer
                                        videoOutput: videoOut
                                        audioOutput: msgRoot.inlineAudioUrl.length === 0 ? primaryAudioOut : null
                                        source: msgRoot.inlineStreamUrl

                                        onPlaybackStateChanged: {
                                            if (msgRoot.inlineAudioUrl.length > 0) {
                                                if (inlinePlayer.playbackState === MediaPlayer.PlayingState &&
                                                    inlineAudioPlayer.playbackState !== MediaPlayer.PlayingState) {
                                                    inlineAudioPlayer.play()
                                                } else if (inlinePlayer.playbackState === MediaPlayer.PausedState &&
                                                           inlineAudioPlayer.playbackState !== MediaPlayer.PausedState) {
                                                    inlineAudioPlayer.pause()
                                                } else if (inlinePlayer.playbackState === MediaPlayer.StoppedState &&
                                                           inlineAudioPlayer.playbackState !== MediaPlayer.StoppedState) {
                                                    inlineAudioPlayer.stop()
                                                }
                                            }
                                        }

                                        onPositionChanged: {
                                            if (msgRoot.inlineAudioUrl.length > 0 && inlinePlayer.playbackState === MediaPlayer.PlayingState) {
                                                var diff = Math.abs(inlinePlayer.position - inlineAudioPlayer.position)
                                                if (diff > 350) {
                                                    inlineAudioPlayer.position = inlinePlayer.position
                                                }
                                            }
                                        }
                                    }

                                    AudioOutput {
                                        id: primaryAudioOut
                                    }

                                    // Secondary audio player for YouTube DASH streams where audio is served as a separate track
                                    MediaPlayer {
                                        id: inlineAudioPlayer
                                        audioOutput: separateAudioOut
                                        source: msgRoot.inlineAudioUrl
                                    }

                                    AudioOutput {
                                        id: separateAudioOut
                                    }

                                    VideoOutput {
                                        id: videoOut
                                        anchors.fill: parent
                                    }

                                    // Video Controls Bar (bottom overlay)
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 36
                                        color: "#dd000000"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Text {
                                                text: inlinePlayer.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"
                                                color: "#ffffff"
                                                font.pixelSize: 14
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (inlinePlayer.playbackState === MediaPlayer.PlayingState) {
                                                            inlinePlayer.pause()
                                                            if (msgRoot.inlineAudioUrl.length > 0) {
                                                                inlineAudioPlayer.pause()
                                                            }
                                                        } else {
                                                            inlinePlayer.play()
                                                            if (msgRoot.inlineAudioUrl.length > 0) {
                                                                inlineAudioPlayer.play()
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Slider {
                                                Layout.fillWidth: true
                                                from: 0
                                                to: Math.max(1, inlinePlayer.duration)
                                                value: inlinePlayer.position
                                                onMoved: {
                                                    inlinePlayer.position = value
                                                    if (msgRoot.inlineAudioUrl.length > 0) {
                                                        inlineAudioPlayer.position = value
                                                    }
                                                }
                                            }

                                            Text {
                                                text: {
                                                    var curS = Math.floor(inlinePlayer.position / 1000)
                                                    var totS = Math.floor(inlinePlayer.duration / 1000)
                                                    var curM = Math.floor(curS / 60)
                                                    var totM = Math.floor(totS / 60)
                                                    return curM + ":" + (curS % 60 < 10 ? "0" : "") + (curS % 60) + " / " + totM + ":" + (totS % 60 < 10 ? "0" : "") + (totS % 60)
                                                }
                                                color: "#ffffff"
                                                font.pixelSize: 10
                                                font.family: theme.fontMono
                                            }

                                            Text {
                                                text: "✕"
                                                color: "#ffffff"
                                                font.pixelSize: 12
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        inlinePlayer.stop()
                                                        if (msgRoot.inlineAudioUrl.length > 0) {
                                                            inlineAudioPlayer.stop()
                                                        }
                                                        msgRoot.isInlinePlaying = false
                                                        msgRoot.inlineStreamUrl = ""
                                                        msgRoot.inlineAudioUrl = ""
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Bottom Action Strip (Buttons for Play, MPV, Browser)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                height: 34
                                color: theme.bgSecondary
                                visible: !msgRoot.isInlinePlaying

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Play Inline button
                                    Rectangle {
                                        height: 24
                                        implicitWidth: playInlineTxt.implicitWidth + 16
                                        radius: 4
                                        color: playInlHover.hovered ? theme.bgHover : theme.bgElevated
                                        border.color: theme.borderSubtle

                                        Text {
                                            id: playInlineTxt
                                            anchors.centerIn: parent
                                            text: msgRoot.isResolvingStream ? "⏳ Resolving..." : "▶ Play Inline"
                                            color: theme.accentCyan
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        HoverHandler { id: playInlHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!msgRoot.isResolvingStream) {
                                                    msgRoot.isResolvingStream = true
                                                    msgRoot.resolveError = ""
                                                    relayController.resolve_media_stream(model.media_url, model.line_ptr)
                                                }
                                            }
                                        }
                                    }

                                    // MPV button
                                    Rectangle {
                                        height: 24
                                        implicitWidth: mpvTxt.implicitWidth + 16
                                        radius: 4
                                        color: mpvHover.hovered ? theme.bgHover : theme.bgElevated
                                        border.color: theme.borderSubtle

                                        Text {
                                            id: mpvTxt
                                            anchors.centerIn: parent
                                            text: "▶ MPV"
                                            color: theme.accentPrimary
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        HoverHandler { id: mpvHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: relayController.play_with_mpv(model.media_url)
                                        }
                                    }

                                    // Status / Error message or spacer
                                    Text {
                                        id: errText
                                        Layout.fillWidth: true
                                        visible: msgRoot.resolveError.length > 0
                                        text: msgRoot.resolveError
                                        color: theme.badgeHighlight
                                        font.pixelSize: 10
                                        elide: Text.ElideRight

                                        HoverHandler { id: errHover }
                                        ToolTip.visible: errHover.hovered && msgRoot.resolveError.length > 0
                                        ToolTip.text: msgRoot.resolveError + "\n(Click to copy error to clipboard)"
                                        ToolTip.delay: 150
                                        ToolTip.timeout: 15000

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: relayController.copy_to_clipboard(msgRoot.resolveError)
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        visible: msgRoot.resolveError.length === 0
                                    }

                                    // Open in Browser button
                                    Rectangle {
                                        height: 24
                                        implicitWidth: openTxt.implicitWidth + 14
                                        radius: 4
                                        color: openHover.hovered ? theme.bgHover : theme.bgElevated
                                        border.color: theme.borderSubtle

                                        Text {
                                            id: openTxt
                                            anchors.centerIn: parent
                                            text: "Open ↗"
                                            color: theme.textSecondary
                                            font.pixelSize: 10
                                        }

                                        HoverHandler { id: openHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Qt.openUrlExternally(model.media_url)
                                        }
                                    }
                                }
                            }

                            // Error Detail Banner (shown if stream resolution encounters an error so it is never truncated)
                            Rectangle {
                                Layout.fillWidth: true
                                visible: msgRoot.resolveError.length > 0 && !msgRoot.isInlinePlaying
                                implicitHeight: errCol.implicitHeight + 12
                                radius: 6
                                color: Qt.alpha(theme.statusError, 0.12)
                                border.color: Qt.alpha(theme.statusError, 0.3)
                                border.width: 1

                                ColumnLayout {
                                    id: errCol
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text { text: "⚠️"; font.pixelSize: 11 }
                                        Text {
                                            text: "Stream Resolution Error"
                                            color: theme.statusError
                                            font.pixelSize: 11
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: "📋 Copy Error"
                                            color: copyErrHover.hovered ? theme.textPrimary : theme.textSecondary
                                            font.pixelSize: 10
                                            font.bold: true
                                            HoverHandler { id: copyErrHover }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: relayController.copy_to_clipboard(msgRoot.resolveError)
                                            }
                                        }
                                    }

                                    Text {
                                        text: msgRoot.resolveError
                                        color: theme.textSecondary
                                        font.pixelSize: 11
                                        font.family: theme.fontMono
                                        wrapMode: Text.WrapAnywhere
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            HoverHandler { id: rowHover }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: function(event) {
                    msgRoot.contextMenuRequested(
                        messageBody,
                        messageBody.selectedText,
                        model.plain_text,
                        model.prefix_plain,
                        model.time_str,
                        messageBody.hoveredLink,
                        model.is_action
                    )
                }
            }
        }
    }
}
