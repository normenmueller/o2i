{-# LANGUAGE OverloadedStrings #-}

-- | Shared Inspection harness and purpose-built AMX model builders.
module O2I.Adapter.AMX.Test.Support where

import qualified Data.ByteString as ByteString
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import O2I.Adapter.AMX
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Types (AMXDocument)
import O2I.Adapter.AMX.Internal.XML
import O2I.Inspection
import System.FilePath ((</>))
import Test.Tasty.HUnit (assertFailure)

decodeCodes :: SourceDocument -> [Text]
decodeCodes document =
  case decodeSource document of
    DecodeUnavailable _ defects -> codes amxDecodeDefectSpec defects
    DecodeRejected _ defects -> codes amxDecodeDefectSpec defects
    DecodePassed _ _ -> []
  where
    codes specification =
      map (diagnosticCodeText . specCode . specification . locatedValue)
        . NonEmpty.toList

inspectText :: ViewSelector -> Text -> IO InspectionReport
inspectText selector = inspectBytes selector . encode

inspectBytes :: ViewSelector -> ByteString.ByteString -> IO InspectionReport
inspectBytes selector bytes =
  case inspectSourceDocument amxAdapter selector noInputs (sourceBytes bytes) of
    InspectionCompleted report -> pure report
    InspectionCommandFailed commandError ->
      assertFailure ("unexpected command error: " <> show commandError)

decodeSource ::
     SourceDocument -> DecodeAttempt SourcePosition AMXDecodeDefect AMXDocument
decodeSource = decodeAMX

noInputs :: InspectionInputs
noInputs =
  InspectionInputs
    { strategyInput = Absent
    , collectiveFitInput = Absent
    , readinessInput = Absent
    , evidenceInput = Absent
    }

diagnosticCodes :: InspectionReport -> [Text]
diagnosticCodes =
  map (diagnosticCodeText . diagnosticCode)
    . diagnosticsList
    . reportDiagnostics

viewResolutionId :: InspectionReport -> Maybe Text
viewResolutionId report =
  case reportViewResolution report of
    ViewResolved (ResolvedViewResolution resolved) ->
      Just (resolvedViewId resolved)
    _ -> Nothing

source :: Text -> SourceDocument
source = sourceBytes . encode

sourceBytes :: ByteString.ByteString -> SourceDocument
sourceBytes = sourceDocumentFromBytes "test.archimate" FileSource

encode :: Text -> ByteString.ByteString
encode = TextEncoding.encodeUtf8

validEmptyModel :: Text
validEmptyModel = model "" []

validContextModel :: Text
validContextModel = validContextModelWith [profileProperty]

validEthosModel :: Text
validEthosModel =
  model
    (grouping "ethos" "Ethos" (Text.concat ethosMetadata)
       <> principle "principle" principleMetadata
       <> contextualization "ownership" "ethos" "principle"
       <> view
            "view"
            "Scope"
            (diagramObject "ethos-object" "ethos"
               <> diagramObject "principle-object" "principle"))
    [profileProperty]

validContextModelWith :: [Text] -> Text
validContextModelWith rootProperties =
  validContextModelWithNodePropertiesAndRoot contextMetadata rootProperties

validContextModelWithNodeProperties :: [Text] -> Text
validContextModelWithNodeProperties nodeProperties =
  validContextModelWithNodePropertiesAndRoot nodeProperties [profileProperty]

validContextModelWithNodePropertiesAndRoot :: [Text] -> [Text] -> Text
validContextModelWithNodePropertiesAndRoot nodeProperties rootProperties =
  model
    (grouping "mission" "Mission" (Text.concat nodeProperties)
       <> view "view" "Scope" (diagramObject "object" "mission"))
    rootProperties

obligatedModel :: Text
obligatedModel =
  model
    (grouping "mission" "Mission" (Text.concat contextMetadata)
       <> driver "driver" ""
       <> contextualization "ownership" "mission" "driver"
       <> view "view" "Scope" (diagramObject "object" "mission"))
    [profileProperty]

wrongRelationshipModel :: Text
wrongRelationshipModel =
  model
    (grouping
       "strategy"
       "Strategy"
       (Text.concat (metadata "Context" "Strategy"))
       <> grouping "need" "Need" (Text.concat (metadata "Context" "Need"))
       <> relationship
            "qualifies"
            "AssociationRelationship"
            "qualifies"
            "strategy"
            "need"
            True
       <> connectedView "qualifies" "strategy" "need")
    [profileProperty]

invalidInterpretationModel :: Text
invalidInterpretationModel =
  model
    (grouping "mission" "Mission" (Text.concat contextMetadata)
       <> assessment "kpi" primitiveKpiMetadata
       <> contextualization "ownership" "mission" "kpi"
       <> view "view" "Scope" (diagramObject "object" "mission"))
    [profileProperty]

visualNestingModel :: Text
visualNestingModel =
  model
    (grouping "mission" "Mission" (Text.concat contextMetadata)
       <> driver "driver" primitiveMetadata
       <> view
            "view"
            "Scope"
            (nestedDiagramObjects
               "mission-object"
               "mission"
               "driver-object"
               "driver"))
    [profileProperty]

duplicateOwnershipModel :: Text
duplicateOwnershipModel =
  model
    (grouping "mission-a" "Mission A" (Text.concat contextMetadata)
       <> grouping "mission-b" "Mission B" (Text.concat contextMetadata)
       <> driver "driver" primitiveMetadata
       <> contextualization "ownership-a" "mission-a" "driver"
       <> contextualization "ownership-b" "mission-b" "driver"
       <> view "view" "Scope" (diagramObject "object" "driver"))
    [profileProperty]

ownerlessOwnershipModel :: Text
ownerlessOwnershipModel =
  model
    (grouping "mission-a" "Mission A" (Text.concat contextMetadata)
       <> grouping "mission-b" "Mission B" (Text.concat contextMetadata)
       <> contextualization "ownership" "mission-a" "mission-b"
       <> view "view" "Scope" (diagramObject "object" "mission-b"))
    [profileProperty]

invalidOwnershipModel :: Text
invalidOwnershipModel =
  model
    (driver "driver" primitiveMetadata
       <> contextualization "ownership" "missing" "driver"
       <> view "view" "Scope" (diagramObject "object" "driver"))
    [profileProperty]

invalidMembershipModel :: Text
invalidMembershipModel =
  model
    (grouping "strategy-a" "Strategy A" (Text.concat strategyMetadata)
       <> grouping "strategy-b" "Strategy B" (Text.concat strategyMetadata)
       <> grouping "dimension" "Dimension" structuringMetadata
       <> outcome "key-result" keyResultMetadata
       <> contextualization "dimension-owner" "strategy-a" "dimension"
       <> contextualization "result-owner" "strategy-b" "key-result"
       <> relationship
            "membership"
            "AggregationRelationship"
            "contains"
            "dimension"
            "key-result"
            False
       <> view "view" "Scope" (diagramObject "object" "dimension"))
    [profileProperty]

legacyOwnershipLabelModel :: Text
legacyOwnershipLabelModel =
  model
    (grouping "mission" "Mission" (Text.concat contextMetadata)
       <> driver "driver" primitiveMetadata
       <> relationship
            "legacy-ownership"
            "CompositionRelationship"
            "contains"
            "mission"
            "driver"
            False
       <> view "view" "Scope" (diagramObject "object" "driver"))
    [profileProperty]

validMembershipModel :: Text
validMembershipModel =
  model
    (grouping "measure" "Measure" (Text.concat (metadata "Context" "Measure"))
       <> grouping "dimension" "Dimension" structuringMetadata
       <> assessment "kpi" primitiveKpiMetadata
       <> contextualization "dimension-owner" "measure" "dimension"
       <> contextualization "kpi-owner" "measure" "kpi"
       <> relationship
            "membership"
            "AggregationRelationship"
            "contains"
            "dimension"
            "kpi"
            False
       <> view
            "view"
            "Scope"
            (diagramObject "dimension-object" "dimension"
               <> diagramObject "kpi-object" "kpi"))
    [profileProperty]

unknownRelationModel :: Text
unknownRelationModel =
  model
    (grouping "mission" "Mission" (Text.concat contextMetadata)
       <> grouping "vision" "Vision" (Text.concat visionMetadata)
       <> relationship
            "unknown"
            "InfluenceRelationship"
            "custom-relation"
            "mission"
            "vision"
            False
       <> connectedView "unknown" "mission" "vision")
    [profileProperty]

invalidEndpointModel :: Text
invalidEndpointModel =
  model
    (grouping "ethos" "Ethos" (Text.concat ethosMetadata)
       <> grouping "vision" "Vision" (Text.concat visionMetadata)
       <> relationship
            "grounds"
            "InfluenceRelationship"
            "grounds"
            "ethos"
            "vision"
            False
       <> connectedView "grounds" "ethos" "vision")
    [profileProperty]

connectionModel :: Text -> Text -> Text -> Text
connectionModel relationReference sourceReference targetReference =
  model
    (grouping "left" "Left" (Text.concat contextMetadata)
       <> grouping "right" "Right" (Text.concat (metadata "Context" "Vision"))
       <> relationship
            "relation"
            "InfluenceRelationship"
            "grounds"
            "left"
            "right"
            False
       <> view
            "view"
            "Scope"
            (diagramObjectWithConnection
               "a"
               "left"
               relationReference
               sourceReference
               targetReference
               <> diagramObject "b" "right"))
    [profileProperty]

connectionModelWithRelationship :: Text -> Text -> Text -> Text
connectionModelWithRelationship relationReference persistedSource persistedTarget =
  model
    (grouping "left" "Left" (Text.concat contextMetadata)
       <> grouping "right" "Right" (Text.concat (metadata "Context" "Vision"))
       <> relationship
            "relation"
            "InfluenceRelationship"
            "grounds"
            persistedSource
            persistedTarget
            False
       <> view
            "view"
            "Scope"
            (diagramObjectWithConnection "a" "left" relationReference "a" "b"
               <> diagramObject "b" "right"))
    [profileProperty]

connectedView :: Text -> Text -> Text -> Text
connectedView relationId sourceId targetId =
  view
    "view"
    "Scope"
    (diagramObjectWithConnection
       "source-object"
       sourceId
       relationId
       "source-object"
       "target-object"
       <> diagramObject "target-object" targetId)

model :: Text -> [Text] -> Text
model body rootProperties =
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    <> "<a:model xmlns:a=\"http://www.archimatetool.com/archimate\" "
    <> "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" "
    <> "version=\"5.0.0\">"
    <> "<folder>"
    <> body
    <> "</folder>"
    <> Text.concat rootProperties
    <> "</a:model>"

grouping :: Text -> Text -> Text -> Text
grouping identifier name properties =
  element "Grouping" identifier name properties

driver :: Text -> Text -> Text
driver identifier properties = element "Driver" identifier "Driver" properties

principle :: Text -> Text -> Text
principle identifier properties =
  element "Principle" identifier "Principle" properties

assessment :: Text -> Text -> Text
assessment identifier properties =
  element "Assessment" identifier "KPI" properties

outcome :: Text -> Text -> Text
outcome identifier properties =
  element "Outcome" identifier "Key Result" properties

element :: Text -> Text -> Text -> Text -> Text
element elementTypeName identifier name properties =
  "<element xsi:type=\"a:"
    <> elementTypeName
    <> "\" id=\""
    <> identifier
    <> "\" name=\""
    <> name
    <> "\">"
    <> properties
    <> "</element>"

relationship :: Text -> Text -> Text -> Text -> Text -> Bool -> Text
relationship identifier relationType name sourceId targetId directed =
  "<element xsi:type=\"a:"
    <> relationType
    <> "\" id=\""
    <> identifier
    <> "\" name=\""
    <> name
    <> "\" source=\""
    <> sourceId
    <> "\" target=\""
    <> targetId
    <> "\""
    <> if directed
         then " directed=\"true\"/>"
         else "/>"

-- | Persist one native contextualization and thereby its Context Ownership.
contextualization :: Text -> Text -> Text -> Text
contextualization identifier contextId elementId =
  relationship
    identifier
    "CompositionRelationship"
    "contextualizes"
    contextId
    elementId
    False

view :: Text -> Text -> Text -> Text
view identifier name children =
  "<element xsi:type=\"a:ArchimateDiagramModel\" id=\""
    <> identifier
    <> "\" name=\""
    <> name
    <> "\">"
    <> children
    <> "</element>"

diagramObject :: Text -> Text -> Text
diagramObject identifier target =
  "<child xsi:type=\"a:DiagramObject\" id=\""
    <> identifier
    <> "\" archimateElement=\""
    <> target
    <> "\"/>"

diagramObjectWithConnection :: Text -> Text -> Text -> Text -> Text -> Text
diagramObjectWithConnection identifier target relationId sourceId targetId =
  "<child xsi:type=\"a:DiagramObject\" id=\""
    <> identifier
    <> "\" archimateElement=\""
    <> target
    <> "\"><sourceConnection xsi:type=\"a:Connection\" id=\"connection\" "
    <> "archimateRelationship=\""
    <> relationId
    <> "\" source=\""
    <> sourceId
    <> "\" target=\""
    <> targetId
    <> "\"/></child>"

nestedDiagramObjects :: Text -> Text -> Text -> Text -> Text
nestedDiagramObjects outerId outerTarget innerId innerTarget =
  "<child xsi:type=\"a:DiagramObject\" id=\""
    <> outerId
    <> "\" archimateElement=\""
    <> outerTarget
    <> "\">"
    <> diagramObject innerId innerTarget
    <> "</child>"

property :: Text -> Text -> Text
property key value =
  "<property key=\"" <> key <> "\" value=\"" <> value <> "\"/>"

profileProperty :: Text
profileProperty = property "o2i.profile" "0.2"

metadata :: Text -> Text -> [Text]
metadata kind nodeType =
  [property "o2i.kind" kind, property "o2i.type" nodeType]

contextMetadata :: [Text]
contextMetadata = metadata "Context" "Mission"

ethosMetadata :: [Text]
ethosMetadata = metadata "Context" "Ethos"

visionMetadata :: [Text]
visionMetadata = metadata "Context" "Vision"

strategyMetadata :: [Text]
strategyMetadata = metadata "Context" "Strategy"

primitiveMetadata :: Text
primitiveMetadata = Text.concat (metadata "Primitive" "Driver")

principleMetadata :: Text
principleMetadata = Text.concat (metadata "Primitive" "Principle")

primitiveKpiMetadata :: Text
primitiveKpiMetadata = Text.concat (metadata "Primitive" "KPI")

structuringMetadata :: Text
structuringMetadata =
  Text.concat (metadata "Structuring" "PerformanceDimension")

keyResultMetadata :: Text
keyResultMetadata = Text.concat (metadata "Primitive" "KeyResult")

fixture :: FilePath -> FilePath
fixture path = "tst" </> "data" </> path

stableUnique :: Ord value => [value] -> [value]
stableUnique = go []
  where
    go _ [] = []
    go seen (value:rest)
      | value `elem` seen = go seen rest
      | otherwise = value : go (value : seen) rest
