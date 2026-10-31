import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Rectangle {
    id: modalRoot
    anchors.fill: parent
    color: "#e607080c"
    visible: false
    z: 115

    property var relayController
    property var theme

    // Media properties
    property string mediaType: "" // "image" or "youtube"
    property string mediaUrl: ""
    property string streamUrl: ""
    property string audioUrl: ""
    property string mediaTitle: ""
    property bool isResolving: false
    property string resolveError: ""
    property bool isMaximized: false
    property real imageZoom: 1.0
    property real imagePanX: 0
    property real imagePanY: 0

    // Active inline delegate item being expanded (seamless continuous video handover)
    property var activeInlineItem: null

    readonly property var currentVideoPlayer: activeInlineItem ? activeInlineItem.inlinePlayer : modalPlayer
    readonly property var currentAudioPlayer: activeInlineItem ? activeInlineItem.inlineAudioPlayer : modalAudioPlayer
    readonly property var currentAudioOut: activeInlineItem ? activeInlineItem.primaryAudioOut : primaryAudioOut
    readonly property var currentSeparateAudioOut: activeInlineItem ? activeInlineItem.separateAudioOut : separateAudioOut

    Connections {
        target: relayController
        function onMedia_stream_resolved(target_id, s_url, a_url) {
            if (target_id === "modal_viewer" && modalRoot.visible) {
                modalRoot.isResolving = false
                modalRoot.resolveError = ""
                modalRoot.streamUrl = s_url
                modalRoot.audioUrl = a_url || ""
                modalPlayer.play()
                if (modalRoot.audioUrl.length > 0) {
                    modalAudioPlayer.play()
                }
            }
        }
        function onMedia_stream_error(target_id, error_msg) {
            if (target_id === "modal_viewer" && modalRoot.visible) {
                modalRoot.isResolving = false
                modalRoot.resolveError = error_msg
            }
        }
    }

    function openMedia(type, mUrl, sUrl, aUrl, title, initialPos, shouldPlay, inlineItem) {
        if (activeInlineItem && activeInlineItem.inlinePlayer && activeInlineItem.videoOut) {
            activeInlineItem.inlinePlayer.videoOutput = activeInlineItem.videoOut
        }
        activeInlineItem = (inlineItem && inlineItem.inlinePlayer) ? inlineItem : null

        mediaType = type
        mediaUrl = mUrl
        streamUrl = sUrl || ""
        audioUrl = aUrl || ""
        mediaTitle = title || mUrl
        resolveError = ""
        imageZoom = 1.0
        if (panZoomContainer) {
            panZoomContainer.x = 0
            panZoomContainer.y = 0
        }
        visible = true
        modalCard.forceActiveFocus()

        if (type === "youtube") {
            if (activeInlineItem) {
                modalPlayer.videoOutput = null
                activeInlineItem.inlinePlayer.videoOutput = modalVideoOut
                isResolving = false
                if (shouldPlay && activeInlineItem.inlinePlayer.playbackState !== MediaPlayer.PlayingState) {
                    activeInlineItem.inlinePlayer.play()
                    if (audioUrl.length > 0 && activeInlineItem.inlineAudioPlayer) {
                        activeInlineItem.inlineAudioPlayer.play()
                    }
                }
            } else {
                modalPlayer.videoOutput = modalVideoOut
                if (streamUrl.length > 0) {
                    isResolving = false
                    if (initialPos > 0) {
                        modalPlayer.position = initialPos
                        if (audioUrl.length > 0) modalAudioPlayer.position = initialPos
                    }
                    if (shouldPlay) {
                        modalPlayer.play()
                        if (audioUrl.length > 0) modalAudioPlayer.play()
                    }
                } else {
                    isResolving = true
                    if (relayController) {
                        relayController.resolve_media_stream(mediaUrl, "modal_viewer")
                    }
                }
            }
        }
    }

    function closeModal() {
        if (activeInlineItem && activeInlineItem.inlinePlayer && activeInlineItem.videoOut) {
            activeInlineItem.inlinePlayer.videoOutput = activeInlineItem.videoOut
            activeInlineItem = null
        } else {
            if (modalPlayer.playbackState === MediaPlayer.PlayingState) {
                modalPlayer.stop()
            }
            if (modalAudioPlayer.playbackState === MediaPlayer.PlayingState) {
                modalAudioPlayer.stop()
            }
        }
        modalPlayer.videoOutput = modalVideoOut
        streamUrl = ""
        audioUrl = ""
        isResolving = false
        imageZoom = 1.0
        if (panZoomContainer) {
            panZoomContainer.x = 0
            panZoomContainer.y = 0
        }
        visible = false
    }

    // Dismiss on clicking backdrop outside the dialog card
    MouseArea {
        anchors.fill: parent
        onClicked: modalRoot.closeModal()
    }

    // Main Card Container
    Rectangle {
        id: modalCard
        width: modalRoot.isMaximized ? parent.width : Math.min(parent.width - 40, 1140)
        height: modalRoot.isMaximized ? parent.height : Math.min(parent.height - 40, 840)
        anchors.centerIn: parent
        radius: modalRoot.isMaximized ? 0 : 12
        color: theme ? theme.bgElevated : "#181a20"
        border.color: modalRoot.isMaximized ? "transparent" : (theme ? theme.borderSubtle : "#303440")
        border.width: modalRoot.isMaximized ? 0 : 1
        clip: true

        focus: modalRoot.visible

        Keys.onEscapePressed: function(event) {
            event.accepted = true
            modalRoot.closeModal()
        }

        Keys.onSpacePressed: function(event) {
            if (modalRoot.mediaType === "youtube") {
                event.accepted = true
                togglePlayback()
            }
        }

        Keys.onLeftPressed: function(event) {
            if (modalRoot.mediaType === "youtube") {
                event.accepted = true
                seekRelative(-5000)
            }
        }

        Keys.onRightPressed: function(event) {
            if (modalRoot.mediaType === "youtube") {
                event.accepted = true
                seekRelative(5000)
            }
        }

        Keys.onUpPressed: function(event) {
            if (modalRoot.mediaType === "youtube") {
                event.accepted = true
                if (modalRoot.currentAudioOut) {
                    modalRoot.currentAudioOut.volume = Math.min(1.0, modalRoot.currentAudioOut.volume + 0.1)
                    if (modalRoot.currentSeparateAudioOut) {
                        modalRoot.currentSeparateAudioOut.volume = modalRoot.currentAudioOut.volume
                    }
                }
            }
        }

        Keys.onDownPressed: function(event) {
            if (modalRoot.mediaType === "youtube") {
                event.accepted = true
                if (modalRoot.currentAudioOut) {
                    modalRoot.currentAudioOut.volume = Math.max(0.0, modalRoot.currentAudioOut.volume - 0.1)
                    if (modalRoot.currentSeparateAudioOut) {
                        modalRoot.currentSeparateAudioOut.volume = modalRoot.currentAudioOut.volume
                    }
                }
            }
        }

        function togglePlayback() {
            var vPlayer = modalRoot.currentVideoPlayer
            var aPlayer = modalRoot.currentAudioPlayer
            if (!vPlayer) return
            if (vPlayer.playbackState === MediaPlayer.PlayingState) {
                vPlayer.pause()
                if (modalRoot.audioUrl.length > 0 && aPlayer) aPlayer.pause()
            } else {
                vPlayer.play()
                if (modalRoot.audioUrl.length > 0 && aPlayer) aPlayer.play()
            }
        }

        function seekRelative(deltaMs) {
            var vPlayer = modalRoot.currentVideoPlayer
            var aPlayer = modalRoot.currentAudioPlayer
            if (!vPlayer) return
            var newPos = Math.max(0, Math.min(vPlayer.duration, vPlayer.position + deltaMs))
            vPlayer.position = newPos
            if (modalRoot.audioUrl.length > 0 && aPlayer) aPlayer.position = newPos
        }

        // Prevent click-through
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // 1. TOP HEADER BAR
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                height: 52
                color: theme ? theme.bgSecondary : "#12141a"
                border.color: theme ? theme.borderSubtle : "#282b36"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 14
                    spacing: 12

                    // Badge
                    Rectangle {
                        height: 26
                        implicitWidth: badgeRow.implicitWidth + 20
                        radius: 6
                        color: modalRoot.mediaType === "youtube" ? "#cc0000" : (theme ? theme.accentPrimary : "#3b82f6")

                        RowLayout {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: modalRoot.mediaType === "youtube" ? "▶" : "🖼"
                                color: "#ffffff"
                                font.pixelSize: 11
                            }
                            Text {
                                id: badgeText
                                text: modalRoot.mediaType === "youtube" ? "YouTube Video" : "Image Preview"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }

                    // Title / Filename
                    Text {
                        Layout.fillWidth: true
                        text: modalRoot.mediaTitle
                        color: theme ? theme.textPrimary : "#f8f9fa"
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideMiddle
                    }

                    // Action: Copy Link
                    Rectangle {
                        height: 32
                        implicitWidth: copyRow.implicitWidth + 24
                        radius: 6
                        color: copyHover.hovered ? (theme ? theme.bgHover : "#2d313d") : (theme ? theme.bgElevated : "#1f222b")
                        border.color: theme ? theme.borderSubtle : "#353945"

                        RowLayout {
                            id: copyRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "📋"; font.pixelSize: 12 }
                            Text {
                                id: copyLinkTxt
                                text: "Copy Link"
                                color: copyHover.hovered ? (theme ? theme.textPrimary : "#ffffff") : (theme ? theme.textSecondary : "#c0c4cc")
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        HoverHandler { id: copyHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (relayController) {
                                    relayController.copy_to_clipboard(modalRoot.mediaUrl)
                                }
                            }
                        }
                    }

                    // Action: MPV (for videos)
                    Rectangle {
                        visible: modalRoot.mediaType === "youtube"
                        height: 32
                        implicitWidth: mpvRow.implicitWidth + 24
                        radius: 6
                        color: mpvModalHover.hovered ? (theme ? theme.bgHover : "#2d313d") : (theme ? theme.bgElevated : "#1f222b")
                        border.color: theme ? theme.borderSubtle : "#353945"

                        RowLayout {
                            id: mpvRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "▶"; color: theme ? theme.accentPrimary : "#a6e3a1"; font.pixelSize: 11 }
                            Text {
                                id: mpvBtnTxt
                                text: "MPV"
                                color: theme ? theme.accentPrimary : "#a6e3a1"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        HoverHandler { id: mpvModalHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (relayController) {
                                    if (modalRoot.currentVideoPlayer) modalRoot.currentVideoPlayer.pause()
                                    if (modalRoot.audioUrl.length > 0 && modalRoot.currentAudioPlayer) modalRoot.currentAudioPlayer.pause()
                                    relayController.play_with_mpv(modalRoot.mediaUrl)
                                }
                            }
                        }
                    }

                    // Action: Open in Browser
                    Rectangle {
                        height: 32
                        implicitWidth: openRow.implicitWidth + 24
                        radius: 6
                        color: openBrwHover.hovered ? (theme ? theme.bgHover : "#2d313d") : (theme ? theme.bgElevated : "#1f222b")
                        border.color: theme ? theme.borderSubtle : "#353945"

                        RowLayout {
                            id: openRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                id: openBrowserTxt
                                text: "Open ↗"
                                color: openBrwHover.hovered ? (theme ? theme.textPrimary : "#ffffff") : (theme ? theme.textSecondary : "#c0c4cc")
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        HoverHandler { id: openBrwHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (relayController) {
                                    relayController.open_url(modalRoot.mediaUrl)
                                }
                            }
                        }
                    }

                    // Maximize / Restore Toggle Button
                    Rectangle {
                        width: 36
                        height: 32
                        radius: 6
                        color: maxHover.hovered ? (theme ? theme.bgHover : "#2d313d") : (theme ? theme.bgElevated : "#1f222b")
                        border.color: theme ? theme.borderSubtle : "#353945"

                        Text {
                            anchors.centerIn: parent
                            text: modalRoot.isMaximized ? "🗗" : "🗖"
                            color: theme ? theme.textSecondary : "#c0c4cc"
                            font.pixelSize: 14
                        }

                        HoverHandler { id: maxHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modalRoot.isMaximized = !modalRoot.isMaximized
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 36
                        height: 32
                        radius: 6
                        color: closeHover.hovered ? "#e06c75" : (theme ? theme.bgElevated : "#1f222b")
                        border.color: theme ? theme.borderSubtle : "#353945"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeHover.hovered ? "#ffffff" : (theme ? theme.textPrimary : "#ffffff")
                            font.pixelSize: 14
                            font.bold: true
                        }

                        HoverHandler { id: closeHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modalRoot.closeModal()
                        }
                    }
                }
            }

            // 2. MAIN MEDIA DISPLAY VIEWPORT
            Item {
                id: viewport
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                onWidthChanged: {
                    if (modalRoot.imageZoom <= 1.0) {
                        panZoomContainer.x = 0
                    }
                }
                onHeightChanged: {
                    if (modalRoot.imageZoom <= 1.0) {
                        panZoomContainer.y = 0
                    }
                }

                // A. IMAGE VIEWER MODE
                Item {
                    anchors.fill: parent
                    visible: modalRoot.mediaType === "image"

                    // Zoomable & Pannable container
                    Item {
                        id: panZoomContainer
                        x: 0
                        y: 0
                        width: viewport.width * modalRoot.imageZoom
                        height: viewport.height * modalRoot.imageZoom

                        Image {
                            id: fullImg
                            anchors.fill: parent
                            source: modalRoot.mediaType === "image" ? modalRoot.mediaUrl : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }
                    }

                    // MouseArea covering the viewport for cursor-centered wheel zooming and click-drag panning
                    MouseArea {
                        id: imgMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        drag.target: modalRoot.imageZoom > 1.0 ? panZoomContainer : null
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: modalRoot.imageZoom > 1.0 ? (viewport.width - panZoomContainer.width - viewport.width * 0.25) : 0
                        drag.maximumX: modalRoot.imageZoom > 1.0 ? (viewport.width * 0.25) : 0
                        drag.minimumY: modalRoot.imageZoom > 1.0 ? (viewport.height - panZoomContainer.height - viewport.height * 0.25) : 0
                        drag.maximumY: modalRoot.imageZoom > 1.0 ? (viewport.height * 0.25) : 0

                        cursorShape: modalRoot.imageZoom > 1.0 ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor

                        onWheel: function(wheel) {
                            var oldZoom = modalRoot.imageZoom
                            var zoomFactor = wheel.angleDelta.y > 0 ? 1.25 : (1.0 / 1.25)
                            var newZoom = Math.max(1.0, Math.min(8.0, oldZoom * zoomFactor))

                            if (Math.abs(newZoom - 1.0) < 0.05 || newZoom <= 1.0) {
                                modalRoot.imageZoom = 1.0
                                panZoomContainer.x = 0
                                panZoomContainer.y = 0
                                return
                            }

                            var ratio = newZoom / oldZoom
                            var mx = wheel.x
                            var my = wheel.y

                            var newX = mx - (mx - panZoomContainer.x) * ratio
                            var newY = my - (my - panZoomContainer.y) * ratio

                            var newW = viewport.width * newZoom
                            var newH = viewport.height * newZoom

                            var minX = viewport.width - newW - viewport.width * 0.25
                            var maxX = viewport.width * 0.25
                            var minY = viewport.height - newH - viewport.height * 0.25
                            var maxY = viewport.height * 0.25

                            modalRoot.imageZoom = newZoom
                            panZoomContainer.x = Math.min(maxX, Math.max(minX, newX))
                            panZoomContainer.y = Math.min(maxY, Math.max(minY, newY))
                        }

                        onDoubleClicked: function(mouse) {
                            if (modalRoot.imageZoom > 1.0) {
                                modalRoot.imageZoom = 1.0
                                panZoomContainer.x = 0
                                panZoomContainer.y = 0
                            } else {
                                var newZoom = 2.5
                                var mx = mouse.x
                                var my = mouse.y
                                var newW = viewport.width * newZoom
                                var newH = viewport.height * newZoom
                                var newX = mx - mx * newZoom
                                var newY = my - my * newZoom
                                var minX = viewport.width - newW - viewport.width * 0.25
                                var maxX = viewport.width * 0.25
                                var minY = viewport.height - newH - viewport.height * 0.25
                                var maxY = viewport.height * 0.25

                                modalRoot.imageZoom = newZoom
                                panZoomContainer.x = Math.min(maxX, Math.max(minX, newX))
                                panZoomContainer.y = Math.min(maxY, Math.max(minY, newY))
                            }
                        }
                    }

                    // Loading indicator for image
                    Item {
                        anchors.centerIn: parent
                        visible: fullImg.status === Image.Loading

                        RowLayout {
                            spacing: 8
                            Text { text: "⏳"; font.pixelSize: 16 }
                            Text {
                                text: "Loading high-resolution image..."
                                color: theme ? theme.textSecondary : "#c0c4cc"
                                font.pixelSize: 13
                            }
                        }
                    }

                    // Image error state
                    Item {
                        anchors.centerIn: parent
                        visible: fullImg.status === Image.Error

                        ColumnLayout {
                            spacing: 10
                            Text {
                                text: "⚠️ Failed to load image preview"
                                color: theme ? theme.statusError : "#f38ba8"
                                font.pixelSize: 14
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                height: 32
                                implicitWidth: 140
                                radius: 6
                                color: theme ? theme.accentPrimary : "#3b82f6"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Open in Browser ↗"
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (relayController) {
                                            relayController.open_url(modalRoot.mediaUrl)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Bottom info strip for image (Zoom level & Dimensions & Reset button)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 14
                        height: 28
                        implicitWidth: imgInfoRow.implicitWidth + 22
                        radius: 6
                        color: "#cc000000"
                        visible: fullImg.status === Image.Ready

                        RowLayout {
                            id: imgInfoRow
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                id: imgInfoTxt
                                text: {
                                    var dim = fullImg.sourceSize.width > 0 ? (fullImg.sourceSize.width + " × " + fullImg.sourceSize.height + " px • ") : ""
                                    return dim + Math.round(modalRoot.imageZoom * 100) + "%"
                                }
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.family: theme ? theme.fontMono : "monospace"
                            }

                            // Quick Reset Button when zoomed
                            Rectangle {
                                visible: modalRoot.imageZoom > 1.0
                                width: 18
                                height: 18
                                radius: 4
                                color: resetZHover.hovered ? "#44ffffff" : "#22ffffff"

                                Text {
                                    anchors.centerIn: parent
                                    text: "↺"
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                }

                                HoverHandler { id: resetZHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modalRoot.imageZoom = 1.0
                                        panZoomContainer.x = 0
                                        panZoomContainer.y = 0
                                    }
                                }
                            }
                        }
                    }
                }

                // B. VIDEO VIEWER MODE (YOUTUBE)
                Item {
                    id: videoContainer
                    anchors.fill: parent
                    visible: modalRoot.mediaType === "youtube"

                    MediaPlayer {
                        id: modalPlayer
                        videoOutput: modalVideoOut
                        audioOutput: modalRoot.audioUrl.length === 0 ? primaryAudioOut : null
                        source: activeInlineItem ? "" : modalRoot.streamUrl

                        onPlaybackStateChanged: {
                            if (modalRoot.audioUrl.length > 0) {
                                if (modalPlayer.playbackState === MediaPlayer.PlayingState &&
                                    modalAudioPlayer.playbackState !== MediaPlayer.PlayingState) {
                                    modalAudioPlayer.play()
                                } else if (modalPlayer.playbackState === MediaPlayer.PausedState &&
                                           modalAudioPlayer.playbackState !== MediaPlayer.PausedState) {
                                    modalAudioPlayer.pause()
                                } else if (modalPlayer.playbackState === MediaPlayer.StoppedState &&
                                           modalAudioPlayer.playbackState !== MediaPlayer.StoppedState) {
                                    modalAudioPlayer.stop()
                                }
                            }
                        }

                        onPositionChanged: {
                            if (modalRoot.audioUrl.length > 0 && modalPlayer.playbackState === MediaPlayer.PlayingState) {
                                var diff = Math.abs(modalPlayer.position - modalAudioPlayer.position)
                                if (diff > 350) {
                                    modalAudioPlayer.position = modalPlayer.position
                                }
                            }
                        }
                    }

                    AudioOutput {
                        id: primaryAudioOut
                        volume: 1.0
                    }

                    // Secondary audio player for YouTube DASH streams
                    MediaPlayer {
                        id: modalAudioPlayer
                        audioOutput: separateAudioOut
                        source: activeInlineItem ? "" : modalRoot.audioUrl
                    }

                    AudioOutput {
                        id: separateAudioOut
                        volume: primaryAudioOut.volume
                        muted: primaryAudioOut.muted
                    }

                    VideoOutput {
                        id: modalVideoOut
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectFit

                        // Click video to toggle play / pause
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modalCard.togglePlayback()
                        }
                    }

                    // Center Big Play Indicator (when paused)
                    Rectangle {
                        width: 72
                        height: 72
                        radius: 36
                        anchors.centerIn: parent
                        color: "#bb000000"
                        visible: modalRoot.currentVideoPlayer && modalRoot.currentVideoPlayer.playbackState !== MediaPlayer.PlayingState && !modalRoot.isResolving && modalRoot.resolveError.length === 0

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 3
                            text: "▶"
                            color: "#ffffff"
                            font.pixelSize: 28
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modalCard.togglePlayback()
                        }
                    }

                    // Stream Resolving Placeholder
                    Item {
                        anchors.centerIn: parent
                        visible: modalRoot.isResolving

                        ColumnLayout {
                            spacing: 12
                            Text {
                                text: "⏳"
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Resolving stream formats with yt-dlp..."
                                color: theme ? theme.textPrimary : "#ffffff"
                                font.pixelSize: 14
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: "Extracting high-definition video and audio tracks"
                                color: theme ? theme.textMuted : "#888888"
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Stream Error Placeholder
                    Item {
                        anchors.centerIn: parent
                        visible: modalRoot.resolveError.length > 0 && !modalRoot.isResolving

                        ColumnLayout {
                            spacing: 12
                            Text {
                                text: "⚠️ Unable to resolve video stream"
                                color: theme ? theme.statusError : "#f38ba8"
                                font.pixelSize: 15
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Text {
                                text: modalRoot.resolveError
                                color: theme ? theme.textSecondary : "#c0c4cc"
                                font.pixelSize: 12
                                font.family: theme ? theme.fontMono : "monospace"
                                Layout.alignment: Qt.AlignHCenter
                                Layout.maximumWidth: 600
                                wrapMode: Text.WrapAnywhere
                            }
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                height: 34
                                implicitWidth: 150
                                radius: 6
                                color: theme ? theme.accentPrimary : "#3b82f6"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Open in Browser ↗"
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (relayController) {
                                            relayController.open_url(modalRoot.mediaUrl)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Bottom Floating Video Controls Bar
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 58
                        color: "#f0000000"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 14

                            // Play / Pause Button
                            Rectangle {
                                width: 38
                                height: 38
                                radius: 19
                                color: playBtnHover.hovered ? "#44ffffff" : "#22ffffff"

                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: (modalRoot.currentVideoPlayer && modalRoot.currentVideoPlayer.playbackState === MediaPlayer.PlayingState) ? 0 : 1
                                    text: (modalRoot.currentVideoPlayer && modalRoot.currentVideoPlayer.playbackState === MediaPlayer.PlayingState) ? "⏸" : "▶"
                                    color: "#ffffff"
                                    font.pixelSize: 16
                                }

                                HoverHandler { id: playBtnHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modalCard.togglePlayback()
                                }
                            }

                            // Progress Slider
                            Slider {
                                id: progressSlider
                                Layout.fillWidth: true
                                from: 0
                                to: Math.max(1, modalRoot.currentVideoPlayer ? modalRoot.currentVideoPlayer.duration : 1)
                                value: modalRoot.currentVideoPlayer ? modalRoot.currentVideoPlayer.position : 0
                                onMoved: {
                                    if (modalRoot.currentVideoPlayer) {
                                        modalRoot.currentVideoPlayer.position = value
                                    }
                                    if (modalRoot.audioUrl.length > 0 && modalRoot.currentAudioPlayer) {
                                        modalRoot.currentAudioPlayer.position = value
                                    }
                                }
                            }

                            // Timestamp Label
                            Text {
                                text: {
                                    var vPlayer = modalRoot.currentVideoPlayer
                                    var pos = vPlayer ? vPlayer.position : 0
                                    var dur = vPlayer ? vPlayer.duration : 0
                                    var curS = Math.floor(pos / 1000)
                                    var totS = Math.floor(dur / 1000)
                                    var curM = Math.floor(curS / 60)
                                    var totM = Math.floor(totS / 60)
                                    return curM + ":" + (curS % 60 < 10 ? "0" : "") + (curS % 60) + " / " + totM + ":" + (totS % 60 < 10 ? "0" : "") + (totS % 60)
                                }
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.family: theme ? theme.fontMono : "monospace"
                            }

                            // Volume Mute / Unmute Button
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 6
                                color: volBtnHover.hovered ? "#33ffffff" : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        var aOut = modalRoot.currentAudioOut
                                        if (!aOut) return "🔊"
                                        return aOut.muted || aOut.volume === 0 ? "🔇" : (aOut.volume < 0.5 ? "🔉" : "🔊")
                                    }
                                    color: "#ffffff"
                                    font.pixelSize: 15
                                }

                                HoverHandler { id: volBtnHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var aOut = modalRoot.currentAudioOut
                                        var sOut = modalRoot.currentSeparateAudioOut
                                        if (aOut) {
                                            aOut.muted = !aOut.muted
                                            if (sOut) sOut.muted = aOut.muted
                                        }
                                    }
                                }
                            }

                            // Volume Slider
                            Slider {
                                Layout.preferredWidth: 84
                                from: 0.0
                                to: 1.0
                                value: modalRoot.currentAudioOut ? modalRoot.currentAudioOut.volume : 1.0
                                onMoved: {
                                    var aOut = modalRoot.currentAudioOut
                                    var sOut = modalRoot.currentSeparateAudioOut
                                    if (aOut) {
                                        aOut.muted = false
                                        aOut.volume = value
                                    }
                                    if (sOut) {
                                        sOut.muted = false
                                        sOut.volume = value
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
