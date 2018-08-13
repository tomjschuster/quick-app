module File
    exposing
        ( File
        , add
        , addToList
        , empty
        , emptyDirectory
        , encode
        , new
        , newDirectory
        )

import Json.Encode as JE


-- Types


type File
    = File Name Content
    | Directory Name (List File)


type alias Name =
    String


type alias Content =
    String


type alias Path =
    List Name



-- Build


empty : Name -> File
empty fileName =
    File fileName ""


new : Name -> Content -> File
new fileName fileContent =
    File fileName fileContent


emptyDirectory : Name -> File
emptyDirectory dirName =
    Directory dirName []


newDirectory : Name -> List File -> File
newDirectory dirName files =
    Directory dirName files


add : File -> Path -> File -> Result String File
add newFile path destinationFile =
    case destinationFile of
        File _ _ ->
            Err "Adding a file to non-directory"

        Directory dirName files ->
            case path of
                [] ->
                    Ok (Directory dirName (files ++ [ newFile ]))

                [ "." ] ->
                    Ok (Directory dirName (files ++ [ newFile ]))

                "." :: remainingPath ->
                    add newFile remainingPath destinationFile

                pathName :: remainingPath ->
                    files
                        |> addToList newFile pathName remainingPath
                        |> Result.map (Directory dirName)


addToList : File -> Name -> Path -> List File -> Result String (List File)
addToList newFile pathName remainingPath files =
    let
        ( result, found ) =
            List.foldr
                (\currentFile ( files, added ) ->
                    case ( nameMatches pathName currentFile, added ) of
                        ( True, False ) ->
                            ( Result.map2 (::)
                                (add newFile remainingPath currentFile)
                                files
                            , True
                            )

                        _ ->
                            ( Result.map ((::) currentFile) files, added )
                )
                ( Ok [], False )
                files
    in
    if found then
        result
    else
        emptyDirectory pathName
            |> add newFile remainingPath
            |> Result.map (List.singleton >> (++) files)



-- Query


nameMatches : Name -> File -> Bool
nameMatches nameString file =
    nameString == name file


name : File -> Name
name file =
    case file of
        File name _ ->
            name

        Directory name _ ->
            name



-- Encode


encode : File -> JE.Value
encode file =
    case file of
        File name content ->
            JE.object
                [ ( "type", JE.string "file" )
                , ( "name", JE.string name )
                , ( "content", JE.string content )
                ]

        Directory name files ->
            JE.object
                [ ( "type", JE.string "directory" )
                , ( "name", JE.string name )
                , ( "files", JE.list (List.map encode files) )
                ]
