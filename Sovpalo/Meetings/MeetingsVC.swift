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

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 100, right: 0)
        return table
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

    private var meetings: [Meeting] = [
        Meeting(
            id: 1,
            title: "Парк Горького",
            dateText: "6.03",
            timeText: "18:00-21:00",
            cityText: "Москва",
            addressText: "м Октябрьская",
            descriptionText: "Вечерняя прогулка и общение",
            attendeesGoing: ["Маша Иванова (Организатор)", "Маша Иванова"],
            attendeesNotGoing: ["Маша Иванова", "Маша Иванова"],
            organizerName: "Маша Иванова",
            responseStatus: .none,
            isArchived: false
        ),
        Meeting(
            id: 2,
            title: "Скаладром ЦСКА",
            dateText: "10.03",
            timeText: "14:00-16:00",
            cityText: "Москва",
            addressText: "3-я песчанная улица 2с1",
            descriptionText: "Большой скаладром с двухэтажным боулдером и трудностью",
            attendeesGoing: ["Маша Иванова (Организатор)", "Маша Иванова"],
            attendeesNotGoing: [],
            organizerName: "Маша Иванова",
            responseStatus: .createdByMe,
            isArchived: false
        ),
        Meeting(
            id: 3,
            title: "Красная площадь",
            dateText: "27.03",
            timeText: "11:00-15:00",
            cityText: "Москва",
            addressText: "Красная площадь",
            descriptionText: "Просто прогулка",
            attendeesGoing: ["Маша Иванова"],
            attendeesNotGoing: [],
            organizerName: "Маша Иванова",
            responseStatus: .createdByMe,
            isArchived: false
        ),
        Meeting(
            id: 4,
            title: "Парк Революции",
            dateText: "6.12",
            timeText: "18:00-21:00",
            cityText: "Москва",
            addressText: "м Октябрьская",
            descriptionText: nil,
            attendeesGoing: ["Маша Иванова"],
            attendeesNotGoing: [],
            organizerName: "Маша Иванова",
            responseStatus: .going,
            isArchived: true
        ),
        Meeting(
            id: 5,
            title: "Скаладром ЦСКА",
            dateText: "12.01",
            timeText: "14:00-16:00",
            cityText: "Москва",
            addressText: "3-я песчанная улица 2с1",
            descriptionText: nil,
            attendeesGoing: ["Маша Иванова"],
            attendeesNotGoing: [],
            organizerName: "Маша Иванова",
            responseStatus: .notGoing,
            isArchived: true
        )
    ]

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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func setupLayout() {
        let segmentContainer = UIView()

        upcomingUnderline.backgroundColor = .label
        archiveUnderline.backgroundColor = .label
        upcomingUnderline.layer.cornerRadius = 1
        archiveUnderline.layer.cornerRadius = 1

        [titleLabel, segmentContainer, tableView, floatingButton].forEach {
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

            floatingButton.widthAnchor.constraint(equalToConstant: 66),
            floatingButton.heightAnchor.constraint(equalToConstant: 66),
            floatingButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            floatingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    private func setupTable() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MeetingCell.self, forCellReuseIdentifier: MeetingCell.identifier)
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
            self?.updateMeetingStatus(id: meeting.id, status: .going)
        }

        cell.onNotGoingTap = { [weak self] in
            self?.updateMeetingStatus(id: meeting.id, status: .notGoing)
        }

        cell.onCancelTap = { [weak self] in
            self?.updateMeetingStatus(id: meeting.id, status: .none)
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        let meeting = filteredMeetings[indexPath.row]
//        let vc = MeetingDetailsVC(meeting: meeting)
//        navigationController?.pushViewController(vc, animated: true)
        print("cell")
    }
}

private extension MeetingsVC {
    func updateMeetingStatus(id: Int, status: MeetingResponseStatus) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }
        meetings[index].responseStatus = status
        tableView.reloadData()
    }
}

