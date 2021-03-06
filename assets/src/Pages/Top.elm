port module Pages.Top exposing (Model, Msg, Params, page)

import Components.Chat as Chat
import Components.Gallery as Gallery
import File exposing (File)
import File.Select as Select
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as JD
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
    , uploadedUrls : List String
    , users : List String
    }


init : Url Params -> ( Model, Cmd Msg )
init { params } =
    ( { draft = ""
      , messages = []
      , connected = False
      , offlineMessages = []
      , uploadedUrls = []
      , users = []
      }
    , getExisting
    )



-- UPDATE


type Msg
    = DraftChanged String
    | UploadedFile (Result Http.Error ())
    | SelectedFiles File (List File)
    | ClickedSelectFiles
    | Send
    | GotMessage (Maybe Message)
    | GotExistingMessages (Result Http.Error (List (Maybe Message)))
    | Connected
    | Disconnected


type Message
    = ChatMessage String
    | NewUploadMessage (List String)
    | GotUsers (List String)


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

        GotExistingMessages response ->
            case response of
                Ok messages ->
                    ( messages
                        |> List.filterMap dropUserMsgs
                        |> List.foldl (\item acc -> handleMessage item acc) model
                    , Cmd.none
                    )

                Err err ->
                    ( model, Cmd.none )

        GotMessage message ->
            ( handleMessage message model, Cmd.none )

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

        ClickedSelectFiles ->
            ( model, requestImages )

        SelectedFiles file files ->
            ( model, file :: files |> upload )

        UploadedFile _ ->
            ( model, Cmd.none )


handleMessage message model =
    case message of
        Just (ChatMessage msg) ->
            { model | messages = model.messages ++ [ msg ] }

        Just (NewUploadMessage uploads) ->
            { model | uploadedUrls = model.uploadedUrls ++ uploads }

        Just (GotUsers userIds) ->
            { model | users = userIds }

        Nothing ->
            model


dropUserMsgs message =
    case message of
        Just (GotUsers _) ->
            Nothing

        msg ->
            Just msg


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ messageReceiver decodeMessagePayload
        , connected (\_ -> Connected)
        , disconnected (\_ -> Disconnected)
        ]


decodeMessage =
    JD.oneOf
        [ JD.map (ChatMessage >> Just) JD.string
        , JD.map (NewUploadMessage >> Just) (JD.field "uploaded" (JD.list JD.string))
        , JD.map (GotUsers >> Just) (JD.field "users" (JD.list JD.string))
        , JD.succeed Nothing
        ]


decodeMessagePayload : String -> Msg
decodeMessagePayload message =
    case JD.decodeString decodeMessage message of
        Ok m ->
            GotMessage m

        Err err ->
            GotMessage Nothing


decodeMessagePayloadAgainLol : String -> Maybe Message
decodeMessagePayloadAgainLol message =
    case JD.decodeString decodeMessage message of
        Ok m ->
            m

        Err err ->
            Nothing



-- VIEW


view : Model -> Document Msg
view model =
    { title = "Wall"
    , body =
        [ div [ class "p-12" ]
            [ h1 [ class "text-xl" ] [ text "Photo wall of greatness" ]
            , div [] [ text ("Current users: " ++ (model.users |> List.length |> String.fromInt)) ]
            , div [ class "flex justify-center my-12" ]
                [ button [ class "inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-yellow-600 hover:bg-yellow-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500", onClick ClickedSelectFiles ] [ text "Upload" ]
                ]
            , Gallery.view
                { urls = model.uploadedUrls
                }
            , div [ class "mt-12" ]
                [ Chat.view
                    { handleSubmit = Send
                    , handleInput = DraftChanged
                    , messages = model.messages
                    , draft = model.draft
                    }
                ]
            ]
        ]
    }



-- PORTS


port sendMessage : String -> Cmd msg


port messageReceiver : (String -> msg) -> Sub msg


port connected : (Bool -> msg) -> Sub msg


port disconnected : (Bool -> msg) -> Sub msg



-- FILE STUFF


upload : List File -> Cmd Msg
upload files =
    Http.request
        { method = "POST"
        , headers = []
        , url = "/upload"
        , body =
            files
                |> List.map (Http.filePart "files[]")
                |> Http.multipartBody
        , expect = Http.expectWhatever UploadedFile
        , timeout = Nothing
        , tracker = Nothing
        }


getExisting : Cmd Msg
getExisting =
    Http.get
        { url = "/messages"
        , expect =
            Http.expectJson GotExistingMessages
                (JD.field "existing_messages"
                    (JD.list
                        (JD.string
                            |> JD.andThen (decodeMessagePayloadAgainLol >> JD.succeed)
                        )
                    )
                )
        }


requestImages : Cmd Msg
requestImages =
    Select.files [ "image/png", "image/jpg" ] SelectedFiles
