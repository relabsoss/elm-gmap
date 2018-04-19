effect module Gmap
    where { command = MyCmd, subscription = MySub }
    exposing
        ( initial
        , toHtml
        , geocodeTask
        , geocode
        , setCirclesTask
        , setCircles
        , setBoundsTask
        , setBounds
        , boundsToCircle

        , onClick

        , Error
        , Model
        , GmapOpts
        , LatLng
        , Circle
        , Circles
        , GeocodeRequest
        , GeocodeRequestRestrictions
        , GeocodeRequestLookup(..)
        , GeocodeResults
        , GeocodeResult
        , GeocodeAddressComponent
        , GeocodeAddressComponents
        , GeocodeGeometry
        )

{-|

Google map elm interface

@docs initial, toHtml, geocodeTask, geocode, onClick, setCircles, setCirclesTask, setBounds,
      setBoundsTask, boundsToCircle

@docs Model, Error, GmapOpts, LatLng, Circle, Circles,
      GeocodeResults, GeocodeResult, GeocodeAddressComponent, GeocodeAddressComponents,
      GeocodeGeometry, GeocodeRequest, GeocodeRequestRestrictions, GeocodeRequestLookup
-}

import Platform
import Task
import Dict
import Html
import Html.Attributes
import Json.Encode
import Json.Decode
import Native.Gmap


type MyCmd msg
  = Init GmapOpts (Result Error Model -> msg)
  | SetCircles Model (List Circle) (Result Error (List Circle) -> msg)


type MySub msg
  = OnClick Model (LatLng -> msg)
  | OnDblClick Model (LatLng -> msg)


type Msg
  = OnClicked Int LatLng
  | OnDblClicked Int LatLng


type alias State msg =
  { clickSubs : MouseSubs msg
  , dblClickSubs : MouseSubs msg
  , processes : List Platform.ProcessId
  }


type alias MouseSubs msg = Dict.Dict Int (List (LatLng -> msg))


{-| Tasks can produce Error values
-}
type Error
  = InitializationFail
  | SetFail
  | GeocodeFail
  | DestructionFail
  | WrongData String


{-| Google map component model
-}
type alias Model =
  { id : Int
  }


{-| Google map options
-}
type alias GmapOpts =
  { center : LatLng
  , gestureHandling : String
  , zoom : Int
  , scrollwheel : Bool
  , zoomControl : Bool
  }


{-| Circle region
-}
type alias Circle =
  { center : LatLng
  , radius : Float
  , strokeColor : String
  , strokeOpacity : Float
  , strokeWeight : Int
  , visible : Bool
  , fillColor : String
  , fillOpacity : Float
  }


{-| Google map geocode request
-}
type alias GeocodeRequest =
  { lookup : GeocodeRequestLookup
  , bounds : Maybe Bounds
  , componentRestrictions : Maybe GeocodeRequestRestrictions
  , region : Maybe String
  }


{-| Google map geocode request type
-}
type GeocodeRequestLookup
  = Address String
  | Location LatLng
  | PlaceId String


{-| Google map geocode request restrictions
-}
type alias GeocodeRequestRestrictions =
  { administrativeArea : Maybe String
  , country : Maybe String
  , locality : Maybe String
  , postalCode : Maybe String
  , route : Maybe String
  }


{-| Google map geocode results
-}
type alias GeocodeResults = List GeocodeResult


{-| Google map geocode result
-}
type alias GeocodeResult =
  { formatted_address : String
  , address_components : GeocodeAddressComponents
  , geometry : GeocodeGeometry
  , place_id : String
  , types : List String
  }


{-| Google map geocode address components
-}
type alias GeocodeAddressComponents = List GeocodeAddressComponent


{-| Google map geocode address component
-}
type alias GeocodeAddressComponent =
  { long_name : String
  , short_name : String
  , types : List String
  }


{-| Google map geocode geometry
-}
type alias GeocodeGeometry =
  { bounds : Maybe Bounds
  , location : LatLng
  , location_type : String
  }


{-| Circle region collection
-}
type alias Circles = List Circle


type alias Bounds =
  { south : Float
  , west : Float
  , north : Float
  , east : Float
  }

{-| Google map coordinate
-}
type alias LatLng =
  { lat : Float
  , lng : Float
  }


{-| Make initial model
-}
initial : GmapOpts -> (Result Error Model -> msg) -> Cmd msg
initial gmapOpts tagger =
  command (Init gmapOpts tagger)


{-| Geodecode command
-}
geocode : Model -> GeocodeRequest -> (Result Error GeocodeResults -> msg) -> Cmd msg
geocode model geocodeRequest tagger =
  geocodeTask model geocodeRequest
    |> Task.attempt tagger


{-| Geodecode task
-}
geocodeTask : Model -> GeocodeRequest -> Task.Task Error GeocodeResults
geocodeTask model geocodeRequest =
  Native.Gmap.geocode model.id (encodeGeocodeRequest geocodeRequest)
    |> Task.andThen (\v ->
      case Json.Decode.decodeValue decodeGeocodeResults v of
        Ok data ->
          Task.succeed data

        Err reason ->
          Task.fail (WrongData reason)
    )


{-| Set google map circles. Current circles will be removed
-}
setCircles : Model -> Circles -> (Result Error Circles -> msg) -> Cmd msg
setCircles model circles tagger =
  setCirclesTask model circles
    |> Task.attempt tagger


{-| Set google map circles task. Current circles will be removed
-}
setCirclesTask : Model -> Circles -> Task.Task Error Circles
setCirclesTask model circles =
  Native.Gmap.setCircles model.id (encodeCircles circles)
    |> Task.andThen (\v ->
        case Json.Decode.decodeValue decodeCircles v of
          Ok data ->
            Task.succeed data

          Err reason ->
            Task.fail (WrongData reason)
      )

{-| Set google map bounds
-}
setBounds : Model -> Bounds -> (Result Error Bounds -> msg) -> Cmd msg
setBounds model bounds tagger =
  setBoundsTask model bounds
    |> Task.attempt tagger


{-| Set google map bounds task
-}
setBoundsTask : Model -> Bounds -> Task.Task Error Bounds
setBoundsTask model bounds =
  Native.Gmap.setBounds model.id (encodeBounds bounds)
    |> Task.andThen (\v ->
      case Json.Decode.decodeValue decodeBounds v of
        Ok data ->
          Task.succeed data

        Err reason ->
          Task.fail (WrongData reason)
    )


{-| On click subscription
-}
onClick : Model -> (LatLng -> msg) -> Sub msg
onClick model tagger =
  subscription (OnClick model tagger)


{-| Google map view
-}
toHtml : Model -> List (Html.Attribute msg) -> Html.Html msg
toHtml =
  Native.Gmap.toHtml


{-| Bounds to circle
-}
boundsToCircle : Bounds -> Circle
boundsToCircle bounds =
  let
    center =
      LatLng
        ((bounds.south + bounds.north)/2)
        ((bounds.east + bounds.west)/2)

    radius =
      (abs (bounds.north - center.lat)) * 111 * 1000
  in
    Circle center radius "" 1 1 True "" 1


init : Task.Task Never (State msg)
init =
  Task.succeed (State Dict.empty Dict.empty [])


cmdMap : (a -> b) -> MyCmd a -> MyCmd b
cmdMap func cmd =
  case cmd of

    Init gmapOpts tagger ->
      Init gmapOpts (tagger >> func)

    SetCircles model circles tagger ->
      SetCircles model circles (tagger >> func)


subMap : (a -> b) -> MySub a -> MySub b
subMap func sub =
  case sub of

    OnClick model tagger ->
      OnClick model (tagger >> func)

    OnDblClick model tagger ->
      OnDblClick model (tagger >> func)


onEffects
  : Platform.Router msg Msg
  -> List (MyCmd msg)
  -> List (MySub msg)
  -> State msg
  -> Task.Task Never (State msg)
onEffects router cmds subs state =
  let
    cmdEffects =
      onCmdEffects cmds router state

    (newOnClickSubs, newOnDblClickSubs) =
      buildSubDict subs (Dict.empty, Dict.empty)
  in
    cmdEffects
      |> Task.andThen (\newState -> Task.succeed { newState | clickSubs = newOnClickSubs, dblClickSubs = newOnDblClickSubs})


onCmdEffects : List (MyCmd msg) -> Platform.Router msg Msg -> State msg -> Task.Task Never (State msg)
onCmdEffects cmds router state =
  case cmds of
    [] ->
      Task.succeed state

    Init gmapOpts tagger :: rest ->
      let
        sendClick tagger idValue value =
          case (Json.Decode.decodeValue Json.Decode.int idValue, Json.Decode.decodeValue decodeLatLng value) of
            (Ok id, Ok latLng) ->
              Platform.sendToSelf router (tagger id latLng)

            any ->
              let
                _ = Debug.log "click message unpack error" any
              in
                Task.succeed ()

        opts =
          { onClick = \id value -> sendClick OnClicked id value
          , onDblClick = \id value -> sendClick OnDblClicked id value
          }

        success instance =
          Platform.sendToApp router (tagger <| Ok <| Model instance)

        fail error =
          Platform.sendToApp router (tagger <| Err error)
      in
        Native.Gmap.init opts (encodeGmapOpts gmapOpts)
          |> Task.andThen success
          |> Task.onError fail
          |> Task.andThen (\_ -> onCmdEffects rest router state)

    _ :: rest ->
      onCmdEffects rest router state


onSelfMsg : Platform.Router msg Msg -> Msg -> State msg -> Task.Task Never (State msg)
onSelfMsg router msg state =
  case msg of
    OnClicked id latLng ->
      Dict.get id state.clickSubs
        |> Maybe.map (\subs ->
          List.map (\tagger ->
            Platform.sendToApp router (tagger latLng)
          ) subs
        )
        |> Maybe.withDefault []
        |> Task.sequence
        |> Task.andThen (\_ -> Task.succeed state)
        |> Task.onError (\_ -> Task.succeed state)

    OnDblClicked id latLng  ->
      Dict.get id state.clickSubs
        |> Maybe.map (\subs ->
          List.map (\tagger ->
            Platform.sendToApp router (tagger latLng)
          ) subs
        )
        |> Maybe.withDefault []
        |> Task.sequence
        |> Task.andThen (\_ -> Task.succeed state)
        |> Task.onError (\_ -> Task.succeed state)


buildSubDict : List (MySub msg) -> (MouseSubs msg, MouseSubs msg) -> (MouseSubs msg, MouseSubs msg)
buildSubDict subs (clickSubs, dblClickSubs) =
  case subs of
    [] ->
      (clickSubs, dblClickSubs)

    OnClick model tagger :: rest ->
      buildSubDict rest ((Dict.update model.id (add tagger) clickSubs), dblClickSubs)

    OnDblClick model tagger :: rest ->
      buildSubDict rest (clickSubs, (Dict.update model.id (add tagger) dblClickSubs))


add : a -> Maybe (List a) -> Maybe (List a)
add value maybeList =
  case maybeList of
    Nothing ->
      Just [value]

    Just list ->
      Just (value :: list)


encodeAddress : Maybe String -> Json.Encode.Value
encodeAddress maybeAddress =
  maybeAddress
    |> Maybe.map Json.Encode.string
    |> Maybe.withDefault Json.Encode.null


encodeGmapOpts : GmapOpts -> Json.Encode.Value
encodeGmapOpts gmapOpts =
  Json.Encode.object
    [ ("center", encodeLatLng gmapOpts.center)
    , ("gestureHandling", Json.Encode.string gmapOpts.gestureHandling)
    , ("zoom", Json.Encode.int gmapOpts.zoom)
    , ("scrollwheel", Json.Encode.bool gmapOpts.scrollwheel)
    , ("zoomControl", Json.Encode.bool gmapOpts.zoomControl)
    ]


encodeLatLng : LatLng -> Json.Encode.Value
encodeLatLng latLng =
  Json.Encode.object
    [ ("lat", Json.Encode.float latLng.lat)
    , ("lng", Json.Encode.float latLng.lng)
    ]

decodeLatLng : Json.Decode.Decoder LatLng
decodeLatLng  =
  Json.Decode.map2 LatLng
     (Json.Decode.field "lat" Json.Decode.float)
     (Json.Decode.field "lng" Json.Decode.float)


encodeCircles : Circles -> Json.Encode.Value
encodeCircles circles =
  List.map encodeCircle circles
    |> Json.Encode.list


encodeCircle : Circle -> Json.Encode.Value
encodeCircle circle =
  Json.Encode.object
    [ ("center", encodeLatLng circle.center)
    , ("radius", Json.Encode.float circle.radius)
    , ("strokeColor", Json.Encode.string circle.strokeColor)
    , ("strokeOpacity", Json.Encode.float circle.strokeOpacity)
    , ("strokeWeight", Json.Encode.int circle.strokeWeight)
    , ("visible", Json.Encode.bool circle.visible)
    , ("fillColor", Json.Encode.string circle.fillColor)
    , ("fillOpacity", Json.Encode.float circle.fillOpacity)
    ]


decodeCircles : Json.Decode.Decoder Circles
decodeCircles =
  Json.Decode.list decodeCircle


decodeCircle : Json.Decode.Decoder Circle
decodeCircle =
  Json.Decode.map8 Circle
    (Json.Decode.field "center" decodeLatLng)
    (Json.Decode.field "radius" Json.Decode.float)
    (Json.Decode.field "strokeColor" Json.Decode.string)
    (Json.Decode.field "strokeOpacity" Json.Decode.float)
    (Json.Decode.field "strokeWeight" Json.Decode.int)
    (Json.Decode.field "visible" Json.Decode.bool)
    (Json.Decode.field "fillColor" Json.Decode.string)
    (Json.Decode.field "fillOpacity" Json.Decode.float)


encodeGeocodeRequest : GeocodeRequest -> Json.Encode.Value
encodeGeocodeRequest request =
  let
    general =
      maybeEncode "bounds" request.bounds encodeBounds []
        |> maybeEncode "componentRestrictions" request.componentRestrictions encodeComponentRestrictions
        |> maybeEncode "region" request.region Json.Encode.string

    fields =
      case request.lookup of
        Address value ->
          ("address", Json.Encode.string value) :: general

        Location value ->
          ("location", encodeLatLng value) :: general

        PlaceId value ->
          ("placeId", Json.Encode.string value) :: general
  in
    Json.Encode.object fields


encodeComponentRestrictions : GeocodeRequestRestrictions -> Json.Encode.Value
encodeComponentRestrictions restrictions =
  maybeEncode "administrativeArea" restrictions.administrativeArea Json.Encode.string []
    |> maybeEncode "country" restrictions.country Json.Encode.string
    |> maybeEncode "locality" restrictions.locality Json.Encode.string
    |> maybeEncode "postalCode" restrictions.postalCode Json.Encode.string
    |> maybeEncode "route" restrictions.route Json.Encode.string
    |> Json.Encode.object

decodeGeocodeResults : Json.Decode.Decoder GeocodeResults
decodeGeocodeResults =
  Json.Decode.list decodeGeocodeResult


decodeGeocodeResult : Json.Decode.Decoder GeocodeResult
decodeGeocodeResult =
  Json.Decode.map5 GeocodeResult
    (Json.Decode.field "formatted_address" Json.Decode.string)
    (Json.Decode.field "address_components" decodeGeocodeAddressComponents)
    (Json.Decode.field "geometry" decodeGeocodeGeometry)
    (Json.Decode.field "place_id" Json.Decode.string)
    (Json.Decode.field "types" (Json.Decode.list Json.Decode.string))


decodeGeocodeAddressComponents : Json.Decode.Decoder GeocodeAddressComponents
decodeGeocodeAddressComponents =
  Json.Decode.list decodeGeocodeAddressComponent


decodeGeocodeAddressComponent : Json.Decode.Decoder GeocodeAddressComponent
decodeGeocodeAddressComponent =
  Json.Decode.map3 GeocodeAddressComponent
    (Json.Decode.field "long_name" Json.Decode.string)
    (Json.Decode.field "short_name" Json.Decode.string)
    (Json.Decode.field "types" (Json.Decode.list Json.Decode.string))


decodeGeocodeGeometry : Json.Decode.Decoder GeocodeGeometry
decodeGeocodeGeometry =
  Json.Decode.map3 GeocodeGeometry
    (Json.Decode.field "bounds" (Json.Decode.maybe decodeBounds))
    (Json.Decode.field "location" decodeLatLng)
    (Json.Decode.field "location_type" Json.Decode.string)


decodeBounds : Json.Decode.Decoder Bounds
decodeBounds =
  Json.Decode.map4 Bounds
    (Json.Decode.field "south" Json.Decode.float)
    (Json.Decode.field "west" Json.Decode.float)
    (Json.Decode.field "north" Json.Decode.float)
    (Json.Decode.field "east" Json.Decode.float)


encodeBounds : Bounds -> Json.Encode.Value
encodeBounds bounds =
  Json.Encode.object
    [ ("south", Json.Encode.float bounds.south)
    , ("west", Json.Encode.float bounds.west)
    , ("north", Json.Encode.float bounds.north)
    , ("east", Json.Encode.float bounds.east)
    ]


maybeEncode : String -> Maybe a -> (a -> Json.Encode.Value) -> List (String, Json.Encode.Value) -> List (String, Json.Encode.Value)
maybeEncode name maybeValue encoder rest =
  case maybeValue of
    Nothing ->
      rest

    Just value ->
      (name, encoder value) :: rest