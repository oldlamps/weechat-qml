mod bridge;
mod config;
mod formatting;
mod relay;
mod servers;

use cpp::cpp;
use cstr::cstr;
use qmetaobject::*;

use crate::bridge::controller::RelayController;

cpp! {{
    #include <QtGui/QGuiApplication>
    #include <QtGui/QClipboard>
    #include <QtGui/QIcon>
}}

pub fn copy_to_clipboard(text: &str) {
    let c_str = std::ffi::CString::new(text).unwrap_or_default();
    let ptr = c_str.as_ptr();
    unsafe {
        cpp!([ptr as "const char*"] {
            if (QGuiApplication::instance()) {
                QClipboard *clipboard = QGuiApplication::clipboard();
                if (clipboard) {
                    clipboard->setText(QString::fromUtf8(ptr));
                }
            }
        });
    }
}

qrc!(app_resources,
    "qml" {
        "qml/Main.qml" as "Main.qml",
        "qml/Theme.qml" as "Theme.qml",
        "qml/components/BufferSidebar.qml" as "components/BufferSidebar.qml",
        "qml/components/ChatHeader.qml" as "components/ChatHeader.qml",
        "qml/components/MessageListView.qml" as "components/MessageListView.qml",
        "qml/components/MessageDelegate.qml" as "components/MessageDelegate.qml",
        "qml/components/ChatInputBar.qml" as "components/ChatInputBar.qml",
        "qml/components/NickSidebar.qml" as "components/NickSidebar.qml",
        "qml/components/QuickSwitcherModal.qml" as "components/QuickSwitcherModal.qml",
        "qml/components/SettingsDialog.qml" as "components/SettingsDialog.qml",
        "qml/components/FilterManagerModal.qml" as "components/FilterManagerModal.qml",
        "qml/components/ServerManagerDialog.qml" as "components/ServerManagerDialog.qml",
        "qml/components/QuitConfirmDialog.qml" as "components/QuitConfirmDialog.qml",
        "qml/components/MediaViewerModal.qml" as "components/MediaViewerModal.qml",
    },
    "icons" {
        "assets/weechat.png" as "weechat.png",
        "assets/weechat.svg" as "weechat.svg",
    }
);

fn main() {
    app_resources();

    qml_register_type::<RelayController>(cstr!("WeeChatQml"), 1, 0, cstr!("RelayController"));

    let mut engine = QmlEngine::new();

    unsafe {
        cpp!([] {
            if (QGuiApplication::instance()) {
                QIcon icon(":/icons/weechat.png");
                QGuiApplication::setWindowIcon(icon);
            }
        });
    }

    engine.load_file("qrc:/qml/Main.qml".into());
    engine.exec();
}
