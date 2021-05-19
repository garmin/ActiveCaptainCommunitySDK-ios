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

import Foundation

struct ActiveCaptainConfiguration {
    #if DEBUG
    public static let apiBaseURL = "https://activecaptain-stage.garmin.com/community/thirdparty"
    public static let apiKey = "STAGE_API_KEY_HERE"
    public static let ssoURL = "https://ssotest.garmin.com/sso/embed?clientId=ACTIVE_CAPTAIN_WEB&locale=en_US"
    public static let webviewBaseUrl = "https://activecaptain-stage.garmin.com"
    public static let webviewDebug = true
    #else
    public static let apiBaseURL = "https://activecaptain.garmin.com/community/thirdparty"
    public static let apiKey = "PRODUCTION_API_KEY_HERE"
    public static let ssoURL = "https://sso.garmin.com/sso/embed?clientId=ACTIVE_CAPTAIN_WEB&locale=en_US"
    public static let webviewBaseUrl = "https://activecaptain.garmin.com"
    public static let webviewDebug = false
    #endif

    public static let appTitle = "ActiveCaptain Sample"

    public static let markerMinSearchLength = 3
    public static let markerMaxSearchResults = 100
    public static let reviewListPageSize = 10
    public static let updateIntervalMins = 15 // Minutes, must be >= 15

    public static var languageCode = "en_US"

    public static let imageScale = 2.0
}
