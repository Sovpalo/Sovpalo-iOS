//
//  MeetingsVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import UIKit

final class MeetingsVC: UIViewController {
    var interactor: MeetingsBusinessLogic?
    var company: Company?
    var companyTitle: String = "Клуб друзей"

    private enum Segment: Int {
        case upcoming = 0
        case archive = 1
    }

    private var selectedSegment: Segment = .upcoming {
        didSet { reloadData() }
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = UIColor(hex: "#7079FB")
        label.textAlignment = .center
        return label
    }()

    private let upcomingButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Новые встречи", for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        return button
    }()

    private let archiveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Архив встреч", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        return button
    }()

    private let upcomingUnderline = UIView()
    private let archiveUnderline = UIView()

    private let offlineBadgeLabel: UILabel = {
        let label = UILabel()
        label.text = "offline"
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor(hex: "#6E73F4")
        label.textAlignment = .center
        label.backgroundColor = UIColor(hex: "#F6F77A")
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.isHidden = true
        return label
    }()

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 100, right: 0)
        return table
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = UIColor(hex: "#7079FB")
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "На данный момент у вас нет встреч"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let floatingButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(hex: "#6E73F4")
        button.tintColor = UIColor(hex: "#F6F77A")
        button.setImage(UIImage(systemName: "sparkle"), for: .normal)
        button.layer.cornerRadius = 33
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var meetings: [Meeting] = []
    private var isLoadingMeetings = false
    private var offlineModeTask: Task<Void, Never>?
    
    private var filteredMeetings: [Meeting] {
        switch selectedSegment {
        case .upcoming:
            return meetings.filter { !$0.isArchived }
        case .archive:
            return meetings.filter { $0.isArchived }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        titleLabel.text = companyTitle
        setupLayout()
        setupTable()
        setupActions()
        updateSegmentUI()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMeetingDeleted),
            name: .meetingDeleted,
            object: nil
        )
    }
    @objc private func handleMeetingDeleted() {
        print(">>> MeetingsVC received meetingDeleted notification")
        interactor?.loadMeetings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        interactor?.loadMeetings()
    }
    
    func applyMeetings(_ meetings: [Meeting]) {
        print("APPLY MEETINGS COUNT =", meetings.count)
        self.meetings = meetings
        setLoading(false)
        reloadData()
    }

    func setOfflineMode(_ isOffline: Bool) {
        if isOffline {
            guard offlineModeTask == nil else { return }
            offlineModeTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.offlineBadgeLabel.isHidden = false
                }
            }
        } else {
            offlineModeTask?.cancel()
            offlineModeTask = nil
            offlineBadgeLabel.isHidden = true
        }
    }

    func setLoading(_ isLoading: Bool) {
        isLoadingMeetings = isLoading
        if isLoading {
            emptyStateLabel.isHidden = true
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
            updateEmptyState()
        }
    }

    func applyAttendanceStatus(eventId: Int, status: MeetingResponseStatus, currentUsername: String?) {
        updateMeetingAttendance(id: eventId, status: status, currentUsername: currentUsername)
    }

    func applyAttendanceSummary(
        eventId: Int,
        status: MeetingResponseStatus,
        attendeesGoing: [String],
        attendeesNotGoing: [String],
        currentUsername: String?
    ) {
        updateMeetingAttendance(
            id: eventId,
            status: status,
            attendeesGoing: attendeesGoing,
            attendeesNotGoing: attendeesNotGoing,
            currentUsername: currentUsername
        )
    }

    func showError(message: String) {
        setLoading(false)
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }

    private func setupLayout() {
        let segmentContainer = UIView()

        upcomingUnderline.backgroundColor = .label
        archiveUnderline.backgroundColor = .label
        upcomingUnderline.layer.cornerRadius = 1
        archiveUnderline.layer.cornerRadius = 1

        [titleLabel, offlineBadgeLabel, segmentContainer, tableView, emptyStateLabel, loadingIndicator, floatingButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        [upcomingButton, archiveButton, upcomingUnderline, archiveUnderline].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            segmentContainer.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            offlineBadgeLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            offlineBadgeLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            offlineBadgeLabel.heightAnchor.constraint(equalToConstant: 20),
            offlineBadgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),

            segmentContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            segmentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            segmentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            segmentContainer.heightAnchor.constraint(equalToConstant: 34),

            upcomingButton.leadingAnchor.constraint(equalTo: segmentContainer.leadingAnchor),
            upcomingButton.topAnchor.constraint(equalTo: segmentContainer.topAnchor),
            upcomingButton.bottomAnchor.constraint(equalTo: segmentContainer.bottomAnchor),

            archiveButton.trailingAnchor.constraint(equalTo: segmentContainer.trailingAnchor),
            archiveButton.topAnchor.constraint(equalTo: segmentContainer.topAnchor),
            archiveButton.bottomAnchor.constraint(equalTo: segmentContainer.bottomAnchor),

            upcomingUnderline.topAnchor.constraint(equalTo: upcomingButton.bottomAnchor, constant: -2),
            upcomingUnderline.leadingAnchor.constraint(equalTo: upcomingButton.leadingAnchor),
            upcomingUnderline.trailingAnchor.constraint(equalTo: upcomingButton.trailingAnchor),
            upcomingUnderline.heightAnchor.constraint(equalToConstant: 2),

            archiveUnderline.topAnchor.constraint(equalTo: archiveButton.bottomAnchor, constant: -2),
            archiveUnderline.leadingAnchor.constraint(equalTo: archiveButton.leadingAnchor),
            archiveUnderline.trailingAnchor.constraint(equalTo: archiveButton.trailingAnchor),
            archiveUnderline.heightAnchor.constraint(equalToConstant: 2),

            tableView.topAnchor.constraint(equalTo: segmentContainer.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -32),
            emptyStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -32),

            floatingButton.widthAnchor.constraint(equalToConstant: 66),
            floatingButton.heightAnchor.constraint(equalToConstant: 66),
            floatingButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            floatingButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -AppLayout.floatingButtonBottomOffset
            )
        ])
    }

    private func setupTable() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MeetingCell.self, forCellReuseIdentifier: MeetingCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 220
    }

    private func setupActions() {
        upcomingButton.addTarget(self, action: #selector(didTapUpcoming), for: .touchUpInside)
        archiveButton.addTarget(self, action: #selector(didTapArchive), for: .touchUpInside)
        floatingButton.addTarget(self, action: #selector(didTapCreateMeeting), for: .touchUpInside)
    }

    private func updateSegmentUI() {
        let isUpcoming = selectedSegment == .upcoming

        upcomingButton.setTitleColor(isUpcoming ? .label : .secondaryLabel, for: .normal)
        archiveButton.setTitleColor(isUpcoming ? .secondaryLabel : .label, for: .normal)

        upcomingUnderline.isHidden = !isUpcoming
        archiveUnderline.isHidden = isUpcoming
    }

    private func reloadData() {
        updateSegmentUI()
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        emptyStateLabel.isHidden = isLoadingMeetings || !filteredMeetings.isEmpty
    }

    @objc private func didTapUpcoming() {
        selectedSegment = .upcoming
    }

    @objc private func didTapArchive() {
        selectedSegment = .archive
    }

    @objc private func didTapCreateMeeting() {
        guard let company else { return }
        let vc = CreateMeetingAssembly.assembly(company: company)
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension MeetingsVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredMeetings.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let meeting = filteredMeetings[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MeetingCell.identifier, for: indexPath) as? MeetingCell else {
            return UITableViewCell()
        }

        cell.configure(with: meeting)

        cell.onGoingTap = { [weak self] in
            self?.interactor?.setAttendance(eventId: meeting.id, status: .going)
        }

        cell.onNotGoingTap = { [weak self] in
            self?.interactor?.setAttendance(eventId: meeting.id, status: .notGoing)
        }

        cell.onCancelTap = { [weak self] in
            self?.interactor?.setAttendance(eventId: meeting.id, status: .none)
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let meeting = filteredMeetings[indexPath.row]
        interactor?.selectMeeting(meeting)
    }
}

private extension MeetingsVC {
    func updateMeetingAttendance(
        id: Int,
        status: MeetingResponseStatus,
        attendeesGoing: [String]? = nil,
        attendeesNotGoing: [String]? = nil,
        currentUsername: String? = nil
    ) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }
        let currentMeeting = meetings[index]
        let resolvedAttendees = resolveAttendees(
            currentMeeting: currentMeeting,
            status: status,
            attendeesGoing: attendeesGoing,
            attendeesNotGoing: attendeesNotGoing,
            currentUsername: currentUsername
        )
        let updatedMeeting = Meeting(
            id: currentMeeting.id,
            title: currentMeeting.title,
            dateText: currentMeeting.dateText,
            timeText: currentMeeting.timeText,
            cityText: currentMeeting.cityText,
            addressText: currentMeeting.addressText,
            descriptionText: currentMeeting.descriptionText,
            photoURL: currentMeeting.photoURL,
            attendeesGoing: resolvedAttendees.going,
            attendeesNotGoing: resolvedAttendees.notGoing,
            organizerName: currentMeeting.organizerName,
            responseStatus: status,
            isArchived: currentMeeting.isArchived
        )
        meetings[index] = updatedMeeting

        guard let visibleRow = filteredMeetings.firstIndex(where: { $0.id == id }) else {
            reloadData()
            return
        }

        let indexPath = IndexPath(row: visibleRow, section: 0)

        guard tableView.numberOfSections > 0,
              visibleRow < tableView.numberOfRows(inSection: 0) else {
            reloadData()
            return
        }

        UIView.performWithoutAnimation {
            if let cell = tableView.cellForRow(at: indexPath) as? MeetingCell {
                cell.applyAttendance(
                    attendeesGoing: updatedMeeting.attendeesGoing,
                    attendeesNotGoing: updatedMeeting.attendeesNotGoing,
                    status: updatedMeeting.responseStatus,
                    archived: updatedMeeting.isArchived
                )
            }
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }

    func resolveAttendees(
        currentMeeting: Meeting,
        status: MeetingResponseStatus,
        attendeesGoing: [String]?,
        attendeesNotGoing: [String]?,
        currentUsername: String?
    ) -> (going: [String], notGoing: [String]) {
        var going = attendeesGoing ?? currentMeeting.attendeesGoing
        var notGoing = attendeesNotGoing ?? currentMeeting.attendeesNotGoing

        guard let currentUsername = currentUsername?.trimmingCharacters(in: .whitespacesAndNewlines),
              !currentUsername.isEmpty else {
            return (going, notGoing)
        }

        let normalizedUsername = currentUsername.lowercased()
        going.removeAll { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedUsername }
        notGoing.removeAll { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedUsername }

        switch status {
        case .going:
            going.append(currentUsername)
        case .notGoing:
            notGoing.append(currentUsername)
        case .none, .createdByMe:
            break
        }

        return (going, notGoing)
    }
}
