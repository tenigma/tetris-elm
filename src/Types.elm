module Types exposing (..)

import Dict exposing (Dict)
import Keyboard exposing (KeyCode)


type alias Color =
    String


type alias Offset =
    ( Int, Int )


type alias Size =
    { width : Int
    , height : Int
    }


addOffset : Offset -> Offset -> Offset
addOffset ( x1, y1 ) ( x2, y2 ) =
    ( x1 + x2, y1 + y2 )


subOffset : Offset -> Offset -> Offset
subOffset ( x1, y1 ) ( x2, y2 ) =
    ( x1 - x2, y1 - y2 )


type Rotation
    = R0
    | RR
    | R2
    | RL


type alias Blocks =
    Dict Offset Color


type Key
    = Left
    | Right
    | Up
    | Down
    | Space
    | F2


toKey : KeyCode -> Maybe Key
toKey code =
    --|> Debug.log "KeyCode: "
    case code of
        32 ->
            Just Space

        37 ->
            Just Left

        38 ->
            Just Up

        39 ->
            Just Right

        40 ->
            Just Down

        113 ->
            Just F2

        _ ->
            Nothing


type Shadow
    = None
    | Gray
    | Color


type alias Settings =
    { shadow : Shadow
    }


setShadow : Shadow -> Settings -> Settings
setShadow shadow settings =
    { settings | shadow = shadow }


defaultSettings : Settings
defaultSettings =
    Settings Gray
