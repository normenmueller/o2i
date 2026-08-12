{-# LANGUAGE OverloadedStrings #-}

module O2I.ArchiMate.Profile.Internal.Closure where

import qualified Data.Map.Strict as Map
import Data.Sequence (Seq, ViewL(..), (|>))
import qualified Data.Sequence as Seq
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.ArchiMate.Profile.Internal.Draft
import O2I.ArchiMate.Profile.Internal.Generated
import O2I.ArchiMate.Profile.Internal.Index
import O2I.ArchiMate.Profile.Internal.Mapping
import O2I.ArchiMate.Profile.Internal.Notation

-- | One subject occurrence displayed by a node or connection in a View.
data DisplayedOccurrence = DisplayedOccurrence
  { displayedViewOccurrenceValue :: !CanonicalOccurrence
  , displayedSubjectOccurrenceValue :: !CanonicalOccurrence
  } deriving (Eq, Ord, Show)

-- | Independent closure branch activated for one selected View.
data ClosureBranch
  = GraphBranch
  | QualificationBranch
  deriving (Eq, Ord, Show)

-- | Exact generated rule evidence that activated one closure branch.
data ActivationProvenance = ActivationProvenance
  { activationProvenanceProfileIdentityValue :: !Text
  , activationProvenanceProfileDigestValue :: !Text
  , activationProvenanceBranchValue :: !ClosureBranch
  , activationProvenanceRuleRankValue :: !Int
  , activationProvenanceRuleIdValue :: !Text
  , activationProvenanceOwnerValue :: !CanonicalOccurrence
  , activationProvenanceTriggerValue :: !CanonicalOccurrence
  , activationProvenanceSourceRuleIdsValue :: ![Text]
  } deriving (Eq, Show)

instance Ord ActivationProvenance where
  compare left right = compare (order left) (order right)
    where
      order provenance =
        ( activationProvenanceBranchValue provenance
        , activationProvenanceRuleRankValue provenance
        , activationProvenanceTriggerValue provenance
        , activationProvenanceOwnerValue provenance
        , activationProvenanceRuleIdValue provenance
        , activationProvenanceSourceRuleIdsValue provenance
        , activationProvenanceProfileIdentityValue provenance
        , activationProvenanceProfileDigestValue provenance)

-- | Exact generated rule evidence that admitted one occurrence to closure.
data ClosureProvenance = ClosureProvenance
  { closureProvenanceProfileIdentityValue :: !Text
  , closureProvenanceProfileDigestValue :: !Text
  , closureProvenanceBranchValue :: !ClosureBranch
  , closureProvenanceRuleRankValue :: !Int
  , closureProvenanceRuleIdValue :: !Text
  , closureProvenanceTriggerValue :: !CanonicalOccurrence
  , closureProvenanceIncludedValue :: !CanonicalOccurrence
  , closureProvenanceContextValue :: ![CanonicalOccurrence]
  } deriving (Eq, Show)

instance Ord ClosureProvenance where
  compare left right = compare (order left) (order right)
    where
      order provenance =
        ( closureProvenanceBranchValue provenance
        , closureProvenanceRuleRankValue provenance
        , closureProvenanceTriggerValue provenance
        , closureProvenanceIncludedValue provenance
        , closureProvenanceRuleIdValue provenance
        , closureProvenanceContextValue provenance
        , closureProvenanceProfileIdentityValue provenance
        , closureProvenanceProfileDigestValue provenance)

-- | Deterministic graph and qualification closure of one selected View.
data ClosedView = ClosedView
  { closedViewDocumentValue :: !CanonicalDocument
  , closedViewIndexValue :: !ProfileIndex
  , closedViewOccurrenceValue :: !CanonicalOccurrence
  , closedViewDisplayedOccurrencesValue :: ![DisplayedOccurrence]
  , closedViewGraphOccurrencesValue :: !(Set CanonicalOccurrence)
  , closedViewQualificationOccurrencesValue :: !(Set CanonicalOccurrence)
  , closedViewQualificationProposalOccurrencesValue :: !(Set CanonicalOccurrence)
  , closedViewUniverseValue :: !(Set CanonicalOccurrence)
  , closedViewActivationProvenanceValue :: !(Set ActivationProvenance)
  , closedViewClosureProvenanceValue :: !(Set ClosureProvenance)
  }

-- | Private deterministic work evidence for one closure evaluation.
data ClosureWork = ClosureWork
  { closureWorkDequeuedItems :: !Int
  , closureWorkActivationRuleChecks :: !Int
  , closureWorkClosureRuleChecks :: !Int
  , closureWorkVisitedIndexCandidates :: !Int
  } deriving (Eq, Show)

newtype WorkDelta = WorkDelta
  { workDeltaVisitedIndexCandidates :: Int
  } deriving (Eq, Show)

instance Semigroup WorkDelta where
  WorkDelta left <> WorkDelta right = WorkDelta (left + right)

instance Monoid WorkDelta where
  mempty = WorkDelta 0

data Measured value = Measured
  { measuredWork :: !WorkDelta
  , measuredValue :: value
  }

data GraphFact
  = GraphMember !CanonicalOccurrence
  | GraphSeed !CanonicalOccurrence !CanonicalOccurrence
  | GraphContextualizableCarrier !CanonicalOccurrence !Text
  | GraphContextualization
      !CanonicalOccurrence
      !CanonicalOccurrence
      !CanonicalOccurrence
  | GraphStructuredFamilyCarrier !Text !CanonicalOccurrence
  | GraphStructuredFamilyIncidence
      !Text
      !CanonicalOccurrence
      !CanonicalOccurrence
  | GraphStructuredFamilyParticipantSegment
      !Text
      !CanonicalOccurrence
      !CanonicalOccurrence
  | GraphStructuredFamilyTargetSegment
      !Text
      !CanonicalOccurrence
      !CanonicalOccurrence
  deriving (Eq, Ord, Show)

data QualificationFact
  = QualificationMember !CanonicalOccurrence
  | QualificationProposalCarrier !CanonicalOccurrence
  | QualificationProposalRoleIncidence !CanonicalOccurrence !CanonicalOccurrence
  | QualificationContextualizableProposalEndpoint
      !CanonicalOccurrence
      !CanonicalOccurrence
      !Text
      !CanonicalOccurrence
  | QualificationContextualizationOfProposalEndpoint
      !CanonicalOccurrence
      !CanonicalOccurrence
      !CanonicalOccurrence
      !CanonicalOccurrence
  | QualificationContextOwnerRequiredByProposal
      !CanonicalOccurrence
      !CanonicalOccurrence
      !CanonicalOccurrence
      !CanonicalOccurrence
      !CanonicalOccurrence
  | QualificationContextualizationOfExactProposalEndpoint
      !CanonicalOccurrence
      !CanonicalOccurrence
      !CanonicalOccurrence
      !CanonicalOccurrence
      !CanonicalOccurrence
  deriving (Eq, Ord, Show)

data ActivationBinding = ActivationBinding
  { bindingOwner :: !CanonicalOccurrence
  , bindingTrigger :: !CanonicalOccurrence
  , bindingSource :: !(Maybe CanonicalOccurrence)
  , bindingTarget :: !(Maybe CanonicalOccurrence)
  , bindingJunction :: !(Maybe CanonicalOccurrence)
  , bindingProposal :: !(Maybe CanonicalOccurrence)
  , bindingValueId :: !(Maybe Text)
  , bindingSourceRuleIds :: ![Text]
  } deriving (Eq, Ord, Show)

data Activation = Activation
  { activationRule :: !GeneratedActivationRule
  , activationBinding :: !ActivationBinding
  } deriving (Eq, Ord, Show)

data GraphProvenance
  = GraphActivationReason !Activation !GraphFact
  | GraphClosureReason !ClosureProvenance !GraphFact
  | GraphSeedReason !CanonicalOccurrence !CanonicalOccurrence
  deriving (Eq, Ord, Show)

data QualificationProvenance
  = QualificationActivationReason !Activation !QualificationFact
  | QualificationClosureReason !ClosureProvenance !QualificationFact
  deriving (Eq, Ord, Show)

data WorkItem
  = GraphActivationWork !Activation
  | QualificationActivationWork !Activation
  | GraphFactWork !GraphFact
  | QualificationFactWork !QualificationFact
  deriving (Eq, Ord, Show)

data IncidenceTrigger
  = GraphIncidenceTrigger !GraphFact
  | QualificationIncidenceTrigger !QualificationFact
  deriving (Eq, Ord, Show)

data IncidenceScan =
  IncidenceScan
    !ClosureBranch
    !GeneratedActivationRule
    !IncidenceTrigger
    !CanonicalOccurrence
  deriving (Eq, Ord, Show)

data ProductState = ProductState
  { productGraphActivations :: !(Set Activation)
  , productGraphFacts :: !(Set GraphFact)
  , productGraphProvenance :: !(Set GraphProvenance)
  , productQualificationActivations :: !(Set Activation)
  , productQualificationFacts :: !(Set QualificationFact)
  , productQualificationProvenance :: !(Set QualificationProvenance)
  , productActivationEvidence :: !(Set ActivationProvenance)
  , productClosureEvidence :: !(Set ClosureProvenance)
  , productPendingWork :: !(Seq WorkItem)
  , productIncidenceScans :: !(Set IncidenceScan)
  , productClosureWork :: !ClosureWork
  }

emptyProduct :: ProductState
emptyProduct =
  ProductState
    { productGraphActivations = Set.empty
    , productGraphFacts = Set.empty
    , productGraphProvenance = Set.empty
    , productQualificationActivations = Set.empty
    , productQualificationFacts = Set.empty
    , productQualificationProvenance = Set.empty
    , productActivationEvidence = Set.empty
    , productClosureEvidence = Set.empty
    , productPendingWork = Seq.empty
    , productIncidenceScans = Set.empty
    , productClosureWork = ClosureWork 0 0 0 0
    }

measuredMapLookup ::
     Ord key => key -> Map.Map key value -> Measured (Maybe value)
measuredMapLookup key values =
  case Map.lookup key values of
    Nothing -> Measured mempty Nothing
    Just value -> Measured (WorkDelta 1) (Just value)

measuredIndexCandidatesWith ::
     (candidate -> [value]) -> [candidate] -> Measured [value]
measuredIndexCandidatesWith project = foldr visit (Measured mempty [])
  where
    visit candidate measured =
      Measured
        (WorkDelta 1 <> measuredWork measured)
        (project candidate ++ measuredValue measured)

measuredIndexCandidatesWithM ::
     (candidate -> Measured [value]) -> [candidate] -> Measured [value]
measuredIndexCandidatesWithM project = foldr visit (Measured mempty [])
  where
    visit candidate measured =
      Measured
        (WorkDelta 1 <> measuredWork projected <> measuredWork measured)
        (measuredValue projected ++ measuredValue measured)
      where
        projected = project candidate

collectMeasured ::
     (candidate -> Measured [value]) -> [candidate] -> Measured [value]
collectMeasured project = foldr collect (Measured mempty [])
  where
    collect candidate measured =
      Measured
        (measuredWork projected <> measuredWork measured)
        (measuredValue projected ++ measuredValue measured)
      where
        projected = project candidate

measuredIndexAny :: (candidate -> Bool) -> [candidate] -> Measured Bool
measuredIndexAny predicate = search 0
  where
    search visited candidates =
      case candidates of
        [] -> Measured (WorkDelta visited) False
        candidate:remaining
          | predicate candidate -> Measured (WorkDelta (visited + 1)) True
          | otherwise -> search (visited + 1) remaining

measuredUniqueIndexCandidate :: [candidate] -> Measured (Maybe candidate)
measuredUniqueIndexCandidate candidates =
  Measured
    (WorkDelta (length candidates))
    (case candidates of
       [candidate] -> Just candidate
       _ -> Nothing)

closeView :: ViewDescriptor -> ClosedView
closeView = fst . closeViewWithWork

closeViewWithWork :: ViewDescriptor -> (ClosedView, ClosureWork)
closeViewWithWork selected =
  ( ClosedView
      { closedViewDocumentValue = document
      , closedViewIndexValue = profileIndex
      , closedViewOccurrenceValue = selectedView
      , closedViewDisplayedOccurrencesValue = displayed
      , closedViewGraphOccurrencesValue = graphMembers final
      , closedViewQualificationOccurrencesValue = qualificationMembers final
      , closedViewQualificationProposalOccurrencesValue =
          qualificationProposals final
      , closedViewUniverseValue =
          seedSubjects
            `Set.union` graphMembers final
            `Set.union` qualificationMembers final
      , closedViewActivationProvenanceValue = productActivationEvidence final
      , closedViewClosureProvenanceValue = productClosureEvidence final
      }
  , productClosureWork final)
  where
    document = viewDescriptorDocumentValue selected
    selectedView = viewDescriptorOccurrenceValue selected
    profileIndex = buildProfileIndex document
    measuredDisplayed = displayedOccurrencesMeasured profileIndex selectedView
    displayed = measuredValue measuredDisplayed
    seedSubjects =
      indexModelRoots profileIndex
        `Set.union` Set.fromList (map displayedSubjectOccurrenceValue displayed)
    final =
      recordIndexCandidates
        (workDeltaVisitedIndexCandidates (measuredWork measuredDisplayed))
        (evaluateProduct profileIndex displayed)

recordDequeuedWork :: ProductState -> ProductState
recordDequeuedWork state =
  state
    { productClosureWork =
        work {closureWorkDequeuedItems = closureWorkDequeuedItems work + 1}
    }
  where
    work = productClosureWork state

recordActivationCheck :: Int -> ProductState -> ProductState
recordActivationCheck candidates state =
  state
    { productClosureWork =
        work
          { closureWorkActivationRuleChecks =
              closureWorkActivationRuleChecks work + 1
          , closureWorkVisitedIndexCandidates =
              closureWorkVisitedIndexCandidates work + candidates
          }
    }
  where
    work = productClosureWork state

recordClosureCheck :: Int -> ProductState -> ProductState
recordClosureCheck candidates state =
  state
    { productClosureWork =
        work
          { closureWorkClosureRuleChecks = closureWorkClosureRuleChecks work + 1
          , closureWorkVisitedIndexCandidates =
              closureWorkVisitedIndexCandidates work + candidates
          }
    }
  where
    work = productClosureWork state

recordIndexCandidates :: Int -> ProductState -> ProductState
recordIndexCandidates candidates state =
  state
    { productClosureWork =
        work
          { closureWorkVisitedIndexCandidates =
              closureWorkVisitedIndexCandidates work + candidates
          }
    }
  where
    work = productClosureWork state

displayedOccurrences ::
     ProfileIndex -> CanonicalOccurrence -> [DisplayedOccurrence]
displayedOccurrences profileIndex =
  measuredValue . displayedOccurrencesMeasured profileIndex

displayedOccurrencesMeasured ::
     ProfileIndex -> CanonicalOccurrence -> Measured [DisplayedOccurrence]
displayedOccurrencesMeasured profileIndex selectedView =
  Measured
    (measuredWork descendants <> measuredWork resolved)
    (measuredValue resolved)
  where
    descendants = descendantsOfMeasured profileIndex selectedView
    resolved = collectMeasured resolve (measuredValue descendants)
    resolve record =
      case recordInfoFamily record of
        ViewNodeFamily -> fromReference ViewNodeElementReferenceField record
        ViewConnectionFamily ->
          fromReference ViewConnectionRelationshipReferenceField record
        _ -> Measured mempty []
    fromReference field record =
      Measured
        (measuredWork measuredReference)
        (case measuredValue measuredReference of
           Just reference ->
             case resolvedReferenceOccurrence reference of
               Just subject ->
                 [DisplayedOccurrence (recordInfoOccurrence record) subject]
               Nothing -> []
           Nothing -> [])
      where
        references =
          Map.findWithDefault
            []
            (recordInfoOccurrence record, field)
            (indexReferencesByOwnerAndField profileIndex)
        measuredReference = measuredUniqueIndexCandidate references

descendantsOfMeasured ::
     ProfileIndex -> CanonicalOccurrence -> Measured [RecordInfo]
descendantsOfMeasured profileIndex parent =
  measuredIndexCandidatesWithM descend children
  where
    children =
      Map.findWithDefault [] parent (indexChildrenByParent profileIndex)
    descend child =
      descendants {measuredValue = child : measuredValue descendants}
      where
        descendants =
          descendantsOfMeasured profileIndex (recordInfoOccurrence child)

evaluateProduct :: ProfileIndex -> [DisplayedOccurrence] -> ProductState
evaluateProduct profileIndex displayed = drainProduct profileIndex withDirect
  where
    withSeeds = foldl' (insertGraphSeed profileIndex) emptyProduct displayed
    displayedSubjects =
      Set.fromList (map displayedSubjectOccurrenceValue displayed)
    directRecords =
      Set.toAscList (indexModelRoots profileIndex `Set.union` displayedSubjects)
    withDirect = foldl' applyRecord withSeeds directRecords
    applyRecord state occurrence =
      foldl'
        (applyDirectActivation profileIndex displayedSubjects occurrence)
        state
        generatedActivationRules

insertGraphSeed ::
     ProfileIndex -> ProductState -> DisplayedOccurrence -> ProductState
insertGraphSeed profileIndex state displayed =
  foldl' addSeed checked (measuredValue measuredSeeds)
  where
    measuredSeeds = graphSeedsForDisplayed profileIndex displayed
    checked =
      recordIndexCandidates
        (workDeltaVisitedIndexCandidates (measuredWork measuredSeeds))
        state
    addSeed current fact@(GraphSeed viewOccurrence subject) =
      addGraphFact (GraphSeedReason viewOccurrence subject) fact current
    addSeed current _ = current

graphSeedsForDisplayed ::
     ProfileIndex -> DisplayedOccurrence -> Measured [GraphFact]
graphSeedsForDisplayed profileIndex displayed =
  case measuredValue measuredViewRecord of
    Just viewRecord
      | recordInfoFamily viewRecord == ViewNodeFamily ->
        measuredSubjectRecord
          { measuredWork =
              measuredWork measuredViewRecord
                <> measuredWork measuredSubjectRecord
          , measuredValue =
              case measuredValue measuredSubjectRecord of
                Just subjectRecord
                  | isConcept subjectRecord ->
                    [GraphSeed viewOccurrence subject]
                _ -> []
          }
    _ -> Measured (measuredWork measuredViewRecord) []
  where
    viewOccurrence = displayedViewOccurrenceValue displayed
    subject = displayedSubjectOccurrenceValue displayed
    measuredViewRecord =
      measuredMapLookup viewOccurrence (indexRecords profileIndex)
    measuredSubjectRecord =
      measuredMapLookup subject (indexRecords profileIndex)

drainProduct :: ProfileIndex -> ProductState -> ProductState
drainProduct profileIndex state =
  case Seq.viewl (productPendingWork state) of
    EmptyL -> state
    work :< pending ->
      drainProduct
        profileIndex
        (processWork
           profileIndex
           work
           (recordDequeuedWork state {productPendingWork = pending}))

processWork :: ProfileIndex -> WorkItem -> ProductState -> ProductState
processWork profileIndex work state =
  case work of
    GraphActivationWork activation ->
      foldl'
        (\current fact ->
           addGraphFact (GraphActivationReason activation fact) fact current)
        state
        (graphActivationFacts activation)
    QualificationActivationWork activation ->
      foldl'
        (\current fact ->
           addQualificationFact
             (QualificationActivationReason activation fact)
             fact
             current)
        state
        (qualificationActivationFacts activation)
    GraphFactWork fact -> processGraphFact profileIndex fact state
    QualificationFactWork fact ->
      processQualificationFact profileIndex fact state

processGraphFact :: ProfileIndex -> GraphFact -> ProductState -> ProductState
processGraphFact profileIndex fact state =
  foldl' addClosure withIncidences generatedClosureRules
  where
    delta = emptyProduct {productGraphFacts = Set.singleton fact}
    withIncidences =
      foldl'
        (applyIncidenceForTrigger
           profileIndex
           GraphBranch
           (GraphIncidenceTrigger fact)
           delta)
        state
        generatedActivationRules
    addClosure current rule =
      let measuredResults = graphClosureResults profileIndex delta rule
       in foldl'
            addGraphClosure
            (recordClosureCheck
               (workDeltaVisitedIndexCandidates (measuredWork measuredResults))
               current)
            (measuredValue measuredResults)

processQualificationFact ::
     ProfileIndex -> QualificationFact -> ProductState -> ProductState
processQualificationFact profileIndex fact state =
  foldl' addClosure withIncidences generatedClosureRules
  where
    delta = emptyProduct {productQualificationFacts = Set.singleton fact}
    withIncidences =
      foldl'
        (applyIncidenceForTrigger
           profileIndex
           QualificationBranch
           (QualificationIncidenceTrigger fact)
           delta)
        state
        generatedActivationRules
    addClosure current rule =
      let measuredResults = qualificationClosureResults profileIndex delta rule
       in foldl'
            addQualificationClosure
            (recordClosureCheck
               (workDeltaVisitedIndexCandidates (measuredWork measuredResults))
               current)
            (measuredValue measuredResults)

applyIncidenceForTrigger ::
     ProfileIndex
  -> ClosureBranch
  -> IncidenceTrigger
  -> ProductState
  -> ProductState
  -> GeneratedActivationRule
  -> ProductState
applyIncidenceForTrigger profileIndex branch trigger delta state rule =
  foldl' applyGroup checked (Map.toAscList grouped)
  where
    measuredMatches = incidenceMatches profileIndex delta rule
    checked =
      recordActivationCheck
        (workDeltaVisitedIndexCandidates (measuredWork measuredMatches))
        state
    grouped =
      Map.fromListWith
        (++)
        [ (bindingOwner binding, [binding])
        | binding <- measuredValue measuredMatches
        ]
    applyGroup current (occurrence, bindings)
      | scan `Set.member` productIncidenceScans current = current
      | otherwise =
        foldl'
          (insertActivation rule)
          current
            { productIncidenceScans =
                Set.insert scan (productIncidenceScans current)
            }
          bindings
      where
        scan = IncidenceScan branch rule trigger occurrence

addGraphClosure ::
     ProductState -> (GraphFact, ClosureProvenance) -> ProductState
addGraphClosure state (fact, provenance) =
  addGraphFact
    (GraphClosureReason provenance fact)
    fact
    state
      { productClosureEvidence =
          Set.insert provenance (productClosureEvidence state)
      }

addQualificationClosure ::
     ProductState -> (QualificationFact, ClosureProvenance) -> ProductState
addQualificationClosure state (fact, provenance) =
  addQualificationFact
    (QualificationClosureReason provenance fact)
    fact
    state
      { productClosureEvidence =
          Set.insert provenance (productClosureEvidence state)
      }

applyDirectActivation ::
     ProfileIndex
  -> Set CanonicalOccurrence
  -> CanonicalOccurrence
  -> ProductState
  -> GeneratedActivationRule
  -> ProductState
applyDirectActivation profileIndex displayed occurrence state rule =
  foldl'
    (insertActivation rule)
    (recordActivationCheck
       (workDeltaVisitedIndexCandidates (measuredWork measuredMatches))
       state)
    (measuredValue measuredMatches)
  where
    measuredMatches = directMatches profileIndex displayed occurrence rule

directMatches ::
     ProfileIndex
  -> Set CanonicalOccurrence
  -> CanonicalOccurrence
  -> GeneratedActivationRule
  -> Measured [ActivationBinding]
directMatches profileIndex displayed occurrence rule =
  case rule of
    ActivateGraphCarrier _ ->
      whenDisplayed (carrierBindingsMeasured profileIndex occurrence)
    ActivateGraphStructuredCarrier _ ->
      whenDisplayed (structuredCarrierBindingsMeasured profileIndex occurrence)
    ActivateGraphStructuredProperty _ ->
      whenDisplayed (structuredPropertyBindingsMeasured profileIndex occurrence)
    ActivateGraphCommittedElement _ ->
      whenDisplayed
        (propertyBindingsMeasured
           profileIndex
           isConcept
           "o2i.commitment"
           [occurrence])
    ActivateGraphCommittedStructuredCarrier _ ->
      whenDisplayed
        (propertyBindingsMeasured
           profileIndex
           isJunction
           "o2i.commitment"
           [occurrence])
    ActivateGraphCommittedRelationship _ ->
      whenDisplayed
        (propertyBindingsMeasured
           profileIndex
           isRelationship
           "o2i.commitment"
           [occurrence])
    ActivateQualificationProposalType _ ->
      whenDisplayed (proposalTypeBindingsMeasured profileIndex occurrence)
    ActivateQualificationProposalSourceKey _ ->
      whenDisplayed
        (propertyBindingsMeasured
           profileIndex
           isConcept
           "o2i.source"
           [occurrence])
    ActivateQualificationRoleKey _ ->
      whenDisplayed
        (propertyBindingsMeasured
           profileIndex
           isRelationship
           "o2i.role"
           [occurrence])
    ActivateSharedUnknownProperty _ ->
      unknownPropertyBindingsMeasured profileIndex [occurrence]
    ActivateSharedTypeKey _ ->
      whenDisplayed
        (propertyBindingsMeasured
           profileIndex
           (\record -> isConcept record || isJunction record)
           "o2i.type"
           [occurrence])
    ActivateGraphRelation _ -> Measured mempty []
    ActivateGraphContextualizationLabel _ -> Measured mempty []
    ActivateGraphContextualizationShape _ -> Measured mempty []
    ActivateGraphStructuredSegment _ -> Measured mempty []
    ActivateQualificationProposalIncidence _ -> Measured mempty []
  where
    whenDisplayed measured
      | occurrence `Set.member` displayed = measured
      | otherwise = Measured mempty []

incidenceMatches ::
     ProfileIndex
  -> ProductState
  -> GeneratedActivationRule
  -> Measured [ActivationBinding]
incidenceMatches profileIndex state rule =
  case rule of
    ActivateGraphCarrier _ -> none
    ActivateGraphStructuredCarrier _ -> none
    ActivateGraphStructuredProperty _ -> none
    ActivateGraphCommittedElement _ -> none
    ActivateGraphCommittedStructuredCarrier _ -> none
    ActivateGraphCommittedRelationship _ -> none
    ActivateQualificationProposalType _ -> none
    ActivateQualificationProposalSourceKey _ -> none
    ActivateQualificationRoleKey _ -> none
    ActivateSharedUnknownProperty _ -> none
    ActivateSharedTypeKey _ -> none
    ActivateGraphRelation _ -> graphRelationBindingsMeasured profileIndex state
    ActivateGraphContextualizationLabel _ ->
      graphContextualizationLabelBindingsMeasured profileIndex state
    ActivateGraphContextualizationShape _ ->
      graphContextualizationShapeBindingsMeasured profileIndex state
    ActivateGraphStructuredSegment _ ->
      structuredSegmentBindingsMeasured profileIndex state
    ActivateQualificationProposalIncidence _ ->
      qualificationIncidenceBindingsMeasured profileIndex state
  where
    none = Measured mempty []

insertActivation ::
     GeneratedActivationRule
  -> ProductState
  -> ActivationBinding
  -> ProductState
insertActivation rule state binding =
  case generatedActivationBranchScope rule of
    GeneratedGraphOnly -> insertGraphActivation activation state
    GeneratedQualificationOnly -> insertQualificationActivation activation state
    GeneratedGraphAndQualification ->
      insertQualificationActivation
        activation
        (insertGraphActivation activation state)
  where
    activation = Activation rule binding

insertGraphActivation :: Activation -> ProductState -> ProductState
insertGraphActivation activation state =
  state
    { productGraphActivations = Set.insert activation known
    , productActivationEvidence =
        Set.insert
          (activationEvidence GraphBranch activation)
          (productActivationEvidence state)
    , productPendingWork =
        if activation `Set.member` known
          then productPendingWork state
          else productPendingWork state |> GraphActivationWork activation
    }
  where
    known = productGraphActivations state

insertQualificationActivation :: Activation -> ProductState -> ProductState
insertQualificationActivation activation state =
  state
    { productQualificationActivations = Set.insert activation known
    , productActivationEvidence =
        Set.insert
          (activationEvidence QualificationBranch activation)
          (productActivationEvidence state)
    , productPendingWork =
        if activation `Set.member` known
          then productPendingWork state
          else productPendingWork state
                 |> QualificationActivationWork activation
    }
  where
    known = productQualificationActivations state

activationEvidence :: ClosureBranch -> Activation -> ActivationProvenance
activationEvidence branch activation =
  ActivationProvenance
    (generatedProfileIdentity generatedProfileDescriptor)
    (generatedProfileContractDigest generatedProfileDescriptor)
    branch
    (activationRuleRank (activationRule activation))
    (generatedActivationProvenanceRuleId (activationRule activation))
    (bindingOwner binding)
    (bindingTrigger binding)
    (Set.toAscList
       (Set.fromList
          (generatedActivationStaticSourceRuleIds (activationRule activation)
             ++ bindingSourceRuleIds binding)))
  where
    binding = activationBinding activation

closureEvidence ::
     ClosureBranch
  -> Text
  -> CanonicalOccurrence
  -> CanonicalOccurrence
  -> [CanonicalOccurrence]
  -> ClosureProvenance
closureEvidence branch ruleId trigger included context =
  ClosureProvenance
    (generatedProfileIdentity generatedProfileDescriptor)
    (generatedProfileContractDigest generatedProfileDescriptor)
    branch
    (closureRuleRank ruleId)
    ruleId
    trigger
    included
    (Set.toAscList (Set.fromList context))

activationRuleRank :: GeneratedActivationRule -> Int
activationRuleRank subject = rankOf subject generatedActivationRules

closureRuleRank :: Text -> Int
closureRuleRank subject =
  rankOf subject (map generatedClosureProvenanceRuleId generatedClosureRules)

rankOf :: Eq value => value -> [value] -> Int
rankOf subject = length . takeWhile (/= subject)

graphActivationFacts :: Activation -> [GraphFact]
graphActivationFacts activation =
  case activationRule activation of
    ActivateGraphCarrier _ ->
      GraphMember owner
        : maybe
            []
            (\value -> [GraphContextualizableCarrier owner value])
            valueId
    ActivateGraphStructuredCarrier _ -> structuredCarrierFacts
    ActivateGraphStructuredProperty _ -> structuredCarrierFacts
    ActivateGraphCommittedElement _ -> [GraphMember owner]
    ActivateGraphCommittedStructuredCarrier _ -> structuredCarrierFacts
    ActivateGraphCommittedRelationship _ -> [GraphMember owner]
    ActivateQualificationProposalType _ -> []
    ActivateQualificationProposalSourceKey _ -> []
    ActivateQualificationRoleKey _ -> []
    ActivateSharedUnknownProperty _ -> [GraphMember owner]
    ActivateSharedTypeKey _ -> [GraphMember owner]
    ActivateGraphRelation _ -> [GraphMember owner]
    ActivateGraphContextualizationLabel _ -> contextualizationFacts
    ActivateGraphContextualizationShape _ -> contextualizationFacts
    ActivateGraphStructuredSegment _ -> structuredSegmentFacts
    ActivateQualificationProposalIncidence _ -> []
  where
    binding = activationBinding activation
    owner = bindingOwner binding
    valueId = bindingValueId binding
    structuredCarrierFacts =
      GraphMember owner
        : maybe
            []
            (\value -> [GraphStructuredFamilyCarrier value owner])
            valueId
    contextualizationFacts =
      case (bindingSource binding, bindingTarget binding) of
        (Just source, Just target) ->
          [GraphMember owner, GraphContextualization owner source target]
        _ -> [GraphMember owner]
    structuredSegmentFacts =
      case ( valueId
           , bindingJunction binding
           , bindingSource binding
           , bindingTarget binding) of
        (Just familyId, Just junction, Just source, Just target)
          | target == junction ->
            [ GraphMember owner
            , GraphStructuredFamilyParticipantSegment familyId junction owner
            ]
          | source == junction ->
            [ GraphMember owner
            , GraphStructuredFamilyTargetSegment familyId junction owner
            ]
        _ -> [GraphMember owner]

qualificationActivationFacts :: Activation -> [QualificationFact]
qualificationActivationFacts activation =
  case activationRule activation of
    ActivateGraphCarrier _ -> []
    ActivateGraphStructuredCarrier _ -> []
    ActivateGraphStructuredProperty _ -> []
    ActivateGraphCommittedElement _ -> []
    ActivateGraphCommittedStructuredCarrier _ -> []
    ActivateGraphCommittedRelationship _ -> []
    ActivateQualificationProposalType _ -> proposalFacts
    ActivateQualificationProposalSourceKey _ -> proposalFacts
    ActivateQualificationRoleKey _ -> [QualificationMember owner]
    ActivateSharedUnknownProperty _ -> [QualificationMember owner]
    ActivateSharedTypeKey _ -> [QualificationMember owner]
    ActivateGraphRelation _ -> []
    ActivateGraphContextualizationLabel _ -> []
    ActivateGraphContextualizationShape _ -> []
    ActivateGraphStructuredSegment _ -> []
    ActivateQualificationProposalIncidence _ ->
      case bindingProposal binding of
        Just proposal ->
          [ QualificationMember owner
          , QualificationProposalRoleIncidence proposal owner
          ]
        Nothing -> [QualificationMember owner]
  where
    binding = activationBinding activation
    owner = bindingOwner binding
    proposalFacts =
      [QualificationMember owner, QualificationProposalCarrier owner]

graphClosureResults ::
     ProfileIndex
  -> ProductState
  -> GeneratedClosureRule
  -> Measured [(GraphFact, ClosureProvenance)]
graphClosureResults profileIndex state rule =
  case rule of
    CloseGraphStableConcept _ -> stableConcepts
    CloseGraphRelationshipSourceEndpoint _ -> relationshipEndpoints True
    CloseGraphRelationshipTargetEndpoint _ -> relationshipEndpoints False
    CloseGraphStructuredIncidenceByTarget _ -> structuredIncidences False
    CloseGraphStructuredIncidenceBySource _ -> structuredIncidences True
    CloseGraphJunctionSourceEndpoint _ -> junctionEndpoints True
    CloseGraphJunctionTargetEndpoint _ -> junctionEndpoints False
    CloseGraphContextualization _ -> contextualizations
    CloseGraphContextOwner _ -> contextOwners
    CloseGraphStructuredCarrierFromParticipantSegment _ ->
      carriersFromSegments True
    CloseGraphStructuredCarrierFromTargetSegment _ -> carriersFromSegments False
    CloseGraphStructuredParticipant _ -> structuredEndpoints True
    CloseGraphStructuredTarget _ -> structuredEndpoints False
    CloseGraphOwnedPropertyValue _ -> ownedProperties
    CloseGraphPropertyDefinition _ -> propertyDefinitions
    CloseQualificationRoleIncidenceBySource _ -> none
    CloseQualificationRoleIncidenceByTarget _ -> none
    CloseQualificationRoleSourceEndpoint _ -> none
    CloseQualificationRoleTargetEndpoint _ -> none
    CloseQualificationOwnerContextualization _ -> none
    CloseQualificationContextOwner _ -> none
    CloseQualificationEndpointContextualization _ -> none
    CloseQualificationOwnedEndpoint _ -> none
    CloseQualificationOwnedPropertyValue _ -> none
    CloseQualificationPropertyDefinition _ -> none
  where
    none = Measured mempty []
    facts = Set.toAscList (productGraphFacts state)
    ruleId = generatedClosureProvenanceRuleId rule
    result included trigger context =
      ( GraphMember included
      , closureEvidence GraphBranch ruleId trigger included context)
    stableConcepts = collectMeasured stableConcept facts
    stableConcept fact =
      case fact of
        GraphSeed viewOccurrence subject ->
          case measuredValue measuredRecord of
            Just record
              | isConcept record ->
                Measured
                  (measuredWork measuredRecord)
                  [result subject viewOccurrence []]
            _ -> Measured (measuredWork measuredRecord) []
          where measuredRecord =
                  measuredMapLookup subject (indexRecords profileIndex)
        _ -> none
    relationshipEndpoints sourceSide = collectMeasured endpoint facts
      where
        endpoint fact =
          case fact of
            GraphMember relationshipOccurrence ->
              case measuredValue measuredRelationship of
                Just relationship ->
                  case selectedEndpoint relationship of
                    Just occurrence ->
                      case measuredValue measuredRecord of
                        Just record
                          | isConcept record || isJunction record ->
                            Measured
                              (measuredWork measuredRelationship
                                 <> measuredWork measuredRecord)
                              [result occurrence relationshipOccurrence []]
                        _ ->
                          Measured
                            (measuredWork measuredRelationship
                               <> measuredWork measuredRecord)
                            []
                      where measuredRecord =
                              measuredMapLookup
                                occurrence
                                (indexRecords profileIndex)
                    Nothing -> Measured (measuredWork measuredRelationship) []
                Nothing -> Measured (measuredWork measuredRelationship) []
              where measuredRelationship =
                      measuredMapLookup
                        relationshipOccurrence
                        (indexRelationships profileIndex)
            _ -> none
        selectedEndpoint relationship =
          if sourceSide
            then relationshipInfoSource relationship
            else relationshipInfoTarget relationship
    structuredIncidences sourceSide = collectMeasured incidence facts
      where
        incidence fact =
          case fact of
            GraphStructuredFamilyCarrier familyId junction ->
              measuredIndexCandidatesWith
                (results familyId junction)
                (if sourceSide
                   then Map.findWithDefault
                          []
                          junction
                          (indexRelationshipsBySource profileIndex)
                   else Map.findWithDefault
                          []
                          junction
                          (indexRelationshipsByTarget profileIndex))
            _ -> none
        results familyId junction relationship =
          [ (GraphMember relationshipOccurrence, evidence)
          , ( GraphStructuredFamilyIncidence
                familyId
                junction
                relationshipOccurrence
            , evidence)
          ]
          where
            relationshipOccurrence = relationshipInfoOccurrence relationship
            evidence =
              closureEvidence
                GraphBranch
                ruleId
                junction
                relationshipOccurrence
                [junction]
    junctionEndpoints sourceSide = collectMeasured endpoint facts
      where
        endpoint fact =
          case fact of
            GraphStructuredFamilyIncidence _ junction relationshipOccurrence ->
              case measuredValue measuredRelationship of
                Just relationship ->
                  case selectedEndpoint relationship of
                    Just occurrence ->
                      case measuredValue measuredRecord of
                        Just record
                          | isConcept record || isJunction record ->
                            Measured
                              (measuredWork measuredRelationship
                                 <> measuredWork measuredRecord)
                              [ result
                                  occurrence
                                  relationshipOccurrence
                                  [junction]
                              ]
                        _ ->
                          Measured
                            (measuredWork measuredRelationship
                               <> measuredWork measuredRecord)
                            []
                      where measuredRecord =
                              measuredMapLookup
                                occurrence
                                (indexRecords profileIndex)
                    Nothing -> Measured (measuredWork measuredRelationship) []
                Nothing -> Measured (measuredWork measuredRelationship) []
              where measuredRelationship =
                      measuredMapLookup
                        relationshipOccurrence
                        (indexRelationships profileIndex)
            _ -> none
        selectedEndpoint relationship =
          if sourceSide
            then relationshipInfoSource relationship
            else relationshipInfoTarget relationship
    contextualizations = collectMeasured contextualization facts
      where
        contextualization fact =
          case fact of
            GraphContextualizableCarrier target _ ->
              measuredIndexCandidatesWith
                (results target)
                (Map.findWithDefault
                   []
                   target
                   (indexRelationshipsByTarget profileIndex))
            _ -> none
        results target relationship =
          case relationshipInfoSource relationship of
            Just source
              | relationshipMatchesContextualization relationship ->
                [ (GraphMember relationshipOccurrence, evidence)
                , ( GraphContextualization relationshipOccurrence source target
                  , evidence)
                ]
              where relationshipOccurrence =
                      relationshipInfoOccurrence relationship
                    evidence =
                      closureEvidence
                        GraphBranch
                        ruleId
                        target
                        relationshipOccurrence
                        [source, target]
            _ -> []
    contextOwners = collectMeasured contextOwner facts
      where
        contextOwner fact =
          case fact of
            GraphContextualization relationshipOccurrence source target ->
              case measuredValue measuredRecord of
                Just record ->
                  let measuredCarrier =
                        isContextCarrierMeasured profileIndex record
                   in Measured
                        (measuredWork measuredRecord
                           <> measuredWork measuredCarrier)
                        [ result source relationshipOccurrence [target]
                        | measuredValue measuredCarrier
                        ]
                Nothing -> Measured (measuredWork measuredRecord) []
              where measuredRecord =
                      measuredMapLookup source (indexRecords profileIndex)
            _ -> none
    carriersFromSegments participantSide = collectMeasured carrier facts
      where
        carrier segment =
          case segmentCoordinates participantSide segment of
            Just (familyId, junction, relationshipOccurrence) ->
              case measuredValue measuredRelationship of
                Just relationship
                  | selectedEndpoint relationship == Just junction ->
                    Measured
                      (measuredWork measuredRelationship)
                      [ ( GraphStructuredFamilyCarrier familyId junction
                        , closureEvidence
                            GraphBranch
                            ruleId
                            relationshipOccurrence
                            junction
                            [relationshipOccurrence])
                      ]
                _ -> Measured (measuredWork measuredRelationship) []
              where measuredRelationship =
                      measuredMapLookup
                        relationshipOccurrence
                        (indexRelationships profileIndex)
            Nothing -> none
        selectedEndpoint relationship =
          if participantSide
            then relationshipInfoTarget relationship
            else relationshipInfoSource relationship
    structuredEndpoints participantSide = collectMeasured endpoint facts
      where
        endpoint segment =
          case segmentCoordinates participantSide segment of
            Just (_, junction, relationshipOccurrence) ->
              case measuredValue measuredRelationship of
                Just relationship ->
                  case selectedEndpoint relationship of
                    Just occurrence ->
                      case measuredValue measuredRecord of
                        Just record
                          | isConcept record ->
                            Measured
                              (measuredWork measuredRelationship
                                 <> measuredWork measuredRecord)
                              [ result
                                  occurrence
                                  relationshipOccurrence
                                  [junction]
                              ]
                        _ ->
                          Measured
                            (measuredWork measuredRelationship
                               <> measuredWork measuredRecord)
                            []
                      where measuredRecord =
                              measuredMapLookup
                                occurrence
                                (indexRecords profileIndex)
                    Nothing -> Measured (measuredWork measuredRelationship) []
                Nothing -> Measured (measuredWork measuredRelationship) []
              where measuredRelationship =
                      measuredMapLookup
                        relationshipOccurrence
                        (indexRelationships profileIndex)
            Nothing -> none
        selectedEndpoint relationship =
          if participantSide
            then relationshipInfoSource relationship
            else relationshipInfoTarget relationship
    segmentCoordinates participantSide segment =
      case segment of
        GraphStructuredFamilyParticipantSegment family junction relationship
          | participantSide -> Just (family, junction, relationship)
        GraphStructuredFamilyTargetSegment family junction relationship
          | not participantSide -> Just (family, junction, relationship)
        _ -> Nothing
    ownedProperties = collectMeasured ownedProperty facts
      where
        ownedProperty fact =
          case fact of
            GraphMember owner ->
              measuredIndexCandidatesWith
                (\property ->
                   [result (propertyInfoOccurrence property) owner []])
                (Map.findWithDefault
                   []
                   owner
                   (indexPropertiesByOwner profileIndex))
            _ -> none
    propertyDefinitions = collectMeasured propertyDefinition facts
      where
        propertyDefinition fact =
          case fact of
            GraphMember propertyOccurrence ->
              case measuredValue measuredProperty of
                Just property ->
                  Measured
                    (measuredWork measuredProperty)
                    [ result definition propertyOccurrence []
                    | Just definition <- [propertyInfoDefinition property]
                    ]
                Nothing -> Measured (measuredWork measuredProperty) []
              where measuredProperty =
                      measuredMapLookup
                        propertyOccurrence
                        (indexPropertyByOccurrence profileIndex)
            _ -> none

qualificationClosureResults ::
     ProfileIndex
  -> ProductState
  -> GeneratedClosureRule
  -> Measured [(QualificationFact, ClosureProvenance)]
qualificationClosureResults profileIndex state rule =
  case rule of
    CloseGraphStableConcept _ -> none
    CloseGraphRelationshipSourceEndpoint _ -> none
    CloseGraphRelationshipTargetEndpoint _ -> none
    CloseGraphStructuredIncidenceByTarget _ -> none
    CloseGraphStructuredIncidenceBySource _ -> none
    CloseGraphJunctionSourceEndpoint _ -> none
    CloseGraphJunctionTargetEndpoint _ -> none
    CloseGraphContextualization _ -> none
    CloseGraphContextOwner _ -> none
    CloseGraphStructuredCarrierFromParticipantSegment _ -> none
    CloseGraphStructuredCarrierFromTargetSegment _ -> none
    CloseGraphStructuredParticipant _ -> none
    CloseGraphStructuredTarget _ -> none
    CloseGraphOwnedPropertyValue _ -> none
    CloseGraphPropertyDefinition _ -> none
    CloseQualificationRoleIncidenceBySource _ -> roleIncidences True
    CloseQualificationRoleIncidenceByTarget _ -> roleIncidences False
    CloseQualificationRoleSourceEndpoint _ -> roleEndpoints True
    CloseQualificationRoleTargetEndpoint _ -> roleEndpoints False
    CloseQualificationOwnerContextualization _ -> ownerContextualizations
    CloseQualificationContextOwner _ -> qualificationContextOwners
    CloseQualificationEndpointContextualization _ -> endpointContextualizations
    CloseQualificationOwnedEndpoint _ -> ownedEndpoints
    CloseQualificationOwnedPropertyValue _ -> ownedProperties
    CloseQualificationPropertyDefinition _ -> propertyDefinitions
  where
    none = Measured mempty []
    facts = Set.toAscList (productQualificationFacts state)
    ruleId = generatedClosureProvenanceRuleId rule
    provenance trigger included context =
      closureEvidence QualificationBranch ruleId trigger included context
    roleIncidences sourceSide = collectMeasured incidences facts
      where
        incidences fact =
          case fact of
            QualificationProposalCarrier proposal ->
              measuredIndexCandidatesWithM
                (results proposal)
                (Map.findWithDefault
                   []
                   proposal
                   (if sourceSide
                      then indexRelationshipsBySource profileIndex
                      else indexRelationshipsByTarget profileIndex))
            _ -> none
        results proposal relationship =
          if sourceSide
            then Measured mempty (factsFor proposal relationship)
            else let measuredRole =
                       measuredHasProperty
                         profileIndex
                         "o2i.role"
                         (relationshipInfoOccurrence relationship)
                  in measuredRole
                       { measuredValue =
                           [ result
                           | measuredValue measuredRole
                           , result <- factsFor proposal relationship
                           ]
                       }
        factsFor proposal relationship =
          [ (QualificationMember relationshipOccurrence, evidence)
          , ( QualificationProposalRoleIncidence proposal relationshipOccurrence
            , evidence)
          ]
          where
            relationshipOccurrence = relationshipInfoOccurrence relationship
            evidence = provenance proposal relationshipOccurrence [proposal]
    roleEndpoints sourceSide = collectMeasured endpoints facts
      where
        endpoints fact =
          case fact of
            QualificationProposalRoleIncidence proposal relationshipOccurrence ->
              case measuredValue measuredRelationship of
                Just relationship ->
                  case selectedEndpoint relationship of
                    Just endpoint ->
                      case measuredValue measuredRecord of
                        Just record
                          | isConcept record ->
                            Measured
                              (measuredWork measuredRelationship
                                 <> measuredWork measuredRecord
                                 <> measuredWork measuredRoles)
                              (concatMap
                                 (factsFor
                                    proposal
                                    relationshipOccurrence
                                    endpoint
                                    evidence)
                                 (measuredValue measuredRoles))
                          | otherwise ->
                            Measured
                              (measuredWork measuredRelationship
                                 <> measuredWork measuredRecord)
                              []
                        Nothing ->
                          Measured
                            (measuredWork measuredRelationship
                               <> measuredWork measuredRecord)
                            []
                      where measuredRecord =
                              measuredMapLookup
                                endpoint
                                (indexRecords profileIndex)
                            measuredRoles =
                              measuredPropertyValues
                                profileIndex
                                "o2i.role"
                                relationshipOccurrence
                            evidence =
                              provenance
                                relationshipOccurrence
                                endpoint
                                [proposal]
                    Nothing -> Measured (measuredWork measuredRelationship) []
                Nothing -> Measured (measuredWork measuredRelationship) []
              where measuredRelationship =
                      measuredMapLookup
                        relationshipOccurrence
                        (indexRelationships profileIndex)
            _ -> none
        factsFor proposal relationshipOccurrence endpoint evidence role =
          [ (QualificationMember endpoint, evidence)
          , ( QualificationContextualizableProposalEndpoint
                proposal
                relationshipOccurrence
                role
                endpoint
            , evidence)
          ]
        selectedEndpoint relationship =
          if sourceSide
            then relationshipInfoSource relationship
            else relationshipInfoTarget relationship
    ownerContextualizations = collectMeasured contextualizations facts
      where
        contextualizations fact =
          case fact of
            QualificationContextualizableProposalEndpoint proposal reference _ endpoint ->
              measuredIndexCandidatesWith
                (results proposal reference endpoint)
                (Map.findWithDefault
                   []
                   endpoint
                   (indexRelationshipsByTarget profileIndex))
            _ -> none
        results proposal reference endpoint relationship =
          if relationshipMatchesContextualization relationship
            then [ (QualificationMember relationshipOccurrence, evidence)
                 , ( QualificationContextualizationOfProposalEndpoint
                       proposal
                       reference
                       endpoint
                       relationshipOccurrence
                   , evidence)
                 ]
            else []
          where
            relationshipOccurrence = relationshipInfoOccurrence relationship
            evidence =
              provenance endpoint relationshipOccurrence [proposal, reference]
    qualificationContextOwners = collectMeasured contextOwners facts
      where
        contextOwners fact =
          case fact of
            QualificationContextualizationOfProposalEndpoint proposal reference endpoint contextualization ->
              case measuredValue measuredRelationship of
                Just relationship ->
                  case relationshipInfoSource relationship of
                    Just owner ->
                      case measuredValue measuredRecord of
                        Just record ->
                          let measuredCarrier =
                                isContextCarrierMeasured profileIndex record
                           in Measured
                                (measuredWork measuredRelationship
                                   <> measuredWork measuredRecord
                                   <> measuredWork measuredCarrier)
                                (if measuredValue measuredCarrier
                                   then [ (QualificationMember owner, evidence)
                                        , ( QualificationContextOwnerRequiredByProposal
                                              proposal
                                              reference
                                              endpoint
                                              contextualization
                                              owner
                                          , evidence)
                                        ]
                                   else [])
                        Nothing ->
                          Measured
                            (measuredWork measuredRelationship
                               <> measuredWork measuredRecord)
                            []
                      where measuredRecord =
                              measuredMapLookup
                                owner
                                (indexRecords profileIndex)
                            evidence =
                              provenance
                                contextualization
                                owner
                                [proposal, reference, endpoint]
                    Nothing -> Measured (measuredWork measuredRelationship) []
                Nothing -> Measured (measuredWork measuredRelationship) []
              where measuredRelationship =
                      measuredMapLookup
                        contextualization
                        (indexRelationships profileIndex)
            _ -> none
    endpointContextualizations = collectMeasured contextualizations facts
      where
        contextualizations fact =
          case fact of
            QualificationContextOwnerRequiredByProposal proposal reference endpoint _ contextOwner ->
              measuredIndexCandidatesWith
                (results proposal reference endpoint contextOwner)
                (Map.findWithDefault
                   []
                   contextOwner
                   (indexRelationshipsBySource profileIndex))
            _ -> none
        results proposal reference endpoint contextOwner relationship =
          if relationshipInfoTarget relationship == Just endpoint
               && relationshipMatchesContextualization relationship
            then [ (QualificationMember relationshipOccurrence, evidence)
                 , ( QualificationContextualizationOfExactProposalEndpoint
                       proposal
                       reference
                       endpoint
                       contextOwner
                       relationshipOccurrence
                   , evidence)
                 ]
            else []
          where
            relationshipOccurrence = relationshipInfoOccurrence relationship
            evidence =
              provenance
                contextOwner
                relationshipOccurrence
                [proposal, reference, endpoint]
    ownedEndpoints =
      Measured
        mempty
        [ ( QualificationMember endpoint
          , provenance
              contextualization
              endpoint
              [proposal, reference, contextOwner])
        | QualificationContextualizationOfExactProposalEndpoint proposal reference endpoint contextOwner contextualization <-
            facts
        ]
    ownedProperties = collectMeasured ownedProperty facts
      where
        ownedProperty fact =
          case fact of
            QualificationMember owner ->
              measuredIndexCandidatesWith
                (\property ->
                   [ ( QualificationMember (propertyInfoOccurrence property)
                     , provenance owner (propertyInfoOccurrence property) [])
                   ])
                (Map.findWithDefault
                   []
                   owner
                   (indexPropertiesByOwner profileIndex))
            _ -> none
    propertyDefinitions = collectMeasured propertyDefinition facts
      where
        propertyDefinition fact =
          case fact of
            QualificationMember propertyOccurrence ->
              case measuredValue measuredProperty of
                Just property ->
                  Measured
                    (measuredWork measuredProperty)
                    [ ( QualificationMember definition
                      , provenance propertyOccurrence definition [])
                    | Just definition <- [propertyInfoDefinition property]
                    ]
                Nothing -> Measured (measuredWork measuredProperty) []
              where measuredProperty =
                      measuredMapLookup
                        propertyOccurrence
                        (indexPropertyByOccurrence profileIndex)
            _ -> none

addGraphFact :: GraphProvenance -> GraphFact -> ProductState -> ProductState
addGraphFact provenance fact state =
  state
    { productGraphFacts = Set.insert fact (productGraphFacts state)
    , productGraphProvenance =
        Set.insert provenance (productGraphProvenance state)
    , productPendingWork =
        if fact `Set.member` productGraphFacts state
          then productPendingWork state
          else productPendingWork state |> GraphFactWork fact
    }

addQualificationFact ::
     QualificationProvenance
  -> QualificationFact
  -> ProductState
  -> ProductState
addQualificationFact provenance fact state =
  state
    { productQualificationFacts =
        Set.insert fact (productQualificationFacts state)
    , productQualificationProvenance =
        Set.insert provenance (productQualificationProvenance state)
    , productPendingWork =
        if fact `Set.member` productQualificationFacts state
          then productPendingWork state
          else productPendingWork state |> QualificationFactWork fact
    }

graphMembers :: ProductState -> Set CanonicalOccurrence
graphMembers state =
  Set.fromList (concatMap members (Set.toAscList (productGraphFacts state)))
  where
    members fact =
      case fact of
        GraphMember occurrence -> [occurrence]
        GraphSeed _ occurrence -> [occurrence]
        _ -> []

qualificationMembers :: ProductState -> Set CanonicalOccurrence
qualificationMembers state =
  Set.fromList
    [ occurrence
    | QualificationMember occurrence <-
        Set.toAscList (productQualificationFacts state)
    ]

qualificationProposals :: ProductState -> Set CanonicalOccurrence
qualificationProposals state =
  Set.fromList
    [ proposal
    | QualificationProposalCarrier proposal <-
        Set.toAscList (productQualificationFacts state)
    ]

measuredPropertyValues ::
     ProfileIndex -> Text -> CanonicalOccurrence -> Measured [Text]
measuredPropertyValues profileIndex key occurrence =
  measuredIndexCandidatesWith
    propertyInfoValues
    (Map.findWithDefault
       []
       (occurrence, key)
       (indexPropertiesByOwnerAndKey profileIndex))

measuredHasProperty ::
     ProfileIndex -> Text -> CanonicalOccurrence -> Measured Bool
measuredHasProperty profileIndex key occurrence =
  measuredIndexAny
    (const True)
    (Map.findWithDefault
       []
       (occurrence, key)
       (indexPropertiesByOwnerAndKey profileIndex))

measuredPropertiesFor ::
     ProfileIndex -> CanonicalOccurrence -> Measured [PropertyInfo]
measuredPropertiesFor profileIndex occurrence =
  measuredIndexCandidatesWith
    (: [])
    (Map.findWithDefault [] occurrence (indexPropertiesByOwner profileIndex))

measuredIncidentRelationships ::
     ProfileIndex -> CanonicalOccurrence -> Measured [RelationshipInfo]
measuredIncidentRelationships profileIndex occurrence =
  measured
    { measuredValue =
        Map.elems (foldl' insertRelationship Map.empty (measuredValue measured))
    }
  where
    measured =
      measuredIndexCandidatesWith
        (: [])
        (Map.findWithDefault
           []
           occurrence
           (indexRelationshipsBySource profileIndex)
           ++ Map.findWithDefault
                []
                occurrence
                (indexRelationshipsByTarget profileIndex))
    insertRelationship relationships relationship =
      Map.insert
        (relationshipInfoOccurrence relationship)
        relationship
        relationships

propertyBindingsMeasured ::
     ProfileIndex
  -> (RecordInfo -> Bool)
  -> Text
  -> [CanonicalOccurrence]
  -> Measured [ActivationBinding]
propertyBindingsMeasured profileIndex predicate key = collectMeasured binding
  where
    binding occurrence =
      case measuredValue measuredRecord of
        Just record
          | predicate record ->
            Measured
              (measuredWork measuredRecord <> measuredWork measuredProperty)
              [ simpleBinding occurrence occurrence []
              | measuredValue measuredProperty
              ]
        _ -> Measured (measuredWork measuredRecord) []
      where
        measuredRecord =
          measuredMapLookup occurrence (indexRecords profileIndex)
        measuredProperty = measuredHasProperty profileIndex key occurrence

carrierBindingsMeasured ::
     ProfileIndex -> CanonicalOccurrence -> Measured [ActivationBinding]
carrierBindingsMeasured profileIndex occurrence =
  case measuredValue measuredRecord of
    Just record
      | isConcept record ->
        Measured
          (measuredWork measuredRecord <> measuredWork measuredTypes)
          [ (simpleBinding occurrence occurrence [ruleId])
            {bindingValueId = Just mappingId}
          | o2iType <- measuredValue measuredTypes
          , GeneratedCarrierMapping mappingId ruleId element _ admitted <-
              generatedCarrierMappings
          , element == archiMateElement record
          , o2iType `elem` admitted
          ]
    _ -> Measured (measuredWork measuredRecord) []
  where
    measuredRecord = measuredMapLookup occurrence (indexRecords profileIndex)
    measuredTypes = measuredPropertyValues profileIndex "o2i.type" occurrence

structuredCarrierBindingsMeasured ::
     ProfileIndex -> CanonicalOccurrence -> Measured [ActivationBinding]
structuredCarrierBindingsMeasured profileIndex occurrence =
  case measuredValue measuredRecord of
    Just record
      | matchesPatternText
          "collective.carrier.archimate-element"
          (archiMateElement record)
          && matchesPatternText
               "collective.carrier.junction-type"
               (if isAndJunction record
                  then "and"
                  else "") ->
        Measured
          (measuredWork measuredRecord <> measuredWork measuredTypes)
          [ (simpleBinding occurrence occurrence [])
            {bindingValueId = Just "collective-strategy-realization"}
          | any
              (matchesPatternText "collective.carrier.o2i-type")
              (measuredValue measuredTypes)
          ]
    _ -> Measured (measuredWork measuredRecord) []
  where
    measuredRecord = measuredMapLookup occurrence (indexRecords profileIndex)
    measuredTypes = measuredPropertyValues profileIndex "o2i.type" occurrence

structuredPropertyBindingsMeasured ::
     ProfileIndex -> CanonicalOccurrence -> Measured [ActivationBinding]
structuredPropertyBindingsMeasured profileIndex occurrence =
  case measuredValue measuredRecord of
    Just record
      | isJunction record ->
        Measured
          (measuredWork measuredRecord <> measuredWork measuredProperty)
          [ (simpleBinding occurrence occurrence [])
            {bindingValueId = Just "collective-strategy-realization"}
          | measuredValue measuredProperty
          ]
    _ -> Measured (measuredWork measuredRecord) []
  where
    measuredRecord = measuredMapLookup occurrence (indexRecords profileIndex)
    measuredProperty =
      measuredHasProperty profileIndex "o2i.participant-completeness" occurrence

proposalTypeBindingsMeasured ::
     ProfileIndex -> CanonicalOccurrence -> Measured [ActivationBinding]
proposalTypeBindingsMeasured profileIndex occurrence =
  case measuredValue measuredRecord of
    Just record
      | isConcept record
          && matchesPatternText
               "qualification.carrier.archimate-element"
               (archiMateElement record) ->
        Measured
          (measuredWork measuredRecord <> measuredWork measuredTypes)
          [ simpleBinding occurrence occurrence []
          | any
              (matchesPatternText "qualification.carrier.o2i-type")
              (measuredValue measuredTypes)
          ]
    _ -> Measured (measuredWork measuredRecord) []
  where
    measuredRecord = measuredMapLookup occurrence (indexRecords profileIndex)
    measuredTypes = measuredPropertyValues profileIndex "o2i.type" occurrence

matchesPatternText :: Text -> Text -> Bool
matchesPatternText subject actual =
  patternExpectationValue PatternTextExpectation subject == Just actual

unknownPropertyBindingsMeasured ::
     ProfileIndex -> [CanonicalOccurrence] -> Measured [ActivationBinding]
unknownPropertyBindingsMeasured profileIndex = collectMeasured bindings
  where
    bindings occurrence =
      measuredProperties
        { measuredValue =
            [ simpleBinding occurrence (propertyInfoOccurrence property) []
            | property <- measuredValue measuredProperties
            , key <- propertyInfoKeys property
            , "o2i." `Text.isPrefixOf` key
            , key `Set.notMember` knownReservedKeys
            ]
        }
      where
        measuredProperties = measuredPropertiesFor profileIndex occurrence

knownReservedKeys :: Set Text
knownReservedKeys =
  Set.insert
    "o2i.profile"
    (Set.fromList
       [key | GeneratedPropertyMapping _ _ key _ <- generatedPropertyMappings])

graphRelationBindingsMeasured ::
     ProfileIndex -> ProductState -> Measured [ActivationBinding]
graphRelationBindingsMeasured profileIndex state =
  collectMeasured matches (Set.toAscList (graphMembers state))
  where
    matches endpoint =
      measuredRelationships
        { measuredValue =
            [ relationshipBinding relationship [ruleId]
            | relationship <- measuredValue measuredRelationships
            , GeneratedRelationMapping _ ruleId kind directed label _ _ <-
                generatedRelationMappings
            , relationshipInfoKind relationship == kind
            , relationshipInfoDirected relationship == directed
            , normalizeLabel (relationshipInfoLabel relationship) == Right label
            ]
        }
      where
        measuredRelationships =
          measuredIncidentRelationships profileIndex endpoint

graphContextualizationLabelBindingsMeasured ::
     ProfileIndex -> ProductState -> Measured [ActivationBinding]
graphContextualizationLabelBindingsMeasured profileIndex state =
  collectMeasured matches (Set.toAscList (graphMembers state))
  where
    matches endpoint =
      measuredRelationships
        { measuredValue =
            [ relationshipBinding relationship []
            | relationship <- measuredValue measuredRelationships
            , relationshipMatchesContextualization relationship
            ]
        }
      where
        measuredRelationships =
          measuredIncidentRelationships profileIndex endpoint

graphContextualizationShapeBindingsMeasured ::
     ProfileIndex -> ProductState -> Measured [ActivationBinding]
graphContextualizationShapeBindingsMeasured profileIndex state =
  collectMeasured bindings (Set.toAscList (productGraphFacts state))
  where
    bindings fact =
      case fact of
        GraphContextualizableCarrier target mappingId ->
          measuredIndexCandidatesWithM
            (binding mappingId)
            (Map.findWithDefault
               []
               target
               (indexRelationshipsByTarget profileIndex))
        _ -> Measured mempty []
    binding mappingId relationship =
      case relationshipInfoSource relationship of
        Nothing -> Measured mempty []
        Just source ->
          case measuredValue measuredRecord of
            Just record ->
              let measuredCarrier = isContextCarrierMeasured profileIndex record
               in measuredCarrier
                    { measuredWork =
                        measuredWork measuredRecord
                          <> measuredWork measuredCarrier
                    , measuredValue =
                        [ relationshipBinding
                          relationship
                          (carrierRuleIds mappingId)
                        | measuredValue measuredCarrier
                        ]
                    }
            Nothing -> Measured (measuredWork measuredRecord) []
          where measuredRecord =
                  measuredMapLookup source (indexRecords profileIndex)

carrierRuleIds :: Text -> [Text]
carrierRuleIds mappingId =
  [ ruleId
  | GeneratedCarrierMapping candidate ruleId _ _ _ <- generatedCarrierMappings
  , candidate == mappingId
  ]

structuredSegmentBindingsMeasured ::
     ProfileIndex -> ProductState -> Measured [ActivationBinding]
structuredSegmentBindingsMeasured profileIndex state =
  collectMeasured bindings (Set.toAscList (productGraphFacts state))
  where
    bindings fact =
      case fact of
        GraphStructuredFamilyCarrier familyId junction ->
          measuredRelationships
            { measuredValue =
                [ (relationshipBinding relationship [])
                  { bindingJunction = Just junction
                  , bindingValueId = Just familyId
                  }
                | relationship <- measuredValue measuredRelationships
                , relationshipMatchesStructuredSegment relationship
                , let endpoints =
                        [ relationshipInfoSource relationship
                        , relationshipInfoTarget relationship
                        ]
                , length (filter (== Just junction) endpoints) == 1
                ]
            }
          where measuredRelationships =
                  measuredIncidentRelationships profileIndex junction
        _ -> Measured mempty []

qualificationIncidenceBindingsMeasured ::
     ProfileIndex -> ProductState -> Measured [ActivationBinding]
qualificationIncidenceBindingsMeasured profileIndex state =
  collectMeasured bindings (Set.toAscList (productQualificationFacts state))
  where
    bindings fact =
      case fact of
        QualificationProposalCarrier proposal ->
          measuredIndexCandidatesWith
            (\relationship ->
               [ (relationshipBinding relationship [])
                 {bindingProposal = Just proposal}
               | relationshipInfoSource relationship == Just proposal
               ])
            (Map.findWithDefault
               []
               proposal
               (indexRelationshipsBySource profileIndex))
        _ -> Measured mempty []

relationshipBinding :: RelationshipInfo -> [Text] -> ActivationBinding
relationshipBinding relationship sourceRules =
  (simpleBinding occurrence occurrence sourceRules)
    { bindingSource = relationshipInfoSource relationship
    , bindingTarget = relationshipInfoTarget relationship
    }
  where
    occurrence = relationshipInfoOccurrence relationship

simpleBinding ::
     CanonicalOccurrence -> CanonicalOccurrence -> [Text] -> ActivationBinding
simpleBinding owner trigger sourceRules =
  ActivationBinding
    owner
    trigger
    Nothing
    Nothing
    Nothing
    Nothing
    Nothing
    sourceRules

relationshipMatchesContextualization :: RelationshipInfo -> Bool
relationshipMatchesContextualization relationship =
  contextualizationMatch
    (relationshipInfoKind relationship)
    (relationshipInfoDirected relationship)
    (relationshipInfoLabel relationship)

relationshipMatchesStructuredSegment :: RelationshipInfo -> Bool
relationshipMatchesStructuredSegment relationship =
  structuredSegmentMatch
    (relationshipInfoKind relationship)
    (relationshipInfoDirected relationship)
    (relationshipInfoLabel relationship)

isContextCarrier :: ProfileIndex -> RecordInfo -> Bool
isContextCarrier profileIndex record =
  any
    matches
    (propertyValues profileIndex "o2i.type" (recordInfoOccurrence record))
  where
    matches o2iType =
      any
        (\mapping ->
           generatedCarrierCategory mapping == "Context"
             && generatedCarrierArchiMateElement mapping
                  == archiMateElement record
             && o2iType `elem` generatedCarrierO2ITypes mapping)
        generatedCarrierMappings

isContextCarrierMeasured :: ProfileIndex -> RecordInfo -> Measured Bool
isContextCarrierMeasured profileIndex record =
  measuredTypes {measuredValue = any matches (measuredValue measuredTypes)}
  where
    measuredTypes =
      measuredPropertyValues
        profileIndex
        "o2i.type"
        (recordInfoOccurrence record)
    matches o2iType =
      any
        (\mapping ->
           generatedCarrierCategory mapping == "Context"
             && generatedCarrierArchiMateElement mapping
                  == archiMateElement record
             && o2iType `elem` generatedCarrierO2ITypes mapping)
        generatedCarrierMappings
