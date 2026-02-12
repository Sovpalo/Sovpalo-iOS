////
////  MainScreenVC.swift
////  Sovpalo
////
////  Created by Jovana on 28.1.26.
////
//
//import UIKit
//
//final class MainScreenViewController: UIViewController, MainScreenDisplayLogic {
//    
//    var interactor: MainScreenBusinessLogic?
//    var router: (MainScreenRoutingLogic & AnyObject)?
//    
//    private let screenView = MainScreenView(presenter: MainScreenPresenter, interactor: MainScreenInteractor)
//    
//    private var dates: [MainScreen.DateItemVM] = []
//    private var selectedDateId: String = ""
//    
//    override func loadView() {
//        view = screenView
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        // If you have your own navigation setup, adjust here
//        navigationItem.title = ""
//        view.backgroundColor = .systemBackground
//        
//        screenView.datesCollection.dataSource = self
//        screenView.datesCollection.delegate = self
//        
//        interactor?.load(.init())
//    }
//    
//    // MARK: - Display
//    func displayLoad(_ viewModel: MainScreen.Load.ViewModel) {
//        dates = viewModel.dates
//        selectedDateId = viewModel.selectedDateId
//        
//        screenView.applyTitles(
//            today: viewModel.todayTitle,
//            freeLeft: viewModel.freeTimeTitleLeft,
//            freeRight: viewModel.freeTimeTitleRight
//        )
//        screenView.applyMeetings(viewModel.meetings)
//        screenView.applyFriends(viewModel.friends, hours: viewModel.hours)
//        screenView.applyBestTime(title: viewModel.bestTimeTitle, value: viewModel.bestTimeValue)
//        
//        screenView.datesCollection.reloadData()
//        scrollToSelectedDateIfNeeded()
//    }
//    
//    func displaySelectDate(_ viewModel: MainScreen.SelectDate.ViewModel) {
//        selectedDateId = viewModel.selectedDateId
//        screenView.applyMeetings(viewModel.meetings)
//        screenView.applyBestTime(title: "Наиболее удобное время:", value: viewModel.bestTimeValue)
//        screenView.datesCollection.reloadData()
//        scrollToSelectedDateIfNeeded()
//    }
//    
//    private func scrollToSelectedDateIfNeeded() {
//        guard let idx = dates.firstIndex(where: { $0.id == selectedDateId }) else { return }
//        screenView.datesCollection.scrollToItem(at: IndexPath(item: idx, section: 0), at: .centeredHorizontally, animated: true)
//    }
//}
//
//extension MainScreenViewController: UICollectionViewDataSource, UICollectionViewDelegate {
//    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        dates.count
//    }
//    
//    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        guard
//            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DatePillCell.reuseId, for: indexPath) as? DatePillCell
//        else { return UICollectionViewCell() }
//        
//        let item = dates[indexPath.item]
//        cell.configure(
//            weekday: item.weekdayShort,
//            day: item.dayNumber,
//            selected: item.id == selectedDateId,
//            isToday: item.isToday
//        )
//        return cell
//    }
//    
//    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        let item = dates[indexPath.item]
//        interactor?.selectDate(.init(dateId: item.id))
//    }
//}
