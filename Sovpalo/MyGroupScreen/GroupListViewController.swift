//
//  GroupListViewController.swift
//  Sovpalo
//
//  Created by Jovana on 25.3.26.
//

import UIKit
import SwiftUI

final class GroupListViewController: UIViewController {

    private var companies: [Company] = []
    private let worker: FirstGroupWorkerProtocol = FirstGroupWorker()
    private let keychain: KeychainLogic = KeychainService()
    private let bellButton = UIButton(type: .system)
    private let invitationWorker: InvitationWorkerProtocol = {
        let keychain = KeychainService()
        return InvitationWorker(
            baseURL: Server.url,
            tokenProvider: {
                guard let tokenData = keychain.getData(forKey: "auth.token") else { return nil }
                return String(data: tokenData, encoding: .utf8)
            }
        )
    }()

    private let bellBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bellBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemRed
        view.layer.cornerRadius = 10
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor.white.cgColor
        view.clipsToBounds = true
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "GroupCell")
        tv.rowHeight = 56
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupHeader()
        setupAddButton()
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -76)
        ])
        loadCompanies()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(true, animated: animated)
        loadCompanies()
        refreshInvitationBadge()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(false, animated: animated)
        }
    }

    private func setupHeader() {
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.setTitle(" Назад", for: .normal)
        backButton.tintColor = UIColor(hex: "#7079FB")
        backButton.titleLabel?.font = .systemFont(ofSize: 17)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.text = "Мои группы"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        bellButton.setImage(UIImage(systemName: "bell", withConfiguration: symbolConfig), for: .normal)
        bellButton.tintColor = .label
        bellButton.translatesAutoresizingMaskIntoConstraints = false
        bellButton.accessibilityLabel = "Приглашения"
        bellButton.addTarget(self, action: #selector(didTapBell), for: .touchUpInside)
        bellButton.clipsToBounds = false
        NSLayoutConstraint.activate([
            bellButton.widthAnchor.constraint(equalToConstant: 44),
            bellButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        bellBadgeView.addSubview(bellBadgeLabel)
        bellButton.addSubview(bellBadgeView)

        NSLayoutConstraint.activate([
            bellBadgeLabel.topAnchor.constraint(equalTo: bellBadgeView.topAnchor, constant: 2),
            bellBadgeLabel.bottomAnchor.constraint(equalTo: bellBadgeView.bottomAnchor, constant: -2),
            bellBadgeLabel.leadingAnchor.constraint(equalTo: bellBadgeView.leadingAnchor, constant: 5),
            bellBadgeLabel.trailingAnchor.constraint(equalTo: bellBadgeView.trailingAnchor, constant: -5),

            bellBadgeView.heightAnchor.constraint(equalToConstant: 20),
            bellBadgeView.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            bellBadgeView.topAnchor.constraint(equalTo: bellButton.topAnchor, constant: 0),
            bellBadgeView.trailingAnchor.constraint(equalTo: bellButton.trailingAnchor, constant: -2.5)
        ])

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(bellButton)

        NSLayoutConstraint.activate([
                backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                backButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

                titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
                titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

                bellButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                bellButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
            ])
    }
    
    private func setupAddButton() {
        let button = UIButton(type: .system)
        button.setTitle("Добавить компанию", for: .normal)
        button.setTitleColor(UIColor(hex: "#7079FB"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor(hex: "#7079FB")?.withAlphaComponent(0.1)
        button.layer.cornerRadius = 14
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(addCompanyTapped), for: .touchUpInside)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            button.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc private func addCompanyTapped() {
        let createVC = CreateGroupAssembly.assembly()
        presentFromGroupList(createVC)
    }

    @objc private func didTapBell() {
        presentFromGroupList(InvitationAssembly.assembly())
    }

    @objc private func backTapped() {
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(false, animated: true)
        navigationController?.popViewController(animated: true)
    }

    private func loadCompanies() {
        guard let tokenData = keychain.getData(forKey: "auth.token"),
              let token = String(data: tokenData, encoding: .utf8) else { return }

        Task {
            do {
                let result = try await worker.GetCompaniesList(token: token)
                await MainActor.run {
                    self.companies = result
                    self.tableView.reloadData()
                }
            } catch {
                print("Failed to load companies: \(error)")
            }
        }
    }

    private func refreshInvitationBadge() {
        Task {
            do {
                let invitations = try await invitationWorker.fetchInvitations()
                let pending = invitations.filter { $0.status == "pending" }
                await MainActor.run {
                    self.setNotificationsBadge(count: pending.count)
                }
            } catch {
                print("Failed to fetch invitations: \(error)")
            }
        }
    }

    private func setNotificationsBadge(count: Int) {
        if count <= 0 {
            bellBadgeView.isHidden = true
        } else {
            bellBadgeView.isHidden = false
            bellBadgeLabel.text = count > 99 ? "99+" : "\(count)"
        }
    }

    private func presentFromGroupList(_ viewController: UIViewController) {
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(dismissPresentedFlow)
        )
        viewController.navigationItem.leftBarButtonItem?.tintColor = UIColor(hex: "#7079FB")
        viewController.navigationItem.backButtonDisplayMode = .minimal

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

    @objc private func dismissPresentedFlow() {
        presentedViewController?.dismiss(animated: true)
    }
}

extension GroupListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        companies.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GroupCell", for: indexPath)
        let company = companies[indexPath.row]
        let avatarView: UIView = {
            let v = UIView()
            v.layer.cornerRadius = 20
            v.backgroundColor = UIColor.systemGray5
            v.translatesAutoresizingMaskIntoConstraints = false
            return v
        }()
        var content = cell.defaultContentConfiguration()
        content.text = company.name
      content.image = UIImage(systemName: "person.3.fill")
 
        content.imageProperties.tintColor = UIColor(hex: "#7079FB")
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

extension GroupListViewController: UITableViewDelegate {
    // In GroupListViewController's didSelectRowAt:
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let company = companies[indexPath.row]

        // Replace the entire tab bar with a new one for the selected company
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let newTabBar = MainTabBarController(selectedCompany: company)
        newTabBar.selectedIndex = 0 // stay on the friends tab after switching
        (tabBarController as? MainTabBarController)?.setCustomTabBarHidden(false, animated: false)

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = newTabBar
        }
    }
}
