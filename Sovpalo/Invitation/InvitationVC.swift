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
    private var pendingInvitationIDs: Set<Int> = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupLayout()
        setupTable()
        loadInvitations()
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

    private func loadInvitations() {
        interactor?.loadInvitations(request: InvitationModels.Load.Request())
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension InvitationVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        invitations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: InvitationCell.reuseID, for: indexPath) as? InvitationCell else {
            return UITableViewCell()
        }

        let item = invitations[indexPath.row]
        cell.configure(with: item)
        cell.setButtonsEnabled(!pendingInvitationIDs.contains(item.id))

        cell.onAccept = { [weak self] in
            self?.handleAction(.accept, at: indexPath)
        }

        cell.onDecline = { [weak self] in
            self?.handleAction(.decline, at: indexPath)
        }

        return cell
    }
}

// MARK: - Display logic
extension InvitationVC {
    func displayInvitations(_ viewModel: InvitationModels.Load.ViewModel) {
        invitations = viewModel.invitations
        tableView.reloadData()
    }

    func displayAcceptedInvitation(_ viewModel: InvitationModels.Accept.ViewModel) {
        pendingInvitationIDs.remove(viewModel.invitationId)
        removeInvitationFromTable(id: viewModel.invitationId)
    }

    func displayDeclinedInvitation(_ viewModel: InvitationModels.Decline.ViewModel) {
        pendingInvitationIDs.remove(viewModel.invitationId)
        removeInvitationFromTable(id: viewModel.invitationId)
    }

    func displayError(_ viewModel: InvitationModels.Error.ViewModel) {
        if let invitationId = viewModel.invitationId {
            pendingInvitationIDs.remove(invitationId)
            reloadRowIfNeeded(for: invitationId)
        }

        let alert = UIAlertController(
            title: "Ошибка",
            message: viewModel.message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Actions handling
private extension InvitationVC {
    enum InvitationAction {
        case accept
        case decline
    }

    func handleAction(_ action: InvitationAction, at indexPath: IndexPath) {
        guard invitations.indices.contains(indexPath.row) else { return }
        let item = invitations[indexPath.row]

        guard !pendingInvitationIDs.contains(item.id) else { return }

        pendingInvitationIDs.insert(item.id)
        reloadRowIfNeeded(for: item.id)

        switch action {
        case .accept:
            interactor?.acceptInvitation(
                request: InvitationModels.Accept.Request(invitationId: item.id)
            )
        case .decline:
            interactor?.declineInvitation(
                request: InvitationModels.Decline.Request(invitationId: item.id)
            )
        }
    }
    
    func reloadRowIfNeeded(for invitationId: Int) {
        guard let row = invitations.firstIndex(where: { $0.id == invitationId }) else { return }
        let indexPath = IndexPath(row: row, section: 0)

        guard tableView.numberOfSections > 0,
              row < tableView.numberOfRows(inSection: 0) else { return }

        tableView.reloadRows(at: [indexPath], with: .none)
    }

    func removeInvitationFromTable(id: Int) {
        guard let index = invitations.firstIndex(where: { $0.id == id }) else { return }
        invitations.remove(at: index)

        let indexPath = IndexPath(row: index, section: 0)
        tableView.performBatchUpdates({
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }, completion: { [weak self] _ in
            self?.tableView.reloadData()
        })
    }
}
