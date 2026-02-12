//
//  MainScreenModels.swift
//  Sovpalo
//
//  Created by Jovana on 28.1.26.
//

import Foundation

enum MainScreen {
    
    // MARK: - Use cases
    enum Load {
        struct Request { }
        
        struct Response {
            let dates: [DateItem]
            let selectedDateId: String
            let todayMeetings: [Meeting]
            let groupTitle: String
            let friends: [Friend]
            let bestTimeText: String
        }
        
        struct ViewModel {
            let dates: [DateItemVM]
            let selectedDateId: String
            let todayTitle: String
            let meetings: [MeetingVM]
            let freeTimeTitleLeft: String
            let freeTimeTitleRight: String
            let friends: [FriendVM]
            let hours: [String]
            let bestTimeTitle: String
            let bestTimeValue: String
        }
    }
    
    enum SelectDate {
        struct Request { let dateId: String }
        struct Response {
            let selectedDateId: String
            let todayMeetings: [Meeting]
            let bestTimeText: String
        }
        struct ViewModel {
            let selectedDateId: String
            let meetings: [MeetingVM]
            let bestTimeValue: String
        }
    }
    
    // MARK: - Domain
    struct DateItem {
        let id: String          // e.g. "2026-01-25"
        let weekdayShort: String // "Вт"
        let dayNumber: String    // "25"
        let isToday: Bool
    }
    
    struct Meeting {
        let timeText: String     // "14:00"
        let title: String        // "Скаладром ЦСКА"
        let locationText: String // "Москва, 3-я песчаная улица 2с1"
    }
    
    struct Friend {
        let id: String
        let name: String         // "Алена"
        let avatarLetter: String // "А"
        let isMe: Bool
    }
    
    // MARK: - ViewModels
    struct DateItemVM {
        let id: String
        let weekdayShort: String
        let dayNumber: String
        let isToday: Bool
    }
    
    struct MeetingVM {
        let timeAndTitle: String // "14:00 — Скаладром ЦСКА"
        let locationText: String
    }
    
    struct FriendVM {
        let id: String
        let title: String        // "Я" / "Алена"
        let avatarText: String   // "Я" / "А"
        let isMe: Bool
    }
}
