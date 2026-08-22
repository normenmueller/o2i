{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Executable contract for the compiled ArchiMate Profile boundary.
module O2I.ArchiMate.Profile.Test.Contract
  ( contractTests
  ) where

import Data.List (nub, sort)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified O2I.ArchiMate.Profile as Profile
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Conformance.Source as Fixture
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Mapping as Mapping
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Projection
import qualified O2I.ArchiMate.Profile.Resolution as Resolution
import qualified O2I.Core.Contract as CoreContract
import O2I.Core.Graph.Observation
  ( Commitment(..)
  , carrierModelIdentity
  , carrierOccurrenceIdentity
  )
import O2I.Core.Identity
  ( ModelIdentity
  , OccurrenceIdentity
  , OccurrenceIdentityDefect
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Structure
  ( foldStructureAssessment
  , structuredIncidenceEndpoint
  , structuredIncidenceRole
  , structuredPropositionCommitment
  , structuredPropositionCompleteness
  , structuredPropositionFamily
  , structuredPropositionIncidences
  , structuredPropositionModelIdentity
  , wellFormedCarriers
  , wellFormedRelations
  , wellFormedStructuredPropositions
  )
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

contractTests :: TestTree
contractTests =
  testGroup
    "compiled ArchiMate Profile"
    [ descriptorTest
    , mappingTest
    , occurrenceIdentityProjectionTest
    , notationOutcomeTest
    , notationGlobalIdentityTest
    , notationProofTest
    , retentionTest
    , markerTest
    , closureDeterminismTest
    , closureAndProjectionTest
    , validKpiCarrierTest
    , relationApplicabilityTest
    , profileDefectTest
    , qualificationTest
    , qualificationInvariantTest
    , candidateRecognitionTest
    , qualificationNormalizationTest
    , qualificationAdversarialTest
    , collectiveTest
    , collectiveChainTest
    , branchIsolationTest
    , unmarkedDisplayedElementTest
    ]

descriptorTest :: TestTree
descriptorTest =
  testCase "exposes exactly one immutable compiled descriptor" $ do
    let descriptor =
          headTotal "compiled descriptor" Profile.compiledProfileInventory
    Profile.profileDescriptorIdentity descriptor @?= "o2i.archimate-profile"
    Profile.profileDescriptorToken descriptor @?= "0.3"
    Profile.profileDescriptorReference descriptor
      @?= "o2i.archimate-profile@0.3"
    Profile.profileDescriptorVersion descriptor @?= "0.3.0"
    Profile.profileDescriptorNotation descriptor @?= "archimate-3.2"
    Profile.profileDescriptorAdapterIds descriptor @?= ["amx"]
    Profile.profileDescriptorContractDigest descriptor
      @?= "3254127ed6029c6df26fb30578956429fe9d3f82de8ee2f9bbe8d363b676d081"

mappingTest :: TestTree
mappingTest =
  testCase "owns exact carrier, relation, and label contracts" $ do
    length Mapping.carrierMappings @?= 12
    length Mapping.relationMappings @?= 25
    Mapping.normalizeRelationshipLabel "\t  directs  \t" @?= Right "directs"
    Mapping.normalizeRelationshipLabel "e\x0301" @?= Right "\x00e9"
    Mapping.normalizeRelationshipLabel "direct\ts"
      @?= Left Mapping.RelationshipLabelContainsTab
    Mapping.normalizeRelationshipLabel " \t "
      @?= Left Mapping.RelationshipLabelEmpty
    Mapping.normalizeRelationshipLabel "direct\n"
      @?= Left (Mapping.RelationshipLabelContainsControl '\n')

occurrenceIdentityProjectionTest :: TestTree
occurrenceIdentityProjectionTest =
  testCase "projects the complete canonical occurrence grammar into Core"
    $ Notation.withCanonicalDocument Fixture.validDraft
    $ \document -> do
        traverse projectOccurrence (recordOccurrences document)
          @?= Right
                [ "archimate:record:0"
                , "archimate:record:1"
                , "archimate:record:2"
                , "archimate:record:3"
                , "archimate:record:4"
                , "archimate:record:5"
                ]
        traverse
          (projectOccurrence . Notation.canonicalPropertyOccurrence)
          (Notation.canonicalDocumentProperties document)
          @?= Right
                [ "archimate:property:0"
                , "archimate:property:1"
                , "archimate:property:2"
                , "archimate:property:3"
                , "archimate:property:4"
                , "archimate:property:5"
                ]
        traverse
          (projectOccurrence . Notation.canonicalReferenceOccurrence)
          (Notation.canonicalDocumentReferences document)
          @?= Right
                [ "archimate:reference:0"
                , "archimate:reference:1"
                , "archimate:reference:2"
                ]
  where
    recordOccurrences document =
      map
        (Notation.foldCanonicalRecord (\occurrence _ _ _ _ -> occurrence))
        (Notation.canonicalDocumentRecords document)
    projectOccurrence occurrence =
      occurrenceIdentityText
        <$> Projection.canonicalOccurrenceIdentity occurrence

notationOutcomeTest :: TestTree
notationOutcomeTest =
  testCase "publishes one closed stable 38-kind Notation algebra" $ do
    NonEmpty.length Notation.allArchiMateNotationIssueKinds @?= 38
    length
      (nub
         (NonEmpty.toList
            (fmap
               Notation.archiMateNotationIssueKindToken
               Notation.allArchiMateNotationIssueKinds)))
      @?= 38

notationGlobalIdentityTest :: TestTree
notationGlobalIdentityTest =
  testGroup
    "enforces model-global identity cardinality before record family"
    [ testCase "rejects a model-root identity duplicated by an Element"
        $ assertGlobalDuplicate
            Fixture.modelRootCrossFamilyDuplicateDraft
            "model-identity-duplicate"
    , testCase "rejects a selected View identity duplicated by an Element"
        $ assertGlobalDuplicate
            Fixture.viewCrossFamilyDuplicateDraft
            "view-identity-duplicate"
    ]

notationProofTest :: TestTree
notationProofTest =
  testCase "constructs the opaque proof only for an issue-free universe" $ do
    case closedView Fixture.validDraft "Main" of
      ClosedView universe -> do
        let assessed = Notation.assessArchiMateNotation universe
        Notation.notationIssues assessed @?= []
        Notation.foldStageResult
          (const (assertFailure "valid Notation unexpectedly rejected"))
          (const (pure ()))
          (Notation.notationConformance assessed)

assertGlobalDuplicate :: Draft.ProfileDraft -> Text -> IO ()
assertGlobalDuplicate draft expectedToken =
  Notation.withCanonicalDocument draft $ \document -> do
    let inventory = Notation.assessCanonicalViewInventory document
        tokens =
          map
            (Notation.archiMateNotationIssueKindToken
               . Notation.archiMateNotationIssueKind)
            inventory
    tokens @?= [expectedToken, "record-identity-duplicate"]
    map (NonEmpty.length . Notation.archiMateNotationIssueEvidence) inventory
      @?= [1, 1]
    let view =
          singleWhere
            "View named Main"
            ((== "Main") . viewName)
            (Notation.canonicalViews document)
    Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile -> do
      let assessed =
            Notation.assessArchiMateNotation
              (Closure.deriveProfileAssessmentUniverse profile document view)
      assertBool
        "global duplicate disappeared from complete Notation assessment"
        (expectedToken
           `elem` map
                    (Notation.archiMateNotationIssueKindToken
                       . Notation.archiMateNotationIssueKind)
                    (Notation.notationIssues assessed))
      Notation.foldStageResult
        (const (pure ()))
        (const (assertFailure "global duplicate produced a conformance proof"))
        (Notation.notationConformance assessed)

retentionTest :: TestTree
retentionTest =
  testCase "retains scalar, key, opaque, and location evidence exactly" $ do
    Notation.withCanonicalDocument Fixture.retentionDraft $ \document -> do
      let retained =
            singleWhere
              "retained property"
              ((== [ "text:text"
                   , "boolean:true"
                   , "number:12.50"
                   , "native-name:{urn:test}name"
                   , "other:json:{\"a\":1}"
                   ])
                 . map renderScalar
                 . Notation.canonicalPropertyValues)
              (Notation.canonicalDocumentProperties document)
      Notation.foldCanonicalPropertyKey
        (const (assertFailure "definition-backed key became direct"))
        (\reference ->
           referenceOutcome (Notation.canonicalReferenceOutcome reference)
             @?= "resolved:definition:property-definition")
        retained
      renderLocation (Notation.canonicalPropertyLocation retained)
        @?= "{urn:test}property[3]/value[1]@10:1:101-12:20:202"
      map renderOpaque (Notation.canonicalPropertyOpaqueEvidence retained)
        @?= [ "attribute:{urn:test}flag:[text:opaque-attribute]:"
                <> "{urn:test}opaque-attribute[3]/value[1]@10:3:101-10:19:202"
            ]
      sort (map renderOpaque (draftOpaqueInventory Fixture.retentionDraft))
        @?= sort
              [ "attribute:{urn:test}flag:[text:opaque-attribute]:"
                  <> "{urn:test}opaque-attribute[3]/value[1]@10:3:101-10:19:202"
              , "child:extension:[text:opaque-child]:"
                  <> "{urn:test}opaque-child[3]/value[1]@13:1:101-14:7:202"
              ]

markerTest :: TestTree
markerTest =
  testCase "retains one exact model-root Profile marker" $ do
    Notation.withCanonicalDocument Fixture.validDraft $ \document -> do
      let counts =
            Notation.foldMarkerEvidenceAssessment
              (\candidates -> Left (length candidates))
              (\candidates properties ->
                 Right (length candidates, length properties))
              (Notation.assessMarkerEvidence document)
      counts @?= Right (1, 1)

closureDeterminismTest :: TestTree
closureDeterminismTest =
  testCase "closes exact deterministic inventories with exact provenance" $ do
    let first = closedView Fixture.validDraft "Main"
        repeated = closedView Fixture.validDraft "Main"
        permuted = closedView Fixture.validDraftPermuted "Main"
        snapshot = closureSnapshot first
    closureSnapshot repeated @?= snapshot
    closureSemanticSnapshot permuted @?= closureSemanticSnapshot first
    snapshot
      @?= ClosureSnapshot
            { snapshotDisplayed = ["record:1"]
            , snapshotGraph =
                [ "record:1"
                , "record:2"
                , "record:3"
                , "property:1"
                , "property:2"
                , "property:3"
                , "property:4"
                , "property:5"
                ]
            , snapshotQualification = ["record:1", "property:1", "property:2"]
            , snapshotUniverse =
                [ "record:0"
                , "record:1"
                , "record:2"
                , "record:3"
                , "property:1"
                , "property:2"
                , "property:3"
                , "property:4"
                , "property:5"
                ]
            , snapshotActivation = map (provenancePrefix <>) activationSuffixes
            , snapshotClosure = map (provenancePrefix <>) closureSuffixes
            }
  where
    provenancePrefix =
      "o2i.archimate-profile|"
        <> "3254127ed6029c6df26fb30578956429fe9d3f82de8ee2f9bbe8d363b676d081|"
    activationSuffixes =
      [ "graph|classification.graph.activate.carrier|record:1|record:1|carrier:context"
      , "graph|classification.graph.activate.committed-element|record:1|record:1|reserved-placement:o2i.commitment"
      , "graph|classification.shared.activate.type-key|record:1|record:1|reserved-placement:o2i.type"
      , "graph|classification.graph.activate.relation|record:3|record:3|relation:relation-syntax:AssociationRelationship:true:qualifies"
      , "qualification|classification.shared.activate.type-key|record:1|record:1|reserved-placement:o2i.type"
      ]
    closureSuffixes =
      [ "graph|graph.stable-concept|record:5|record:1|"
      , "graph|graph.relationship-source-endpoint|record:3|record:1|"
      , "graph|graph.relationship-target-endpoint|record:3|record:2|"
      , "graph|graph.owned-property-value|record:1|property:1|"
      , "graph|graph.owned-property-value|record:1|property:2|"
      , "graph|graph.owned-property-value|record:2|property:3|"
      , "graph|graph.owned-property-value|record:2|property:4|"
      , "graph|graph.owned-property-value|record:3|property:5|"
      , "qualification|qualification.owned-property-value|record:1|property:1|"
      , "qualification|qualification.owned-property-value|record:1|property:2|"
      ]

closureAndProjectionTest :: TestTree
closureAndProjectionTest =
  testCase "closes one View and projects one Core-valid effect graph" $ do
    let closed = closedView Fixture.validDraft "Main"
    length (closedDisplayedOccurrences closed) @?= 1
    assertBool
      "graph branch did not close beyond its displayed seed"
      (length (closedGraphOccurrences closed) > 1)
    assertBool
      "qualification validation branch is missing its shared typed seed"
      (not (null (closedQualificationOccurrences closed)))
    assertBool
      "graph and qualification closure were conflated"
      (closedGraphOccurrences closed /= closedQualificationOccurrences closed)
    assertBool
      "activation provenance is missing"
      (not (null (closedActivationProvenance closed)))
    assertBool
      "closure provenance is missing"
      (not (null (closedClosureProvenance closed)))
    withAcceptedProjection closed $ \projected -> do
      mappingProvenance projected
        @?= [ ( "carrier"
              , "archimate:record:1"
              , "carrier:context"
              , "context"
              , Nothing
              , Nothing)
            , ( "carrier"
              , "archimate:record:2"
              , "carrier:context"
              , "context"
              , Nothing
              , Nothing)
            , ( "relation"
              , "archimate:record:3"
              , "relation:relation-syntax:AssociationRelationship:true:qualifies"
              , "relation-syntax:AssociationRelationship:true:qualifies"
              , Just "archimate:record:1"
              , Just "archimate:record:2")
            ]
      Projection.profileQualificationProposals projected @?= []
      summary <- assessProjectedStructure projected
      summaryCarrierCount summary @?= 2
      summaryRelationCount summary @?= 1

validKpiCarrierTest :: TestTree
validKpiCarrierTest =
  testCase "projects a KPI carrier without qualification semantics" $ do
    let closed = closedView Fixture.validKpiDraft "KPI"
    withAcceptedProjection closed $ \projected -> do
      mappingProvenance projected
        @?= [ ( "carrier"
              , "archimate:record:1"
              , "carrier:context"
              , "context"
              , Nothing
              , Nothing)
            , ( "carrier"
              , "archimate:record:2"
              , "carrier:primitive.kpi"
              , "primitive.kpi"
              , Nothing
              , Nothing)
            ]
      Projection.profileQualificationProposals projected @?= []
      summary <- assessProjectedStructure projected
      summaryCarrierCount summary @?= 2
      summaryRelationCount summary @?= 0

relationApplicabilityTest :: TestTree
relationApplicabilityTest =
  testGroup
    "enforces the generated positive relation projection plan"
    (map rejectedCase rejectedRelations <> map acceptedCase acceptedRelations)
  where
    rejectedCase (name, draft) =
      rulePresentTest
        ("rejects " <> name)
        draft
        "Relation"
        "graph.committed-relationship.archimate-applicability"
    acceptedCase (name, draft) =
      testCase ("accepts " <> name) $ do
        let closed = closedView draft "Relation"
        withAcceptedProjection closed $ \projected ->
          length
            [ ()
            | (kind, _, _, _, _, _) <- mappingProvenance projected
            , kind == "relation"
            ]
            @?= 1
    rejectedRelations =
      [ relationCase
          "Influence contributes-to Action -> Action"
          "InfluenceRelationship"
          False
          "contributes-to"
          "CourseOfAction"
          "Action"
          "CourseOfAction"
          "Action"
      , relationCase
          "Influence guides Principle -> Action"
          "InfluenceRelationship"
          False
          "guides"
          "Principle"
          "Principle"
          "CourseOfAction"
          "Action"
      , relationCase
          "Influence guides Action -> Action"
          "InfluenceRelationship"
          False
          "guides"
          "CourseOfAction"
          "Action"
          "CourseOfAction"
          "Action"
      , relationCase
          "Realization contributes-to Key Result -> Key Result"
          "RealizationRelationship"
          False
          "contributes-to"
          "Outcome"
          "KeyResult"
          "Outcome"
          "KeyResult"
      , relationCase
          "Realization contributes-to Action -> Action"
          "RealizationRelationship"
          False
          "contributes-to"
          "CourseOfAction"
          "Action"
          "CourseOfAction"
          "Action"
      ]
    acceptedRelations =
      [ relationCase
          "Association contributes-to Action -> Action"
          "AssociationRelationship"
          True
          "contributes-to"
          "CourseOfAction"
          "Action"
          "CourseOfAction"
          "Action"
      , relationCase
          "Association guides Principle -> Action"
          "AssociationRelationship"
          True
          "guides"
          "Principle"
          "Principle"
          "CourseOfAction"
          "Action"
      , relationCase
          "Association guides Action -> Action"
          "AssociationRelationship"
          True
          "guides"
          "CourseOfAction"
          "Action"
          "CourseOfAction"
          "Action"
      , relationCase
          "Influence contributes-to Key Result -> Key Result"
          "InfluenceRelationship"
          False
          "contributes-to"
          "Outcome"
          "KeyResult"
          "Outcome"
          "KeyResult"
      , relationCase
          "Association contributes-to Key Result -> Key Result"
          "AssociationRelationship"
          True
          "contributes-to"
          "Outcome"
          "KeyResult"
          "Outcome"
          "KeyResult"
      ]
    relationCase name relationshipType directed label sourceElement sourceType targetElement targetType =
      ( name
      , Fixture.relationApplicabilityDraft
          relationshipType
          directed
          label
          sourceElement
          sourceType
          targetElement
          targetType)

profileDefectTest :: TestTree
profileDefectTest =
  testGroup
    "pairs generated defects with occurrence-complete typed evidence"
    [ testCase "retains one exact invalid scalar" $ do
        let closed = closedView Fixture.invalidCarrierDraft "Main"
        defects <- projectionDefectSummaries closed
        map (\(rule, _, _) -> rule) defects
          @?= ["property:typed-carrier:o2i.type:value-domain"]
        let (_, kind, scalarCount) = headTotal "invalid carrier defect" defects
        kind @?= "property-value"
        scalarCount @?= 1
    , testCase "retains every invalid scalar as separate evidence" $ do
        defects <-
          projectionDefectSummaries
            (closedView
               Fixture.qualificationMultipleInvalidRoleValuesDraft
               "Qualification")
        sort
          [ (rule, scalarCount)
          | (rule, kind, scalarCount) <- defects
          , kind == "property-value"
          ]
          @?= sort
                [ ( "property:qualification-proposal-reference-association:"
                      <> "o2i.role:admitted-values"
                  , 1)
                , ( "property:qualification-proposal-reference-association:"
                      <> "o2i.role:value-kind"
                  , 1)
                ]
    ]

qualificationTest :: TestTree
qualificationTest =
  testCase "projects one exact four-role qualification proposal" $ do
    let closed = closedView Fixture.qualificationDraft "Qualification"
    withAcceptedProjection closed $ \projected -> do
      let proposal =
            headTotal
              "qualification proposal"
              (Projection.profileQualificationProposals projected)
          identities = projectedIdentityInventory closed
          references =
            [ ( CoreContract.coreQualificationProposalRoleIdText
                  (Projection.qualificationReferenceRole reference)
              , targetModelIdentity
                  identities
                  (Projection.qualificationReferenceTarget reference))
            | reference <- Projection.qualificationProposalReferences proposal
            ]
      modelIdentityText (Projection.qualificationProposalIdentity proposal)
        @?= "proposal"
      qualificationRationale proposal
        @?= Just
              ( "proposal-documentation-field[1]"
              , "A precise qualification rationale.")
      qualificationSources proposal
        @?= [("archimate:property:2", "source-document")]
      references
        @?= [ ("need-qualification-proposal.role.strategy", "strategy")
            , ("need-qualification-proposal.role.need", "need")
            , ("need-qualification-proposal.role.objective", "objective")
            , ("need-qualification-proposal.role.key-result", "key-result")
            ]

qualificationInvariantTest :: TestTree
qualificationInvariantTest =
  testGroup
    "retains qualification invariants only on actual proposals"
    [ testCase "pairs exactly two rules with the projected proposal occurrence" $ do
        let closed = closedView Fixture.qualificationDraft "Qualification"
        withAcceptedProjection closed $ \projected -> do
          let proposal =
                headTotal
                  "qualification proposal"
                  (Projection.profileQualificationProposals projected)
              expectedOccurrence =
                Projection.qualificationProposalOccurrence proposal
          map
            qualificationInvariantObservation
            (Projection.profileQualificationInvariantEvidence projected)
            @?= [ ( "qualification.proposal.carrier.category"
                  , Just (Right expectedOccurrence))
                , ( "qualification.proposal.carrier.stable-identity-scope"
                  , Just (Right expectedOccurrence))
                ]
    , testCase "emits no invariant row without a projected proposal" $ do
        let closed = closedView Fixture.validDraft "Main"
        withAcceptedProjection closed $ \projected ->
          length (Projection.profileQualificationInvariantEvidence projected)
            @?= 0
    , testCase "retains exactly two constant invariant facts per proposal" $ do
        let proposalCount = 32
            closed =
              closedView
                (Fixture.qualificationBatchDraft proposalCount)
                "Qualification batch"
        withAcceptedProjection closed $ \projected -> do
          let proposals = Projection.profileQualificationProposals projected
              evidence =
                Projection.profileQualificationInvariantEvidence projected
          length proposals @?= proposalCount
          length evidence @?= 2 * proposalCount
          mapM_
            (\proposal -> do
               let occurrence =
                     Projection.qualificationProposalOccurrence proposal
                   rules =
                     [ rule
                     | invariant <- evidence
                     , let (rule, observed) =
                             qualificationInvariantObservation invariant
                     , observed == Just (Right occurrence)
                     ]
               rules
                 @?= [ "qualification.proposal.carrier.category"
                     , "qualification.proposal.carrier.stable-identity-scope"
                     ])
            proposals
    ]

candidateRecognitionTest :: TestTree
candidateRecognitionTest =
  testGroup
    "recognizes pattern candidates before validating their carriers"
    [ rulePresentTest
        "recognizes an exact collective marker on the wrong carrier"
        Fixture.collectiveWrongCarrierDraft
        "Collective"
        "pattern.collective-strategy-realization.carrier.archimate-element"
    , rulePresentTest
        "recognizes a Junction with an invalid collective type"
        Fixture.collectiveInvalidTypeDraft
        "Collective"
        "pattern.collective-strategy-realization.carrier.o2i-type"
    , rulePresentTest
        "recognizes an exact qualification marker on the wrong carrier"
        Fixture.qualificationWrongCarrierDraft
        "Qualification"
        "qualification.proposal.carrier.archimate-element"
    , rulePresentTest
        "recognizes an Assessment with an invalid qualification type"
        Fixture.qualificationInvalidTypeDraft
        "Qualification"
        "qualification.proposal.carrier.o2i-type"
    ]

qualificationNormalizationTest :: TestTree
qualificationNormalizationTest =
  testGroup
    "normalizes qualification rationale and source values"
    [ testCase "accepts an absent rationale" $ do
        proposal <-
          acceptedQualificationProposal Fixture.qualificationNoRationaleDraft
        Projection.qualificationProposalRationale proposal @?= Nothing
    , testCase "normalizes one rationale deterministically" $ do
        proposal <-
          acceptedQualificationProposal
            Fixture.qualificationNormalizedRationaleDraft
        qualificationRationale proposal
          @?= Just ("proposal-documentation-field[1]", "Caf\x00e9\nLine 2")
    , testCase "omits an ambiguous rationale" $ do
        proposal <-
          acceptedQualificationProposal
            Fixture.qualificationMultipleRationaleDraft
        Projection.qualificationProposalRationale proposal @?= Nothing
    , testCase "omits an invalid rationale" $ do
        proposal <-
          acceptedQualificationProposal
            Fixture.qualificationInvalidRationaleDraft
        Projection.qualificationProposalRationale proposal @?= Nothing
    , testCase "normalizes sources while preserving occurrences and order" $ do
        proposal <-
          acceptedQualificationProposal
            Fixture.qualificationNormalizedSourcesDraft
        qualificationSources proposal
          @?= [ ("archimate:property:2", "z-source")
              , ("archimate:property:3", "a-source")
              , ("archimate:property:4", "a-source")
              , ("archimate:property:5", "\x00e9-source")
              ]
    ]

qualificationSources :: Projection.QualificationProposal -> [(Text, Text)]
qualificationSources proposal =
  [ ( occurrenceIdentityText (Projection.qualificationSourceOccurrence source)
    , Projection.qualificationSourceValue source)
  | source <- Projection.qualificationProposalSources proposal
  ]

qualificationRationale :: Projection.QualificationProposal -> Maybe (Text, Text)
qualificationRationale proposal =
  fmap
    (\rationale ->
       ( renderLocation (Projection.qualificationRationaleLocation rationale)
       , Projection.qualificationRationaleValue rationale))
    (Projection.qualificationProposalRationale proposal)

mappingProvenance ::
     Projection.ProfileProjection profile document
  -> [(Text, Text, Text, Text, Maybe Text, Maybe Text)]
mappingProvenance projection =
  map
    (Projection.foldProfileMappingProvenance
       (\rule occurrence mappingId ->
          ( "carrier"
          , occurrenceIdentityText occurrence
          , rule
          , mappingId
          , Nothing
          , Nothing))
       (\rule occurrence mappingId source target ->
          ( "relation"
          , occurrenceIdentityText occurrence
          , rule
          , mappingId
          , Just (occurrenceIdentityText source)
          , Just (occurrenceIdentityText target)))
       (\rule occurrence mappingId ->
          ( "construction"
          , occurrenceIdentityText occurrence
          , rule
          , mappingId
          , Nothing
          , Nothing)))
    (Projection.profileMappingProvenance projection)

qualificationInvariantObservation ::
     Projection.ProfileInvariantEvidence profile document
  -> (Text, Maybe (Either OccurrenceIdentityDefect OccurrenceIdentity))
qualificationInvariantObservation =
  Projection.foldProfileInvariantEvidence
    (\rule evidence ->
       ( rule
       , Projection.foldProfileEvidence
           (const Nothing)
           (const Nothing)
           (\_ _ -> Nothing)
           (\_ _ -> Nothing)
           (\_ _ _ -> Nothing)
           (\_ _ _ -> Nothing)
           (Just . Projection.canonicalOccurrenceIdentity)
           (\_ _ _ -> Nothing)
           (const Nothing)
           (\_ _ _ -> Nothing)
           (const Nothing)
           (\_ _ -> Nothing)
           evidence))

rulePresentTest :: String -> Draft.ProfileDraft -> Text -> Text -> TestTree
rulePresentTest name draft view expected =
  testCase name $ do
    rules <- projectionDefectRules (closedView draft view)
    assertBool
      ("missing rule " <> Text.unpack expected <> " in " <> show rules)
      (expected `elem` rules)

acceptedQualificationProposal ::
     Draft.ProfileDraft -> IO Projection.QualificationProposal
acceptedQualificationProposal draft =
  withAcceptedProjection (closedView draft "Qualification") $ \projected ->
    pure
      (headTotal
         "qualification proposal"
         (Projection.profileQualificationProposals projected))

qualificationAdversarialTest :: TestTree
qualificationAdversarialTest =
  testGroup
    "rejects malformed qualification references completely"
    [ rejectionTest
        "requires an explicit role"
        Fixture.qualificationMissingRoleDraft
        [ "property:qualification-proposal-reference-association:o2i.role:property-cardinality"
        , "qualification.proposal.reference.role-property"
        ]
    , rejectionTest
        "rejects an unknown role"
        Fixture.qualificationWrongRoleDraft
        [ "property:qualification-proposal-reference-association:o2i.role:admitted-values"
        ]
    , rejectionTest
        "requires an Association relationship"
        Fixture.qualificationWrongRelationshipDraft
        ["qualification.proposal.reference.relationship-type"]
    , rejectionTest
        "requires proposal-to-target direction"
        Fixture.qualificationWrongDirectionDraft
        [ "qualification.proposal.reference.direction"
        , "reserved-placement:o2i.role"
        ]
    , rejectionTest
        "rejects role metadata outside proposal references"
        Fixture.qualificationNonProposalRoleDraft
        [ "graph.committed-relationship.mapping-selection"
        , "reserved-placement:o2i.role"
        ]
    ]
  where
    rejectionTest name draft expected =
      testCase name $ do
        defects <- projectionDefectRules (closedView draft "Qualification")
        defects @?= expected

collectiveTest :: TestTree
collectiveTest =
  testGroup
    "projects structured collective strategy realization"
    [ collectiveCase
        "closed participants"
        Fixture.collectiveClosedDraft
        "closed"
    , collectiveCase "open participants" Fixture.collectiveOpenDraft "open"
    ]
  where
    collectiveCase name draft completeness =
      testCase name $ do
        let closed = closedView draft "Collective"
        withAcceptedProjection closed $ \projected -> do
          summary <- assessProjectedStructure projected
          summaryStructuredPropositions summary
            @?= [ StructuredSummary
                    { structuredIdentity = "claim"
                    , structuredFamily = "collective-strategy-realization"
                    , structuredCompleteness = completeness
                    , structuredCommitment = "asserted"
                    , structuredIncidences =
                        [ ( "collective-strategy-realization.role.participant"
                          , "contributor-a")
                        , ( "collective-strategy-realization.role.participant"
                          , "contributor-b")
                        , ( "collective-strategy-realization.role.target"
                          , "target")
                        ]
                    }
                ]

collectiveChainTest :: TestTree
collectiveChainTest =
  testCase "rejects a junction chain with its complete defect inventory" $ do
    defects <-
      projectionDefectRules
        (closedView Fixture.collectiveChainDraft "Collective")
    defects @?= ["pattern.collective-strategy-realization.junction.chains"]

branchIsolationTest :: TestTree
branchIsolationTest =
  testCase "keeps graph and qualification branches isolated" $ do
    let qualification =
          closedView Fixture.branchIsolationDraft "Qualification only"
        collective = closedView Fixture.branchIsolationDraft "Collective only"
    closureModelIdentities (closedGraphOccurrences qualification) qualification
      @?= ["proposal"]
    closureModelIdentities
      (closedQualificationOccurrences qualification)
      qualification
      @?= sort
            [ "key-result"
            , "need"
            , "objective"
            , "proposal"
            , "proposal-key-result"
            , "proposal-need"
            , "proposal-objective"
            , "proposal-strategy"
            , "strategy"
            ]
    closureModelIdentities
      (closedQualificationOccurrences collective)
      collective
      @?= ["claim"]
    closureModelIdentities (closedGraphOccurrences collective) collective
      @?= sort
            [ "claim"
            , "contributor-a"
            , "contributor-b"
            , "incoming-a"
            , "incoming-b"
            , "outgoing"
            , "target"
            ]
    withAcceptedProjection qualification $ \qualificationProjection ->
      withAcceptedProjection collective $ \collectiveProjection -> do
        length
          (Projection.profileQualificationProposals qualificationProjection)
          @?= 1
        Projection.profileQualificationProposals collectiveProjection @?= []
        qualificationStructure <-
          assessProjectedStructure qualificationProjection
        collectiveStructure <- assessProjectedStructure collectiveProjection
        summaryStructuredPropositions qualificationStructure @?= []
        length (summaryStructuredPropositions collectiveStructure) @?= 1

unmarkedDisplayedElementTest :: TestTree
unmarkedDisplayedElementTest =
  testCase "includes repeated unmarked display only in the Graph branch" $ do
    let closed = closedView Fixture.unmarkedDisplayedDraft "Main"
    length (closedDisplayedOccurrences closed) @?= 2
    map renderOccurrence (closedGraphOccurrences closed) @?= ["record:1"]
    closedQualificationOccurrences closed @?= []
    length (closedViewUniverse closed) @?= 2
    closedActivationProvenance closed @?= []
    closedClosureProvenance closed
      @?= [ stableConceptProvenance "record:3"
          , stableConceptProvenance "record:4"
          ]
  where
    stableConceptProvenance trigger =
      "o2i.archimate-profile|"
        <> "3254127ed6029c6df26fb30578956429fe9d3f82de8ee2f9bbe8d363b676d081|"
        <> "graph|graph.stable-concept|"
        <> trigger
        <> "|record:1|"

withAcceptedProjection ::
     ClosedView
  -> (forall profile document. Projection.ProfileProjection profile document -> IO
                                                                                  result)
  -> IO result
withAcceptedProjection (ClosedView universe) consume =
  Notation.foldStageResult
    (\issues ->
       assertFailure ("Notation rejected: " <> show (NonEmpty.length issues)))
    (Projection.foldProfileProjectionAssessment
       (\failures ->
          assertFailure
            ("Profile/Core contract failed: " <> show (NonEmpty.length failures)))
       (\defects ->
          assertFailure ("Profile rejected: " <> show (NonEmpty.length defects)))
       consume
       . Projection.assessSelectedView)
    (Notation.notationConformance (Notation.assessArchiMateNotation universe))

data StructureSummary = StructureSummary
  { summaryCarrierCount :: Int
  , summaryRelationCount :: Int
  , summaryStructuredPropositions :: [StructuredSummary]
  } deriving (Eq, Show)

data StructuredSummary = StructuredSummary
  { structuredIdentity :: Text
  , structuredFamily :: Text
  , structuredCompleteness :: Text
  , structuredCommitment :: Text
  , structuredIncidences :: [(Text, Text)]
  } deriving (Eq, Show)

assessProjectedStructure ::
     Projection.ProfileProjection profile document -> IO StructureSummary
assessProjectedStructure projected =
  Projection.withProfileStructureAssessment
    projected
    (\defects -> assertFailure ("identity index rejected: " <> show defects))
    (\defects -> assertFailure ("scope rejected: " <> show defects))
    (\defects -> assertFailure ("Core boundary rejected: " <> show defects))
    (foldStructureAssessment
       (\defects ->
          assertFailure
            ("Core Structure rejected: " <> show (NonEmpty.length defects)))
       (pure . summarizeGraph))
  where
    summarizeGraph graph =
      StructureSummary
        { summaryCarrierCount = length (wellFormedCarriers graph)
        , summaryRelationCount = length (wellFormedRelations graph)
        , summaryStructuredPropositions =
            map
              (summarize
                 [ ( carrierOccurrenceIdentity carrier
                   , carrierModelIdentity carrier)
                 | carrier <- wellFormedCarriers graph
                 ])
              (wellFormedStructuredPropositions graph)
        }
    summarize identities proposition =
      StructuredSummary
        { structuredIdentity =
            modelIdentityText (structuredPropositionModelIdentity proposition)
        , structuredFamily =
            CoreContract.coreStructuredPropositionFamilyIdText
              (structuredPropositionFamily proposition)
        , structuredCompleteness =
            CoreContract.coreParticipantCompletenessToken
              (structuredPropositionCompleteness proposition)
        , structuredCommitment =
            commitmentText (structuredPropositionCommitment proposition)
        , structuredIncidences =
            [ ( CoreContract.coreStructuredPropositionRoleIdText
                  (structuredIncidenceRole incidence)
              , targetModelIdentity
                  identities
                  (structuredIncidenceEndpoint incidence))
            | incidence <- structuredPropositionIncidences proposition
            ]
        }

recordIdentity ::
     Notation.CanonicalRecord
  -> (Notation.CanonicalOccurrence, Notation.IdentityOutcome)
recordIdentity =
  Notation.foldCanonicalRecord
    (\occurrence _ outcome _ _ -> (occurrence, outcome))

resolvedIdentity :: Notation.IdentityOutcome -> Maybe ModelIdentity
resolvedIdentity =
  Notation.foldIdentityOutcome Nothing (const Nothing) invalid resolved
  where
    invalid _ _ = Nothing
    resolved _ identifier = Just identifier

projectedOccurrence :: Notation.CanonicalOccurrence -> OccurrenceIdentity
projectedOccurrence occurrence =
  case Projection.canonicalOccurrenceIdentity occurrence of
    Right identifier -> identifier
    Left defect -> error ("invalid projected occurrence: " <> show defect)

identityOutcome :: Notation.IdentityOutcome -> Text
identityOutcome =
  Notation.foldIdentityOutcome
    "missing"
    (\scalars -> "multiple:" <> Text.pack (show (length scalars)))
    (\_ reason -> "invalid:" <> identityInvalidReason reason)
    (\_ identifier -> "resolved:" <> modelIdentityText identifier)

identityInvalidReason :: Notation.IdentityInvalidReason -> Text
identityInvalidReason =
  Notation.foldIdentityInvalidReason
    (\kind ->
       "non-text-"
         <> Draft.foldDraftValueKind
              "text"
              "boolean"
              "number"
              "native-name"
              id
              kind)
    "empty"
    "u0000"
    "surrogate"

referenceOutcome :: Notation.ReferenceOutcome -> Text
referenceOutcome =
  Notation.foldReferenceOutcome
    (\outcome -> "invalid:" <> identityOutcome outcome)
    (\_ identifier -> "missing:" <> modelIdentityText identifier)
    (\_ identifier expected targets ->
       Text.intercalate
         ":"
         [ "wrong-family"
         , modelIdentityText identifier
         , recordFamily expected
         , recordFamily
             (Notation.canonicalTargetFamily
                (headTotal "wrong-family target" targets))
         , Text.pack (show (length targets))
         ])
    (\_ identifier expected targets ->
       Text.intercalate
         ":"
         [ "ambiguous"
         , modelIdentityText identifier
         , recordFamily expected
         , Text.pack (show (length targets))
         ])
    (\_ identifier target ->
       Text.intercalate
         ":"
         [ "resolved"
         , modelIdentityText identifier
         , recordFamily (Notation.canonicalTargetFamily target)
         ])

recordFamily :: Draft.DraftRecordFamilyValue -> Text
recordFamily =
  Draft.foldDraftRecordFamilyValue
    "model-root"
    "property-definition"
    "element"
    "relationship"
    "view"
    "view-node"
    "view-connection"

renderScalar :: Draft.DraftScalar -> Text
renderScalar =
  Draft.foldDraftScalarValue
    ("text:" <>)
    (\value ->
       if value
         then "boolean:true"
         else "boolean:false")
    ("number:" <>)
    (\name -> "native-name:" <> renderNativeName name)
    (\kind value -> "other:" <> kind <> ":" <> value)

renderNativeName :: Draft.DraftNativeName -> Text
renderNativeName name =
  maybe
    ""
    (\namespace -> "{" <> namespace <> "}")
    (Draft.draftNativeNamespace name)
    <> Draft.draftNativeLocalName name

renderLocation :: Draft.DraftLocation -> Text
renderLocation location =
  renderPath (Draft.draftLocationPath location)
    <> maybe "" (("@" <>) . renderSpan) (Draft.draftLocationSpan location)

renderPath :: Draft.DraftSourcePath -> Text
renderPath =
  Draft.foldDraftSourcePath $ \first rest ->
    Text.intercalate "/" (map renderStep (first : rest))

renderStep :: Draft.DraftPathStep -> Text
renderStep step =
  renderNativeName (Draft.draftPathStepName step)
    <> "["
    <> Text.pack (show (Draft.draftPathStepOrdinal step))
    <> "]"

renderSpan :: Draft.DraftSourceSpan -> Text
renderSpan spanValue =
  renderPosition (Draft.draftSpanStart spanValue)
    <> "-"
    <> renderPosition (Draft.draftSpanEnd spanValue)

renderPosition :: Draft.DraftSourcePosition -> Text
renderPosition position =
  Text.intercalate
    ":"
    [ Text.pack (show (Draft.draftSourceLine position))
    , Text.pack (show (Draft.draftSourceColumn position))
    , maybe "-" (Text.pack . show) (Draft.draftSourceOffset position)
    ]

renderOpaque :: Draft.DraftOpaqueEvidence -> Text
renderOpaque evidence =
  Text.intercalate
    ":"
    [ Draft.foldDraftOpaquePosition
        "attribute"
        "child"
        (Draft.draftOpaquePosition evidence)
    , renderNativeName (Draft.draftOpaqueName evidence)
    , "["
        <> Text.intercalate
             ","
             (map renderScalar (Draft.draftOpaqueScalars evidence))
        <> "]"
    , renderLocation (Draft.draftOpaqueLocation evidence)
    ]

draftOpaqueInventory :: Draft.ProfileDraft -> [Draft.DraftOpaqueEvidence]
draftOpaqueInventory = collectOpaqueRecord . Draft.profileDraftRoot

collectOpaqueRecord ::
     Draft.DraftRecord recordRole -> [Draft.DraftOpaqueEvidence]
collectOpaqueRecord record =
  concatMap
    (Draft.foldDraftMember
       (\_ _ _ -> [])
       (\property -> Draft.draftPropertyOpaqueEvidence property)
       (const [])
       collectOpaqueRecord
       (: []))
    (Draft.draftRecordMembers record)

singleWhere :: String -> (value -> Bool) -> [value] -> value
singleWhere subject predicate = headTotal subject . filter predicate

data ClosedView =
  forall profile document. ClosedView
                             (Closure.ProfileAssessmentUniverse profile document)

closedView :: Draft.ProfileDraft -> Text -> ClosedView
closedView draft name =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument draft $ \document ->
      ClosedView
        (Closure.deriveProfileAssessmentUniverse
           profile
           document
           (singleWhere
              ("View named " <> Text.unpack name)
              ((== name) . viewName)
              (Notation.canonicalViews document)))

viewName :: Notation.CanonicalView document -> Text
viewName descriptor =
  Text.concat
    [ Draft.draftScalarText scalar
    | field <- Notation.canonicalViewNameFields descriptor
    , scalar <- Notation.canonicalFieldScalars field
    ]

data ClosureSnapshot = ClosureSnapshot
  { snapshotDisplayed :: [Text]
  , snapshotGraph :: [Text]
  , snapshotQualification :: [Text]
  , snapshotUniverse :: [Text]
  , snapshotActivation :: [Text]
  , snapshotClosure :: [Text]
  } deriving (Eq, Show)

closedDisplayedOccurrences :: ClosedView -> [Closure.DisplayedOccurrence]
closedDisplayedOccurrences (ClosedView universe) =
  Closure.assessmentDisplayedOccurrences universe

closedGraphOccurrences :: ClosedView -> [Notation.CanonicalOccurrence]
closedGraphOccurrences (ClosedView universe) =
  Closure.assessmentGraphOccurrences universe

closedQualificationOccurrences :: ClosedView -> [Notation.CanonicalOccurrence]
closedQualificationOccurrences (ClosedView universe) =
  Closure.assessmentQualificationOccurrences universe

closedViewUniverse :: ClosedView -> [Notation.CanonicalOccurrence]
closedViewUniverse (ClosedView universe) = Closure.assessmentUniverse universe

closedActivationProvenance :: ClosedView -> [Text]
closedActivationProvenance (ClosedView universe) =
  map renderActivation (Closure.assessmentActivationProvenance universe)

closedClosureProvenance :: ClosedView -> [Text]
closedClosureProvenance (ClosedView universe) =
  map renderClosure (Closure.assessmentClosureProvenance universe)

canonicalRecordIdentities ::
     ClosedView -> [(Notation.CanonicalOccurrence, Notation.IdentityOutcome)]
canonicalRecordIdentities (ClosedView universe) =
  [ recordIdentity record
  | record <-
      Notation.canonicalDocumentRecords
        (Closure.assessmentCanonicalDocument universe)
  ]

closureSnapshot :: ClosedView -> ClosureSnapshot
closureSnapshot closed =
  ClosureSnapshot
    { snapshotDisplayed =
        [ renderOccurrence (Closure.displayedSubjectOccurrence displayed)
        | displayed <- closedDisplayedOccurrences closed
        ]
    , snapshotGraph = map renderOccurrence (closedGraphOccurrences closed)
    , snapshotQualification =
        map renderOccurrence (closedQualificationOccurrences closed)
    , snapshotUniverse = map renderOccurrence (closedViewUniverse closed)
    , snapshotActivation = closedActivationProvenance closed
    , snapshotClosure = closedClosureProvenance closed
    }

closureSemanticSnapshot :: ClosedView -> ([Text], [Text], [Text])
closureSemanticSnapshot closed =
  ( closureModelIdentities (closedGraphOccurrences closed) closed
  , closureModelIdentities (closedQualificationOccurrences closed) closed
  , sort
      [ modelIdentityText identityValue
      | (_, identityValue) <- projectedIdentityInventory closed
      ])

renderOccurrence :: Notation.CanonicalOccurrence -> Text
renderOccurrence occurrence =
  Notation.foldCanonicalOccurrenceKind
    "record"
    "property"
    "reference"
    (Notation.canonicalOccurrenceKind occurrence)
    <> ":"
    <> Text.pack (show (Notation.canonicalOccurrenceOrdinal occurrence))

renderActivation :: Closure.ActivationProvenance profile document -> Text
renderActivation =
  Closure.foldActivationProvenance $ \profile digest branch rule owner trigger sources ->
    Text.intercalate
      "|"
      [ profile
      , digest
      , closureBranch branch
      , rule
      , renderOccurrence owner
      , renderOccurrence trigger
      , Text.intercalate "," sources
      ]

renderClosure :: Closure.ClosureProvenance profile document -> Text
renderClosure =
  Closure.foldClosureProvenance $ \profile digest branch rule trigger included context ->
    Text.intercalate
      "|"
      [ profile
      , digest
      , closureBranch branch
      , rule
      , renderOccurrence trigger
      , renderOccurrence included
      , Text.intercalate "," (map renderOccurrence context)
      ]

closureBranch :: Closure.ClosureBranch -> Text
closureBranch = Closure.foldClosureBranch "graph" "qualification"

projectedIdentityInventory ::
     ClosedView -> [(OccurrenceIdentity, ModelIdentity)]
projectedIdentityInventory closed =
  [ (projectedOccurrence occurrence, identifier)
  | (occurrence, outcome) <- canonicalRecordIdentities closed
  , identifier <- maybeToList (resolvedIdentity outcome)
  ]

targetModelIdentity ::
     [(OccurrenceIdentity, ModelIdentity)] -> OccurrenceIdentity -> Text
targetModelIdentity identities occurrence =
  case [ modelIdentityText identifier
       | (candidate, identifier) <- identities
       , candidate == occurrence
       ] of
    [identifier] -> identifier
    values ->
      error
        ("expected one model identity for "
           <> Text.unpack (occurrenceIdentityText occurrence)
           <> ", got "
           <> show values)

closureModelIdentities :: [Notation.CanonicalOccurrence] -> ClosedView -> [Text]
closureModelIdentities occurrences closed =
  sort
    [ modelIdentityText identifier
    | (occurrence, identifier) <- canonicalIdentityInventory closed
    , occurrence `elem` occurrences
    ]

canonicalIdentityInventory ::
     ClosedView -> [(Notation.CanonicalOccurrence, ModelIdentity)]
canonicalIdentityInventory closed =
  [ (occurrence, identifier)
  | (occurrence, outcome) <- canonicalRecordIdentities closed
  , identifier <- maybeToList (resolvedIdentity outcome)
  ]

projectionDefectSummaries :: ClosedView -> IO [(Text, Text, Int)]
projectionDefectSummaries (ClosedView universe) =
  Notation.foldStageResult
    (\issues -> assertFailure ("unexpected Notation defects: " <> show issues))
    (Projection.foldProfileProjectionAssessment
       (\failures ->
          assertFailure
            ("unexpected Profile/Core contract failures: "
               <> show (NonEmpty.length failures)))
       (pure . map summarize . NonEmpty.toList)
       (const (assertFailure "invalid Profile fixture unexpectedly projected"))
       . Projection.assessSelectedView)
    (Notation.notationConformance (Notation.assessArchiMateNotation universe))
  where
    summarize evidence =
      Projection.foldProfileDiagnosticEvidence
        (\rule exact -> (rule, evidenceKind exact, evidenceScalarCount exact))
        evidence

projectionDefectRules :: ClosedView -> IO [Text]
projectionDefectRules closed =
  map (\(rule, _, _) -> rule) <$> projectionDefectSummaries closed

commitmentText :: Commitment -> Text
commitmentText Candidate = "candidate"
commitmentText Asserted = "asserted"

evidenceKind :: Projection.ProfileEvidence profile document kind -> Text
evidenceKind evidence =
  Projection.foldProfileEvidenceKind
    "carrier"
    "classification"
    "metadata"
    "property-occurrence"
    "property-slot"
    "property-value"
    "proposal-carrier"
    "proposal-reference"
    "relationship"
    "reserved-property"
    "structured-carrier"
    "structured-incidence"
    (Projection.profileEvidenceKind evidence)

evidenceScalarCount :: Projection.ProfileEvidence profile document kind -> Int
evidenceScalarCount =
  Projection.foldProfileEvidence
    (const 0)
    (const 0)
    (\_ _ -> 0)
    (\_ _ -> 0)
    (\_ _ _ -> 0)
    (\_ _ scalars -> length scalars)
    (const 0)
    (\_ _ _ -> 0)
    (const 0)
    (\_ _ _ -> 0)
    (const 0)
    (\_ _ -> 0)

maybeToList :: Maybe value -> [value]
maybeToList Nothing = []
maybeToList (Just value) = [value]

headTotal :: String -> [value] -> value
headTotal _ [value] = value
headTotal subject values =
  error
    (subject <> ": expected exactly one value, got " <> show (length values))
