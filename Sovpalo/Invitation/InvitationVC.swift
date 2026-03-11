//
//  InvitationVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import UIKit

final class InvitationVC: UIViewController {
    // MARK: - Public
    var interactor: InvitationBusinessLogic?

    // MARK: - UI
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Уведомления"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 120
        tv.keyboardDismissMode = .onDrag
        return tv
    }()

    // MARK: - Data
    private var invitations: [Invitation] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupLayout()
        setupTable()
        loadMockInvitations()
    }

    // MARK: - Setup
    private func setupLayout() {
        view.addSubview(titleLabel)
        view.addSubview(tableView)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            titleLabel.centerXAnchor.constraint(equalTo: guide.centerXAnchor),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(InvitationCell.self, forCellReuseIdentifier: InvitationCell.reuseID)
        tableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 16, right: 0)
    }

    private func loadMockInvitations() {
        // Моковые данные. В реальной реализации сюда придут данные из интерактора/сервиса
        invitations = [
            Invitation(id: 1, companyId: 10, companyName: "Цыгани", invitedByUsername: "jovana", status: "pending", createdAt: "2026-03-11T15:40:41.580Z"),
            Invitation(id: 2, companyId: 11, companyName: "Ботаем", invitedByUsername: "alex", status: "pending", createdAt: "2026-03-10T09:20:00.000Z"),
            Invitation(id: 3, companyId: 12, companyName: "Скалазолы", invitedByUsername: "maria", status: "pending", createdAt: "2026-03-09T21:05:12.000Z")
        ]
        tableView.reloadData()
    }
}
// MARK: - UITableViewDataSource & UITableViewDelegate
extension InvitationVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return invitations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: InvitationCell.reuseID, for: indexPath) as? InvitationCell else {
            return UITableViewCell()
        }
        let item = invitations[indexPath.row]
        cell.configure(with: item)

        // Обработчики действий
        cell.onAccept = { [weak self] in
            self?.handleAction(.accept, at: indexPath)
        }
        cell.onDecline = { [weak self] in
            self?.handleAction(.decline, at: indexPath)
        }
        return cell
    }
}

// MARK: - Actions handling
private extension InvitationVC {
    enum InvitationAction { case accept, decline }

    func handleAction(_ action: InvitationAction, at indexPath: IndexPath) {
        guard invitations.indices.contains(indexPath.row) else { return }
        let item = invitations[indexPath.row]
        switch action {
        case .accept:
            print("Accept invitation id: \(item.id) for company: \(item.companyName)")
        case .decline:
            print("Decline invitation id: \(item.id) for company: \(item.companyName)")
        }

        // Удаляем строку с анимацией (моковое поведение)
        invitations.remove(at: indexPath.row)
        tableView.performBatchUpdates({
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }, completion: { [weak self] _ in
            self?.tableView.reloadData()
        })
    }
}



