port module Pages.Wall exposing (Model, Msg, Params, page)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as D
import Spa.Document exposing (Document)
import Spa.Page as Page exposing (Page)
import Spa.Url as Url exposing (Url)


page : Page Params Model Msg
page =
    Page.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- INIT


type alias Params =
    ()


type alias Model =
    { draft : String
    , messages : List String
    , offlineMessages : List String
    , connected : Bool
    }


init : Url Params -> ( Model, Cmd Msg )
init { params } =
    ( { draft = ""
      , messages = []
      , connected = False
      , offlineMessages = []
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = DraftChanged String
    | Send
    | Recv String
    | Connected
    | Disconnected


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DraftChanged draft ->
            ( { model | draft = draft }
            , Cmd.none
            )

        Send ->
            if model.connected then
                ( { model | draft = "" }, sendMessage model.draft )

            else
                ( { model
                    | offlineMessages = model.offlineMessages ++ [ model.draft ]
                    , draft = ""
                  }
                , Cmd.none
                )

        Recv message ->
            ( { model | messages = model.messages ++ [ message ] }
            , Cmd.none
            )

        Connected ->
            let
                cmds =
                    model.offlineMessages |> List.map sendMessage
            in
            ( { model
                | connected = True
                , offlineMessages = []
              }
            , Cmd.batch cmds
            )

        Disconnected ->
            ( { model | connected = False }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ messageReceiver Recv
        , connected (\_ -> Connected)
        , disconnected (\_ -> Disconnected)
        ]



-- VIEW


view : Model -> Document Msg
view model =
    { title = "Wall"
    , body =
        [ div []
            [ h1 [] [ text "Echo Chat" ]
            , ul []
                (List.map (\msg -> li [] [ text msg ]) model.messages)
            , input
                [ type_ "text"
                , placeholder "Draft"
                , onInput DraftChanged
                , on "keydown" (ifIsEnter Send)
                , value model.draft
                ]
                []
            , button [ onClick Send ] [ text "Send" ]
            ]
        ]
    }


ifIsEnter : msg -> D.Decoder msg
ifIsEnter msg =
    D.field "key" D.string
        |> D.andThen
            (\key ->
                if key == "Enter" then
                    D.succeed msg

                else
                    D.fail "some other key"
            )



-- PORTS


port sendMessage : String -> Cmd msg


port messageReceiver : (String -> msg) -> Sub msg


port connected : (Bool -> msg) -> Sub msg


port disconnected : (Bool -> msg) -> Sub msg
