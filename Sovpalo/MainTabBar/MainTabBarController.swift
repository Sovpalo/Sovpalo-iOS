import UIKit
import SwiftUI

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }

    private func setupTabs() {
        let mainScreen = MainScreenAssembly.build()
        let mainHosting = UIHostingController(rootView: mainScreen)
        mainHosting.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "chart.pie"),
            selectedImage: UIImage(systemName: "chart.pie.fill")
        )

        let meetingsVC = MeetingsAssembly.assembly()
        let meetingsNav = UINavigationController(rootViewController: meetingsVC)
        meetingsNav.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "calendar"),
            selectedImage: UIImage(systemName: "calendar")
        )

        let ideasPlaceholder = UIViewController()
        ideasPlaceholder.view.backgroundColor = .systemBackground
        ideasPlaceholder.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "lightbulb"),
            selectedImage: UIImage(systemName: "lightbulb.fill")
        )

        let friendsPlaceholder = UIViewController()
        friendsPlaceholder.view.backgroundColor = .systemBackground
        friendsPlaceholder.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "person.3"),
            selectedImage: UIImage(systemName: "person.3.fill")
        )

        viewControllers = [
            mainHosting,
            meetingsNav,
            ideasPlaceholder,
            friendsPlaceholder
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
