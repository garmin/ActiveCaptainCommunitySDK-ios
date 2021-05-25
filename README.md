# ActiveCaptain Community SDK - iOS
The ActiveCaptain Community SDK contains functions for storing and rendering data from a SQLite database exported from [ActiveCaptain Community](https://activecaptain.garmin.com).

# Quick Start
In your [Podfile](https://guides.cocoapods.org/syntax/podfile.html):

```Ruby
use_frameworks!

target "MyApp" do
  pod "ActiveCaptainCommunitySDK", "~> 2.0"
end
```

# Requesting a Stage API Key
* Create an account on [ActiveCaptain Community](https://activecaptain.garmin.com).  If you already have a personal account, create a separate account for app development only.
* Go to the [Developer page](https://activecaptain.garmin.com/Developer) and click the Request Access button.  Fill out the information form and agree to the terms and conditions.
* Once you have access to the Developer Portal, you can access it [here](https://activecaptain.garmin.com/Profile/DeveloperPortal).
* In the Developer Portal, click "Add Application" and give your application a name.
* Your app will be assigned a Stage API key.  Click the eye icon to view it.

# Building and Running Sample App
* Clone the repository.
* Initialize submodules recursively: ```git submodule update --init --recursive```
* Install Cocoapods: ```pod install --project-directory=ActiveCaptainSample```
* In Xcode, open ActiveCaptainSample/ActiveCaptainSample.xcworkspace
* In ActiveCaptainSample/ActiveCaptainConfiguration.swift, replace "STAGE_API_KEY_HERE" with your Stage API key.
* Product > Build
* Product > Run

# Using the Sample App
* Log in to Garmin SSO.  Create a new account if needed.
* Wait a few minutes for data exports to be downloaded and installed.
* Initial marker will be displayed.
  * Use the magnifying glass to search for other markers by name.
  * Use the links on the page to display additional information or edit the marker.
