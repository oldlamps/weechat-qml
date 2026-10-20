use std::process::Command;

fn main() {
    let qmake = std::env::var("QMAKE").unwrap_or_else(|_| {
        if Command::new("qmake6").arg("-v").output().is_ok() {
            "qmake6".to_string()
        } else {
            "qmake".to_string()
        }
    });

    let include_dir = String::from_utf8(
        Command::new(&qmake)
            .args(["-query", "QT_INSTALL_HEADERS"])
            .output()
            .expect("Failed to execute qmake to query QT_INSTALL_HEADERS")
            .stdout,
    )
    .expect("Invalid UTF-8 from qmake")
    .trim()
    .to_string();

    let lib_dir = String::from_utf8(
        Command::new(&qmake)
            .args(["-query", "QT_INSTALL_LIBS"])
            .output()
            .expect("Failed to execute qmake to query QT_INSTALL_LIBS")
            .stdout,
    )
    .expect("Invalid UTF-8 from qmake")
    .trim()
    .to_string();

    let mut config = cpp_build::Config::new();
    config.flag("-std=c++17");
    config.include(&include_dir);
    config.include(format!("{}/QtCore", include_dir));
    config.include(format!("{}/QtGui", include_dir));
    config.include(format!("{}/QtQml", include_dir));
    config.include(format!("{}/QtQuick", include_dir));
    config.include(format!("{}/QtQuickControls2", include_dir));
    config.include(format!("{}/QtMultimedia", include_dir));
    config.build("src/main.rs");

    println!("cargo:rustc-link-search={}", lib_dir);
    println!("cargo:rustc-link-lib=Qt6Core");
    println!("cargo:rustc-link-lib=Qt6Gui");
    println!("cargo:rustc-link-lib=Qt6Qml");
    println!("cargo:rustc-link-lib=Qt6Quick");
    println!("cargo:rustc-link-lib=Qt6QuickControls2");
    println!("cargo:rustc-link-lib=Qt6Multimedia");
    println!("cargo:rerun-if-changed=qml/");
}
