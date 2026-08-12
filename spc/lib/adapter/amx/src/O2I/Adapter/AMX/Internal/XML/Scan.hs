{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Resource-bounded namespace-aware safety scan before the XML parser.
module O2I.Adapter.AMX.Internal.XML.Scan
  ( DecodeLimits(..)
  , defaultDecodeLimits
  , enforceInputByteLimit
  , scanXmlText
  , hasExpandedRootSignal
  ) where

import Control.Monad (foldM)
import qualified Data.ByteString as ByteString
import Data.Char (ord)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML.DTD (skipDoctypeDeclaration)
import O2I.Adapter.AMX.Internal.XML.Lexical

data DecodeLimits = DecodeLimits
  { maximumInputBytes :: !Int
  , maximumXmlDepth :: !Int
  , maximumXmlElements :: !Int
  , maximumXmlAttributes :: !Int
  , maximumXmlTextCharacters :: !Int
  } deriving (Eq, Show)

defaultDecodeLimits :: DecodeLimits
defaultDecodeLimits =
  DecodeLimits
    { maximumInputBytes = 64 * 1024 * 1024
    , maximumXmlDepth = 128
    , maximumXmlElements = 500000
    , maximumXmlAttributes = 2000000
    , maximumXmlTextCharacters = 32 * 1024 * 1024
    }

enforceInputByteLimit ::
     DecodeLimits -> ByteString.ByteString -> Either NativeFailure ()
enforceInputByteLimit limits bytes =
  checkLimit
    InputLimitExceeded
    (maximumInputBytes limits)
    (ByteString.length bytes)

-- | Validate the XML envelope and return its declared encoding, if present.
scanXmlText :: DecodeLimits -> Text -> Either NativeFailure (Maybe Text)
scanXmlText limits input = do
  Text.foldl'
    (\result character -> result >> validateScalar character)
    (Right ())
    input
  (encoding, content) <-
    case Text.stripPrefix "<?xml" input of
      Just afterPrefix
        | Just (separator, _) <- Text.uncons afterPrefix
        , isXmlSpace separator ->
          case parseXmlDeclaration input of
            Just (declaration, rest) ->
              Right (declarationEncoding declaration, rest)
            Nothing -> Left MalformedXml
      _ -> Right (Nothing, input)
  scanDocument limits initialState content
  pure encoding

-- | Recognize one exact expanded root name without claiming malformed input
-- that precedes the namespace binding establishing adapter ownership.
hasExpandedRootSignal :: Maybe Text -> Text -> Text -> Bool
hasExpandedRootSignal expectedNamespace expectedLocal input =
  case firstRootStart input of
    Nothing -> False
    Just root ->
      let (lexicalName, attributes) = takeName root
       in validQName lexicalName
            && qNameLocal lexicalName == expectedLocal
            && probeAttributes
                 lexicalName
                 expectedNamespace
                 initialProbeState
                 attributes

data ExpandedName =
  ExpandedName !(Maybe Text) !Text
  deriving (Eq, Ord)

data ElementFrame = ElementFrame
  { frameLexicalName :: !Text
  , frameNamespaces :: !(Map Text Text)
  }

data ProbeState = ProbeState
  { probeLexicalNames :: !(Set Text)
  , probeNamespaces :: !(Map Text Text)
  , probeExpandedNames :: !(Set ExpandedName)
  , probePendingNames :: !(Map Text (Set Text))
  , probeOwnsRoot :: !Bool
  }

data ScanState = ScanState
  { scanFrames :: ![ElementFrame]
  , scanDepth :: !Int
  , scanElements :: !Int
  , scanAttributes :: !Int
  , scanTextCharacters :: !Int
  , scanRootSeen :: !Bool
  }

initialState :: ScanState
initialState = ScanState [] 0 0 0 0 False

initialProbeState :: ProbeState
initialProbeState =
  ProbeState Set.empty initialNamespaces Set.empty Map.empty False

xmlNamespace, xmlnsNamespace :: Text
xmlNamespace = "http://www.w3.org/XML/1998/namespace"

xmlnsNamespace = "http://www.w3.org/2000/xmlns/"

initialNamespaces :: Map Text Text
initialNamespaces = Map.singleton "xml" xmlNamespace

scanDocument :: DecodeLimits -> ScanState -> Text -> Either NativeFailure ()
scanDocument limits !state input =
  case Text.uncons input of
    Nothing
      | null (scanFrames state) && scanRootSeen state -> Right ()
      | otherwise -> Left MalformedXml
    Just ('<', rest)
      | Just after <- Text.stripPrefix "!--" rest ->
        maybe
          (Left MalformedXml)
          (scanDocument limits state)
          (skipXmlComment after)
      | Just after <- Text.stripPrefix "![CDATA[" rest ->
        if null (scanFrames state)
          then Left MalformedXml
          else scanCData limits state after
      | Just after <- Text.stripPrefix "?" rest ->
        maybe
          (Left MalformedXml)
          (scanDocument limits state)
          (skipXmlProcessingInstruction after)
      | Just after <- Text.stripPrefix "/" rest ->
        scanClosingTag limits state after
      | Just _ <- Text.stripPrefix "!" rest -> Left UnsupportedXmlFacility
      | otherwise -> scanOpeningTag limits state rest
    Just ('&', rest)
      | null (scanFrames state) -> Left MalformedXml
      | otherwise -> do
        (remaining, scalar) <- scanEntity rest
        validateScalarValue scalar
        state' <- addText limits state
        scanDocument limits state' remaining
    Just (']', rest)
      | Just _ <- Text.stripPrefix "]>" rest -> Left MalformedXml
    Just (character, rest)
      | null (scanFrames state) && not (isXmlSpace character) ->
        Left MalformedXml
      | otherwise ->
        addText limits state >>= \state' -> scanDocument limits state' rest

scanCData :: DecodeLimits -> ScanState -> Text -> Either NativeFailure ()
scanCData limits = go
  where
    go !state remaining
      | Just after <- Text.stripPrefix "]]>" remaining =
        scanDocument limits state after
      | otherwise =
        case Text.uncons remaining of
          Nothing -> Left MalformedXml
          Just (_, after) -> addText limits state >>= \state' -> go state' after

scanClosingTag :: DecodeLimits -> ScanState -> Text -> Either NativeFailure ()
scanClosingTag limits state input = do
  let (name, afterName) = takeName input
      remaining = Text.dropWhile isXmlSpace afterName
  frame <-
    case scanFrames state of
      current:_ -> Right current
      [] -> Left MalformedXml
  if validQName name && name == frameLexicalName frame
    then pure ()
    else Left MalformedXml
  _ <- resolveElementName (frameNamespaces frame) name
  after <- maybe (Left MalformedXml) Right (Text.stripPrefix ">" remaining)
  scanDocument
    limits
    state
      {scanFrames = drop 1 (scanFrames state), scanDepth = scanDepth state - 1}
    after

scanOpeningTag :: DecodeLimits -> ScanState -> Text -> Either NativeFailure ()
scanOpeningTag limits state input = do
  let elements = scanElements state + 1
      depth = scanDepth state + 1
  if null (scanFrames state) && scanRootSeen state
    then Left MalformedXml
    else pure ()
  checkLimit XmlElementLimitExceeded (maximumXmlElements limits) elements
  checkLimit XmlDepthLimitExceeded (maximumXmlDepth limits) depth
  case takeName input of
    (name, remaining)
      | not (validQName name) -> Left MalformedXml
      | otherwise ->
        scanTag
          limits
          state {scanDepth = depth, scanElements = elements}
          name
          Set.empty
          []
          remaining

scanTag ::
     DecodeLimits
  -> ScanState
  -> Text
  -> Set Text
  -> [(Text, Text)]
  -> Text
  -> Either NativeFailure ()
scanTag limits !state elementName !lexicalNames !attributes input =
  case Text.stripPrefix "/>" input of
    Just rest -> finishStartTag limits state elementName attributes True rest
    Nothing ->
      case Text.uncons input of
        Nothing -> Left MalformedXml
        Just ('>', rest) ->
          finishStartTag limits state elementName attributes False rest
        Just (separator, _)
          | isXmlSpace separator -> do
            let remaining = Text.dropWhile isXmlSpace input
            case Text.stripPrefix "/>" remaining of
              Just rest ->
                finishStartTag limits state elementName attributes True rest
              Nothing ->
                case Text.uncons remaining of
                  Just ('>', rest) ->
                    finishStartTag
                      limits
                      state
                      elementName
                      attributes
                      False
                      rest
                  _ -> do
                    let (name, afterName) = takeName remaining
                    if not (validQName name) || Set.member name lexicalNames
                      then Left MalformedXml
                      else do
                        afterEquals <-
                          requireEquals (Text.dropWhile isXmlSpace afterName)
                        (value, afterValue) <-
                          maybe
                            (Left MalformedXml)
                            Right
                            (quotedXmlValue afterEquals)
                        state' <- addAttribute limits state
                        scanTag
                          limits
                          state'
                          elementName
                          (Set.insert name lexicalNames)
                          ((name, value) : attributes)
                          afterValue
        _ -> Left MalformedXml

finishStartTag ::
     DecodeLimits
  -> ScanState
  -> Text
  -> [(Text, Text)]
  -> Bool
  -> Text
  -> Either NativeFailure ()
finishStartTag limits state lexicalName reversedAttributes selfClosing rest = do
  let parentNamespaces =
        case scanFrames state of
          frame:_ -> frameNamespaces frame
          [] -> initialNamespaces
      attributes = reverse reversedAttributes
  namespaces <- foldM applyNamespaceDeclaration parentNamespaces attributes
  _ <- resolveElementName namespaces lexicalName
  expandedAttributes <-
    traverse
      (resolveAttributeName namespaces . fst)
      (ordinaryAttributes attributes)
  if unique expandedAttributes
    then pure ()
    else Left MalformedXml
  let frame = ElementFrame lexicalName namespaces
      rootSeen = scanRootSeen state || null (scanFrames state)
      frames =
        if selfClosing
          then scanFrames state
          else frame : scanFrames state
      depth =
        if selfClosing
          then scanDepth state - 1
          else scanDepth state
  scanDocument
    limits
    state {scanFrames = frames, scanDepth = depth, scanRootSeen = rootSeen}
    rest

applyNamespaceDeclaration ::
     Map Text Text -> (Text, Text) -> Either NativeFailure (Map Text Text)
applyNamespaceDeclaration namespaces (name, rawValue) =
  case namespaceDeclarationPrefix name of
    Nothing -> Right namespaces
    Just prefix -> do
      value <-
        maybe (Left MalformedXml) Right (normalizeXmlAttributeValue rawValue)
      validateNamespaceBinding prefix value
      pure
        (if Text.null value
           then Map.delete prefix namespaces
           else Map.insert prefix value namespaces)

validateNamespaceBinding :: Text -> Text -> Either NativeFailure ()
validateNamespaceBinding prefix value
  | prefix == "xmlns" = Left MalformedXml
  | value == xmlnsNamespace = Left MalformedXml
  | prefix == "xml" && value /= xmlNamespace = Left MalformedXml
  | prefix /= "xml" && value == xmlNamespace = Left MalformedXml
  | not (Text.null prefix) && Text.null value = Left MalformedXml
  | otherwise = Right ()

resolveElementName :: Map Text Text -> Text -> Either NativeFailure ExpandedName
resolveElementName namespaces lexical =
  case splitQName lexical of
    (Nothing, local) -> Right (ExpandedName (Map.lookup "" namespaces) local)
    (Just "xmlns", _) -> Left MalformedXml
    (Just prefix, local) ->
      case Map.lookup prefix namespaces of
        Just namespace -> Right (ExpandedName (Just namespace) local)
        Nothing -> Left MalformedXml

resolveAttributeName ::
     Map Text Text -> Text -> Either NativeFailure ExpandedName
resolveAttributeName namespaces lexical =
  case splitQName lexical of
    (Nothing, local) -> Right (ExpandedName Nothing local)
    (Just "xmlns", _) -> Left MalformedXml
    (Just prefix, local) ->
      case Map.lookup prefix namespaces of
        Just namespace -> Right (ExpandedName (Just namespace) local)
        Nothing -> Left MalformedXml

ordinaryAttributes :: [(Text, Text)] -> [(Text, Text)]
ordinaryAttributes = filter (not . isNamespaceDeclarationName . fst)

namespaceDeclarationPrefix :: Text -> Maybe Text
namespaceDeclarationPrefix "xmlns" = Just ""
namespaceDeclarationPrefix name = Text.stripPrefix "xmlns:" name

isNamespaceDeclarationName :: Text -> Bool
isNamespaceDeclarationName =
  maybe False (const True) . namespaceDeclarationPrefix

probeAttributes :: Text -> Maybe Text -> ProbeState -> Text -> Bool
probeAttributes lexicalName expectedNamespace = go
  where
    expectedAttribute =
      case fst (splitQName lexicalName) of
        Nothing -> "xmlns"
        Just prefix -> "xmlns:" <> prefix
    go state input =
      case Text.uncons input of
        Just (separator, _)
          | isXmlSpace separator ->
            let remaining = Text.dropWhile isXmlSpace input
             in case Text.uncons remaining of
                  Just ('>', _) -> probeIsEstablished state
                  _
                    | Just _ <- Text.stripPrefix "/>" remaining ->
                      probeIsEstablished state
                    | otherwise ->
                      let (name, afterName) = takeName remaining
                       in if not (validQName name)
                               || Set.member name (probeLexicalNames state)
                            then False
                            else case requireEquals
                                        (Text.dropWhile isXmlSpace afterName) of
                                   Left _ -> False
                                   Right afterEquals ->
                                     case quotedXmlValue afterEquals of
                                       Nothing -> False
                                       Just (rawValue, rest) ->
                                         case normalizeXmlAttributeValue
                                                rawValue of
                                           Nothing -> False
                                           Just value
                                             | name == expectedAttribute ->
                                               case namespaceDeclarationPrefix
                                                      name of
                                                 Nothing -> False
                                                 Just prefix ->
                                                   advanceNamespace
                                                     state
                                                     name
                                                     prefix
                                                     value
                                                     (Just value
                                                        == expectedNamespace)
                                                     rest
                                             | Just prefix <-
                                                 namespaceDeclarationPrefix name ->
                                               advanceNamespace
                                                 state
                                                 name
                                                 prefix
                                                 value
                                                 False
                                                 rest
                                             | otherwise ->
                                               advanceAttribute state name rest
        _ -> False
    advanceNamespace state name prefix value owns rest =
      case validateNamespaceBinding prefix value of
        Left _ -> False
        Right () ->
          case bindProbeNamespace prefix value state of
            Nothing -> False
            Just bound ->
              continue
                bound
                  { probeLexicalNames =
                      Set.insert name (probeLexicalNames bound)
                  , probeOwnsRoot = probeOwnsRoot bound || owns
                  }
                rest
    advanceAttribute state name rest =
      case insertProbeAttribute name state of
        Nothing -> False
        Just observed ->
          continue
            observed
              {probeLexicalNames = Set.insert name (probeLexicalNames observed)}
            rest
    continue state rest
      | probeIsEstablished state = True
      | otherwise = go state rest

probeIsEstablished :: ProbeState -> Bool
probeIsEstablished = probeOwnsRoot

insertProbeAttribute :: Text -> ProbeState -> Maybe ProbeState
insertProbeAttribute lexical state =
  case splitQName lexical of
    (Nothing, local) -> insertExpandedName (ExpandedName Nothing local) state
    (Just prefix, local) ->
      case Map.lookup prefix (probeNamespaces state) of
        Just namespace ->
          insertExpandedName (ExpandedName (Just namespace) local) state
        Nothing ->
          Just
            state
              { probePendingNames =
                  Map.insertWith
                    Set.union
                    prefix
                    (Set.singleton local)
                    (probePendingNames state)
              }

bindProbeNamespace :: Text -> Text -> ProbeState -> Maybe ProbeState
bindProbeNamespace prefix value state = do
  let namespaces =
        if Text.null value
          then Map.delete prefix (probeNamespaces state)
          else Map.insert prefix value (probeNamespaces state)
      pending = Map.findWithDefault Set.empty prefix (probePendingNames state)
      withoutPending =
        state
          { probeNamespaces = namespaces
          , probePendingNames = Map.delete prefix (probePendingNames state)
          }
  foldM
    (\current local ->
       insertExpandedName (ExpandedName (Just value) local) current)
    withoutPending
    pending

insertExpandedName :: ExpandedName -> ProbeState -> Maybe ProbeState
insertExpandedName name state
  | Set.member name (probeExpandedNames state) = Nothing
  | otherwise =
    Just state {probeExpandedNames = Set.insert name (probeExpandedNames state)}

firstRootStart :: Text -> Maybe Text
firstRootStart input
  | Just afterPrefix <- Text.stripPrefix "<?xml" input
  , Just (separator, _) <- Text.uncons afterPrefix
  , isXmlSpace separator = snd <$> parseXmlDeclaration input >>= prolog True
  | otherwise = prolog True input
  where
    prolog allowDoctype remaining = do
      afterOpen <- Text.stripPrefix "<" (Text.dropWhile isXmlSpace remaining)
      case () of
        _
          | Just rest <- Text.stripPrefix "!--" afterOpen ->
            skipXmlComment rest >>= prolog allowDoctype
          | Just rest <- Text.stripPrefix "?" afterOpen ->
            skipXmlProcessingInstruction rest >>= prolog allowDoctype
          | allowDoctype
          , Just rest <- Text.stripPrefix "!DOCTYPE" afterOpen ->
            skipDoctypeDeclaration rest >>= prolog False
          | Just _ <- Text.stripPrefix "!" afterOpen -> Nothing
          | Just _ <- Text.stripPrefix "/" afterOpen -> Nothing
          | otherwise -> Just afterOpen

qNameLocal :: Text -> Text
qNameLocal = snd . splitQName

splitQName :: Text -> (Maybe Text, Text)
splitQName lexical =
  case Text.breakOn ":" lexical of
    (prefix, rest)
      | not (Text.null prefix) && not (Text.null rest) ->
        (Just prefix, Text.drop 1 rest)
    _ -> (Nothing, lexical)

takeName :: Text -> (Text, Text)
takeName = Text.span isXmlNameCharacter

requireEquals :: Text -> Either NativeFailure Text
requireEquals input =
  case Text.uncons input of
    Just ('=', remaining) -> Right (Text.dropWhile isXmlSpace remaining)
    _ -> Left MalformedXml

scanEntity :: Text -> Either NativeFailure (Text, Int)
scanEntity input =
  case xmlCharacterReference input of
    Just (value, rest) -> Right (rest, value)
    Nothing -> Left UnsupportedXmlFacility

validateScalar :: Char -> Either NativeFailure ()
validateScalar = validateScalarValue . ord

validateScalarValue :: Int -> Either NativeFailure ()
validateScalarValue value
  | validXmlScalar value = Right ()
  | otherwise = Left (ForbiddenXmlScalar value)

addAttribute :: DecodeLimits -> ScanState -> Either NativeFailure ScanState
addAttribute limits state = do
  let observed = scanAttributes state + 1
  checkLimit XmlAttributeLimitExceeded (maximumXmlAttributes limits) observed
  pure state {scanAttributes = observed}

addText :: DecodeLimits -> ScanState -> Either NativeFailure ScanState
addText limits state = do
  let observed = scanTextCharacters state + 1
  checkLimit XmlTextLimitExceeded (maximumXmlTextCharacters limits) observed
  pure state {scanTextCharacters = observed}

unique :: Ord value => [value] -> Bool
unique values = Set.size (Set.fromList values) == length values

checkLimit ::
     (Int -> Int -> NativeFailure) -> Int -> Int -> Either NativeFailure ()
checkLimit defect limit observed
  | observed <= limit = Right ()
  | otherwise = Left (defect limit observed)
