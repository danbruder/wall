module Components.Chat exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


view config =
    section [ attribute "aria-labelledby" "notes-title" ]
        [ div [ class "bg-white shadow sm:rounded-lg sm:overflow-hidden" ]
            [ div [ class "divide-y divide-gray-200" ]
                [ div [ class "px-4 py-5 sm:px-6" ]
                    [ h2 [ class "text-lg font-medium text-gray-900", id "notes-title" ]
                        [ text "Chat" ]
                    ]
                , div [ class "px-4 py-6 sm:px-6" ]
                    [ config.messages
                        |> List.map viewMessage
                        |> ul [ class "space-y-8" ]
                    ]
                ]
            , div [ class "bg-gray-50 px-4 py-6 sm:px-6" ]
                [ div [ class "flex space-x-3" ]
                    [ div [ class "flex-shrink-0" ]
                        [ div [ alt "", class "h-10 w-10 rounded-full bg-yellow-600 flex justify-center items-center text-white" ]
                            [ text "?" ]
                        ]
                    , div [ class "min-w-0 flex-1" ]
                        [ Html.form [ onSubmit config.handleSubmit ]
                            [ div []
                                [ label [ class "sr-only", for "comment" ]
                                    [ text "About" ]
                                , input
                                    [ onInput config.handleInput
                                    , value config.draft
                                    , class
                                        "p-4 shadow-sm block w-full focus:ring-yellow-500 focus:border-yellow-500 sm:text-sm border-gray-300 rounded-md"
                                    , id "comment"
                                    , placeholder "Message"
                                    , type_ "text"
                                    ]
                                    []
                                ]
                            , div [ class "mt-3 flex items-center justify-between" ]
                                [ a [ class "group inline-flex items-start text-sm space-x-2 text-gray-500 hover:text-gray-900", href "#" ]
                                    []
                                , button [ class "inline-flex items-center justify-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-yellow-600 hover:bg-yellow-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500", type_ "submit" ]
                                    [ text "Send" ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]


viewMessage message =
    li []
        [ div [ class "flex space-x-3" ]
            [ div [ class "flex-shrink-0" ]
                [ div [ alt "", class "h-10 w-10 rounded-full bg-yellow-600 flex justify-center items-center text-white" ]
                    [ text "?" ]
                ]
            , div []
                [ div [ class "text-sm" ]
                    [ a [ class "font-medium text-gray-900", href "#" ]
                        [ text "User 1" ]
                    ]
                , div [ class "mt-1 text-sm text-gray-700" ]
                    [ p []
                        [ text message ]
                    ]
                ]
            ]
        ]
