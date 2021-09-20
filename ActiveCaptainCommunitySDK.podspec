sdkBase = "ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK"
cppBase = "#{sdkBase}/cpp/acdb"
submoduleBase = "#{cppBase}/submodules"

Pod::Spec.new do |spec|

  spec.name         = "ActiveCaptainCommunitySDK"
  spec.version      = "2.0.1"
  spec.summary      = "Garmin ActiveCaptain Community SDK"
  spec.description  = <<-DESC
    SDK for maintaining and retrieving data from Garmin ActiveCaptain Community SQLite database.
                   DESC

  spec.homepage     = "https://activecaptain.garmin.com/Developer"
  spec.license      = "Apache License, Version 2.0"
  spec.author       = "Garmin Ltd."

  spec.platform     = :ios

  spec.source       = { :git => "https://github.com/garmin/ActiveCaptainCommunitySDK-ios.git", :tag => "v2.0.1", :submodules => true }

  spec.ios.deployment_target = '12.0'
  spec.source_files  = "#{sdkBase}/*.{h,m,mm}", "#{cppBase}/*.{c,cpp}", "#{cppBase}/{Adapters,DTO,Json,Navionics,Presentation,Presentation/Field,Presentation/Section,Queries,Thirdparty,Thirdparty/Navionics/Extensions}/*.{c,cpp}", "#{submoduleBase}/SQLiteCpp/sqlite3/sqlite3.c", "#{submoduleBase}/SQLiteCpp/src/*.cpp"
  spec.exclude_files  = "#{cppBase}/Thirdparty/FileUtilWindows.cpp"
  spec.preserve_paths = "#{cppBase}/Include/**/*.{h,hpp}", "#{cppBase}/Navionics/**/*.{h,hpp}", "#{cppBase}/submodules/**/*.{h,hpp}", "#{cppBase}/Thirdparty/**/*.{h,hpp}"
  spec.public_header_files = "#{sdkBase}/*.h"
  spec.resource_bundles = {
    'ActiveCaptainCommunitySDK' => ["#{sdkBase}/assets/acdb/img/*.png", "#{sdkBase}/assets/acdb/img/map/*.png"]
  }
  spec.compiler_flags = "-DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_RTREE -DSQLITE_TEMP_STORE=3"
  spec.requires_arc = true

  spec.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"$(inherited)" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/Include/Private" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/Include/Private/Acdb" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/Include/Public" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/Include/Public/Acdb" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/Navionics" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/Navionics/Stubs" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/submodules/mustache" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/submodules/rapidjson/include" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/submodules/SQLiteCpp/include" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/submodules/SQLiteCpp/sqlite3" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/Thirdparty/Include/Private" "$(PODS_TARGET_SRCROOT)/ActiveCaptainCommunitySDK/ActiveCaptainCommunitySDK/cpp/acdb/Thirdparty/Navionics/Extensions"',
    'USER_HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)"',
    'USE_HEADERMAP' => 'NO',
    'ALWAYS_SEARCH_USER_PATHS' => 'NO'
  }
end
