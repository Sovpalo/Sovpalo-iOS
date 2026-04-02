import UIKit
import SwiftUI

final class MainTabBarController: UITabBarController {

    let selectedCompany: Company

    private var customTabBarHost: UIHostingController<CustomTabBar>?
    private var customTabBarBottomConstraint: NSLayoutConstraint?
    private var isKeyboardVisible = false
    private var isCustomTabBarForcedHidden = false

    init(selectedCompany: Company) {
        self.selectedCompany = selectedCompany
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
        setupCustomTabBar()
        setupKeyboardObservers()
        selectedIndex = 0
        updateCustomTabBar()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        tabBar.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    private func setupTabs() {
        let mainScreen = MainScreenAssembly.build(company: selectedCompany)
        let mainHosting = UIHostingController(rootView: mainScreen)
        let mainNav = UINavigationController(rootViewController: mainHosting)
        mainNav.navigationBar.isHidden = true
        mainNav.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "clock"),
            selectedImage: UIImage(systemName: "clock.fill")
        )

        let meetingsVC = MeetingsAssembly.assembly(company: selectedCompany)
        let meetingsNav = UINavigationController(rootViewController: meetingsVC)
        meetingsNav.navigationBar.isHidden = true
        meetingsNav.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "calendar"),
            selectedImage: UIImage(systemName: "calendar")
        )

        let ideasVC = IdeasListAssembly.assembly(company: selectedCompany)
        let ideasNav = UINavigationController(rootViewController: ideasVC)
        ideasNav.navigationBar.isHidden = true
        ideasNav.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "lightbulb"),
            selectedImage: UIImage(systemName: "lightbulb.fill")
        )

        let groupMembersVC = GroupMembersAssembly.build(company: selectedCompany)
        let friendsNav = UINavigationController(rootViewController: groupMembersVC)
        friendsNav.navigationBar.isHidden = true
        friendsNav.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "person.2"),
            selectedImage: UIImage(systemName: "person.2.fill")
        )

        viewControllers = [
            mainNav,
            meetingsNav,
            ideasNav,
            friendsNav
        ]
    }

    private func setupAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        tabBar.tintColor = UIColor(hex: "#7079FB")
        tabBar.unselectedItemTintColor = .label

        tabBar.layer.cornerRadius = 28
        tabBar.layer.masksToBounds = true

        tabBar.isHidden = true
    }

    private func setupCustomTabBar() {
        let host = UIHostingController(rootView: makeCustomTabBar())
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let bottomConstraint = host.view.bottomAnchor.constraint(
            equalTo: view.bottomAnchor,
            constant: -8
        )
        self.customTabBarBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint
        ])

        self.customTabBarHost = host

        view.layoutIfNeeded()
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    @objc
    private func handleKeyboardFrameChange(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
            let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt,
            let tabBarView = customTabBarHost?.view
        else { return }

        let convertedEndFrame = view.convert(endFrame, from: nil)
        let keyboardOverlap = max(0, view.bounds.maxY - convertedEndFrame.minY)
        let shouldHideForKeyboard = keyboardOverlap > view.safeAreaInsets.bottom + 1

        isKeyboardVisible = shouldHideForKeyboard

        let shouldHideTabBar = isCustomTabBarForcedHidden || isKeyboardVisible
        let hiddenOffset = tabBarView.bounds.height + 24
        let transform = shouldHideTabBar
            ? CGAffineTransform(translationX: 0, y: hiddenOffset)
            : .identity

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curveRaw << 16),
            animations: {
                tabBarView.transform = transform
                tabBarView.alpha = shouldHideTabBar ? 0 : 1
            }
        )
    }

    private func makeCustomTabBar() -> CustomTabBar {
        CustomTabBar(
            selectedTab: TabBar.Tab(rawValue: selectedIndex) ?? .home,
            onSelect: { [weak self] tab in
                self?.selectedIndex = tab.rawValue
                self?.updateCustomTabBar()
            }
        )
    }

    private func updateCustomTabBar() {
        customTabBarHost?.rootView = makeCustomTabBar()
        let shouldHideTabBar = isCustomTabBarForcedHidden || isKeyboardVisible
        customTabBarHost?.view.alpha = shouldHideTabBar ? 0 : 1
        customTabBarHost?.view.transform = shouldHideTabBar
            ? CGAffineTransform(translationX: 0, y: (customTabBarHost?.view.bounds.height ?? 0) + 24)
            : .identity
    }

    func setCustomTabBarHidden(_ isHidden: Bool, animated: Bool) {
        guard let tabBarView = customTabBarHost?.view else { return }
        isCustomTabBarForcedHidden = isHidden

        let hiddenOffset = tabBarView.bounds.height + 24
        let shouldHideTabBar = isCustomTabBarForcedHidden || isKeyboardVisible
        let animations = {
            tabBarView.transform = shouldHideTabBar
                ? CGAffineTransform(translationX: 0, y: hiddenOffset)
                : .identity
            tabBarView.alpha = shouldHideTabBar ? 0 : 1
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: animations)
        } else {
            animations()
        }
    }
}
