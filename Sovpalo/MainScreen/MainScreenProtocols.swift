//
//  MainScreenProtocols.swift
//  Sovpalo
//
//  Created by Jovana on 28.1.26.
//

import UIKit

// MARK: - View
protocol MainScreenDisplayLogic: AnyObject {
    func displayLoad(_ viewModel: MainScreen.Load.ViewModel)
    func displaySelectDate(_ viewModel: MainScreen.SelectDate.ViewModel)
}

// MARK: - Interactor
protocol MainScreenBusinessLogic {
    func load(_ request: MainScreen.Load.Request)
    func selectDate(_ request: MainScreen.SelectDate.Request)
}

// MARK: - Presenter
protocol MainScreenPresentationLogic {
    func presentLoad(_ response: MainScreen.Load.Response)
    func presentSelectDate(_ response: MainScreen.SelectDate.Response)
}

// MARK: - Router
protocol MainScreenRoutingLogic { }

// MARK: - Data Passing (can stay empty for now)
protocol MainScreenDataPassing { }
