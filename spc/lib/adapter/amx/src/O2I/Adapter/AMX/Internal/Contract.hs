{-# LANGUAGE OverloadedStrings #-}

-- | Closed native AMX rule inventory and executable adapter definition.
module O2I.Adapter.AMX.Internal.Contract
  ( AMXAdapterDefect
  , foldAMXAdapterDefect
  , compileAMXAdapter
  ) where

import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Adapter.AMX.Internal.Draft (projectNativeDocument)
import O2I.Adapter.AMX.Internal.Types
import O2I.Adapter.AMX.Internal.XML
import O2I.Operation.Adapter (Adapter, AdapterOccurrence)
import O2I.Operation.Adapter.Authoring

data AMXAdapterDefect
  = AMXIdentifierDefect !AdapterDefinitionDefect
  | AMXDescriptorDefect !AdapterDefinitionDefect
  | AMXRuleDefinitionDefect !AdapterDefinitionDefect
  | AMXCompilationDefect !AdapterCompilationDefect

-- | Consume the closed AMX construction-defect categories without exposing
-- their representation or underlying Operation defects.
foldAMXAdapterDefect ::
     result -> result -> result -> result -> AMXAdapterDefect -> result
foldAMXAdapterDefect identifier descriptor ruleDefinition compilation defect =
  case defect of
    AMXIdentifierDefect _ -> identifier
    AMXDescriptorDefect _ -> descriptor
    AMXRuleDefinitionDefect _ -> ruleDefinition
    AMXCompilationDefect _ -> compilation

compileAMXAdapter :: Either (NonEmpty AMXAdapterDefect) Adapter
compileAMXAdapter = do
  identifier <- first (pure . AMXIdentifierDefect) (mkAdapterId "amx")
  descriptor <-
    first
      (fmap AMXDescriptorDefect)
      (mkAdapterDescriptor
         identifier
         "Archi Model XML"
         "5.0.0-v1"
         "archimate-3.2")
  recognitionRules <- nativeFailureRuleDefinitions "recognition"
  decodeRules <- nativeFailureRuleDefinitions "decode"
  rootRule <- rule rootRuleSpecification
  versionRule <- rule versionRuleSpecification
  first
    (fmap AMXCompilationDefect)
    (compileAdapter
       descriptor
       (definition recognitionRules decodeRules rootRule versionRule))

definition ::
     NativeFailureRules AdapterRuleDefinition
  -> NativeFailureRules AdapterRuleDefinition
  -> AdapterRuleDefinition
  -> AdapterRuleDefinition
  -> AdapterDefinition scope (AdapterBehavior scope)
definition recognitionDefinitions decodeDefinitions rootDefinition versionDefinition =
  behavior
    <$> declareNativeFailureRules recognitionRule recognitionDefinitions
    <*> declareNativeFailureRules decodeRule decodeDefinitions
    <*> decodeRule rootDefinition
    <*> decodeRule versionDefinition
  where
    behavior recognitionRules decodeRules rootRule versionRule =
      adapterBehavior
        (recognize recognitionRules)
        (decode decodeRules rootRule versionRule)

recognize ::
     NativeFailureRules (RecognitionRule scope)
  -> ByteString
  -> RecognitionResult scope
recognize rules bytes =
  case decodeNative bytes of
    Left failure ->
      recognitionFailure
        (recognitionDiagnostic
           (nativeFailureRule failure rules)
           singletonOccurrence
           :| [])
    Right (NativeFormatMatch _) -> recognitionMatch
    Right (NativeFormatMismatch _ _) -> noRecognitionMatch

decode ::
     NativeFailureRules (DecodeRule scope)
  -> DecodeRule scope
  -> DecodeRule scope
  -> ByteString
  -> DecodeResult scope
decode rules rootRule versionRule bytes =
  case decodeNative bytes of
    Left failure ->
      decodeFailure
        (decodeDiagnostic (nativeFailureRule failure rules) singletonOccurrence
           :| [])
    Right (NativeFormatMatch document) ->
      decodedDraft (projectNativeDocument document)
    Right (NativeFormatMismatch _ (NativeDocument root)) ->
      case NonEmpty.nonEmpty diagnostics of
        Just failures -> decodeFailure failures
        Nothing -> decodedDraft (projectNativeDocument (NativeDocument root))
      where diagnostics =
              [ decodeDiagnostic
                rootRule
                (pathOccurrence (nativeElementPath root))
              | nativeElementName root /= expectedRootName
              ]
                <> [ decodeDiagnostic versionRule (versionOccurrence root)
                   | map nativeAttributeValue (lookupAttribute versionName root)
                       /= ["5.0.0"]
                   ]

versionOccurrence :: NativeElement -> NonEmpty AdapterOccurrence
versionOccurrence root =
  case lookupAttribute versionName root of
    attribute:_ -> pathOccurrence (nativeAttributePath attribute)
    [] -> pathOccurrence (nativeElementPath root)

pathOccurrence :: NativePath -> NonEmpty AdapterOccurrence
pathOccurrence path =
  case NonEmpty.nonEmpty (map renderPathStep path)
         >>= eitherToMaybe . nativePath of
    Just sourceLocation -> locatedOccurrence sourceLocation :| []
    Nothing -> singletonOccurrence

renderPathStep :: NativePathStep -> Text
renderPathStep step =
  renderName (nativePathStepName step)
    <> "["
    <> Text.pack (show (nativePathStepOrdinal step))
    <> "]"

renderName :: NativeName -> Text
renderName name =
  maybe "" (\namespace -> "{" <> namespace <> "}") (nativeNameNamespace name)
    <> nativeNameLocal name

eitherToMaybe :: Either failure value -> Maybe value
eitherToMaybe result =
  case result of
    Left _ -> Nothing
    Right value -> Just value

singletonOccurrence :: NonEmpty AdapterOccurrence
singletonOccurrence = unlocatedOccurrence :| []

type RuleSpecification = (Text, Text, Text, Text)

data NativeFailureRules rule = NativeFailureRules
  { inputLimitRule :: !rule
  , depthLimitRule :: !rule
  , elementLimitRule :: !rule
  , attributeLimitRule :: !rule
  , textLimitRule :: !rule
  , utf8Rule :: !rule
  , encodingRule :: !rule
  , facilityRule :: !rule
  , scalarRule :: !rule
  , wellFormednessRule :: !rule
  }

declareNativeFailureRules ::
     (AdapterRuleDefinition -> AdapterDefinition scope rule)
  -> NativeFailureRules AdapterRuleDefinition
  -> AdapterDefinition scope (NativeFailureRules rule)
declareNativeFailureRules declare definitions =
  NativeFailureRules
    <$> declare (inputLimitRule definitions)
    <*> declare (depthLimitRule definitions)
    <*> declare (elementLimitRule definitions)
    <*> declare (attributeLimitRule definitions)
    <*> declare (textLimitRule definitions)
    <*> declare (utf8Rule definitions)
    <*> declare (encodingRule definitions)
    <*> declare (facilityRule definitions)
    <*> declare (scalarRule definitions)
    <*> declare (wellFormednessRule definitions)

nativeFailureRule :: NativeFailure -> NativeFailureRules rule -> rule
nativeFailureRule failure rules =
  case failure of
    InputLimitExceeded _ _ -> inputLimitRule rules
    XmlDepthLimitExceeded _ _ -> depthLimitRule rules
    XmlElementLimitExceeded _ _ -> elementLimitRule rules
    XmlAttributeLimitExceeded _ _ -> attributeLimitRule rules
    XmlTextLimitExceeded _ _ -> textLimitRule rules
    InvalidUtf8 -> utf8Rule rules
    UnsupportedEncoding _ -> encodingRule rules
    UnsupportedXmlFacility -> facilityRule rules
    ForbiddenXmlScalar _ -> scalarRule rules
    MalformedXml -> wellFormednessRule rules

nativeFailureRuleDefinitions ::
     Text
  -> Either
       (NonEmpty AMXAdapterDefect)
       (NativeFailureRules AdapterRuleDefinition)
nativeFailureRuleDefinitions stage =
  traverseNativeFailureRules rule (nativeFailureRuleSpecifications stage)

traverseNativeFailureRules ::
     Applicative effect
  => (left -> effect right)
  -> NativeFailureRules left
  -> effect (NativeFailureRules right)
traverseNativeFailureRules transform definitions =
  NativeFailureRules
    <$> transform (inputLimitRule definitions)
    <*> transform (depthLimitRule definitions)
    <*> transform (elementLimitRule definitions)
    <*> transform (attributeLimitRule definitions)
    <*> transform (textLimitRule definitions)
    <*> transform (utf8Rule definitions)
    <*> transform (encodingRule definitions)
    <*> transform (facilityRule definitions)
    <*> transform (scalarRule definitions)
    <*> transform (wellFormednessRule definitions)

nativeFailureRuleSpecifications :: Text -> NativeFailureRules RuleSpecification
nativeFailureRuleSpecifications stage =
  NativeFailureRules
    { inputLimitRule =
        nativeRule
          "input-byte-limit"
          "Input stays within the AMX byte limit."
          "Use an AMX document within the published byte limit."
    , depthLimitRule =
        nativeRule
          "xml-depth-limit"
          "XML nesting stays within the AMX depth limit."
          "Reduce XML nesting below the published depth limit."
    , elementLimitRule =
        nativeRule
          "xml-element-limit"
          "The XML element count stays within the AMX limit."
          "Use an AMX document within the published element limit."
    , attributeLimitRule =
        nativeRule
          "xml-attribute-limit"
          "The XML attribute count stays within the AMX limit."
          "Use an AMX document within the published attribute limit."
    , textLimitRule =
        nativeRule
          "xml-text-limit"
          "XML text stays within the AMX character limit."
          "Use an AMX document within the published text limit."
    , utf8Rule =
        nativeRule
          "utf8"
          "The input is valid UTF-8."
          "Encode the AMX document as valid UTF-8."
    , encodingRule =
        nativeRule
          "encoding"
          "The XML encoding is UTF-8."
          "Save the AMX document with UTF-8 encoding."
    , facilityRule =
        nativeRule
          "xml-facility"
          "XML uses only side-effect-free facilities supported by the AMX adapter."
          "Use well-formed XML whose DTD, when present, needs no entity expansion or external resolution."
    , scalarRule =
        nativeRule
          "xml-scalar"
          "XML contains only permitted XML 1.0 scalar values."
          "Remove characters forbidden by XML 1.0."
    , wellFormednessRule =
        nativeRule
          "xml-well-formedness"
          "The input is well-formed XML 1.0."
          "Correct the malformed XML structure."
    }
  where
    nativeRule suffix expectation action =
      ( "o2i.amx." <> stage <> "." <> suffix
      , expectation
      , nativeFailureMeaning stage
      , action)

nativeFailureMeaning :: Text -> Text
nativeFailureMeaning stage
  | stage == "recognition" =
    "Recognition distinguishes a clean non-match from an owned native representation that cannot be classified safely."
  | otherwise =
    "Draft projection requires one complete, safely decoded native XML observation."

rootRuleSpecification, versionRuleSpecification :: RuleSpecification
rootRuleSpecification =
  ( "o2i.amx.decode.root-qname"
  , "The document root has expanded name {http://www.archimatetool.com/archimate}model."
  , "The exact root identifies native Archi Model XML independently of prefix spelling."
  , "Use the native Archi model root and namespace.")

versionRuleSpecification =
  ( "o2i.amx.decode.native-version"
  , "The native model root declares exactly one version attribute with value 5.0.0."
  , "The adapter contract is bound to one exact native serialization version."
  , "Save the model with a supported Archi native format version.")

rule ::
     RuleSpecification
  -> Either (NonEmpty AMXAdapterDefect) AdapterRuleDefinition
rule (identifier, expectation, meaning, action) =
  first
    (fmap AMXRuleDefinitionDefect)
    (mkAdapterRuleDefinition identifier expectation meaning action)

versionName :: NativeName
versionName = NativeName Nothing "version"
