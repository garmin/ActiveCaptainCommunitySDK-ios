/*------------------------------------------------------------------------------
Copyright 2021 Garmin Ltd. or its subsidiaries.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
------------------------------------------------------------------------------*/

import ActiveCaptainCommunitySDK
import os
import UIKit

extension MapIcon {
    var filename: String {
        switch self {
        case .unknown:
            return "stacked_points_icon.png"
        case .anchorage:
            return "anchorage_icon.png"
        case .hazard:
            return "hazard_icon.png"
        case .marina:
            return "marina_icon.png"
        case .boatRamp:
            return "boatramp_icon.png"
        case .business:
            return "shop_icon.png"
        case .inlet:
            return "inlet_icon.png"
        case .bridge:
            return "bridge_icon.png"
        case .lock:
            return "lock_icon.png"
        case .dam:
            return "dam_icon.png"
        case .ferry:
            return "ferry_icon.png"
        case .anchorageSponsor:
            return "anchorage_sponsored_icon.png"
        case .businessSponsor:
            return "shop_sponsored_icon.png"
        case .marinaSponsor:
            return "marina_sponsored_icon.png"
        @unknown default:
            return "stacked_points_icon.png"
        }
    }
}

class SearchViewController: UITableViewController, UISearchResultsUpdating {
    var searchMarkers = [SearchMarker]()
    lazy var searchResultsController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.searchBar.sizeToFit()

        tableView.tableHeaderView = controller.searchBar

        return controller
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchResultsController.searchBar.becomeFirstResponder()
    }

    override func numberOfSections(in view:UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section:Int) -> Int {
        return searchMarkers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if indexPath.row < searchMarkers.count {
            cell.textLabel?.text = searchMarkers[indexPath.row].name
            let data = ActiveCaptainManager.instance.loadImage(searchMarkers[indexPath.row].mapIcon.filename)
            if let data = data {
                cell.imageView?.image = UIImage(data: data)
            } else {
                cell.imageView?.image = nil
            }
        } else {
            cell.textLabel?.text = nil
            cell.imageView?.image = nil
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let userInfo = [MarkerIdUserInfoKey: Int64(searchMarkers[indexPath.row].markerId)]
        NotificationCenter.default.post(name: NotifyType.markerSelected.name, object:nil, userInfo:userInfo)

        self.dismiss(animated:true)
    }

    func updateSearchResults(for searchController: UISearchController) {
        if searchController.searchBar.text!.count > ActiveCaptainConfiguration.markerMinSearchLength {
            searchMarkers = ActiveCaptainManager.instance.database.getSearchMarkers(byName: searchController.searchBar.text!, south:-90.0, west:-180.0, north: 90.0, east:180.0, maxResultCount:Int32(ActiveCaptainConfiguration.markerMaxSearchResults))
        }

        self.tableView.reloadData()
    }
}
