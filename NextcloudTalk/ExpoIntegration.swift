//
//  ExpoIntegration.swift
//  NextcloudTalk
//
//  Brownfield entry point: embeds a React Native screen from the shared
//  `ExpoBrownfieldPackage` Swift Package. A floating "Expo" button is added on
//  its own UIWindow (above the app UI); tapping it presents the RN screen.
//  See https://github.com/briones-agent/expo-brownfield-shared-ios
//

import UIKit
import ExpoBrownfieldKit

final class ExpoOverlayWindow: UIWindow {
    weak var interactiveView: UIView?
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if rootViewController?.presentedViewController != nil { return super.hitTest(point, with: event) }
        let hit = super.hitTest(point, with: event)
        if let iv = interactiveView, let hit = hit, (hit == iv || hit.isDescendant(of: iv)) { return hit }
        return nil
    }
}

@MainActor
@objc final class ExpoIntegration: NSObject {
    private static var overlayWindow: ExpoOverlayWindow?

    @objc static func bootstrap() {
        ReactNativeHostManager.shared.initialize()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            installExpoButton()
            if UserDefaults.standard.bool(forKey: "expoAutoOpen") {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                openExpo()
            }
        }
    }

    private static func installExpoButton() {
        guard overlayWindow == nil else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                installExpoButton()
            }
            return
        }
        let window = ExpoOverlayWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        let root = UIViewController()
        root.view.backgroundColor = .clear
        window.rootViewController = root
        let button = UIButton(type: .system)
        button.setTitle("Expo", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.0, green: 0.086, blue: 0.169, alpha: 1.0)
        button.layer.cornerRadius = 24
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.35
        button.layer.shadowRadius = 6
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(openExpo), for: .touchUpInside)
        root.view.addSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 88),
            button.heightAnchor.constraint(equalToConstant: 48),
            button.trailingAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            button.bottomAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.bottomAnchor, constant: -90),
        ])
        window.interactiveView = button
        window.isHidden = false
        overlayWindow = window
    }

    @objc private static func openExpo() {
        guard let root = overlayWindow?.rootViewController, root.presentedViewController == nil else { return }
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.forEach { $0.endEditing(true) }
        let rn = ReactNativeViewController(moduleName: "main")
        let nav = UINavigationController(rootViewController: rn)
        nav.modalPresentationStyle = .fullScreen
        rn.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeExpo))
        rn.title = "React Native"
        root.present(nav, animated: true)
    }

    @objc private static func closeExpo() { overlayWindow?.rootViewController?.dismiss(animated: true) }
}
