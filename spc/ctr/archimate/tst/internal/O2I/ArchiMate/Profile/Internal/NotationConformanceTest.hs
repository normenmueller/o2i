{-# LANGUAGE OverloadedStrings #-}

module O2I.ArchiMate.Profile.Internal.NotationConformanceTest
  ( notationConformanceTests
  ) where

import Data.List (sortOn)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import O2I.ArchiMate.Profile.Internal.Draft
import qualified O2I.ArchiMate.Profile.Internal.Notation as Raw
import O2I.ArchiMate.Profile.Internal.Notation.Conformance
import O2I.Core.Identity (ModelIdentity, modelIdentity)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

notationConformanceTests :: TestTree
notationConformanceTests =
  testGroup
    "closed Notation conformance"
    [ testCase
        "emits every one of the 38 closed classifications with exact evidence" $ do
        length classificationCases @?= 38
        map caseKind classificationCases
          @?= NonEmpty.toList allArchiMateNotationIssueKindsValue
        mapM_ assertClassification classificationCases
    , testCase "orders classifications canonically independent of input order"
        $ canonicalOrder (reverse allIssues)
            @?= sortOn archiMateNotationIssueKindValue allIssues
    ]
  where
    allIssues = concatMap caseIssues classificationCases

data ClassificationCase = ClassificationCase
  { caseKind :: ArchiMateNotationIssueKind
  , caseIssues :: [ArchiMateNotationIssue]
  , caseSubject :: DraftLocation
  , caseEvidence :: NonEmpty.NonEmpty ArchiMateNotationEvidence
  }

assertClassification :: ClassificationCase -> Assertion
assertClassification expectation =
  case caseIssues expectation of
    [actual] -> do
      archiMateNotationIssueKindValue actual @?= caseKind expectation
      archiMateNotationIssueSubjectValue actual @?= caseSubject expectation
      archiMateNotationIssueEvidenceValue actual @?= caseEvidence expectation
    actual ->
      assertFailure
        ("expected one issue for "
           <> show (caseKind expectation)
           <> ", got "
           <> show actual)

classificationCases :: [ClassificationCase]
classificationCases =
  inventoryIdentityCases
    ModelIdentityMissing
    ModelIdentityMultiplicity
    ModelIdentityValueKindInvalid
    ModelIdentityGrammarInvalid
    ModelIdentityDuplicate
    <> inventoryIdentityCases
         ViewIdentityMissing
         ViewIdentityMultiplicity
         ViewIdentityValueKindInvalid
         ViewIdentityGrammarInvalid
         ViewIdentityDuplicate
    <> viewNameCases
    <> markerKeyCases
    <> markerReferenceIdentityCases
    <> markerReferenceTargetCases
    <> markerDefinitionNameCases
    <> selectedIdentityCases
    <> selectedReferenceIdentityCases
    <> selectedReferenceTargetCases

inventoryIdentityCases ::
     ViewInventoryIssueKind
  -> ViewInventoryIssueKind
  -> ViewInventoryIssueKind
  -> ViewInventoryIssueKind
  -> ViewInventoryIssueKind
  -> [ClassificationCase]
inventoryIdentityCases missing multiple invalid grammar duplicate =
  zipWith
    make
    (map
       ViewInventoryNotationKind
       [missing, multiple, invalid, grammar, duplicate])
    identityOutcomes
  where
    make kind (outcome, duplicates, expected) =
      ClassificationCase
        kind
        (inventoryIdentityIssues
           missing
           multiple
           invalid
           grammar
           duplicate
           duplicates
           (canonicalRecord outcome []))
        subjectLocation
        expected

selectedIdentityCases :: [ClassificationCase]
selectedIdentityCases =
  zipWith
    make
    (map
       SelectedUniverseNotationKind
       [ RecordIdentityMissing
       , RecordIdentityMultiplicity
       , RecordIdentityValueKindInvalid
       , RecordIdentityGrammarInvalid
       , RecordIdentityDuplicate
       ])
    identityOutcomes
  where
    make kind (outcome, duplicates, expected) =
      ClassificationCase
        kind
        (selectedIdentityIssues duplicates (canonicalRecord outcome []))
        subjectLocation
        expected

identityOutcomes ::
     [( Raw.IdentityOutcome
      , Map.Map ModelIdentity [DraftLocation]
      , NonEmpty.NonEmpty ArchiMateNotationEvidence)]
identityOutcomes =
  [ (Raw.IdentityMissing, Map.empty, occurrenceEvidence subjectLocation)
  , ( Raw.IdentityMultiple [scalarA, scalarB]
    , Map.empty
    , scalarEvidence [scalarA, scalarB])
  , ( Raw.IdentityInvalid
        scalarBoolean
        (Raw.IdentityValueIsNotText DraftBoolean)
    , Map.empty
    , scalarEvidence [scalarBoolean])
  , ( Raw.IdentityInvalid scalarEmpty Raw.IdentityValueIsEmpty
    , Map.empty
    , scalarEvidence [scalarEmpty])
  , ( Raw.IdentityResolved scalarDuplicate duplicateIdentity
    , Map.singleton duplicateIdentity [subjectLocation, targetLocation]
    , NotationReferenceEvidence
        subjectLocation
        "duplicate"
        [subjectLocation, targetLocation]
        NonEmpty.:| [])
  ]

viewNameCases :: [ClassificationCase]
viewNameCases =
  [ ClassificationCase
      (ViewInventoryNotationKind ViewNameMissing)
      (viewNameIssues (canonicalRecord resolvedIdentity []))
      subjectLocation
      (occurrenceEvidence subjectLocation)
  , ClassificationCase
      (ViewInventoryNotationKind ViewNameMultiplicity)
      (viewNameIssues
         (canonicalRecord
            resolvedIdentity
            [nameField [scalarA], nameField [scalarB]]))
      subjectLocation
      (scalarEvidence [scalarA, scalarB])
  , ClassificationCase
      (ViewInventoryNotationKind ViewNameValueKindInvalid)
      (viewNameIssues
         (canonicalRecord resolvedIdentity [nameField [scalarBoolean]]))
      subjectLocation
      (scalarEvidence [scalarBoolean])
  ]

markerKeyCases :: [ClassificationCase]
markerKeyCases =
  [ markerKeyCase
      MarkerKeyMissing
      Raw.MarkerKeyMissing
      (occurrenceEvidence subjectLocation)
  , markerKeyCase
      MarkerKeyMultiplicity
      (Raw.MarkerKeyMultiple [scalarA, scalarB])
      (scalarEvidence [scalarA, scalarB])
  , markerKeyCase
      MarkerKeyValueKindInvalid
      (Raw.MarkerKeyNonText scalarBoolean)
      (scalarEvidence [scalarBoolean])
  ]

markerKeyCase ::
     ProfileMarkerIssueKind
  -> Raw.MarkerKeyOutcome
  -> NonEmpty.NonEmpty ArchiMateNotationEvidence
  -> ClassificationCase
markerKeyCase kind outcome expected =
  ClassificationCase
    (ProfileMarkerNotationKind kind)
    (markerKeyIssues
       MarkerKeyMissing
       MarkerKeyMultiplicity
       MarkerKeyValueKindInvalid
       subjectLocation
       outcome)
    subjectLocation
    expected

markerReferenceIdentityCases :: [ClassificationCase]
markerReferenceIdentityCases =
  [ markerReferenceIdentityCase
      MarkerReferenceIdentityMissing
      Raw.IdentityMissing
      (occurrenceEvidence subjectLocation)
  , markerReferenceIdentityCase
      MarkerReferenceIdentityMultiplicity
      (Raw.IdentityMultiple [scalarA, scalarB])
      (scalarEvidence [scalarA, scalarB])
  , markerReferenceIdentityCase
      MarkerReferenceIdentityValueKindInvalid
      (Raw.IdentityInvalid
         scalarBoolean
         (Raw.IdentityValueIsNotText DraftBoolean))
      (scalarEvidence [scalarBoolean])
  , markerReferenceIdentityCase
      MarkerReferenceIdentityGrammarInvalid
      (Raw.IdentityInvalid scalarEmpty Raw.IdentityValueIsEmpty)
      (scalarEvidence [scalarEmpty])
  ]

markerReferenceIdentityCase ::
     ProfileMarkerIssueKind
  -> Raw.IdentityOutcome
  -> NonEmpty.NonEmpty ArchiMateNotationEvidence
  -> ClassificationCase
markerReferenceIdentityCase kind outcome expected =
  ClassificationCase
    (ProfileMarkerNotationKind kind)
    (markerReferenceIdentityIssues subjectLocation outcome)
    subjectLocation
    expected

markerReferenceTargetCases :: [ClassificationCase]
markerReferenceTargetCases =
  [ markerCandidateCase
      MarkerReferenceTargetMissing
      (Raw.ReferenceTargetMissing scalarTarget targetIdentity)
      []
  , markerCandidateCase
      MarkerReferenceTargetWrongFamily
      (Raw.ReferenceTargetWrongFamily
         scalarTarget
         targetIdentity
         PropertyDefinitionFamily
         [canonicalTarget])
      [targetLocation]
  , markerCandidateCase
      MarkerReferenceTargetAmbiguous
      (Raw.ReferenceExpectedFamilyAmbiguous
         scalarTarget
         targetIdentity
         PropertyDefinitionFamily
         [canonicalTarget, canonicalTarget])
      [targetLocation, targetLocation]
  ]

markerCandidateCase ::
     ProfileMarkerIssueKind
  -> Raw.ReferenceOutcome
  -> [DraftLocation]
  -> ClassificationCase
markerCandidateCase kind outcome targets =
  ClassificationCase
    (ProfileMarkerNotationKind kind)
    (markerCandidateIssues
       (referencedMarkerCandidate outcome Raw.MarkerKeyMissing))
    subjectLocation
    (NotationReferenceEvidence subjectLocation "target" targets NonEmpty.:| [])

markerDefinitionNameCases :: [ClassificationCase]
markerDefinitionNameCases =
  [ markerDefinitionCase
      MarkerDefinitionNameMissing
      Raw.MarkerKeyMissing
      (occurrenceEvidence subjectLocation)
  , markerDefinitionCase
      MarkerDefinitionNameMultiplicity
      (Raw.MarkerKeyMultiple [scalarA, scalarB])
      (scalarEvidence [scalarA, scalarB])
  , markerDefinitionCase
      MarkerDefinitionNameValueKindInvalid
      (Raw.MarkerKeyNonText scalarBoolean)
      (scalarEvidence [scalarBoolean])
  ]

markerDefinitionCase ::
     ProfileMarkerIssueKind
  -> Raw.MarkerKeyOutcome
  -> NonEmpty.NonEmpty ArchiMateNotationEvidence
  -> ClassificationCase
markerDefinitionCase kind outcome expected =
  ClassificationCase
    (ProfileMarkerNotationKind kind)
    (markerCandidateIssues
       (referencedMarkerCandidate
          (Raw.ReferenceResolved scalarTarget targetIdentity canonicalTarget)
          outcome))
    subjectLocation
    expected

selectedReferenceIdentityCases :: [ClassificationCase]
selectedReferenceIdentityCases =
  [ selectedReferenceIdentityCase
      ReferenceIdentityMissing
      Raw.IdentityMissing
      (occurrenceEvidence subjectLocation)
  , selectedReferenceIdentityCase
      ReferenceIdentityMultiplicity
      (Raw.IdentityMultiple [scalarA, scalarB])
      (scalarEvidence [scalarA, scalarB])
  , selectedReferenceIdentityCase
      ReferenceIdentityValueKindInvalid
      (Raw.IdentityInvalid
         scalarBoolean
         (Raw.IdentityValueIsNotText DraftBoolean))
      (scalarEvidence [scalarBoolean])
  , selectedReferenceIdentityCase
      ReferenceIdentityGrammarInvalid
      (Raw.IdentityInvalid scalarEmpty Raw.IdentityValueIsEmpty)
      (scalarEvidence [scalarEmpty])
  ]

selectedReferenceIdentityCase ::
     SelectedUniverseIssueKind
  -> Raw.IdentityOutcome
  -> NonEmpty.NonEmpty ArchiMateNotationEvidence
  -> ClassificationCase
selectedReferenceIdentityCase kind outcome expected =
  ClassificationCase
    (SelectedUniverseNotationKind kind)
    (selectedReferenceIssues
       (canonicalReference (Raw.ReferenceIdentityInvalid outcome)))
    subjectLocation
    expected

selectedReferenceTargetCases :: [ClassificationCase]
selectedReferenceTargetCases =
  [ selectedReferenceTargetCase
      ReferenceTargetMissing
      (Raw.ReferenceTargetMissing scalarTarget targetIdentity)
      []
  , selectedReferenceTargetCase
      ReferenceTargetWrongFamily
      (Raw.ReferenceTargetWrongFamily
         scalarTarget
         targetIdentity
         ElementFamily
         [canonicalTarget])
      [targetLocation]
  , selectedReferenceTargetCase
      ReferenceTargetAmbiguous
      (Raw.ReferenceExpectedFamilyAmbiguous
         scalarTarget
         targetIdentity
         ElementFamily
         [canonicalTarget, canonicalTarget])
      [targetLocation, targetLocation]
  ]

selectedReferenceTargetCase ::
     SelectedUniverseIssueKind
  -> Raw.ReferenceOutcome
  -> [DraftLocation]
  -> ClassificationCase
selectedReferenceTargetCase kind outcome targets =
  ClassificationCase
    (SelectedUniverseNotationKind kind)
    (selectedReferenceIssues (canonicalReference outcome))
    subjectLocation
    (NotationReferenceEvidence subjectLocation "target" targets NonEmpty.:| [])

referencedMarkerCandidate ::
     Raw.ReferenceOutcome -> Raw.MarkerKeyOutcome -> Raw.MarkerCandidate
referencedMarkerCandidate outcome keyOutcome =
  Raw.MarkerCandidate
    (Raw.CanonicalProperty
       propertyOccurrence
       recordOccurrence
       ModelRootFamily
       subjectLocation
       []
       []
       (Raw.CanonicalReferencedPropertyKey (canonicalReference outcome)))
    []
    keyOutcome

canonicalRecord ::
     Raw.IdentityOutcome -> [Raw.CanonicalField] -> Raw.CanonicalRecord
canonicalRecord outcome fields =
  Raw.CanonicalRecord
    recordOccurrence
    Nothing
    ElementFamily
    outcome
    subjectLocation
    fields
    (DraftRecord DraftElement (DraftIdentity []) subjectLocation [])

canonicalReference :: Raw.ReferenceOutcome -> Raw.CanonicalReference
canonicalReference outcome =
  Raw.CanonicalReference
    referenceOccurrence
    recordOccurrence
    ViewNodeElementReferenceField
    ElementFamily
    subjectLocation
    outcome

canonicalTarget :: Raw.CanonicalTarget
canonicalTarget =
  Raw.CanonicalTarget
    targetOccurrence
    ElementFamily
    targetIdentity
    targetLocation
    []

nameField :: [DraftScalar] -> Raw.CanonicalField
nameField values = Raw.CanonicalField NameField values subjectLocation

resolvedIdentity :: Raw.IdentityOutcome
resolvedIdentity = Raw.IdentityResolved scalarResolved resolvedModelIdentity

recordOccurrence, targetOccurrence, propertyOccurrence, referenceOccurrence ::
     Raw.CanonicalOccurrence
recordOccurrence = Raw.CanonicalOccurrence Raw.CanonicalRecordOccurrence 1

targetOccurrence = Raw.CanonicalOccurrence Raw.CanonicalRecordOccurrence 2

propertyOccurrence = Raw.CanonicalOccurrence Raw.CanonicalPropertyOccurrence 1

referenceOccurrence = Raw.CanonicalOccurrence Raw.CanonicalReferenceOccurrence 1

subjectLocation, targetLocation :: DraftLocation
subjectLocation = location "subject"

targetLocation = location "target"

scalarA, scalarB, scalarBoolean, scalarEmpty, scalarDuplicate, scalarResolved, scalarTarget ::
     DraftScalar
scalarA = textScalar "a" "scalar-a"

scalarB = textScalar "b" "scalar-b"

scalarBoolean =
  DraftScalar (DraftBooleanScalar True) (location "scalar-boolean")

scalarEmpty = textScalar "" "scalar-empty"

scalarDuplicate = textScalar "duplicate" "scalar-duplicate"

scalarResolved = textScalar "resolved" "scalar-resolved"

scalarTarget = textScalar "target" "scalar-target"

duplicateIdentity, resolvedModelIdentity, targetIdentity :: ModelIdentity
duplicateIdentity = exactIdentity "duplicate"

resolvedModelIdentity = exactIdentity "resolved"

targetIdentity = exactIdentity "target"

exactIdentity :: Text -> ModelIdentity
exactIdentity value =
  case modelIdentity value of
    Left defect -> error ("invalid test identity: " <> show defect)
    Right identityValue -> identityValue

textScalar :: Text -> Text -> DraftScalar
textScalar value source = DraftScalar (DraftTextScalar value) (location source)

location :: Text -> DraftLocation
location subject =
  DraftLocation
    (DraftSourcePath (DraftPathStep (DraftNativeName Nothing subject) 1) [])
    Nothing

scalarEvidence :: [DraftScalar] -> NonEmpty.NonEmpty ArchiMateNotationEvidence
scalarEvidence values =
  case NonEmpty.nonEmpty (map scalarNotationEvidence values) of
    Nothing -> error "test evidence must be non-empty"
    Just evidence -> evidence
