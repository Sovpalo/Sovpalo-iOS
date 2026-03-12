//
//  MeetingsVC.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import UIKit
import SwiftUI

final class MeetingsVC: UIViewController {
    var interactor: MeetingsBusinessLogic?
    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Новые встречи", "Архив встреч"])
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    private let floatingButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.layer.cornerRadius = 28
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var meetings: [Meeting] = [
        Meeting(id: 1, title: "Встреча с командой", date: Date().addingTimeInterval(3600), place: "Кафе Central", address: "ул. Ленина, 10", isAttending: false, isPast: false),
        Meeting(id: 2, title: "Презентация проекта", date: Date().addingTimeInterval(86400 * 3), place: "Офис", address: "пр. Мира, 25", isAttending: true, isPast: false),
        Meeting(id: 3, title: "Встреча с клиентом", date: Date().addingTimeInterval(-86400 * 2), place: "Конференц-зал", address: "ул. Гагарина, 7", isAttending: false, isPast: true)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        view.addSubview(floatingButton)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            segmentedControl.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            floatingButton.widthAnchor.constraint(equalToConstant: 56),
            floatingButton.heightAnchor.constraint(equalToConstant: 56),
            floatingButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            floatingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(MeetingCell.self, forCellReuseIdentifier: MeetingCell.identifier)
    }
}
extension MeetingsVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       meetings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let meeting = meetings[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MeetingCell.identifier, for: indexPath) as? MeetingCell else {
            return UITableViewCell()
        }
        cell.configure(with: meeting)
        return cell
    }
}


