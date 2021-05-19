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
            return "H_UX_Icon_Acdb_stacked_points.bmp"
        case .anchorage:
            return "H_UX_Icon_Acdb_anchorage.bmp"
        case .hazard:
            return "H_UX_Icon_Acdb_hazard.bmp"
        case .marina:
            return "H_UX_Icon_Acdb_marina.bmp"
        case .boatRamp:
            return "H_UX_Icon_Acdb_lk_boatramp.bmp"
        case .business:
            return "H_UX_Icon_Acdb_lk_shop.bmp"
        case .inlet:
            return "H_UX_Icon_Acdb_lk_inlet.bmp"
        case .bridge:
            return "H_UX_Icon_Acdb_lk_bridge.bmp"
        case .lock:
            return "H_UX_Icon_Acdb_lk_lock.bmp"
        case .dam:
            return "H_UX_Icon_Acdb_lk_dam.bmp"
        case .ferry:
            return "H_UX_Icon_Acdb_lk_ferry.bmp"
        case .anchorageSponsor:
            return "H_UX_Icon_Acdb_anchorage_sponsor.bmp"
        case .businessSponsor:
            return "H_UX_Icon_Acdb_lk_shop_sponsor.bmp"
        case .marinaSponsor:
            return "H_UX_Icon_Acdb_marina_sponsor.bmp"
        @unknown default:
            return "H_UX_Icon_Acdb_stacked_points.bmp"
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
