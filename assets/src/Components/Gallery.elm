module Components.Gallery exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


view config =
    section []
        [ div [ class "md:flex flex-wrap" ] <| List.map viewPhoto <| config.urls
        ]


viewPhoto url =
    div [ class "p-2" ]
        [ img [ src url, class "rounded-lg shadow-lg md:w-64" ] []
        ]
