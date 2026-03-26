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
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        loadCompanies()
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

    @objc private func backTapped() {
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
//        avatartext = String(member.username.prefix(1)).uppercased()
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

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = newTabBar
        }
    }
}
