module Language.JavaScript
    exposing
        ( array
        , arrowFunction
        , block
        , blockComment
        , conciseArrowFunction
        , const
        , function
        , functionCall
        , let_
        , methodCall
        , moduleExports
        , namedFunction
        , object
        , property
        , require
        , return
        , set
        , singleComment
        , string
        , useStrict
        , var
        , variable
        )

import Doc exposing ((|+), Doc)
import Language.JavaScript.Ast as Ast exposing (..)
import Regex exposing (Regex)
import String.Extra


test : Ast.Program
test =
    module_
        [ importModule "abc.js"
        , importAllAs Nothing "tool" "xyz.js"
        , import_
            (Just "defaultVar")
            [ ( "abc", Nothing ), ( "XYZ", Just "xyz" ) ]
            "123.js"
        , exportFrom
            [ ( "abc", Nothing ), ( "XYZ", Just "xyz" ) ]
            "abc.js"
        , exportAllFrom "example.js"
        ]



{- Missing:
   - Patterns
   - Generators, Async Functions, Async Generators

-}
{- Module -}


module_ : List ModuleItem -> Ast.Program
module_ moduleItems =
    Module moduleItems


importModule : ModulePath -> ModuleItem
importModule modulePath =
    ImportItem <| ImportModulePath modulePath


import_ :
    Maybe Identifier
    -> List ( Identifier, Maybe Identifier )
    -> ModulePath
    -> ModuleItem
import_ defaultId imports modulePath =
    ImportItem <|
        Import
            (NamedImport defaultId (List.map importSpecifier imports))
            modulePath


importAllAs :
    Maybe Identifier
    -> Identifier
    -> ModulePath
    -> ModuleItem
importAllAs defaultId importAs modulePath =
    ImportItem <|
        Import (NameSpaceImport defaultId importAs) modulePath


exportFrom :
    List ( Identifier, Maybe Identifier )
    -> ModulePath
    -> ModuleItem
exportFrom exports modulePath =
    ExportItem <|
        ExportFrom (List.map exportSpecifier exports) modulePath


exportAllFrom : ModulePath -> ModuleItem
exportAllFrom modulePath =
    ExportItem <| ExportAllFrom modulePath


exportConst : List ( Identifier, Maybe Expression ) -> ModuleItem
exportConst bindings =
    ExportItem <| DeclarationExport <| LexicalDeclaration <| constDeclaration bindings


exportLet : List ( Identifier, Maybe Expression ) -> ModuleItem
exportLet bindings =
    ExportItem <| DeclarationExport <| LexicalDeclaration <| letDeclaration bindings


exportVar : List ( Identifier, Maybe Expression ) -> ModuleItem
exportVar bindings =
    ExportItem <| VariableStatementExport (List.map binding bindings)


exportFunction :
    Identifier
    -> List ( Identifier, Maybe Expression )
    -> Maybe Identifier
    -> List StatementListItem
    -> ModuleItem
exportFunction identifier fnParameters rest body =
    ExportItem <|
        DeclarationExport <|
            HoistableDeclaration <|
                functionDeclaration identifier fnParameters rest body


exportClass :
    Identifier
    -> Maybe Identifier
    -> List ( Bool, MethodDefinition )
    -> ModuleItem
exportClass identifier extends classElements =
    ExportItem <| DeclarationExport <| classDeclaration identifier extends classElements


exportDefault : Expression -> ModuleItem
exportDefault expression =
    ExportItem <| DefaultExpressionExport expression


exportDefaultFunction :
    Identifier
    -> List ( Identifier, Maybe Expression )
    -> Maybe Identifier
    -> List StatementListItem
    -> ModuleItem
exportDefaultFunction identifier fnParameters rest body =
    ExportItem <|
        DefaultHoistableDeclarationExport <|
            functionDeclaration identifier fnParameters rest body


exportDefaultClass :
    Identifier
    -> Maybe Identifier
    -> List ( Bool, MethodDefinition )
    -> ModuleItem
exportDefaultClass identifier extends classElements =
    ExportItem <|
        DefaultClassDeclarationExport identifier
            (heritage extends)
            (List.map classElement classElements)



-- Module Helpers


importSpecifier :
    ( Identifier, Maybe Identifier )
    -> ImportSpecifier
importSpecifier ( identifier, alias ) =
    alias
        |> Maybe.map (AsImportSpecifier identifier)
        |> Maybe.withDefault (ImportSpecifier identifier)


exportSpecifier : ( Identifier, Maybe Identifier ) -> ExportSpecifier
exportSpecifier ( identifier, alias ) =
    alias
        |> Maybe.map (AsExportSpecifier identifier)
        |> Maybe.withDefault (ExportSpecifier identifier)



{- Statements -}


const : List ( Identifier, Maybe Expression ) -> StatementListItem
const bindings =
    DeclarationItem <| LexicalDeclaration <| constDeclaration bindings


let_ : List ( Identifier, Maybe Expression ) -> StatementListItem
let_ bindings =
    DeclarationItem <| LexicalDeclaration <| letDeclaration bindings


var : List ( Identifier, Maybe Expression ) -> StatementListItem
var bindings =
    StatementItem <| VariableStatement (List.map binding bindings)


function :
    Identifier
    -> List ( Identifier, Maybe Expression )
    -> Maybe Identifier
    -> List StatementListItem
    -> StatementListItem
function identifier fnParameters rest statements =
    DeclarationItem <|
        HoistableDeclaration <|
            functionDeclaration identifier fnParameters rest statements


class :
    Identifier
    -> Maybe Identifier
    -> List ( Bool, MethodDefinition )
    -> StatementListItem
class identifier extends classElements =
    DeclarationItem <|
        ClassDeclaration identifier
            (heritage extends)
            (List.map classElement classElements)



-- Declaration Helper
{- Declarations -}


constDeclaration : List ( Identifier, Maybe Expression ) -> LexicalDeclaration
constDeclaration bindings =
    Const (List.map binding bindings)


letDeclaration : List ( Identifier, Maybe Expression ) -> LexicalDeclaration
letDeclaration bindings =
    Let (List.map binding bindings)


functionDeclaration :
    Identifier
    -> List ( Identifier, Maybe Expression )
    -> Maybe Identifier
    -> List StatementListItem
    -> HoistableDeclaration
functionDeclaration identifier fnParameters rest statements =
    FunctionDeclaration identifier
        (parameters fnParameters rest)
        (Block statements)


classDeclaration :
    Identifier
    -> Maybe Identifier
    -> List ( Bool, MethodDefinition )
    -> Declaration
classDeclaration identifier extends classElements =
    ClassDeclaration identifier
        (heritage extends)
        (List.map classElement classElements)



-- Declaration Helpers


binding : ( Identifier, Maybe Expression ) -> Binding
binding ( identifier, initializer ) =
    IdentifierBinding identifier initializer


parameters :
    List ( Identifier, Maybe Expression )
    -> Maybe Identifier
    -> Parameters
parameters fnParameters rest =
    Parameters
        (List.map parameter fnParameters)
        (Maybe.map BindingRestElementIdentifier rest)


parameter : ( Identifier, Maybe Expression ) -> BindingElement
parameter ( identifier, initializer ) =
    SingleNameBindingElement identifier initializer


heritage : Maybe Identifier -> Heritage
heritage extends =
    case extends of
        Just identifier ->
            Heritage identifier

        nothing ->
            NoHeritage


classElement : ( Bool, MethodDefinition ) -> ClassElement
classElement ( static, methodDefinition ) =
    if static then
        StaticClassMethod methodDefinition
    else
        ClassMethod methodDefinition



{- Statements -}
-- Declarations


varOBS : String -> Doc -> Doc
varOBS variable expression =
    declare "var" variable expression


let_OBS : String -> Doc -> Doc
let_OBS variable expression =
    declare "let" variable expression


constOBS : String -> Doc -> Doc
constOBS variable expression =
    declare "const" variable expression


variable : String -> Doc
variable variable =
    Doc.string variable


set : Doc -> Doc -> Doc
set expression variable =
    variable
        |+ equals
        |+ expression
        |+ semicolon


moduleExports : Doc -> Doc
moduleExports expression =
    variable "module"
        |> property "exports"
        |> set expression


declare : String -> String -> Doc -> Doc
declare label variable expression =
    Doc.string label
        |+ Doc.space
        |+ Doc.string variable
        |+ equals
        |+ expression
        |+ semicolon



-- Functions


functionOBS : List String -> List Doc -> Doc
functionOBS argList statements =
    Doc.string "function"
        |+ declareArgs argList
        |+ block statements


namedFunction : String -> List String -> List Doc -> Doc
namedFunction name argList statements =
    Doc.string "function"
        |+ Doc.space
        |+ Doc.string name
        |+ declareArgs argList
        |+ block statements


arrowFunction : List String -> List Doc -> Doc
arrowFunction argList statements =
    declareArgs argList
        |+ fatArrow
        |+ block statements


conciseArrowFunction : List String -> Doc -> Doc
conciseArrowFunction argList statement =
    declareArgs argList
        |+ fatArrow
        |+ statement


return : Doc -> Doc
return expression =
    Doc.string "return"
        |+ Doc.space
        |+ expression
        |+ semicolon


functionCall : String -> List Doc -> Doc
functionCall name callArgs =
    Doc.string name
        |+ Doc.parens (Doc.join comma callArgs)


methodCall : String -> List Doc -> Doc -> Doc
methodCall name callArgs object =
    object
        |+ dot
        |+ functionCall name callArgs


declareArgs : List String -> Doc
declareArgs argList =
    argList
        |> List.map Doc.string
        |> Doc.join comma
        |> Doc.parens



-- Control Flow


block : List Doc -> Doc
block statements =
    Doc.braces (Doc.join semicolon statements)



-- Other


require : String -> Doc
require path =
    Doc.string "require"
        |+ Doc.parens (string path)



{- Expressions -}
-- Data Types


string : String -> Doc
string value =
    value
        |> String.Extra.replace "'" "\\'"
        |> Doc.string
        |> Doc.squotes


object : List ( String, Doc ) -> Doc
object keyValues =
    keyValues
        |> List.map (uncurry keyValue)
        |> Doc.join comma
        |> Doc.braces


property : String -> Doc -> Doc
property name object =
    if onlyWordChars name then
        object |+ dot |+ Doc.string name
    else
        object |+ Doc.brackets (string name)


onlyWordChars : String -> Bool
onlyWordChars value =
    Regex.contains nonASCIIRegex value


nonASCIIRegex : Regex
nonASCIIRegex =
    Regex.regex "^[_$a-zA-Z\\xA0-\\uFFFF][_$a-zA-Z0-9 -\\uFFFF]*$"


array : List Doc -> Doc
array expressions =
    expressions
        |> Doc.join comma
        |> Doc.brackets


keyValue : String -> Doc -> Doc
keyValue key expression =
    string key
        |+ colon
        |+ expression



-- Other


useStrict : Doc
useStrict =
    string "use strict"
        |+ semicolon



{- Grammar -}


singleComment : String -> Doc
singleComment comment =
    Doc.line
        |+ slash
        |+ slash
        |+ Doc.space
        |+ Doc.string comment
        |+ Doc.line


blockComment : String -> Doc
blockComment comment =
    Doc.surround (Doc.string "/*") (Doc.string "*/") (Doc.string comment)


fatArrow : Doc
fatArrow =
    Doc.string "=>"


comma : Doc
comma =
    Doc.char ','


equals : Doc
equals =
    Doc.char '='


colon : Doc
colon =
    Doc.char ':'


semicolon : Doc
semicolon =
    Doc.char ';'


dot : Doc
dot =
    Doc.char '.'


slash : Doc
slash =
    Doc.char '/'
