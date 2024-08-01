module Main where

import Data.List.Split
import System.IO
import Data.Char
import Debug.Trace

main :: IO ()
main = do
    (jsonFileName, nixFileName) <- getFileNames
    handle <- openFile jsonFileName ReadMode
    contents <- hGetContents handle
    let nixContent = json2nix contents
    writeFile nixFileName nixContent
    hClose handle

getFileNames :: IO (String, String)
getFileNames = do
    putStrLn "--- step 1 of 2 ---"
    putStr "File name: "
    jsonFileName <- getLine
    putStrLn ""
    let nixFileNameSuggestion = jsonFileNameToNixFileName jsonFileName
    putStrLn "--- step 2 of 2 ---"
    putStrLn "Enter a name for the generated nix file"
    putStr ("Nix file name (" ++ nixFileNameSuggestion ++ "): ")
    nixFileName <- getLine
    let nixFileNameResult = if nixFileName == ""
        then nixFileNameSuggestion
        else nixFileName
    return (jsonFileName, nixFileNameResult)

jsonFileNameToNixFileName :: String -> String
jsonFileNameToNixFileName s = let
  parts = splitOn "." s
  in head parts ++ ".nix"

data Value =
  NullValue
  | IntValue Int
  | FloatValue Float
  | BoolValue Bool
  | StringValue String
  | ArrayValue [Value]
  | ObjectValue [ObjectAttribute]

instance Show Value where
  show (NullValue) = "null"
  show (IntValue a) = show a
  show (FloatValue a) = show a
  show (StringValue a) = show a
  show (BoolValue a) = show a
  show (ArrayValue xs) = "[\n" ++ unlines (map showAsNix xs) ++ "]"
  -- show (ObjectValue xs)

data ObjectAttribute = ObjectAttribute String Value

instance Show ObjectAttribute where
  show (ObjectAttribute name value) = name ++ " = " ++ show value

type JsonInput = String
type Nix = String

json2nix :: JsonInput -> Nix
json2nix s = let
  value = parseJson s
  in showAsNix value

showAsNix :: Value -> Nix
showAsNix v = case v of
  StringValue a -> a
  IntValue a -> show a
  NullValue -> "null"
  ArrayValue xs -> "[\n" ++ unlines (map showAsNix xs) ++ "]"
  _ -> "unsupported type"

type Index = Int

parseJson :: JsonInput -> Value
parseJson jsonInput =
  let
    parseObjectAttribute :: JsonInput -> Index -> (ObjectAttribute, Index)
    parseObjectAttribute input i = let
      (name, nextIndex) = parseObjectAttributeName input i
      (value, newIndex) = nextValue input nextIndex
      in (ObjectAttribute name value, newIndex)
    nextValue :: JsonInput -> Index -> (Value, Index)
    nextValue input index = let
      indexChar = input !! index
      in if indexChar `elem` [' ', ',', ';']
         then nextValue jsonInput (index + 1)
         else case indexChar of
                '"' -> let
                  (value, newIndex) = parseString input index
                  in (StringValue value, newIndex)
                'n' -> (NullValue, index + 4)
                '[' -> let
                  parseList :: JsonInput -> Index -> [Value] -> ([Value], Index)
                  parseList input1 i values = let
                    indexChar = input1 !! i
                    in case indexChar of
                      ' ' -> parseList input1 (i + 1) values
                      ',' -> parseList input1 (i + 1) values
                      ']' -> (values, i + 1)
                      _   -> let
                        (value2, index2) = nextValue input1 i
                        in parseList input1 index2  (values ++ [value2])
                    in let
                      (values3, index3) = parseList input (index + 1) []
                      in (ArrayValue values3, index3)
                c -> if isDigit c
                  then let
                    (number, newIndex) = parseInt input index
                    in (IntValue number, newIndex)
                  else (StringValue ("unknown character to parse: " ++ [c]), index + 1)
  in fst (nextValue jsonInput 0)

-- should be extended for float parsing
parseInt :: JsonInput -> Index -> (Int, Index)
parseInt input i = let
  numberString = takeWhile isDigit (drop i input)
  newIndex = i + length numberString
  number = read numberString :: Int
  in (number, newIndex)

parseString :: JsonInput -> Index -> (String, Index)
parseString input i = let
  startAtIndex = snd (splitAt (i + 1) input)
  value = takeWhile (/= '\"') startAtIndex
  in (value, length value + i + 2)

parseObjectAttributeName :: JsonInput -> Index -> (String, Index)
parseObjectAttributeName input i = parseString input i

