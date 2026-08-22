{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main
  ( main
  ) where

import Data.List (sort)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Core.Contract
import O2I.Core.Contract.Internal (structureRuleIds)
import O2I.Core.Graph.Observation
import O2I.Core.Identity
import O2I.Structure hiding (StructureAssessment)
import qualified O2I.Structure.Index as StructureIndex
import O2I.Structure.Internal
  ( CollectiveParticipantCardinalityEvidence(..)
  , CollectiveParticipantTypeEvidence(..)
  , CollectiveParticipantUniquenessEvidence(..)
  , CollectiveTargetCardinalityEvidence(..)
  , CollectiveTargetDistinctnessEvidence(..)
  , CollectiveTargetTypeEvidence(..)
  , ContextualizationSourceCategoryEvidence(..)
  , ContextualizationTargetCategoryEvidence(..)
  , ContextualizationTargetOwnerCardinalityEvidence(..)
  , QualifiedEndpointCatalogMembershipEvidence(..)
  , SemanticRelationCompatibilityEvidence(..)
  , StructureAssessment(..)
  , StructureDefect(..)
  , StructureRule(..)
  , StructureZeroOrMultipleOccurrences(..)
  , StructuredPropositionIdentityEvidence(..)
  , foldStructureDefect
  , structureDefectRule
  , structureRuleId
  )
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

main :: IO ()
main =
  defaultMain
    (testGroup
       "selected-View Structure"
       [ acceptedProjectionIsCanonical
       , inputBoundaryIsComplete
       , contextualizationRulesAreAtomic
       , endpointAndRelationRulesAreExact
       , collectiveFamilyRulesAreComplete
       , duplicateHeavyClaimIdentityEvidenceIsLinear
       , structureDefectAlgebraIsExact
       , cardinalityEvidenceIsExact
       , structureRuleOwnershipIsExact
       ])

acceptedProjectionIsCanonical :: TestTree
acceptedProjectionIsCanonical =
  testCase "accepts and canonically enumerates a valid projection" $ do
    snapshot canonicalProjection canonicalSelected
      @?= snapshot
            (reverseProjection canonicalProjection)
            (reverse canonicalSelected)
    snapshot canonicalProjection canonicalSelected @?= Right expectedSnapshot

inputBoundaryIsComplete :: TestTree
inputBoundaryIsComplete =
  testCase "reports exact projection-boundary defects before model rules" $ do
    inputDefects outsideProjection [carrierA]
      @?= [ProjectionOutsideSelectedView carrierB]
    inputDefects duplicateProjection [carrierA]
      @?= [ DuplicateStructureProjection
              carrierA
              (CarrierProjectionKind
                 NonEmpty.:| [StructuredPropositionProjectionKind])
          ]
    inputDefects missingCarrierProjection missingCarrierSelected
      @?= [ MissingCarrierProjection
              relationOccurrence
              RelationTargetRole
              carrierB
          ]
    inputDefects missingPropositionProjection missingPropositionSelected
      @?= [ MissingStructuredPropositionProjection
              incidenceParticipantA
              propositionOccurrence
          ]

contextualizationRulesAreAtomic :: TestTree
contextualizationRulesAreAtomic =
  testCase "separates category, ownership, and catalog defects" $ do
    ruleIds
      invalidContextualizationSource
      invalidContextualizationSourceSelected
      `containsRule` "core.contextualization.source-category"
    ruleIds
      invalidContextualizationTarget
      invalidContextualizationTargetSelected
      `containsRule` "core.contextualization.target-category"
    ruleIds missingContextOwner missingContextOwnerSelected
      @?= ["core.contextualization.target-owner-cardinality"]
    ruleIds invalidDirectEndpoint invalidDirectEndpointSelected
      @?= ["core.qualified-endpoint.catalog-membership"]

endpointAndRelationRulesAreExact :: TestTree
endpointAndRelationRulesAreExact =
  testCase "rejects one incompatible binary semantic relation" $ do
    ruleIds incompatibleRelation incompatibleRelationSelected
      @?= ["core.semantic-relation.compatibility"]

collectiveFamilyRulesAreComplete :: TestTree
collectiveFamilyRulesAreComplete =
  testCase "validates every admitted collective family invariant" $ do
    ruleIdsWithIndex
      duplicateClaimIdentityIndex
      canonicalProjection
      canonicalSelected
      `containsRule` "core.structured-proposition.identity"
    ruleIds oneParticipant oneParticipantSelected
      `containsRule` "core.collective-strategy-realization.participant-cardinality"
    ruleIds duplicateParticipant duplicateParticipantSelected
      `containsRule` "core.collective-strategy-realization.participant-uniqueness"
    ruleIds wrongParticipantType wrongParticipantTypeSelected
      `containsRule` "core.collective-strategy-realization.participant-type"
    ruleIds noTarget noTargetSelected
      `containsRule` "core.collective-strategy-realization.target-cardinality"
    ruleIds wrongTargetType wrongTargetTypeSelected
      `containsRule` "core.collective-strategy-realization.target-type"
    ruleIds overlappingTarget overlappingTargetSelected
      `containsRule` "core.collective-strategy-realization.target-distinctness"

duplicateHeavyClaimIdentityEvidenceIsLinear :: TestTree
duplicateHeavyClaimIdentityEvidenceIsLinear =
  testCase "emits one canonical defect for a duplicate-heavy claim identity" $ do
    let defects =
          identityDefectsWithIndex
            duplicateHeavyClaimIdentityIndex
            duplicateHeavyClaimProjection
            duplicateHeavyClaimOccurrences
    defects
      @?= [ ( minimum duplicateHeavyClaimOccurrences
            , sort duplicateHeavyClaimOccurrences)
          ]
    sum (map (length . snd) defects) @?= length duplicateHeavyClaimOccurrences

structureDefectAlgebraIsExact :: TestTree
structureDefectAlgebraIsExact =
  testCase "eliminates all twelve branches with exact typed evidence" $ do
    map (foldStructureDefect branchEliminator) examples @?= [(0 :: Int) .. 11]
    map structureDefectRule examples @?= expectedRules
    assertBool
      "a Structure rule permutation must not preserve exact associations"
      (map structureDefectRule examples
         /= drop 1 expectedRules ++ take 1 expectedRules)
    examples
      @?= [ QualifiedEndpointCatalogMembershipDefect
              (QualifiedEndpointCatalogMembershipEvidence carrierA)
          , ContextualizationSourceCategoryDefect
              (ContextualizationSourceCategoryEvidence
                 contextualizationOccurrence
                 carrierA)
          , ContextualizationTargetCategoryDefect
              (ContextualizationTargetCategoryEvidence
                 contextualizationOccurrence
                 carrierB)
          , ContextualizationTargetOwnerCardinalityDefect
              (ContextualizationTargetOwnerCardinalityEvidence
                 carrierA
                 NoStructureOccurrence)
          , SemanticRelationCompatibilityDefect
              (SemanticRelationCompatibilityEvidence
                 relationOccurrence
                 carrierA
                 carrierB)
          , StructuredPropositionIdentityDefect
              (StructuredPropositionIdentityEvidence
                 propositionOccurrence
                 claimAlias
                 propositionOccurrence
                 [])
          , CollectiveParticipantTypeDefect
              (CollectiveParticipantTypeEvidence
                 propositionOccurrence
                 incidenceParticipantA
                 carrierA)
          , CollectiveParticipantCardinalityDefect
              (CollectiveParticipantCardinalityEvidence
                 propositionOccurrence
                 (Just carrierA))
          , CollectiveParticipantUniquenessDefect
              (CollectiveParticipantUniquenessEvidence
                 propositionOccurrence
                 (carrierA NonEmpty.:| []))
          , CollectiveTargetTypeDefect
              (CollectiveTargetTypeEvidence
                 propositionOccurrence
                 incidenceTarget
                 targetCarrier)
          , CollectiveTargetCardinalityDefect
              (CollectiveTargetCardinalityEvidence
                 propositionOccurrence
                 NoStructureOccurrence)
          , CollectiveTargetDistinctnessDefect
              (CollectiveTargetDistinctnessEvidence
                 propositionOccurrence
                 (carrierA NonEmpty.:| []))
          ]
  where
    examples =
      [ defectFor
          QualifiedEndpointCatalogMembershipRule
          invalidDirectEndpoint
          invalidDirectEndpointSelected
      , defectFor
          ContextualizationSourceCategoryRule
          invalidContextualizationSource
          invalidContextualizationSourceSelected
      , defectFor
          ContextualizationTargetCategoryRule
          invalidContextualizationTarget
          invalidContextualizationTargetSelected
      , defectFor
          ContextualizationTargetOwnerCardinalityRule
          missingContextOwner
          missingContextOwnerSelected
      , defectFor
          SemanticRelationCompatibilityRule
          incompatibleRelation
          incompatibleRelationSelected
      , defectForWithIndex
          duplicateClaimIdentityIndex
          StructuredPropositionIdentityRule
          canonicalProjection
          canonicalSelected
      , defectFor
          CollectiveParticipantTypeRule
          wrongParticipantType
          wrongParticipantTypeSelected
      , defectFor
          CollectiveParticipantCardinalityRule
          oneParticipant
          oneParticipantSelected
      , defectFor
          CollectiveParticipantUniquenessRule
          duplicateParticipant
          duplicateParticipantSelected
      , defectFor
          CollectiveTargetTypeRule
          wrongTargetType
          wrongTargetTypeSelected
      , defectFor CollectiveTargetCardinalityRule noTarget noTargetSelected
      , defectFor
          CollectiveTargetDistinctnessRule
          overlappingTarget
          overlappingTargetSelected
      ]
    expectedRules =
      map
        structureRuleId
        [ QualifiedEndpointCatalogMembershipRule
        , ContextualizationSourceCategoryRule
        , ContextualizationTargetCategoryRule
        , ContextualizationTargetOwnerCardinalityRule
        , SemanticRelationCompatibilityRule
        , StructuredPropositionIdentityRule
        , CollectiveParticipantTypeRule
        , CollectiveParticipantCardinalityRule
        , CollectiveParticipantUniquenessRule
        , CollectiveTargetTypeRule
        , CollectiveTargetCardinalityRule
        , CollectiveTargetDistinctnessRule
        ]
    branchEliminator =
      StructureDefectEliminator
        { eliminateQualifiedEndpointCatalogMembership = const 0
        , eliminateContextualizationSourceCategory = const 1
        , eliminateContextualizationTargetCategory = const 2
        , eliminateContextualizationTargetOwnerCardinality = const 3
        , eliminateSemanticRelationCompatibility = const 4
        , eliminateStructuredPropositionIdentity = const 5
        , eliminateCollectiveParticipantType = const 6
        , eliminateCollectiveParticipantCardinality = const 7
        , eliminateCollectiveParticipantUniqueness = const 8
        , eliminateCollectiveTargetType = const 9
        , eliminateCollectiveTargetCardinality = const 10
        , eliminateCollectiveTargetDistinctness = const 11
        }

cardinalityEvidenceIsExact :: TestTree
cardinalityEvidenceIsExact =
  testCase "retains zero, one, multiple, and NonEmpty evidence exactly" $ do
    defectFor
      CollectiveParticipantCardinalityRule
      noParticipant
      noParticipantSelected
      @?= CollectiveParticipantCardinalityDefect
            (CollectiveParticipantCardinalityEvidence
               propositionOccurrence
               Nothing)
    defectFor
      ContextualizationTargetOwnerCardinalityRule
      multipleContextOwners
      multipleContextOwnersSelected
      @?= ContextualizationTargetOwnerCardinalityDefect
            (ContextualizationTargetOwnerCardinalityEvidence
               actionMember
               (MultipleStructureOccurrences carrierA carrierB [targetCarrier]))
    defectFor
      CollectiveTargetCardinalityRule
      multipleTargets
      multipleTargetsSelected
      @?= CollectiveTargetCardinalityDefect
            (CollectiveTargetCardinalityEvidence
               propositionOccurrence
               (MultipleStructureOccurrences carrierA targetCarrier []))

structureRuleOwnershipIsExact :: TestTree
structureRuleOwnershipIsExact =
  testCase "partitions runtime behavior and constructor guarantees exactly" $ do
    sort (map structureRuleId [minBound .. maxBound] ++ constructorRules)
      @?= sort (NonEmpty.toList structureRuleIds)
  where
    constructorRules =
      map
        exactRule
        [ "core.structured-proposition.family"
        , "core.structured-proposition.commitment"
        , "core.structured-proposition.incidence"
        ]

data Snapshot =
  Snapshot
    [(Text, Text, Text, Commitment)]
    [(Text, Text, Text, Commitment)]
    [(Text, Text, Text, Text, Commitment)]
    [(Text, Text, Text, Text, Commitment, [(Text, Text, Text)])]
  deriving (Eq, Show)

snapshot ::
     StructureProjection -> [OccurrenceIdentity] -> Either String Snapshot
snapshot projection selected = runStructure projection selected inspect
  where
    inspect assessment =
      case assessment of
        Left defects -> Left (show defects)
        Right (StructureRejected defects) -> Left (show defects)
        Right (StructureAccepted graph) ->
          Right
            (Snapshot
               [ ( occurrenceIdentityText (carrierOccurrenceIdentity carrier)
                 , modelIdentityText (carrierModelIdentity carrier)
                 , coreQualifiedEndpointIdText
                     (carrierQualifiedEndpoint carrier)
                 , carrierCommitment carrier)
               | carrier <- wellFormedCarriers graph
               ]
               [ ( occurrenceIdentityText
                     (contextualizationOccurrenceIdentity contextualization)
                 , occurrenceIdentityText
                     (contextualizationOwnerOccurrence contextualization)
                 , occurrenceIdentityText
                     (contextualizationMemberOccurrence contextualization)
                 , contextualizationCommitment contextualization)
               | contextualization <- wellFormedContextualizations graph
               ]
               [ ( occurrenceIdentityText (relationOccurrenceIdentity relation)
                 , occurrenceIdentityText (relationSourceOccurrence relation)
                 , coreRelationTokenText (relationToken relation)
                 , occurrenceIdentityText (relationTargetOccurrence relation)
                 , relationCommitment relation)
               | relation <- wellFormedRelations graph
               ]
               [ ( occurrenceIdentityText
                     (structuredPropositionOccurrence proposition)
                 , modelIdentityText
                     (structuredPropositionModelIdentity proposition)
                 , coreStructuredPropositionFamilyIdText
                     (structuredPropositionFamily proposition)
                 , coreParticipantCompletenessToken
                     (structuredPropositionCompleteness proposition)
                 , structuredPropositionCommitment proposition
                 , [ ( occurrenceIdentityText
                         (structuredIncidenceOccurrence incidence)
                     , coreStructuredPropositionRoleIdText
                         (structuredIncidenceRole incidence)
                     , occurrenceIdentityText
                         (structuredIncidenceEndpoint incidence))
                   | incidence <- structuredPropositionIncidences proposition
                   ])
               | proposition <- wellFormedStructuredPropositions graph
               ])

inputDefects ::
     StructureProjection -> [OccurrenceIdentity] -> [StructureInputDefect]
inputDefects projection selected = runStructure projection selected inspect
  where
    inspect assessment =
      case assessment of
        Left defects -> NonEmpty.toList defects
        Right _ -> []

ruleIds :: StructureProjection -> [OccurrenceIdentity] -> [Text]
ruleIds = ruleIdsWithIndex identityIndex

ruleIdsWithIndex ::
     ModelIdentityIndex -> StructureProjection -> [OccurrenceIdentity] -> [Text]
ruleIdsWithIndex index projection selected =
  runStructureWithIndex index projection selected inspect
  where
    inspect assessment =
      case assessment of
        Right (StructureRejected defects) ->
          map (coreRuleIdText . defectRuleId) (NonEmpty.toList defects)
        _ -> []

structureDefectsWithIndex ::
     ModelIdentityIndex
  -> StructureProjection
  -> [OccurrenceIdentity]
  -> [StructureDefect]
structureDefectsWithIndex index projection selected =
  runStructureWithIndex index projection selected inspect
  where
    inspect assessment =
      case assessment of
        Right (StructureRejected defects) -> NonEmpty.toList defects
        _ -> []

defectFor ::
     StructureRule
  -> StructureProjection
  -> [OccurrenceIdentity]
  -> StructureDefect
defectFor = defectForWithIndex identityIndex

defectForWithIndex ::
     ModelIdentityIndex
  -> StructureRule
  -> StructureProjection
  -> [OccurrenceIdentity]
  -> StructureDefect
defectForWithIndex index rule projection selected =
  case filter
         ((== structureRuleId rule) . defectRuleId)
         (structureDefectsWithIndex index projection selected) of
    [defect] -> defect
    defects ->
      error
        ("expected one Structure defect for "
           ++ show rule
           ++ ", got "
           ++ show defects)

identityDefectsWithIndex ::
     ModelIdentityIndex
  -> StructureProjection
  -> [OccurrenceIdentity]
  -> [(OccurrenceIdentity, [OccurrenceIdentity])]
identityDefectsWithIndex index projection selected =
  runStructureWithIndex index projection selected inspect
  where
    inspect assessment =
      case assessment of
        Right (StructureRejected defects) ->
          mapMaybe identityEvidence (NonEmpty.toList defects)
        _ -> []

defectRuleId :: StructureDefect -> CoreRuleId
defectRuleId = structureDefectRule

identityEvidence ::
     StructureDefect -> Maybe (OccurrenceIdentity, [OccurrenceIdentity])
identityEvidence = foldStructureDefect eliminator
  where
    eliminator =
      StructureDefectEliminator
        { eliminateQualifiedEndpointCatalogMembership = const Nothing
        , eliminateContextualizationSourceCategory = const Nothing
        , eliminateContextualizationTargetCategory = const Nothing
        , eliminateContextualizationTargetOwnerCardinality = const Nothing
        , eliminateSemanticRelationCompatibility = const Nothing
        , eliminateStructuredPropositionIdentity =
            \evidence ->
              Just
                ( structuredPropositionIdentitySubject evidence
                , structuredPropositionIdentityFirstOccurrence evidence
                    : structuredPropositionIdentitySecondOccurrence evidence
                    : structuredPropositionIdentityRemainingOccurrences evidence)
        , eliminateCollectiveParticipantType = const Nothing
        , eliminateCollectiveParticipantCardinality = const Nothing
        , eliminateCollectiveParticipantUniqueness = const Nothing
        , eliminateCollectiveTargetType = const Nothing
        , eliminateCollectiveTargetCardinality = const Nothing
        , eliminateCollectiveTargetDistinctness = const Nothing
        }

runStructure ::
     StructureProjection
  -> [OccurrenceIdentity]
  -> (forall scope. Either
                      (NonEmpty StructureInputDefect)
                      (StructureAssessment scope) -> result)
  -> result
runStructure projection selected inspect =
  runStructureWithIndex identityIndex projection selected inspect

runStructureWithIndex ::
     ModelIdentityIndex
  -> StructureProjection
  -> [OccurrenceIdentity]
  -> (forall scope. Either
                      (NonEmpty StructureInputDefect)
                      (StructureAssessment scope) -> result)
  -> result
runStructureWithIndex index projection selected inspect =
  case withSelectedViewScope
         index
         selected
         (\scope -> inspect (StructureIndex.assessStructure scope projection)) of
    Left defects -> error ("invalid selected-View fixture: " ++ show defects)
    Right result -> result

containsRule :: [Text] -> Text -> IO ()
containsRule actual expected =
  assertBool
    ("missing rule " ++ show expected ++ " in " ++ show actual)
    (expected `elem` actual)

exactRule :: Text -> CoreRuleId
exactRule identifier =
  fromMaybe
    (error ("unknown Core rule in test fixture: " ++ show identifier))
    (findRule identifier)

findRule :: Text -> Maybe CoreRuleId
findRule identifier =
  case filter ((== identifier) . coreRuleIdText) (NonEmpty.toList coreRuleIds) of
    [rule] -> Just rule
    _ -> Nothing

canonicalProjection :: StructureProjection
canonicalProjection =
  structureProjection
    [ strategyCarrier carrierB
    , strategyCarrier targetCarrier
    , strategyCarrier carrierA
    ]
    []
    []
    [collectiveProposition propositionOccurrence]
    [ participantIncidence incidenceParticipantB carrierB
    , targetIncidence incidenceTarget targetCarrier
    , participantIncidence incidenceParticipantA carrierA
    ]

reverseProjection :: StructureProjection -> StructureProjection
reverseProjection _ =
  structureProjection
    [ strategyCarrier carrierA
    , strategyCarrier targetCarrier
    , strategyCarrier carrierB
    ]
    []
    []
    [collectiveProposition propositionOccurrence]
    [ participantIncidence incidenceParticipantA carrierA
    , targetIncidence incidenceTarget targetCarrier
    , participantIncidence incidenceParticipantB carrierB
    ]

expectedSnapshot :: Snapshot
expectedSnapshot =
  Snapshot
    [ ("carrier-a", "model-carrier-a", "context.strategy", Asserted)
    , ("carrier-b", "model-carrier-b", "context.strategy", Asserted)
    , ("target", "model-target", "context.strategy", Asserted)
    ]
    []
    []
    [ ( "proposition"
      , "model-proposition"
      , "collective-strategy-realization"
      , "closed"
      , Asserted
      , [ ( "incidence-a"
          , "collective-strategy-realization.role.participant"
          , "carrier-a")
        , ( "incidence-b"
          , "collective-strategy-realization.role.participant"
          , "carrier-b")
        , ( "incidence-target"
          , "collective-strategy-realization.role.target"
          , "target")
        ])
    ]

canonicalSelected :: [OccurrenceIdentity]
canonicalSelected =
  [ carrierA
  , carrierB
  , targetCarrier
  , propositionOccurrence
  , incidenceParticipantA
  , incidenceParticipantB
  , incidenceTarget
  ]

outsideProjection :: StructureProjection
outsideProjection = structureProjection [strategyCarrier carrierB] [] [] [] []

duplicateProjection :: StructureProjection
duplicateProjection =
  structureProjection
    [strategyCarrier carrierA]
    []
    []
    [collectiveProposition carrierA]
    []

missingCarrierProjection :: StructureProjection
missingCarrierProjection =
  structureProjection
    [strategyCarrier carrierA]
    []
    [ relationProjection
        relationOccurrence
        carrierA
        directsToken
        carrierB
        Asserted
    ]
    []
    []

missingCarrierSelected :: [OccurrenceIdentity]
missingCarrierSelected = [carrierA, carrierB, relationOccurrence]

missingPropositionProjection :: StructureProjection
missingPropositionProjection =
  structureProjection
    [strategyCarrier carrierA]
    []
    []
    []
    [participantIncidence incidenceParticipantA carrierA]

missingPropositionSelected :: [OccurrenceIdentity]
missingPropositionSelected =
  [carrierA, propositionOccurrence, incidenceParticipantA]

invalidContextualizationSource :: StructureProjection
invalidContextualizationSource =
  structureProjection
    [ anchorCarrier carrierA
    , carrierProjection carrierB primitiveCategory actionType Asserted
    ]
    [ contextualizationProjection
        contextualizationOccurrence
        carrierA
        carrierB
        Asserted
    ]
    []
    []
    []

invalidContextualizationSourceSelected :: [OccurrenceIdentity]
invalidContextualizationSourceSelected =
  [carrierA, carrierB, contextualizationOccurrence]

invalidContextualizationTarget :: StructureProjection
invalidContextualizationTarget =
  structureProjection
    [strategyCarrier carrierA, needCarrier carrierB]
    [ contextualizationProjection
        contextualizationOccurrence
        carrierA
        carrierB
        Asserted
    ]
    []
    []
    []

invalidContextualizationTargetSelected :: [OccurrenceIdentity]
invalidContextualizationTargetSelected =
  [carrierA, carrierB, contextualizationOccurrence]

missingContextOwner :: StructureProjection
missingContextOwner =
  structureProjection
    [carrierProjection carrierA primitiveCategory actionType Asserted]
    []
    []
    []
    []

missingContextOwnerSelected :: [OccurrenceIdentity]
missingContextOwnerSelected = [carrierA]

invalidDirectEndpoint :: StructureProjection
invalidDirectEndpoint =
  structureProjection
    [carrierProjection carrierA contextCategory actionType Asserted]
    []
    []
    []
    []

invalidDirectEndpointSelected :: [OccurrenceIdentity]
invalidDirectEndpointSelected = [carrierA]

incompatibleRelation :: StructureProjection
incompatibleRelation =
  structureProjection
    [strategyCarrier carrierA, needCarrier carrierB]
    []
    [ relationProjection
        relationOccurrence
        carrierA
        directsToken
        carrierB
        Asserted
    ]
    []
    []

incompatibleRelationSelected :: [OccurrenceIdentity]
incompatibleRelationSelected = [carrierA, carrierB, relationOccurrence]

oneParticipant :: StructureProjection
oneParticipant =
  collectiveProjection
    [strategyCarrier carrierA, strategyCarrier targetCarrier]
    [participantIncidence incidenceParticipantA carrierA]
    [targetIncidence incidenceTarget targetCarrier]

oneParticipantSelected :: [OccurrenceIdentity]
oneParticipantSelected =
  [ carrierA
  , targetCarrier
  , propositionOccurrence
  , incidenceParticipantA
  , incidenceTarget
  ]

duplicateParticipant :: StructureProjection
duplicateParticipant =
  collectiveProjection
    [strategyCarrier carrierA, strategyCarrier targetCarrier]
    [ participantIncidence incidenceParticipantA carrierA
    , participantIncidence incidenceParticipantB carrierA
    ]
    [targetIncidence incidenceTarget targetCarrier]

duplicateParticipantSelected :: [OccurrenceIdentity]
duplicateParticipantSelected = canonicalSelected

wrongParticipantType :: StructureProjection
wrongParticipantType =
  collectiveProjection
    [ needCarrier carrierA
    , strategyCarrier carrierB
    , strategyCarrier targetCarrier
    ]
    [ participantIncidence incidenceParticipantA carrierA
    , participantIncidence incidenceParticipantB carrierB
    ]
    [targetIncidence incidenceTarget targetCarrier]

wrongParticipantTypeSelected :: [OccurrenceIdentity]
wrongParticipantTypeSelected = canonicalSelected

noTarget :: StructureProjection
noTarget =
  collectiveProjection
    [strategyCarrier carrierA, strategyCarrier carrierB]
    [ participantIncidence incidenceParticipantA carrierA
    , participantIncidence incidenceParticipantB carrierB
    ]
    []

noTargetSelected :: [OccurrenceIdentity]
noTargetSelected =
  [ carrierA
  , carrierB
  , propositionOccurrence
  , incidenceParticipantA
  , incidenceParticipantB
  ]

noParticipant :: StructureProjection
noParticipant =
  collectiveProjection
    [strategyCarrier targetCarrier]
    []
    [targetIncidence incidenceTarget targetCarrier]

noParticipantSelected :: [OccurrenceIdentity]
noParticipantSelected = [targetCarrier, propositionOccurrence, incidenceTarget]

multipleTargets :: StructureProjection
multipleTargets =
  collectiveProjection
    [ strategyCarrier carrierA
    , strategyCarrier carrierB
    , strategyCarrier targetCarrier
    ]
    [ participantIncidence incidenceParticipantA carrierA
    , participantIncidence incidenceParticipantB carrierB
    ]
    [ targetIncidence incidenceTarget carrierA
    , targetIncidence incidenceTargetSecond targetCarrier
    ]

multipleTargetsSelected :: [OccurrenceIdentity]
multipleTargetsSelected = canonicalSelected ++ [incidenceTargetSecond]

multipleContextOwners :: StructureProjection
multipleContextOwners =
  structureProjection
    [ strategyCarrier carrierA
    , strategyCarrier carrierB
    , strategyCarrier targetCarrier
    , carrierProjection actionMember primitiveCategory actionType Asserted
    ]
    [ contextualizationProjection
        contextualizationOccurrence
        carrierA
        actionMember
        Asserted
    , contextualizationProjection
        contextualizationSecond
        carrierB
        actionMember
        Asserted
    , contextualizationProjection
        contextualizationThird
        targetCarrier
        actionMember
        Asserted
    ]
    []
    []
    []

multipleContextOwnersSelected :: [OccurrenceIdentity]
multipleContextOwnersSelected =
  [ carrierA
  , carrierB
  , targetCarrier
  , actionMember
  , contextualizationOccurrence
  , contextualizationSecond
  , contextualizationThird
  ]

wrongTargetType :: StructureProjection
wrongTargetType =
  collectiveProjection
    [ strategyCarrier carrierA
    , strategyCarrier carrierB
    , needCarrier targetCarrier
    ]
    [ participantIncidence incidenceParticipantA carrierA
    , participantIncidence incidenceParticipantB carrierB
    ]
    [targetIncidence incidenceTarget targetCarrier]

wrongTargetTypeSelected :: [OccurrenceIdentity]
wrongTargetTypeSelected = canonicalSelected

overlappingTarget :: StructureProjection
overlappingTarget =
  collectiveProjection
    [strategyCarrier carrierA, strategyCarrier carrierB]
    [ participantIncidence incidenceParticipantA carrierA
    , participantIncidence incidenceParticipantB carrierB
    ]
    [targetIncidence incidenceTarget carrierA]

overlappingTargetSelected :: [OccurrenceIdentity]
overlappingTargetSelected =
  [ carrierA
  , carrierB
  , propositionOccurrence
  , incidenceParticipantA
  , incidenceParticipantB
  , incidenceTarget
  ]

collectiveProjection ::
     [CarrierProjection]
  -> [StructuredIncidenceProjection]
  -> [StructuredIncidenceProjection]
  -> StructureProjection
collectiveProjection carriers participants targets =
  structureProjection
    carriers
    []
    []
    [collectiveProposition propositionOccurrence]
    (participants ++ targets)

strategyCarrier :: OccurrenceIdentity -> CarrierProjection
strategyCarrier identifier =
  carrierProjection identifier contextCategory strategyType Asserted

needCarrier :: OccurrenceIdentity -> CarrierProjection
needCarrier identifier =
  carrierProjection identifier contextCategory needType Asserted

anchorCarrier :: OccurrenceIdentity -> CarrierProjection
anchorCarrier identifier =
  carrierProjection
    identifier
    situationAnchorCategory
    businessCapabilityType
    Asserted

collectiveProposition :: OccurrenceIdentity -> StructuredPropositionProjection
collectiveProposition identifier =
  structuredPropositionProjection
    identifier
    collectiveFamily
    completenessClosed
    Asserted

participantIncidence ::
     OccurrenceIdentity -> OccurrenceIdentity -> StructuredIncidenceProjection
participantIncidence identifier endpoint =
  structuredIncidenceProjection
    identifier
    propositionOccurrence
    participantRole
    endpoint

targetIncidence ::
     OccurrenceIdentity -> OccurrenceIdentity -> StructuredIncidenceProjection
targetIncidence identifier endpoint =
  structuredIncidenceProjection
    identifier
    propositionOccurrence
    targetRole
    endpoint

contextCategory :: CoreCarrierCategory
contextCategory = exact "Context" lookupCoreCarrierCategory

primitiveCategory :: CoreCarrierCategory
primitiveCategory = exact "Primitive" lookupCoreCarrierCategory

situationAnchorCategory :: CoreCarrierCategory
situationAnchorCategory = exact "SituationAnchor" lookupCoreCarrierCategory

strategyType :: CoreO2IType
strategyType = exact "Strategy" lookupCoreO2IType

needType :: CoreO2IType
needType = exact "Need" lookupCoreO2IType

actionType :: CoreO2IType
actionType = exact "Action" lookupCoreO2IType

businessCapabilityType :: CoreO2IType
businessCapabilityType = exact "BusinessCapability" lookupCoreO2IType

directsToken :: CoreRelationToken
directsToken = exact "directs" lookupCoreRelationToken

collectiveFamily :: CoreStructuredPropositionFamilyId
collectiveFamily =
  exact
    "collective-strategy-realization"
    lookupCoreStructuredPropositionFamilyId

participantRole :: CoreStructuredPropositionRoleId
participantRole =
  exact
    "collective-strategy-realization.role.participant"
    lookupCoreStructuredPropositionRoleId

targetRole :: CoreStructuredPropositionRoleId
targetRole =
  exact
    "collective-strategy-realization.role.target"
    lookupCoreStructuredPropositionRoleId

completenessClosed :: CoreParticipantCompleteness
completenessClosed = exact "closed" lookupCoreParticipantCompletenessToken

exact :: Show key => key -> (key -> Maybe value) -> value
exact key decoder =
  fromMaybe (error ("invalid test fixture value: " ++ show key)) (decoder key)

carrierA, carrierB, targetCarrier, propositionOccurrence :: OccurrenceIdentity
carrierA = occurrence "carrier-a"

carrierB = occurrence "carrier-b"

targetCarrier = occurrence "target"

propositionOccurrence = occurrence "proposition"

relationOccurrence, contextualizationOccurrence :: OccurrenceIdentity
relationOccurrence = occurrence "relation"

contextualizationOccurrence = occurrence "contextualization"

incidenceParticipantA, incidenceParticipantB, incidenceTarget, incidenceTargetSecond ::
     OccurrenceIdentity
incidenceParticipantA = occurrence "incidence-a"

incidenceParticipantB = occurrence "incidence-b"

incidenceTarget = occurrence "incidence-target"

incidenceTargetSecond = occurrence "incidence-target-second"

actionMember, contextualizationSecond, contextualizationThird ::
     OccurrenceIdentity
actionMember = occurrence "action-member"

contextualizationSecond = occurrence "contextualization-second"

contextualizationThird = occurrence "contextualization-third"

allOccurrences :: [OccurrenceIdentity]
allOccurrences =
  [ carrierA
  , carrierB
  , targetCarrier
  , propositionOccurrence
  , relationOccurrence
  , contextualizationOccurrence
  , incidenceParticipantA
  , incidenceParticipantB
  , incidenceTarget
  , incidenceTargetSecond
  , actionMember
  , contextualizationSecond
  , contextualizationThird
  ]

occurrence :: Text -> OccurrenceIdentity
occurrence = expectRight . occurrenceIdentity

model :: OccurrenceIdentity -> ModelOccurrence
model identifier =
  modelOccurrence
    identifier
    (expectRight (modelIdentity ("model-" <> occurrenceIdentityText identifier)))

identityIndex :: ModelIdentityIndex
identityIndex = expectRight (buildModelIdentityIndex (map model allOccurrences))

duplicateClaimIdentityIndex :: ModelIdentityIndex
duplicateClaimIdentityIndex =
  expectRight
    (buildModelIdentityIndex
       (modelOccurrence
          claimAlias
          (expectRight (modelIdentity "model-proposition"))
          : map model allOccurrences))

duplicateHeavyClaimOccurrences :: [OccurrenceIdentity]
duplicateHeavyClaimOccurrences =
  [ occurrence ("claim-collision-" <> Text.pack (show number))
  | number <- [(1 :: Int) .. 64]
  ]

duplicateHeavyClaimProjection :: StructureProjection
duplicateHeavyClaimProjection =
  structureProjection
    []
    []
    []
    (map collectiveProposition duplicateHeavyClaimOccurrences)
    []

duplicateHeavyClaimIdentityIndex :: ModelIdentityIndex
duplicateHeavyClaimIdentityIndex =
  expectRight
    (buildModelIdentityIndex
       [ modelOccurrence identifier sharedIdentity
       | identifier <- duplicateHeavyClaimOccurrences
       ])
  where
    sharedIdentity = expectRight (modelIdentity "model-claim-collision")

claimAlias :: OccurrenceIdentity
claimAlias = occurrence "claim-alias"

expectRight :: Show problem => Either problem value -> value
expectRight value =
  case value of
    Left problem -> error ("invalid test fixture: " ++ show problem)
    Right result -> result
