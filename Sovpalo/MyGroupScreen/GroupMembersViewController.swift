//  GroupMembersViewController.swift
//  Sovpalo

import UIKit

protocol GroupMembersDisplayLogic: AnyObject {
    func displayMembers(_ members: [GroupMembersModels.MemberViewModel])
    func displayError(_ message: String)
}

final class GroupMembersViewController: UIViewController {

    var interactor: GroupMembersBusinessLogic?
    private let company: Company
    private let worker: CompanyMembersWorkerProtocol
    private let settingsButton = UIButton(type: .system)

    private var members: [GroupMembersModels.MemberViewModel] = []

    // MARK: - UI

    private lazy var groupNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        return label
    }()

    private lazy var membersCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var avatarView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 28
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.backgroundColor = .systemGroupedBackground
        tv.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        tv.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
        tv.register(MemberCell.self, forCellReuseIdentifier: MemberCell.reuseID)
        tv.register(AddMemberCell.self, forCellReuseIdentifier: AddMemberCell.reuseID)
        tv.dataSource = self
        tv.delegate = self
        tv.rowHeight = 56
        if #available(iOS 15.0, *) {
            tv.sectionHeaderTopPadding = 0
        }
        tv.contentInset = UIEdgeInsets(top: -36, left: 0, bottom: 0, right: 0)
        return tv
    }()

    private lazy var myGroupsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Мои группы  →", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(hex: "#7079FB")
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 24
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(myGroupsTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Init

    init(company: Company) {
        self.company = company
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.isHidden = true
        edgesForExtendedLayout = .all
        extendedLayoutIncludesOpaqueBars = true
        setupHeader()
        setupTableView()
        groupNameLabel.text = company.name
        interactor?.loadMembers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: - Setup

    private func setupHeader() {
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 14
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let avatarLabel = UILabel()
        avatarLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        avatarLabel.textColor = .secondaryLabel
        avatarLabel.text = String(company.name.prefix(1)).uppercased()
        avatarLabel.textAlignment = .center
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(avatarLabel)
        NSLayoutConstraint.activate([
            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor)
        ])

        let textStack = UIStackView(arrangedSubviews: [groupNameLabel, membersCountLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        // Settings button
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = .label
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        headerStack.addArrangedSubview(avatarView)
        headerStack.addArrangedSubview(textStack)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(settingsButton)

        NSLayoutConstraint.activate([
            avatarView.widthAnchor.constraint(equalToConstant: 56),
            avatarView.heightAnchor.constraint(equalToConstant: 56)
        ])

        view.addSubview(headerStack)
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func setupTableView() {
        view.addSubview(tableView)
        view.addSubview(myGroupsButton)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 76),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: myGroupsButton.topAnchor, constant: -12),

            myGroupsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            myGroupsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            myGroupsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            myGroupsButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    // MARK: - Actions

    @objc private func myGroupsTapped() {
        let groupListVC = GroupListViewController()
        navigationController?.pushViewController(groupListVC, animated: true)
    }
}

// MARK: - DisplayLogic

extension GroupMembersViewController: GroupMembersDisplayLogic {
    func displayMembers(_ members: [GroupMembersModels.MemberViewModel]) {
        self.members = members
        membersCountLabel.text = "\(members.count) друзей"
        tableView.reloadData()
    }

    func displayError(_ message: String) {
        print("GroupMembers error: \(message)")
    }

    @objc private func settingsTapped() {
        let settingsVC = SettingsAssembly.assembly()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension GroupMembersViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        members.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            return tableView.dequeueReusableCell(withIdentifier: AddMemberCell.reuseID, for: indexPath) as! AddMemberCell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: MemberCell.reuseID, for: indexPath) as! MemberCell
        cell.configure(with: members[indexPath.row - 1])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension GroupMembersViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 {
            let inviteVC = InviteUserAssembly.assembly(companyId: Int(company.id))
            inviteVC.shouldPopOnDone = true
            navigationController?.pushViewController(inviteVC, animated: true)
        }
    }
}
