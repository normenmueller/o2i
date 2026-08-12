{-# LANGUAGE OverloadedStrings #-}

-- | Side-effect-free XML 1.0 document type declaration recognition.
module O2I.Adapter.AMX.Internal.XML.DTD
  ( skipDoctypeDeclaration
  ) where

import Data.Char (ord)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX.Internal.XML.Lexical
  ( isXmlNameCharacter
  , isXmlSpace
  , parseQName
  , skipXmlComment
  , skipXmlProcessingInstruction
  , validXmlName
  , validXmlScalar
  , xmlCharacterReference
  )

type XmlParser = Text -> Maybe Text

-- | Consume a complete XML 1.0 document type declaration after
-- @<!DOCTYPE@. Entity declarations and references are recognized but never
-- resolved or expanded.
skipDoctypeDeclaration :: XmlParser
skipDoctypeDeclaration input = do
  afterSpace <- requiredSpace input
  (_, afterName) <- qName afterSpace
  doctypeTail afterName

doctypeTail :: XmlParser
doctypeTail input =
  case Text.uncons input of
    Just (character, _)
      | isXmlSpace character ->
        let remaining = skipSpace input
         in if Text.isPrefixOf "SYSTEM" remaining
                 || Text.isPrefixOf "PUBLIC" remaining
              then externalId remaining >>= doctypeEnd
              else doctypeEnd remaining
    _ -> doctypeEnd input

doctypeEnd :: XmlParser
doctypeEnd input =
  case Text.uncons (skipSpace input) of
    Just ('>', rest) -> Just rest
    Just ('[', rest) -> do
      afterSubset <- internalSubset rest
      Text.stripPrefix ">" (skipSpace afterSubset)
    _ -> Nothing

internalSubset :: XmlParser
internalSubset input
  | Just rest <- Text.stripPrefix "]" input = Just rest
  | Just rest <- Text.stripPrefix "<!--" input =
    skipXmlComment rest >>= internalSubset
  | Just rest <- Text.stripPrefix "<?" input =
    skipXmlProcessingInstruction rest >>= internalSubset
  | Just rest <- Text.stripPrefix "<!ELEMENT" input =
    elementDeclaration rest >>= internalSubset
  | Just rest <- Text.stripPrefix "<!ATTLIST" input =
    attributeListDeclaration rest >>= internalSubset
  | Just rest <- Text.stripPrefix "<!ENTITY" input =
    entityDeclaration rest >>= internalSubset
  | Just rest <- Text.stripPrefix "<!NOTATION" input =
    notationDeclaration rest >>= internalSubset
  | Just rest <- Text.stripPrefix "%" input =
    parameterEntityReference rest >>= internalSubset
  | Just (character, _) <- Text.uncons input
  , isXmlSpace character = internalSubset (skipSpace input)
  | otherwise = Nothing

elementDeclaration :: XmlParser
elementDeclaration input = do
  afterSpace <- requiredSpace input
  (_, afterName) <- xmlName afterSpace
  afterSeparator <- requiredSpace afterName
  afterContent <- contentSpecification afterSeparator
  closeDeclaration afterContent

contentSpecification :: XmlParser
contentSpecification input
  | Just rest <- Text.stripPrefix "EMPTY" input = Just rest
  | Just rest <- Text.stripPrefix "ANY" input = Just rest
  | Just rest <- Text.stripPrefix "(" input =
    let afterSpace = skipSpace rest
     in case Text.stripPrefix "#PCDATA" afterSpace of
          Just afterPcdata -> mixedContent afterPcdata
          Nothing -> modelGroup afterSpace >>= optionalOccurrence
  | otherwise = Nothing

mixedContent :: XmlParser
mixedContent input =
  case Text.uncons (skipSpace input) of
    Just (')', rest) -> Just rest
    Just ('|', rest) -> mixedNames rest
    _ -> Nothing

mixedNames :: XmlParser
mixedNames input = do
  (_, afterName) <- xmlName (skipSpace input)
  case Text.uncons (skipSpace afterName) of
    Just ('|', rest) -> mixedNames rest
    Just (')', rest) -> Text.stripPrefix "*" rest
    _ -> Nothing

modelGroup :: XmlParser
modelGroup input = do
  afterFirst <- contentParticle input
  modelGroupTail (skipSpace afterFirst)

modelGroupTail :: XmlParser
modelGroupTail input =
  case Text.uncons input of
    Just (')', rest) -> Just rest
    Just ('|', rest) -> separatedParticles '|' rest
    Just (',', rest) -> separatedParticles ',' rest
    _ -> Nothing

separatedParticles :: Char -> XmlParser
separatedParticles separator input = do
  afterParticle <- contentParticle (skipSpace input)
  case Text.uncons (skipSpace afterParticle) of
    Just (character, rest)
      | character == separator -> separatedParticles separator rest
    Just (')', rest) -> Just rest
    _ -> Nothing

contentParticle :: XmlParser
contentParticle input =
  case Text.uncons input of
    Just ('(', rest) -> modelGroup (skipSpace rest) >>= optionalOccurrence
    _ -> do
      (_, rest) <- xmlName input
      optionalOccurrence rest

optionalOccurrence :: XmlParser
optionalOccurrence input =
  case Text.uncons input of
    Just (character, rest)
      | character == '?' || character == '*' || character == '+' -> Just rest
    _ -> Just input

attributeListDeclaration :: XmlParser
attributeListDeclaration input = do
  afterSpace <- requiredSpace input
  (_, afterName) <- xmlName afterSpace
  attributeDefinitions afterName

attributeDefinitions :: XmlParser
attributeDefinitions input =
  case Text.uncons input of
    Just ('>', rest) -> Just rest
    Just (character, _)
      | isXmlSpace character ->
        let remaining = skipSpace input
         in case Text.uncons remaining of
              Just ('>', rest) -> Just rest
              _ -> attributeDefinition remaining >>= attributeDefinitions
    _ -> Nothing

attributeDefinition :: XmlParser
attributeDefinition input = do
  (_, afterName) <- xmlName input
  afterNameSpace <- requiredSpace afterName
  afterType <- attributeType afterNameSpace
  afterTypeSpace <- requiredSpace afterType
  defaultDeclaration afterTypeSpace

attributeType :: XmlParser
attributeType input
  | Just rest <- Text.stripPrefix "NOTATION" input = do
    afterSpace <- requiredSpace rest
    nameAlternatives afterSpace
  | Just rest <- Text.stripPrefix "(" input = nmtokenAlternatives rest
  | otherwise = do
    let (token, rest) = Text.span isXmlNameCharacter input
    if token `elem` tokenizedAttributeTypes
      then Just rest
      else Nothing

tokenizedAttributeTypes :: [Text]
tokenizedAttributeTypes =
  [ "CDATA"
  , "ID"
  , "IDREF"
  , "IDREFS"
  , "ENTITY"
  , "ENTITIES"
  , "NMTOKEN"
  , "NMTOKENS"
  ]

nameAlternatives :: XmlParser
nameAlternatives input = do
  afterOpen <- Text.stripPrefix "(" input
  (_, afterName) <- xmlName (skipSpace afterOpen)
  alternatives xmlName afterName

nmtokenAlternatives :: XmlParser
nmtokenAlternatives input = do
  (_, afterToken) <- nmtoken (skipSpace input)
  alternatives nmtoken afterToken

alternatives :: (Text -> Maybe (Text, Text)) -> XmlParser
alternatives item input =
  case Text.uncons (skipSpace input) of
    Just (')', rest) -> Just rest
    Just ('|', rest) -> do
      (_, afterItem) <- item (skipSpace rest)
      alternatives item afterItem
    _ -> Nothing

defaultDeclaration :: XmlParser
defaultDeclaration input
  | Just rest <- Text.stripPrefix "#REQUIRED" input = Just rest
  | Just rest <- Text.stripPrefix "#IMPLIED" input = Just rest
  | Just rest <- Text.stripPrefix "#FIXED" input =
    requiredSpace rest >>= attributeValue
  | otherwise = attributeValue input

entityDeclaration :: XmlParser
entityDeclaration input = do
  afterSpace <- requiredSpace input
  case Text.uncons afterSpace of
    Just ('%', rest) -> parameterEntityDeclaration rest
    _ -> generalEntityDeclaration afterSpace

generalEntityDeclaration :: XmlParser
generalEntityDeclaration input = do
  (_, afterName) <- xmlName input
  afterSpace <- requiredSpace afterName
  afterDefinition <- generalEntityDefinition afterSpace
  closeDeclaration afterDefinition

parameterEntityDeclaration :: XmlParser
parameterEntityDeclaration input = do
  afterPercentSpace <- requiredSpace input
  (_, afterName) <- xmlName afterPercentSpace
  afterNameSpace <- requiredSpace afterName
  afterDefinition <- parameterEntityDefinition afterNameSpace
  closeDeclaration afterDefinition

generalEntityDefinition :: XmlParser
generalEntityDefinition input
  | startsWithQuote input = entityValue input
  | otherwise = do
    afterExternal <- externalId input
    optionalNData afterExternal

parameterEntityDefinition :: XmlParser
parameterEntityDefinition input
  | startsWithQuote input = entityValue input
  | otherwise = externalId input

optionalNData :: XmlParser
optionalNData input =
  case Text.uncons input of
    Just (character, _)
      | isXmlSpace character ->
        let remaining = skipSpace input
         in case Text.stripPrefix "NDATA" remaining of
              Just rest -> do
                afterSpace <- requiredSpace rest
                snd <$> xmlName afterSpace
              Nothing -> Just remaining
    _ -> Just input

notationDeclaration :: XmlParser
notationDeclaration input = do
  afterSpace <- requiredSpace input
  (_, afterName) <- xmlName afterSpace
  afterNameSpace <- requiredSpace afterName
  afterIdentifier <- notationIdentifier afterNameSpace
  closeDeclaration afterIdentifier

notationIdentifier :: XmlParser
notationIdentifier input
  | Just rest <- Text.stripPrefix "SYSTEM" input =
    requiredSpace rest >>= systemLiteral
  | Just rest <- Text.stripPrefix "PUBLIC" input = do
    afterSpace <- requiredSpace rest
    afterPublic <- publicIdLiteral afterSpace
    optionalNotationSystemLiteral afterPublic
  | otherwise = Nothing

optionalNotationSystemLiteral :: XmlParser
optionalNotationSystemLiteral input =
  case Text.uncons input of
    Just (character, _)
      | isXmlSpace character ->
        let remaining = skipSpace input
         in if startsWithQuote remaining
              then systemLiteral remaining
              else Just remaining
    _ -> Just input

externalId :: XmlParser
externalId input
  | Just rest <- Text.stripPrefix "SYSTEM" input =
    requiredSpace rest >>= systemLiteral
  | Just rest <- Text.stripPrefix "PUBLIC" input = do
    afterSpace <- requiredSpace rest
    afterPublic <- publicIdLiteral afterSpace
    requiredSpace afterPublic >>= systemLiteral
  | otherwise = Nothing

systemLiteral :: XmlParser
systemLiteral = quotedLiteral (validXmlScalar . ord)

publicIdLiteral :: XmlParser
publicIdLiteral = quotedLiteral validPubidCharacter

quotedLiteral :: (Char -> Bool) -> XmlParser
quotedLiteral accepted input = do
  (quote, content) <- Text.uncons input
  if quote == '\'' || quote == '"'
    then do
      let (literal, ending) = Text.break (== quote) content
      if Text.all accepted literal
        then snd <$> Text.uncons ending
        else Nothing
    else Nothing

attributeValue :: XmlParser
attributeValue = quotedReferenceValue False

entityValue :: XmlParser
entityValue = quotedReferenceValue True

quotedReferenceValue :: Bool -> XmlParser
quotedReferenceValue allowParameterReferences input = do
  (quote, content) <- Text.uncons input
  if quote == '\'' || quote == '"'
    then referenceValue quote content
    else Nothing
  where
    referenceValue quote remaining =
      let plainCharacter character =
            character /= quote
              && character /= '&'
              && (not allowParameterReferences || character /= '%')
              && (allowParameterReferences || character /= '<')
          (plain, ending) = Text.span plainCharacter remaining
       in if not (Text.all (validXmlScalar . ord) plain)
            then Nothing
            else case Text.uncons ending of
                   Just (character, rest)
                     | character == quote -> Just rest
                     | character == '&' ->
                       reference rest >>= referenceValue quote
                     | character == '%' && allowParameterReferences ->
                       parameterEntityReference rest >>= referenceValue quote
                   _ -> Nothing

reference :: XmlParser
reference input
  | Text.isPrefixOf "#" input = do
    (value, rest) <- xmlCharacterReference input
    if validXmlScalar value
      then Just rest
      else Nothing
  | otherwise = do
    (_, afterName) <- xmlName input
    Text.stripPrefix ";" afterName

parameterEntityReference :: XmlParser
parameterEntityReference input = do
  (_, afterName) <- xmlName input
  Text.stripPrefix ";" afterName

closeDeclaration :: XmlParser
closeDeclaration = Text.stripPrefix ">" . skipSpace

requiredSpace :: XmlParser
requiredSpace input = do
  (character, rest) <- Text.uncons input
  if isXmlSpace character
    then Just (skipSpace rest)
    else Nothing

skipSpace :: Text -> Text
skipSpace = Text.dropWhile isXmlSpace

qName :: Text -> Maybe (Text, Text)
qName input = do
  let (name, rest) = Text.span isXmlNameCharacter input
  case parseQName name of
    Just _ -> Just (name, rest)
    Nothing -> Nothing

xmlName :: Text -> Maybe (Text, Text)
xmlName input = do
  let (name, rest) = Text.span isXmlNameCharacter input
  if validXmlName name
    then Just (name, rest)
    else Nothing

nmtoken :: Text -> Maybe (Text, Text)
nmtoken input =
  let (token, rest) = Text.span isXmlNameCharacter input
   in if Text.null token
        then Nothing
        else Just (token, rest)

startsWithQuote :: Text -> Bool
startsWithQuote input =
  case Text.uncons input of
    Just (character, _) -> character == '\'' || character == '"'
    Nothing -> False

validPubidCharacter :: Char -> Bool
validPubidCharacter character =
  character == ' '
    || character == '\r'
    || character == '\n'
    || isAsciiLetter character
    || isAsciiDigit character
    || Text.any (== character) "-'()+,./:=?;!*#@$_%"

isAsciiLetter :: Char -> Bool
isAsciiLetter character =
  (character >= 'A' && character <= 'Z')
    || (character >= 'a' && character <= 'z')

isAsciiDigit :: Char -> Bool
isAsciiDigit character = character >= '0' && character <= '9'
