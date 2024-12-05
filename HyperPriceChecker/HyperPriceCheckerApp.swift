//
//  HyperPriceCheckerApp.swift
//  HyperPriceChecker
//
//  Created by saku on 2024/12/05.
//

import SwiftUI

@main
struct HyperPriceCheckerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // ウィンドウを持たないため、空にします
        Settings {
            // 必要に応じて設定画面を追加できます
        }
    }
}
