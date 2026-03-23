import UIKit
import SwiftUI

final class MainTabBarController: UITabBarController {

    let selectedCompany: Company

    private var customTabBarHost: UIHostingController<CustomTabBar>?
    private var customTabBarBottomConstraint: NSLayoutConstraint?

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
        selectedIndex = 0
        updateCustomTabBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBar.isHidden = true
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

        let ideasPlaceholder = UIViewController()
        ideasPlaceholder.view.backgroundColor = .systemBackground
        let ideasNav = UINavigationController(rootViewController: ideasPlaceholder)
        ideasNav.navigationBar.isHidden = true
        ideasNav.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "lightbulb"),
            selectedImage: UIImage(systemName: "lightbulb.fill")
        )

        let friendsPlaceholder = UIViewController()
        friendsPlaceholder.view.backgroundColor = .systemBackground
        let friendsNav = UINavigationController(rootViewController: friendsPlaceholder)
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
    }
}
