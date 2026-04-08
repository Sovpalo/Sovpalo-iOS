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

        view.addSubview(backButton)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
                backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                backButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

                titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
                titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
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
        navigationController?.pushViewController(createVC, animated: true)
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
