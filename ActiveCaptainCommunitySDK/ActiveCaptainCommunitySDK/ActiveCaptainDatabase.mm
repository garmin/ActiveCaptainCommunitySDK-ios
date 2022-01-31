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

#import "AcdbUrlAction.h"
#import "AcdbUrlAction.hpp"
#import "ActiveCaptainDatabase.h"
#import "DataService.hpp"
#import "ISettingsManager.hpp"
#import "LastUpdateInfoType.h"
#import "NavDateTimeExtensions.hpp"
#import "Repository.hpp"
#import "SearchMarker.h"
#import "StringUtil.hpp"
#import "UpdateService.hpp"
#import "UTL_pub_lib_cnvt.h"
#import "Version.hpp"

using DataServicePtr = std::shared_ptr<Acdb::IDataService>;
using UpdateServicePtr = std::shared_ptr<Acdb::IUpdateService>;

@implementation ActiveCaptainDatabase {
    DataServicePtr dataService;
    Acdb::RepositoryPtr repository;
    UpdateServicePtr updateService;
}

- (id)initWithPath:(NSString *) databasePath andLanguage:(NSString *) languageCode {
    self = [super init];
    if (self) {
        repository.reset(new Acdb::Repository([self toString:databasePath]));
        repository->Open();
        dataService.reset(new Acdb::DataService(repository, [self toString:languageCode]));
        updateService.reset(new Acdb::UpdateService(repository));
    }

    return self;
}
- (NSString *)toNSString: (const std::string&)str {
    return [NSString stringWithUTF8String:str.c_str()];
}
- (std::string)toString: (NSString *)nsStr {
    if (nsStr == nil) {
        return std::string();
    }

    return std::string([nsStr UTF8String], [nsStr lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

// Repository
- (void)deleteDatabase
{
    repository->Delete();
}
- (void)deleteTileWithTileX: (int)tileX tileY:(int) tileY {
    Acdb::TileXY tileXY(tileX, tileY);
    repository->DeleteTile(tileXY);
}
- (void)deleteTileReviewsWithTileX: (int)tileX tileY:(int) tileY {
    Acdb::TileXY tileXY(tileX, tileY);
    repository->DeleteTileReviews(tileXY);
}
- (LastUpdateInfoType *)getTileLastModifiedWithTileX: (int)tileX tileY:(int) tileY {
    Acdb::TileXY tileXY(tileX, tileY);
    Acdb::LastUpdateInfoType lastUpdateInfo;

    repository->GetTileLastUpdateInfo(tileXY, lastUpdateInfo);

    LastUpdateInfoType *result = [[LastUpdateInfoType alloc] init];
    if (lastUpdateInfo.mMarkerLastUpdate != 0) {
        Navionics::NavDateTime markerLastUpdate = Acdb::NavDateTimeExtensions::EpochToNavDateTime(Acdb::UNIX_EPOCH, lastUpdateInfo.mMarkerLastUpdate);
        std::string markerLastUpdateStr;
        markerLastUpdate.ToString(markerLastUpdateStr, YYYYMMDDTHHMMSSZ_FORMAT);
        result.markerLastUpdate = [self toNSString:markerLastUpdateStr];
    }

    if (lastUpdateInfo.mUserReviewLastUpdate != 0) {
        Navionics::NavDateTime reviewLastUpdate = Acdb::NavDateTimeExtensions::EpochToNavDateTime(Acdb::UNIX_EPOCH, lastUpdateInfo.mUserReviewLastUpdate);
        std::string reviewLastUpdateStr;
        reviewLastUpdate.ToString(reviewLastUpdateStr, YYYYMMDDTHHMMSSZ_FORMAT);
        result.reviewLastUpdate = [self toNSString:reviewLastUpdateStr];
    }

    return result;
}
- (NSDictionary *)getTilesLastModifiedByBoundingBoxWithSouth:(double)south west:(double) west north:(double) north east:(double) east {
    bbox_type bbox;
    bbox.nec.lat = (int32_t)north * UTL_DEG_TO_SEMI;
    bbox.nec.lon = (int32_t)east * UTL_DEG_TO_SEMI;
    bbox.swc.lat = (int32_t)south * UTL_DEG_TO_SEMI;
    bbox.swc.lon = (int32_t)west * UTL_DEG_TO_SEMI;

    std::vector<bbox_type> bboxes{bbox};
    std::map<Acdb::TileXY, Acdb::LastUpdateInfoType> lastUpdateInfos;

    repository->GetTilesLastUpdateInfoByBoundingBoxes(bboxes, lastUpdateInfos);

    NSMutableDictionary *results = [[NSMutableDictionary alloc] init];

    for (std::map<Acdb::TileXY, Acdb::LastUpdateInfoType>::iterator it = lastUpdateInfos.begin(); it != lastUpdateInfos.end(); it++) {
        LastUpdateInfoType *result = [[LastUpdateInfoType alloc] init];

        if (it->second.mMarkerLastUpdate != 0) {
            Navionics::NavDateTime markerLastUpdate = Acdb::NavDateTimeExtensions::EpochToNavDateTime(Acdb::UNIX_EPOCH, it->second.mMarkerLastUpdate);
            std::string markerLastUpdateStr;
            markerLastUpdate.ToString(markerLastUpdateStr, YYYYMMDDTHHMMSSZ_FORMAT);

            result.markerLastUpdate = [self toNSString:markerLastUpdateStr];
        }

        if (it->second.mUserReviewLastUpdate != 0) {
            Navionics::NavDateTime reviewLastUpdate = Acdb::NavDateTimeExtensions::EpochToNavDateTime(Acdb::UNIX_EPOCH, it->second.mUserReviewLastUpdate);
            std::string reviewLastUpdateStr;
            reviewLastUpdate.ToString(reviewLastUpdateStr, YYYYMMDDTHHMMSSZ_FORMAT);

            result.reviewLastUpdate = [self toNSString:reviewLastUpdateStr];
        }

        TileXY tileXY;
        tileXY.tileX = it->first.mX;
        tileXY.tileY = it->first.mY;

        NSValue* key = [NSValue value:&tileXY withObjCType:@encode(TileXY)];
        [results setObject:result forKey:key];
    }

    return results;
}
- (NSString *)getVersion {
    std::string version = repository->GetVersion().ToString();
    return [self toNSString:version];
}
- (void)installTileWithPath: (NSString *)path tileX:(int) tileX tileY:(int) tileY {
    Acdb::TileXY tileXY(tileX, tileY);
    repository->InstallSingleTileDatabase([self toString:path], tileXY);
}

// DataService
- (NSArray<SearchMarker *> *)getSearchMarkersByName: (NSString *)name south:(double)south west:(double)west north:(double)north east:(double)east maxResultCount:(int)maxResultCount escapeHtml:(bool)escapeHtml {
    Acdb::SearchMarkerFilter filter;

    std::string nameStr = [self toString:name];
    if (!nameStr.empty()) {
        filter.SetSearchString(nameStr);
    }

    bbox_type bbox;
    bbox.nec.lat = (int32_t)(north * UTL_DEG_TO_SEMI);
    bbox.nec.lon = (east == -180.0 || east == 180.0) ? INT32_MAX : (int32_t)(east * UTL_DEG_TO_SEMI);
    bbox.swc.lat = (int32_t)(south * UTL_DEG_TO_SEMI);
    bbox.swc.lon = (west == -180.0 || west == 180.0) ? INT32_MIN : (int32_t)(west * UTL_DEG_TO_SEMI);
    filter.SetBbox(bbox);

    filter.AddType(ACDB_ALL_TYPES);
    filter.AddCategory(Acdb::SearchMarkerFilter::Any);
    filter.SetMaxResults(maxResultCount);

    std::vector<Acdb::ISearchMarkerPtr> searchMarkers;
    dataService->GetSearchMarkersByFilter(filter, searchMarkers);

    const std::map<ACDB_type_type, MarkerType> MARKER_TYPES = {
        {ACDB_UNKNOWN_TYPE, MarkerTypeUnknown},
        {ACDB_ANCHORAGE, MarkerTypeAnchorage},
        {ACDB_BOAT_RAMP, MarkerTypeBoatRamp},
        {ACDB_BRIDGE, MarkerTypeBridge},
        {ACDB_BUSINESS, MarkerTypeBusiness},
        {ACDB_DAM, MarkerTypeDam},
        {ACDB_FERRY, MarkerTypeFerry},
        {ACDB_HAZARD, MarkerTypeHazard},
        {ACDB_INLET, MarkerTypeInlet},
        {ACDB_LOCK, MarkerTypeLock},
        {ACDB_MARINA, MarkerTypeMarina}
    };

    const std::map<Acdb::MapIconType, MapIcon> MAP_ICON_TYPES = {
        {Acdb::MapIconType::Unknown, MapIconUnknown},
        {Acdb::MapIconType::Anchorage, MapIconAnchorage},
        {Acdb::MapIconType::BoatRamp, MapIconBoatRamp},
        {Acdb::MapIconType::Bridge, MapIconBridge},
        {Acdb::MapIconType::Business, MapIconBusiness},
        {Acdb::MapIconType::Dam, MapIconDam},
        {Acdb::MapIconType::Ferry, MapIconFerry},
        {Acdb::MapIconType::Hazard, MapIconHazard},
        {Acdb::MapIconType::Inlet, MapIconInlet},
        {Acdb::MapIconType::Lock, MapIconLock},
        {Acdb::MapIconType::Marina, MapIconMarina},
        {Acdb::MapIconType::AnchorageSponsor, MapIconAnchorageSponsor},
        {Acdb::MapIconType::BusinessSponsor, MapIconBusinessSponsor},
        {Acdb::MapIconType::MarinaSponsor, MapIconMarinaSponsor}
    };

    NSMutableArray *results = [[NSMutableArray alloc] init];
    for (std::vector<Acdb::ISearchMarkerPtr>::iterator it = searchMarkers.begin(); it != searchMarkers.end(); it++) {
        std::string markerName = it->get()->GetName();
        if (escapeHtml == true) {
            Acdb::String::HtmlEscape(markerName);
        }

        std::map<ACDB_type_type, MarkerType>::const_iterator markerTypeIt = MARKER_TYPES.find((*it)->GetType());
        if (markerTypeIt == MARKER_TYPES.end()) {
            markerTypeIt = MARKER_TYPES.begin();
        }

        std::map<Acdb::MapIconType, MapIcon>::const_iterator mapIconIt = MAP_ICON_TYPES.find((*it)->GetMapIcon());
        if (mapIconIt == MAP_ICON_TYPES.end()) {
            mapIconIt = MAP_ICON_TYPES.begin();
        }

        SearchMarker* result = [[SearchMarker alloc] init];
        result.markerId = (*it)->GetId();
        result.name = [self toNSString:markerName];
        result.markerType = markerTypeIt->second;
        result.latitude = (*it)->GetPosition().lat * UTL_SEMI_TO_DEG;
        result.longitude = (*it)->GetPosition().lon * UTL_SEMI_TO_DEG;
        result.mapIcon = mapIconIt->second;

        [results addObject:result];
    }

    return results;
}

- (void)setHeadContentWithValue: (NSString *)value {
    dataService->SetHeadContent([self toString:value]);
}
- (void)setImagePrefixWithValue: (NSString *)value {
    dataService->SetImagePrefix([self toString:value]);
}
- (void)setLanguageWithValue: (NSString *)value {
    dataService->SetLanguage([self toString:value]);
}

// ISettingsManager
- (void)setCoordinateFormatWithValue: (CoordinateFormat)value {
    Acdb::ISettingsManager::GetISettingsManager().SetCoordinateFormat((ACDB_coord_format_type)value);
}
- (void)setDateFormatWithValue:(DateFormat)value {
    Acdb::ISettingsManager::GetISettingsManager().SetDateFormat((ACDB_date_format_type)value);
}
- (void)setDistanceUnitWithValue:(DistanceUnit)value {
    Acdb::ISettingsManager::GetISettingsManager().SetDistanceUnit((ACDB_unit_type)value);
}

// UpdateService
- (unsigned long)processCreateMarkerResponseWithJson:(NSString *)json {
    ACDB_marker_idx_type markerId;
    updateService->ProcessCreateMarkerResponse([self toString:json], markerId);

    return markerId;
}
- (void)processMoveMarkerResponseWithJson:(NSString *)json {
    updateService->ProcessMoveMarkerResponse([self toString:json]);
}
- (unsigned long)processSyncMarkersResponseWithJson: (NSString *)json tileX:(int) tileX tileY:(int) tileY {
    std::size_t responseCount;

    Acdb::TileXY tileXY(tileX, tileY);
    updateService->ProcessSyncMarkersResponse([self toString:json], tileXY, responseCount);

    return responseCount;
}
- (unsigned long)processSyncReviewsResponseWithJson: (NSString *)json tileX:(int) tileX tileY:(int) tileY {
    std::size_t responseCount;

    Acdb::TileXY tileXY(tileX, tileY);
    updateService->ProcessSyncReviewsResponse([self toString:json], tileXY, responseCount);

    return responseCount;
}
- (void)processVoteForReviewResponseWithJson: (NSString *)json {
    updateService->ProcessVoteForReviewResponse([self toString:json]);
}
- (void)processWebViewResponseWithJson:(NSString *)json {
    updateService->ProcessWebViewResponse([self toString:json]);
}

// AcdbUrlAction
- (AcdbUrlAction *)parseAcdbUrlWithUrl: (NSString *)url captainName:(NSString *) captainName pageSize:(int) pageSize {
    AcdbUrlAction *result = nil;

    ActionType resultAction = ActionType::ActionTypeUnknown;
    std::string content;

    Acdb::AcdbUrlActionPtr action;

    std::string captainNameStr = [self toString:captainName];

    if (Acdb::ParseAcdbUrl([self toString:url], action)) {
        switch (action->GetAction())
        {
            case Acdb::AcdbUrlAction::ActionType::SeeAll:
            {
                resultAction = ActionType::ActionTypeSeeAll;

                Acdb::SeeAllAction* seeAllAction = static_cast<Acdb::SeeAllAction*>(action.get());

                if (Acdb::IsReviewsSection(seeAllAction->GetSection())) {
                    content = dataService->GetReviewListHtml(seeAllAction->GetMarkerId(), seeAllAction->GetPageNumber(), pageSize, captainNameStr);
                } else {
                    content = dataService->GetSectionPageHtml(seeAllAction->GetMarkerId(), seeAllAction->GetSection());
                }

                break;
            }
            case Acdb::AcdbUrlAction::ActionType::ShowPhotos:
            {
                resultAction = ActionType::ActionTypeShowPhotos;

                Acdb::ShowPhotosAction* showPhotosAction = static_cast<Acdb::ShowPhotosAction*>(action.get());
                content = dataService->GetBusinessPhotoListHtml(showPhotosAction->GetMarkerId());

                break;
            }
            case Acdb::AcdbUrlAction::ActionType::ShowSummary:
            {
                resultAction = ActionType::ActionTypeShowSummary;

                Acdb::ShowSummaryAction* showSummaryAction = static_cast<Acdb::ShowSummaryAction*>(action.get());
                content = dataService->GetPresentationMarkerHtml(showSummaryAction->GetMarkerId(), captainNameStr);

                break;
            }
            case Acdb::AcdbUrlAction::ActionType::Edit:
            {
                resultAction = ActionType::ActionTypeEdit;

                Acdb::EditAction* editAction = static_cast<Acdb::EditAction*>(action.get());
                content = editAction->GetUrl();

                break;
            }
            case Acdb::AcdbUrlAction::ActionType::ReportReview:
            {
                resultAction = ActionType::ActionTypeReportReview;

                Acdb::ReportReviewAction* reportReviewAction = static_cast<Acdb::ReportReviewAction*>(action.get());
                content = reportReviewAction->GetUrl();

                break;
            }
            case Acdb::AcdbUrlAction::ActionType::VoteReview:
            {
                resultAction = ActionType::ActionTypeVoteReview;

                Acdb::VoteReviewAction* voteAction = static_cast<Acdb::VoteReviewAction*>(action.get());
                content = std::to_string(voteAction->GetReviewId());

                break;
            }
        }
    }

    if (!content.empty()) {
        result = [[AcdbUrlAction alloc] init];
        result.action = resultAction;
        result.content = [self toNSString:content];
    }

    return result;
}
@end
