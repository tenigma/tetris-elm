module Matrix exposing (..)

import Svg exposing (..)
import Svg.Attributes exposing (..)
import Types exposing (..)
import Tetromino exposing (Tetromino)
import Dict exposing (Dict)


type alias Matrix =
    { width : Int
    , height : Int
    , blocks : Blocks
    }


type alias Falling =
    { tetromino : Tetromino
    , rotation : Rotation
    , offset : Offset
    }


newFalling : Matrix -> Tetromino -> Falling
newFalling matrix tetromino =
    Falling tetromino R0 (spawnOffset matrix tetromino)


spawnOffset : Matrix -> Tetromino -> Offset
spawnOffset matrix tetromino =
    let
        col =
            (matrix.width - tetromino.size) // 2
    in
        ( 0, col )


type ValidationResult
    = Valid
    | OutOfMatrix
    | BlockIntersection


isValid : Matrix -> Falling -> Bool
isValid matrix falling =
    let
        intersects =
            matrix.blocks
                |> Dict.keys
                |> List.any (\pos -> blocks falling |> Dict.member pos)

        inMatrix =
            blocks falling
                |> Dict.filter (\( row, col ) _ -> row >= matrix.height || col < 0 || col >= matrix.width)
                |> Dict.isEmpty
    in
        inMatrix && not intersects


type alias Transformation =
    Falling -> Falling


blocks : Falling -> Blocks
blocks falling =
    Tetromino.blocks falling.offset falling.rotation falling.tetromino


rotateLeft : Matrix -> Falling -> Maybe Falling
rotateLeft matrix falling =
    let
        rotation =
            case falling.rotation of
                R0 ->
                    RL

                RL ->
                    R2

                R2 ->
                    RR

                RR ->
                    R0

        next =
            { falling | rotation = rotation }
    in
        if isValid matrix next then
            Just next
        else
            Nothing


rotateRight : Matrix -> Falling -> Maybe Falling
rotateRight matrix falling =
    let
        rotation =
            case falling.rotation of
                R0 ->
                    RR

                RR ->
                    R2

                R2 ->
                    RL

                RL ->
                    R0

        next =
            { falling | rotation = rotation }
    in
        if isValid matrix next then
            Just next
        else
            Nothing


moveLeft : Matrix -> Falling -> Maybe Falling
moveLeft matrix falling =
    let
        next =
            { falling | offset = addOffset ( 0, -1 ) falling.offset }
    in
        if isValid matrix next then
            Just next
        else
            Nothing


moveRight : Matrix -> Falling -> Maybe Falling
moveRight matrix falling =
    let
        next =
            { falling | offset = addOffset ( 0, 1 ) falling.offset }
    in
        if isValid matrix next then
            Just next
        else
            Nothing


moveDown : Matrix -> Falling -> Maybe Falling
moveDown matrix falling =
    let
        next =
            { falling | offset = addOffset ( 1, 0 ) falling.offset }
    in
        if isValid matrix next then
            Just next
        else
            Nothing


softDrop : Matrix -> Falling -> Maybe ( Int, Falling )
softDrop matrix valid =
    let
        loop matrix valid count =
            case ( count, moveDown matrix valid ) of
                ( cnt, Just next ) ->
                    loop matrix next (cnt + 1)

                ( 0, Nothing ) ->
                    Nothing

                ( cnt, Nothing ) ->
                    Just ( count, valid )
    in
        loop matrix valid 0


defaultSize : { width : Int, height : Int }
defaultSize =
    { width = 10, height = 22 }


empty : Matrix
empty =
    (Matrix defaultSize.width defaultSize.height Dict.empty)


addBlocks : Falling -> Matrix -> Matrix
addBlocks falling matrix =
    { matrix | blocks = matrix.blocks |> Dict.union (blocks falling) }


removeFullLines : Matrix -> ( Int, Matrix )
removeFullLines matrix =
    let
        ( full, rest ) =
            matrix
                |> toList
                |> List.partition (\row -> countFull row == matrix.width)

        countFull row =
            List.filterMap identity row
                |> List.length

        count =
            List.length full

        emptyRow =
            List.repeat matrix.width Nothing

        emptyLines =
            List.repeat count emptyRow
    in
        ( count, fromList (List.append emptyLines rest) )


toList : Matrix -> List (List (Maybe Color))
toList { width, height, blocks } =
    List.range 0 (height - 1)
        |> List.map
            (\row ->
                List.range 0 (width - 1)
                    |> List.map (\col -> Dict.get ( row, col ) blocks)
            )


fromList : List (List (Maybe Color)) -> Matrix
fromList list =
    let
        height =
            List.length list

        width =
            List.head list |> Maybe.map List.length |> Maybe.withDefault 0

        transformRow row cells =
            cells
                |> List.indexedMap (\col cell -> cell |> Maybe.map ((,) ( row, col )))

        blocks =
            list
                |> List.indexedMap (,)
                |> List.concatMap (uncurry transformRow)
                |> List.filterMap identity
                |> Dict.fromList
    in
        Matrix width height blocks


vals : List Int -> String
vals values =
    values |> List.map toString |> String.join " "


nothing : Svg msg
nothing =
    g [] []


viewMatrix : Settings -> Int -> Matrix -> Maybe Falling -> Svg msg
viewMatrix settings cellSize matrix falling =
    let
        w =
            toString <| matrix.width * cellSize

        h =
            toString <| matrix.height * cellSize
    in
        svg
            [ width w
            , height h
            , viewBox <| vals [ 0, 0, matrix.width, matrix.height ]
            ]
            [ viewGrid matrix.width matrix.height
            , viewBlocks matrix.blocks
            , falling |> Maybe.map viewFalling |> Maybe.withDefault nothing
            , falling |> Maybe.map (viewShadow settings.shadow matrix) |> Maybe.withDefault nothing
            ]


viewGrid : Int -> Int -> Svg msg
viewGrid gridWidth gridHeight =
    let
        viewCell row col =
            rect
                [ x <| toString col
                , y <| toString row
                , width "1"
                , height "1"
                , color "black"
                , stroke "gray"
                , strokeWidth "0.02"
                ]
                []

        viewRow width row =
            g [] (List.range 0 (gridWidth - 1) |> List.map (viewCell row))
    in
        g [] (List.range 0 (gridHeight - 1) |> List.map (viewRow width))


viewFalling : Falling -> Svg msg
viewFalling falling =
    let
        viewDebug =
            rect
                [ x <| toString (Tuple.second falling.offset)
                , y <| toString (Tuple.first falling.offset)
                , width <| toString falling.tetromino.size
                , height <| toString falling.tetromino.size
                , fill "none"
                , stroke "red"
                , strokeWidth "0.1"
                ]
                []
    in
        g []
            [ Tetromino.blocks falling.offset falling.rotation falling.tetromino
                |> viewBlocks
              --, viewDebug
            ]


shadowColor : Color
shadowColor =
    "dimgray"


viewShadow : Shadow -> Matrix -> Falling -> Svg msg
viewShadow shadow matrix falling =
    let
        maybeShadow =
            case shadow of
                None ->
                    Nothing

                _ ->
                    softDrop matrix falling

        mapShadow _ color =
            case shadow of
                Gray ->
                    "gray"

                Color ->
                    color

                _ ->
                    color
    in
        case maybeShadow of
            Just ( _, shadow ) ->
                g [ fillOpacity "0.5" ]
                    [ Tetromino.blocks shadow.offset shadow.rotation shadow.tetromino
                        |> Dict.map mapShadow
                        |> viewBlocks
                    ]

            Nothing ->
                g [] []


viewBlocks : Blocks -> Svg msg
viewBlocks blocks =
    g []
        (blocks
            |> Dict.toList
            |> List.map viewBlock
        )


viewBlock : ( Offset, Color ) -> Svg msg
viewBlock ( ( row, col ), color ) =
    rect
        [ x <| toString (toFloat col + 0.05)
        , y <| toString (toFloat row + 0.05)
        , width "0.9"
        , height "0.9"
        , fill color
        ]
        []


viewSample : Settings -> Int -> Svg msg
viewSample settings cellSize =
    let
        t =
            Tetromino.tetrominoI

        sample =
            empty
                |> addBlocks (Falling t R0 ( 1, 3 ))
                |> addBlocks (Falling t RR ( 2 + t.size, 3 ))
                |> addBlocks (Falling t R2 ( 3 + 2 * t.size, 3 ))
                |> addBlocks (Falling t RL ( 4 + 3 * t.size, 3 ))
    in
        viewMatrix settings cellSize sample Nothing
