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

#import <Foundation/Foundation.h>

@class AcdbUrlAction;
@class LastUpdateInfoType;
@class SearchMarker;

typedef NS_ENUM(NSInteger, CoordinateFormat) {
    CoordinateFormatDecimalDegrees,
    CoordinateFormatDegreesMinutes,
    CoordinateFormatDegreesMinutesSeconds
};

typedef NS_ENUM(NSInteger, DateFormat) {
    DateFormatMonthAbbreviated,
    DateFormatDMYSlash,
    DateFormatMDYSlash,
    DateFormatDMYDash,
    DateFormatMDYDash
};

typedef NS_ENUM(NSInteger, DistanceUnit) {
    DistanceUnitUnknown,
    DistanceUnitFeet,
    DistanceUnitMeter
};

typedef NS_ENUM(NSInteger, MarkerType) {
    MarkerTypeUnknown,
    MarkerTypeAnchorage,
    MarkerTypeBoatRamp,
    MarkerTypeBridge,
    MarkerTypeBusiness,
    MarkerTypeDam,
    MarkerTypeFerry,
    MarkerTypeHazard,
    MarkerTypeInlet,
    MarkerTypeLock,
    MarkerTypeMarina
};

typedef NS_ENUM(NSInteger, MapIcon) {
    MapIconUnknown,
    MapIconAnchorage,
    MapIconHazard,
    MapIconMarina,
    MapIconBoatRamp,
    MapIconBusiness,
    MapIconInlet,
    MapIconBridge,
    MapIconLock,
    MapIconDam,
    MapIconFerry,

    MapIconAnchorageSponsor,
    MapIconBusinessSponsor,
    MapIconMarinaSponsor
};

typedef struct TileXY {
    int tileX;
    int tileY;
} TileXY;

@interface ActiveCaptainDatabase : NSObject
/*!
    @brief Initializer
    @param databasePath path where SQLite database will be stored, name will be active_captain.db
    @param languageCode language ISO code in format xx_YY.  For example, "en_US" or "pt_BR".
 */
- (id)initWithPath:(NSString *) databasePath andLanguage:(NSString *)languageCode;

// Repository functions

/*!
    @brief Delete the SQLite database.
 */
- (void)deleteDatabase;
/*!
    @brief Delete markers and reviews for the specified tile from the SQLite database.
    @param tileX tile X coordinate, valid values are 0-15
    @param tileY tile Y coordinate, valid values are 0-15
 */
- (void)deleteTileWithTileX: (int)tileX tileY:(int) tileY;
/*!
    @brief Delete reviews for the specified tile from the SQLite database.
    @param tileX tile X coordinate, valid values are 0-15
    @param tileY tile Y coordinate, valid values are 0-15
 */
- (void)deleteTileReviewsWithTileX: (int)tileX tileY:(int) tileY;
/*!
    @brief Retrieve marker and review last modified values for the specified tile.
    @param tileX tile X coordinate, valid values are 0-15
    @param tileY tile Y coordinate, valid values are 0-15
    @return LastUpdateInfoType with marker and review last modified values initialized.
 */
- (LastUpdateInfoType *)getTileLastModifiedWithTileX: (int)tileX tileY:(int) tileY;
/*!
    @brief Retrieve tile coordinates and marker/review last modified values for tiles overlapped by the specified bounding box.
    @param south longitude of southern edge of bounding box
    @param west latitude of western edge of bounding box
    @param north longitude of northern edge of bounding box
    @param east latitude of eastern edge of bounding box
    @return dictionary of LastUpdateInfoType objects by TileXY
 */
- (NSDictionary *)getTilesLastModifiedByBoundingBoxWithSouth:(double)south west:(double) west north:(double) north east:(double) east;
/*!
    @brief Get database version
    @return String containing database version.  If SQLite database is present, will be 2.x.x.x.  If not, will be 0.0.0.0.
 */
- (NSString *)getVersion;
/*!
    @brief Install specified tile in SQLite database.  May overwrite or merged into the existing database.
    @param path path to the SQLite file to install
    @param tileX tile X coordinate, valid values are 0-15
    @param tileY tile Y coordinate, valid values are 0-15
 */
- (void)installTileWithPath: (NSString*)path tileX:(int) tileX tileY:(int) tileY;

// DataService

/*!
    @brief Search for markers in the given bounding box.
    @param name name to search for, may be null or empty string
    @param south longitude of southern edge of bounding box
    @param west latitude of western edge of bounding box
    @param north longitude of northern edge of bounding box
    @param east latitude of eastern edge of bounding box
    @param maxResultCount maximum number of results to return
    @return Array of SearchMarkers in the given bounding box (matching name, if specified)
 */
- (NSArray<SearchMarker *> *)getSearchMarkersByName: (NSString *)name south:(double)south west:(double)west north:(double)north east:(double)east maxResultCount:(int)maxResultCount;
/*!
   @brief Set content of HTML &lt;head&gt; tag to be used in rendered HTML.  If not called, default CSS will be used.
   @param value content of HTML &lt;head&gt; tag, including CSS style values
 */
- (void)setHeadContentWithValue: (NSString *)value;
/*!
    @brief Set prefix to be added to all icon URLs in rendered HTML.  If not called, no prefix will be added.
    @discussion This is provided in case a prefix needs to be specified for icon images to be located
        correctly.  On Android a special URL is used to indicate the icon will be be loaded from .aar
        assets.
    @param value content of image prefix
 */
- (void)setImagePrefixWithValue: (NSString *)value;
/*!
    @brief Set language to use when rendering HTML.
    @discussion American English will be used by default if no translation is available in the specified
        language.
    @param value language code for the desired language.
 */
- (void)setLanguageWithValue: (NSString *)value;

// ISettingsManager

/*!
    @brief Specify format to render coordinates in.
    @param value desired coordinate format.
 */
- (void)setCoordinateFormatWithValue: (CoordinateFormat)value;
/*!
    @brief Specify format to render dates in.
    @param value desired coordinate format.
 */
- (void)setDateFormatWithValue: (DateFormat)value;
/*!
    @brief Specify units to render distances in.
    @param value desired distance unit.
 */
- (void)setDistanceUnitWithValue: (DistanceUnit)value;

// UpdateService

/*!
    @brief Process response body from POST api/v2/points-of-interest endpoint.  Only call this if API call was successful.
    @param json response body content
    @return id of newly created marker
 */
- (unsigned long)processCreateMarkerResponseWithJson: (NSString *)json;
/*!
    @brief Process response body from PUT api/v2/points-of-interest/{id}/location endpoint.  Only call this if API call was successful.
    @param json response body content
 */
- (void)processMoveMarkerResponseWithJson: (NSString *)json;
/*!
    @brief Process response body from GET api/v2/points-of-interest/sync endpoint.  Only call this if API call was successful.
    @param json response body content
    @param tileX tile X coordinate, valid values are 0-15
    @param tileY tile Y coordinate, valid values are 0-15
    @return number of markers processed
 */
- (unsigned long)processSyncMarkersResponseWithJson: (NSString *)json tileX:(int) tileX tileY:(int) tileY;
/*!
    @brief Process response body from GET api/v2/reviews/sync endpoint.  Only call this if API call was successful.
    @param json response body content
    @param tileX tile X coordinate, valid values are 0-15
    @param tileY tile Y coordinate, valid values are 0-15
    @return number of reviews processed
 */
- (unsigned long)processSyncReviewsResponseWithJson: (NSString *)json tileX:(int) tileX tileY:(int) tileY;
/*!
    @brief Process response body from POST api/v2/reviews/{id}/votes endpoint.  Only call this if API call was successful.
    @param json response body content
 */
- (void)processVoteForReviewResponseWithJson: (NSString*)json;
/*!
    @brief Process response content from a webview call.
    @param json response body content
 */
- (void)processWebViewResponseWithJson: (NSString *)json;

// AcdbUrlAction

/*!
    @brief Parse an acdb:// URL.
    @discussion To render a marker with given id, call this function with "acdb://summary/{id}".  Rendered
        HTML will include acdb:// links to marker's photo list, section details, review list, etc.
    @param url acdb:// URL the user selected.
    @param captainName user's captain name
    @param pageSize review list page size
    @return AcdbUrlAction for the specified URL.  Content will be initialized based on the action type.
 */
- (AcdbUrlAction *)parseAcdbUrlWithUrl: (NSString *)url captainName:(NSString*) captainName pageSize:(int) pageSize;
@end
