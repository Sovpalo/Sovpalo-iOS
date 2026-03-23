import UIKit
import SwiftUI

final class MainTabBarController: UITabBarController {

    let selectedCompany: Company

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
    }

    private func setupTabs() {
        let mainScreen = MainScreenAssembly.build(company: selectedCompany)
        let mainHosting = UIHostingController(rootView: mainScreen)
        let mainNav = UINavigationController(rootViewController: mainHosting)
        mainNav.navigationBar.isHidden = true
        mainNav.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "chart.pie"),
            selectedImage: UIImage(systemName: "chart.pie.fill")
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
            image: UIImage(systemName: "person.3"),
            selectedImage: UIImage(systemName: "person.3.fill")
        )

        viewControllers = [
            mainNav,
            meetingsNav,
            ideasNav,
            friendsNav
        ]

        selectedIndex = 0
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
    }
}
