module Main exposing (main)

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Html.Lazy
import Json.Decode
import String
import Task
import Gmap

main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias Model =
    { ui : UiType
    , gmap : Maybe Gmap.Model
    , clicked : Maybe Gmap.LatLng
    }


type UiType
  = Map
  | Text


init : ( Model, Cmd Msg )
init =
    ( { ui = Map, gmap = Nothing, clicked = Nothing }
    , Gmap.initial (Gmap.GmapOpts (Gmap.LatLng 63 63) "cooperative" 10 True True) GmapInit
    )


type Msg
    = ToUi UiType
    | GmapInit (Result Gmap.Error Gmap.Model)
    | GmapClicked Gmap.LatLng
    | GmapGeocode (Result Gmap.Error Gmap.GeocodeResults)
    | GmapCircles (Result Gmap.Error Gmap.Circles)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    ToUi ui ->
      case ui of
        Map ->
          ({model | ui = ui}, Cmd.none)

        _ ->
          ({model | ui = ui}, Cmd.none)

    GmapInit (Ok gmapModel) ->
      ( {model | gmap = Just gmapModel}
      , Gmap.geocode gmapModel (Gmap.GeocodeRequest (Gmap.Address "Москва") Nothing Nothing Nothing) GmapGeocode
      )

    GmapInit (Err _) ->
      (model, Cmd.none)

    GmapClicked latLng ->
      ( {model | clicked = Just latLng}
      , model.gmap
        |> Maybe.map (\v ->
          Gmap.geocode v (Gmap.GeocodeRequest (Gmap.Location latLng) Nothing Nothing Nothing) GmapGeocode
        )
        |> Maybe.withDefault Cmd.none
      )

    GmapGeocode (Ok []) ->
      (model, Cmd.none)

    GmapGeocode (Ok results)->
      let
        bounds =
          results
            |> List.filterMap (\i ->
              let
                addresses =
                  i.address_components
                    |> List.filter (\a ->
                      a.types
                        |> List.filter (\t ->
                          (String.startsWith "sublocality" t) || (String.startsWith "administrative_area_level" t)
                        )
                        |> List.length
                        |> (<) 0
                    )
              in
                case addresses of
                  [] ->
                    Nothing

                  _ ->
                    Just {i | address_components = addresses}
            )
            |> List.filterMap (\i -> i.geometry.bounds)
      in
        case bounds of
          [] ->
            (model, Cmd.none)

          first :: rest ->
            let
              circle = Gmap.boundsToCircle first
              circles =
                [
                  { circle | strokeColor = "#ff0000", fillColor = "#000000", fillOpacity = 0.1 }
                ]
            in
              ( model,
                model.gmap
                  |> Maybe.map (\gmap ->
                    Gmap.setCirclesTask gmap circles
                      |> Task.andThen (\result ->
                        Gmap.setBoundsTask gmap first
                          |> Task.andThen (\_ -> Task.succeed result)
                          |> Task.onError (\_ -> Task.succeed result)
                      )
                      |> Task.attempt GmapCircles
                  )
                  |> Maybe.withDefault Cmd.none
              )



    GmapGeocode (Err reason) ->
      let
        _ = Debug.log "reason" reason
      in
        (model, Cmd.none)

    GmapCircles data ->
      let
        _ = Debug.log "GmapCircles" data
      in
        (model, Cmd.none)


view : Model -> Html Msg
view model =
  let
    btns =
      Html.div []
        [ Html.button [Html.Events.onClick <| ToUi Map] [Html.text "To map"]
        , Html.button [Html.Events.onClick <| ToUi Text] [Html.text "To text"]
        ]
  in
    case model.ui of
      Map ->
        Html.div []
          [ Html.text <| "Gmap example" ++ (
            model.clicked
              |> Maybe.map (\v -> " (" ++ (toString v.lat) ++ ", " ++ (toString v.lng) ++ ")")
              |> Maybe.withDefault ""
            )
          , btns
          , model.gmap
              |> Maybe.map mapView
              |> Maybe.withDefault (Html.text "Loading")
          ]

      _ ->
        Html.div []
          [ Html.text "Gmap example"
          , btns
          , Html.div [] [Html.text "Text Ui"]
          ]


mapView : Gmap.Model -> Html Msg
mapView model =
  Gmap.toHtml model
    [ Html.Attributes.style [("width", "300px"), ("height", "300px")]
    ]


subscriptions : Model -> Sub Msg
subscriptions model =
  case model.gmap of
    Nothing ->
      Sub.none

    Just gmap ->
      Sub.batch
        [ Gmap.onClick gmap GmapClicked ]