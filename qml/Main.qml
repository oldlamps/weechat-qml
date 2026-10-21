import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import WeeChatQml 1.0
import "components"

ApplicationWindow {
    id: rootWindow
    width: 1280
    height: 820
    minimumWidth: 880
    minimumHeight: 560
    visible: true
    title: {
        var base = "WeeChat QML"
        if (relay.active_buffer_name.length > 0) {
            base = relay.active_buffer_name + " (" + relay.active_buffer_server + ") — WeeChat QML"
        }
        if (relay.total_unread_count > 0) {
            base = "[" + relay.total_unread_count + "] " + base
        }
        return base
    }
    color: appTheme.bgPrimary

    property bool showLeftSidebar: true
    property bool showRightSidebar: true
    property bool forceClose: false

    function requestQuit() {
        if (relay.confirm_on_quit && !forceClose) {
            quitConfirmDialog.openDialog()
        } else {
            forceClose = true
            Qt.quit()
        }
    }

    onClosing: function(close) {
        if (relay.confirm_on_quit && !forceClose) {
            close.accepted = false
            quitConfirmDialog.openDialog()
        }
    }

    Theme {
        id: appTheme
        Binding on activeThemeName {
            value: relay.theme_name.length > 0 ? relay.theme_name : "Catppuccin Mocha"
        }
        Binding on baseFontSize {
            value: relay.font_size > 0 ? relay.font_size : 13
        }
    }

    RelayController {
        id: relay
        Component.onCompleted: {
            relay.init_controller()
            if (relay.should_show_server_manager_on_startup()) {
                serverManagerDialog.openManager()
            }
        }
        onActive_buffer_changed: {
            chatInputBar.focusInput()
        }
    }

    // Keyboard Shortcuts
    Shortcut {
        sequence: "Ctrl+K"
        onActivated: {
            if (quickSwitcher.visible) {
                quickSwitcher.closeModal()
            } else {
                quickSwitcher.openModal()
            }
        }
    }

    // Next / Previous Channel Shortcuts (Ctrl+Tab & Ctrl+Shift+Tab, Ctrl+PageDown & Ctrl+PageUp)
    Shortcut {
        sequence: "Ctrl+Tab"
        onActivated: relay.select_next_buffer()
    }

    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        onActivated: relay.select_previous_buffer()
    }

    Shortcut {
        sequence: "Ctrl+Page_Down"
        onActivated: relay.select_next_buffer()
    }

    Shortcut {
        sequence: "Ctrl+Page_Up"
        onActivated: relay.select_previous_buffer()
    }

    // PageUp & PageDown when global focus is elsewhere
    Shortcut {
        sequence: "Page_Up"
        onActivated: messageListView.scrollPageUp()
    }

    Shortcut {
        sequence: "Page_Down"
        onActivated: messageListView.scrollPageDown()
    }

    Shortcut {
        sequence: "Home"
        onActivated: messageListView.scrollToTop()
    }

    Shortcut {
        sequence: "End"
        onActivated: messageListView.scrollToBottom()
    }

    // Application Quit Shortcut
    Shortcut {
        sequence: "Ctrl+Q"
        onActivated: rootWindow.requestQuit()
    }

    // Next Unread Hotkeys (Ctrl+U and classic Alt+A)
    Shortcut {
        sequence: "Ctrl+U"
        onActivated: relay.select_next_unread_buffer()
    }

    Shortcut {
        sequence: "Alt+A"
        onActivated: relay.select_next_unread_buffer()
    }

    // Numbered buffer quick jump shortcuts: Alt+1 through Alt+9
    Shortcut { sequence: "Alt+1"; onActivated: relay.select_buffer_by_number(1) }
    Shortcut { sequence: "Alt+2"; onActivated: relay.select_buffer_by_number(2) }
    Shortcut { sequence: "Alt+3"; onActivated: relay.select_buffer_by_number(3) }
    Shortcut { sequence: "Alt+4"; onActivated: relay.select_buffer_by_number(4) }
    Shortcut { sequence: "Alt+5"; onActivated: relay.select_buffer_by_number(5) }
    Shortcut { sequence: "Alt+6"; onActivated: relay.select_buffer_by_number(6) }
    Shortcut { sequence: "Alt+7"; onActivated: relay.select_buffer_by_number(7) }
    Shortcut { sequence: "Alt+8"; onActivated: relay.select_buffer_by_number(8) }
    Shortcut { sequence: "Alt+9"; onActivated: relay.select_buffer_by_number(9) }
    Shortcut { sequence: "Alt+0"; onActivated: relay.select_buffer_by_number(10) }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: {
            chatHeader.showSearchBar = !chatHeader.showSearchBar
        }
    }

    // Main Three-Pane Desktop Layout
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Left Pane: Collapsible Buffer Tree & Server List
        BufferSidebar {
            visible: rootWindow.showLeftSidebar
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            relayController: relay
            theme: appTheme
            onOpenServerManagerRequested: serverManagerDialog.openManager()
            onOpenQuickSwitcherRequested: quickSwitcher.openModal()
            onOpenSettingsRequested: settingsDialog.visible = true
        }

        // Center Pane: Header + Message Stream + Rich Input Bar
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ChatHeader {
                id: chatHeader
                Layout.fillWidth: true
                relayController: relay
                theme: appTheme
                showBufferSidebar: rootWindow.showLeftSidebar
                showNickSidebar: rootWindow.showRightSidebar
                onToggleBufferSidebar: rootWindow.showLeftSidebar = !rootWindow.showLeftSidebar
                onToggleNickSidebar: rootWindow.showRightSidebar = !rootWindow.showRightSidebar
                onOpenSettingsRequested: settingsDialog.visible = true
            }

            MessageListView {
                id: messageListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                relayController: relay
                theme: appTheme
                onMentionNickRequested: function(nick) {
                    chatInputBar.insertMention(nick)
                }
            }

            ChatInputBar {
                id: chatInputBar
                Layout.fillWidth: true
                relayController: relay
                theme: appTheme
                onPageUpRequested: messageListView.scrollPageUp()
                onPageDownRequested: messageListView.scrollPageDown()
                onHomeRequested: messageListView.scrollToTop()
                onEndRequested: messageListView.scrollToBottom()
                onQuitRequested: rootWindow.requestQuit()
                onQuickSwitcherRequested: {
                    if (quickSwitcher.visible) {
                        quickSwitcher.closeModal()
                    } else {
                        quickSwitcher.openModal()
                    }
                }
            }
        }

        // Right Pane: Collapsible Nicklist Drawer (shown for channels)
        NickSidebar {
            visible: rootWindow.showRightSidebar && relay.active_buffer_type === "channel"
            Layout.preferredWidth: 215
            Layout.fillHeight: true
            relayController: relay
            theme: appTheme
            onMentionNickRequested: function(nick) {
                chatInputBar.insertMention(nick)
            }
        }
    }

    // Ctrl+K Quick Switcher Modal
    QuickSwitcherModal {
        id: quickSwitcher
        relayController: relay
        theme: appTheme
    }

    // Preferences & Settings Modal
    SettingsDialog {
        id: settingsDialog
        relayController: relay
        theme: appTheme
    }

    // Persistent Server Manager Modal
    ServerManagerDialog {
        id: serverManagerDialog
        relayController: relay
        theme: appTheme
    }

    // Quit Confirmation Modal
    QuitConfirmDialog {
        id: quitConfirmDialog
        relayController: relay
        theme: appTheme
        onQuitConfirmed: {
            rootWindow.forceClose = true
            Qt.quit()
        }
    }
}
