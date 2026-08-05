{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- | Family validator for collective Strategy contribution.
module O2I.Validation.Collective.Contribution.Eval
  ( ValidatedContributionGraph
  , CollectiveStrategyContribution
  , CandidateCollectiveStrategyContribution
  , CollectiveContributionClaimStructureAssessment
  , CollectiveStrategyContributionAssessment
  , ValidatedCollectiveStrategyContributions
  , assessCollectiveContributionClaimStructure
  , blockedCollectiveStrategyContributionAssessment
  , assessCollectiveStrategyContributions
  , collectiveStrategyContributionErrors
  , validateCollectiveStrategyContributions
  , collectiveStrategyContributions
  , candidateCollectiveStrategyContributions
  , contributionAssessmentPreparationWork
  , contributionAssessmentWork
  , collectiveContributionId
  , collectiveContributionParticipants
  , collectiveContributionTarget
  , collectiveContributionEvidenceReference
  , collectiveContributionRationales
  , collectiveContributionPrimitiveGraph
  , contributionGraphMode
  , contributionGraphNodes
  , contributionGraphOccurrences
  , candidateCollectiveContributionClaim
  , candidateCollectiveContributionIssues
  ) where

import Data.List (foldl', group, sort)
import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Set (Set)
import qualified Data.Text as Text
import Data.Validation (Validation(..))
import O2I.Graph.Raw
import O2I.Graph.Typed
import O2I.Language.Claim
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Collective.Contribution.Index
import O2I.Validation.Collective.Contribution.Types
import qualified O2I.Validation.Collective.FanIn as FanIn
import O2I.Validation.Collective.Types
import O2I.Validation.Structure.Internal

-- | Opaque homogeneous, connected, exactly bound Primitive-evidence graph.
data ValidatedContributionGraph
  = ValidatedKeyResultContributionGraph
      (NonEmpty RawNodeId)
      (NonEmpty (Int, RawEdge))
      JointContributionRationaleRef
      Text.Text
  | ValidatedActionContributionGraph
      (NonEmpty RawNodeId)
      (NonEmpty (Int, RawEdge))
      JointContributionRationaleRef
      Text.Text

-- | Opaque validated Asserted collective Strategy contribution.
data CollectiveStrategyContribution =
  CollectiveStrategyContribution
    ClaimId
    (NonEmpty (ContextRef 'Strategy))
    (ContextRef 'Strategy)
    CollectiveContributionEvidenceRef
    (NonEmpty RawJointContributionRationale)
    ValidatedContributionGraph

-- | Opaque diagnostic result for one structurally valid Candidate.
data CandidateCollectiveStrategyContribution =
  CandidateCollectiveStrategyContribution
    (Claim RawCollectiveStrategyContribution)
    [CollectiveStrategyContributionIssue]

-- | Total family assessment retaining errors, Candidates, and exact work.
data CollectiveStrategyContributionAssessment =
  CollectiveStrategyContributionAssessment
    [CollectiveStrategyContributionError]
    [ContributionEvaluation]
    [CandidateCollectiveStrategyContribution]
    CollectiveContributionPreparationWork
    CollectiveContributionValidationWork

-- | Opaque aggregate of all accepted Asserted family witnesses.
newtype ValidatedCollectiveStrategyContributions =
  ValidatedCollectiveStrategyContributions [CollectiveStrategyContribution]

data StructuralContribution =
  StructuralContribution
    (Claim RawCollectiveStrategyContribution)
    (FanIn.StructurallyValidCollectiveFanIn CollectiveContributionEvidenceRef)

-- | Opaque context-independent structural assessment of contribution claims.
data CollectiveContributionClaimStructureAssessment =
  CollectiveContributionClaimStructureAssessment
    [CollectiveStrategyContributionError]
    [StructuralContribution]
    CollectiveContributionValidationWork

data ContributionEvaluation =
  ContributionEvaluation
    StructuralContribution
    [CollectiveStrategyContributionIssue]
    (Maybe (NonEmpty RawJointContributionRationale))
    (Maybe ValidatedContributionGraph)

-- | Capture every contribution claim against the structural model boundary.
assessCollectiveContributionClaimStructure ::
     StructuralAssessment
  -> [Claim RawCollectiveStrategyContribution]
  -> CollectiveContributionClaimStructureAssessment
assessCollectiveContributionClaimStructure structure claims =
  CollectiveContributionClaimStructureAssessment
    (identityErrors ++ structuralErrors)
    structural
    (mconcat structuralWork)
  where
    identityErrors =
      [ DuplicateCollectiveContributionClaimId identifier
      | identifier <-
          duplicates (map (rawContributionId . claimedProposition) claims)
      ]
    structuralResults = map (assessStructure structure) claims
    structuralErrors = concatMap firstOfThree structuralResults
    structural = mapMaybe secondOfThree structuralResults
    structuralWork = map thirdOfThree structuralResults

-- | Retain structurally valid Candidates when Context semantics is unavailable.
--
-- Asserted claims remain unevaluated and construct no witness. Structural
-- defects remain fatal and observable through the ordinary error accessor.
blockedCollectiveStrategyContributionAssessment ::
     CollectiveContributionClaimStructureAssessment
  -> CollectiveStrategyContributionAssessment
blockedCollectiveStrategyContributionAssessment (CollectiveContributionClaimStructureAssessment errors structural work) =
  CollectiveStrategyContributionAssessment
    errors
    []
    (mapMaybe blockedCandidateAssessment structural)
    mempty
    work

-- | Assess every structurally captured contribution claim in source order.
--
-- Evidence references use one prepared bucket lookup per proposition. Supplied
-- Primitive graphs use exact occurrence lookups and linear graph traversals.
assessCollectiveStrategyContributions ::
     PreparedCollectiveContribution
  -> CollectiveContributionClaimStructureAssessment
  -> CollectiveStrategyContributionAssessment
assessCollectiveStrategyContributions prepared (CollectiveContributionClaimStructureAssessment structuralErrors structural structuralWork) =
  CollectiveStrategyContributionAssessment
    (structuralErrors ++ semanticErrors)
    evaluations
    (mapMaybe candidateAssessment evaluations)
    (collectiveContributionPreparationWork prepared)
    (structuralWork <> mconcat evaluationWork)
  where
    evaluated = map (evaluateContribution prepared) structural
    evaluations = map fst evaluated
    evaluationWork = map snd evaluated
    semanticErrors = concatMap evaluationErrors evaluations

-- | Enumerate fatal structural and Asserted semantic errors in source order.
collectiveStrategyContributionErrors ::
     CollectiveStrategyContributionAssessment
  -> [CollectiveStrategyContributionError]
collectiveStrategyContributionErrors (CollectiveStrategyContributionAssessment errors _ _ _ _) =
  errors

-- | Admit an aggregate only when every Asserted claim is fully valid.
validateCollectiveStrategyContributions ::
     CollectiveStrategyContributionAssessment
  -> Validation
       (NonEmpty CollectiveStrategyContributionError)
       ValidatedCollectiveStrategyContributions
validateCollectiveStrategyContributions assessment =
  case NonEmpty.nonEmpty (collectiveStrategyContributionErrors assessment) of
    Just failures -> Failure failures
    Nothing ->
      Success
        (ValidatedCollectiveStrategyContributions
           (mapMaybe contributionWitness (assessedEvaluations assessment)))

-- | Enumerate validated Asserted contributions in proposition source order.
collectiveStrategyContributions ::
     ValidatedCollectiveStrategyContributions
  -> [CollectiveStrategyContribution]
collectiveStrategyContributions (ValidatedCollectiveStrategyContributions contributions) =
  contributions

-- | Enumerate diagnostic-only Candidates in proposition source order.
candidateCollectiveStrategyContributions ::
     CollectiveStrategyContributionAssessment
  -> [CandidateCollectiveStrategyContribution]
candidateCollectiveStrategyContributions (CollectiveStrategyContributionAssessment _ _ candidates _ _) =
  candidates

-- | Read exact one-time index preparation work for this assessment.
contributionAssessmentPreparationWork ::
     CollectiveStrategyContributionAssessment
  -> CollectiveContributionPreparationWork
contributionAssessmentPreparationWork (CollectiveStrategyContributionAssessment _ _ _ work _) =
  work

-- | Read exact proposition-local validation work.
contributionAssessmentWork ::
     CollectiveStrategyContributionAssessment
  -> CollectiveContributionValidationWork
contributionAssessmentWork (CollectiveStrategyContributionAssessment _ _ _ _ work) =
  work

-- | Read the stable identity of one validated collective contribution.
collectiveContributionId :: CollectiveStrategyContribution -> ClaimId
collectiveContributionId (CollectiveStrategyContribution identifier _ _ _ _ _) =
  identifier

-- | Read the known participant Strategies in declared source order.
collectiveContributionParticipants ::
     CollectiveStrategyContribution -> NonEmpty (ContextRef 'Strategy)
collectiveContributionParticipants (CollectiveStrategyContribution _ participants _ _ _ _) =
  participants

-- | Read the unique target Strategy.
collectiveContributionTarget ::
     CollectiveStrategyContribution -> ContextRef 'Strategy
collectiveContributionTarget (CollectiveStrategyContribution _ _ target _ _ _) =
  target

-- | Read the exact family-evidence reference.
collectiveContributionEvidenceReference ::
     CollectiveStrategyContribution -> CollectiveContributionEvidenceRef
collectiveContributionEvidenceReference (CollectiveStrategyContribution _ _ _ reference _ _) =
  reference

-- | Read the non-empty provenance-bearing joint rationales.
collectiveContributionRationales ::
     CollectiveStrategyContribution -> NonEmpty RawJointContributionRationale
collectiveContributionRationales (CollectiveStrategyContribution _ _ _ _ rationales _) =
  rationales

-- | Read the validated homogeneous Primitive-evidence graph.
collectiveContributionPrimitiveGraph ::
     CollectiveStrategyContribution -> ValidatedContributionGraph
collectiveContributionPrimitiveGraph (CollectiveStrategyContribution _ _ _ _ _ graph) =
  graph

-- | Read the closed Primitive-evidence mode.
contributionGraphMode :: ValidatedContributionGraph -> PrimitiveContributionMode
contributionGraphMode graph =
  case graph of
    ValidatedKeyResultContributionGraph {} -> KeyResultContributionGraph
    ValidatedActionContributionGraph {} -> ActionContributionGraph

-- | Read validated graph nodes in evidence source order.
contributionGraphNodes :: ValidatedContributionGraph -> NonEmpty RawNodeId
contributionGraphNodes graph =
  case graph of
    ValidatedKeyResultContributionGraph nodes _ _ _ -> nodes
    ValidatedActionContributionGraph nodes _ _ _ -> nodes

-- | Read exact asserted edge occurrences in evidence source order.
contributionGraphOccurrences ::
     ValidatedContributionGraph -> NonEmpty (Int, RawEdge)
contributionGraphOccurrences graph =
  case graph of
    ValidatedKeyResultContributionGraph _ occurrences _ _ -> occurrences
    ValidatedActionContributionGraph _ occurrences _ _ -> occurrences

-- | Read the original Candidate claim.
candidateCollectiveContributionClaim ::
     CandidateCollectiveStrategyContribution
  -> Claim RawCollectiveStrategyContribution
candidateCollectiveContributionClaim (CandidateCollectiveStrategyContribution claim _) =
  claim

-- | Read deterministic Candidate diagnostics; no issue is a witness.
candidateCollectiveContributionIssues ::
     CandidateCollectiveStrategyContribution
  -> [CollectiveStrategyContributionIssue]
candidateCollectiveContributionIssues (CandidateCollectiveStrategyContribution _ issues) =
  issues

assessStructure ::
     StructuralAssessment
  -> Claim RawCollectiveStrategyContribution
  -> ( [CollectiveStrategyContributionError]
     , Maybe StructuralContribution
     , CollectiveContributionValidationWork)
assessStructure structure claim =
  ( map CollectiveContributionStructuralError errors
  , fmap (StructuralContribution claim) validated
  , mempty {contributionStructuralWork = work})
  where
    proposition = claimedProposition claim
    rawFanIn =
      FanIn.RawCollectiveFanIn
        { FanIn.rawFanInId = rawContributionId proposition
        , FanIn.rawFanInParticipants = rawContributionParticipants proposition
        , FanIn.rawFanInTarget = rawContributionTarget proposition
        , FanIn.rawFanInCompleteness = rawContributionCompleteness proposition
        , FanIn.rawFanInEvidence = rawContributionEvidence proposition
        , FanIn.rawFanInEvidenceReferenceText =
            collectiveContributionEvidenceRefText
              (rawContributionEvidence proposition)
        }
    fanInClaim = claimWithCommitment (claimCommitment claim) rawFanIn
    (errors, validated, work) =
      FanIn.assessCollectiveFanInStructure
        structure
        CollectiveStrategyContributionFamily
        fanInClaim

evaluateContribution ::
     PreparedCollectiveContribution
  -> StructuralContribution
  -> (ContributionEvaluation, CollectiveContributionValidationWork)
evaluateContribution prepared structural =
  case evidenceResolution of
    MissingContributionEvidence ->
      result
        [CollectiveContributionEvidenceNotFound reference]
        Nothing
        Nothing
        baseWork
    AmbiguousContributionEvidence ->
      result
        [CollectiveContributionEvidenceAmbiguous reference]
        Nothing
        Nothing
        baseWork
    UniqueContributionEvidence evidence ->
      let (issues, rationales, graph, work) =
            validateEvidence prepared structural evidence
       in result
            issues
            rationales
            graph
            (baseWork {contributionEvidencePayloadReads = 1} <> work)
  where
    proposition = claimedProposition (structuralClaim structural)
    reference = rawContributionEvidence proposition
    evidenceResolution = lookupContributionEvidence reference prepared
    baseWork = mempty {contributionEvidenceBucketProbes = 1}
    result issues rationales graph work =
      (ContributionEvaluation structural issues rationales graph, work)

validateEvidence ::
     PreparedCollectiveContribution
  -> StructuralContribution
  -> RawCollectiveContributionEvidence
  -> ( [CollectiveStrategyContributionIssue]
     , Maybe (NonEmpty RawJointContributionRationale)
     , Maybe ValidatedContributionGraph
     , CollectiveContributionValidationWork)
validateEvidence prepared structural evidence =
  (bindingIssues ++ rationaleIssues ++ graphIssues, rationales, graph, work)
  where
    proposition = claimedProposition (structuralClaim structural)
    expectedParticipants = rawContributionParticipants proposition
    expectedTarget = rawContributionTarget proposition
    suppliedRationales = rawJointContributionRationales evidence
    bindingIssues =
      [ CollectiveContributionEvidenceClaimMismatch
        (rawContributionId proposition)
        (rawContributionEvidenceClaim evidence)
      | rawContributionEvidenceClaim evidence /= rawContributionId proposition
      ]
        ++ [ CollectiveContributionParticipantsMismatch
           | not
               (sameIdentifierSet
                  expectedParticipants
                  (rawContributionEvidenceParticipants evidence))
           ]
        ++ [ CollectiveContributionTargetMismatch
             expectedTarget
             (rawContributionEvidenceTarget evidence)
           | rawContributionEvidenceTarget evidence /= expectedTarget
           ]
    (rationaleIssues, rationaleIndex) = validateRationales suppliedRationales
    rationales = NonEmpty.nonEmpty suppliedRationales
    (graphIssues, graph, graphWork) =
      case rawContributionPrimitiveGraph evidence of
        Nothing
          | claimCommitment (structuralClaim structural) == Asserted ->
            ( [AssertedCollectiveContributionMissingPrimitiveGraph]
            , Nothing
            , mempty)
          | otherwise -> ([], Nothing, mempty)
        Just rawGraph ->
          validateGraph prepared structural rationaleIndex rawGraph
    work =
      graphWork
        <> mempty {contributionRationalesRead = length suppliedRationales}

validateRationales ::
     [RawJointContributionRationale]
  -> ( [CollectiveStrategyContributionIssue]
     , Map JointContributionRationaleRef RawJointContributionRationale)
validateRationales rationales =
  ( issues
  , Map.fromList [(rawJointRationaleRef value, value) | value <- rationales])
  where
    references = map rawJointRationaleRef rationales
    issues =
      [MissingJointContributionRationale | null rationales]
        ++ [ BlankJointContributionRationaleReference
           | reference <- references
           , blankRationaleReference reference
           ]
        ++ map
             DuplicateJointContributionRationaleReference
             (duplicates references)
        ++ [ BlankJointContributionRationale reference
           | rationale <- rationales
           , let reference = rawJointRationaleRef rationale
           , Text.null (Text.strip (rawJointRationaleText rationale))
           ]
        ++ [ BlankJointContributionRationaleProvenance reference
           | rationale <- rationales
           , let reference = rawJointRationaleRef rationale
           , Text.null (Text.strip (rawJointRationaleProvenance rationale))
           ]

validateGraph ::
     PreparedCollectiveContribution
  -> StructuralContribution
  -> Map JointContributionRationaleRef RawJointContributionRationale
  -> RawContributionEvidenceGraph
  -> ( [CollectiveStrategyContributionIssue]
     , Maybe ValidatedContributionGraph
     , CollectiveContributionValidationWork)
validateGraph prepared structural rationales rawGraph = (issues, witness, work)
  where
    (mode, graph) = rawGraphMode rawGraph
    proposition = claimedProposition (structuralClaim structural)
    participantIds = rawContributionParticipants proposition
    targetId = rawContributionTarget proposition
    ownerIds = Set.fromList (targetId : participantIds)
    nodes = rawContributionGraphNodes graph
    edges = rawContributionGraphEdges graph
    nodeSet = Set.fromList nodes
    duplicateNodes = duplicates nodes
    duplicateEdges = duplicates edges
    rationale = Map.lookup (rawContributionGraphRationale graph) rationales
    bindingIssues =
      [ ContributionGraphClaimMismatch
        (rawContributionId proposition)
        (rawContributionGraphClaim graph)
      | rawContributionGraphClaim graph /= rawContributionId proposition
      ]
        ++ [ ContributionGraphRationaleNotFound
             (rawContributionGraphRationale graph)
           | rationale == Nothing
           ]
        ++ [ ContributionGraphProvenanceMismatch
             (rawContributionGraphRationale graph)
           | Just selected <- [rationale]
           , normalized (rawContributionGraphProvenance graph)
               /= normalized (rawJointRationaleProvenance selected)
           ]
        ++ [EmptyContributionPrimitiveGraph | null nodes || null edges]
        ++ map DuplicateContributionGraphNode duplicateNodes
        ++ map DuplicateContributionGraphEdge duplicateEdges
    nodeResults = map (validateGraphNode prepared mode ownerIds) nodes
    nodeIssues = concatMap firstOfThree nodeResults
    validNodes = mapMaybe secondOfThree nodeResults
    formulationLookups = sum (map thirdOfThree nodeResults)
    representedOwners = Set.fromList (map snd validNodes)
    representationIssues =
      [ ContributionGraphMissingParticipant participant
      | participant <- participantIds
      , Set.notMember participant representedOwners
      ]
        ++ [ ContributionGraphMissingTarget targetId
           | Set.notMember targetId representedOwners
           ]
    edgeResults = map (validateGraphEdge prepared mode nodeSet) edges
    edgeIssues = concatMap firstOfThree edgeResults
    validOccurrences = mapMaybe secondOfThree edgeResults
    occurrenceLookups = sum (map thirdOfThree edgeResults)
    validEdges = map snd validOccurrences
    (topologyIssues, nodeVisits, edgeVisits, adjacencyInsertions) =
      validateTopology nodes validEdges validNodes participantIds targetId
    issues =
      bindingIssues
        ++ nodeIssues
        ++ representationIssues
        ++ edgeIssues
        ++ topologyIssues
    witness =
      case ( issues
           , NonEmpty.nonEmpty nodes
           , NonEmpty.nonEmpty validOccurrences
           , rationale) of
        ([], Just nonEmptyNodes, Just nonEmptyOccurrences, Just selected) ->
          Just
            (mkGraphWitness
               mode
               nonEmptyNodes
               nonEmptyOccurrences
               (rawContributionGraphRationale graph)
               (rawJointRationaleProvenance selected))
        _ -> Nothing
    work =
      mempty
        { contributionNodeLookups = length nodes
        , contributionFormulationLookups = formulationLookups
        , contributionEdgeOccurrenceLookups = occurrenceLookups
        , contributionAdjacencyInsertions = adjacencyInsertions
        , contributionTraversalNodeVisits = nodeVisits
        , contributionTraversalEdgeVisits = edgeVisits
        }

validateGraphNode ::
     PreparedCollectiveContribution
  -> PrimitiveContributionMode
  -> Set RawNodeId
  -> RawNodeId
  -> ([CollectiveStrategyContributionIssue], Maybe (RawNodeId, RawNodeId), Int)
validateGraphNode prepared mode owners identifier =
  case lookupContributionNode identifier prepared of
    Nothing ->
      case lookupStructuralNodeDeclaration
             (preparedContributionStructure prepared)
             identifier of
        Just declaration
          | structuralNodeDeclarationCommitment declaration == Candidate ->
            ([CandidateContributionGraphNode identifier], Nothing, 0)
        _ -> ([UnknownContributionGraphNode identifier], Nothing, 0)
    Just (SomeNode (PrimitiveNode _ owner context primitive _))
      | contextValue context /= Strategy
          || primitiveValue primitive /= modePrimitive mode ->
        ([InvalidContributionGraphNodeKind mode identifier], Nothing, 0)
      | Set.notMember ownerId owners ->
        ([InvalidContributionGraphNodeOwner identifier ownerId], Nothing, 0)
      | not (contributionFormulationContains mode ownerId identifier prepared) ->
        ( [ContributionGraphNodeOutsideFormulation identifier ownerId]
        , Nothing
        , 1)
      | otherwise -> ([], Just (identifier, ownerId), 1)
      where ownerId = unNodeId owner
    Just _ -> ([InvalidContributionGraphNodeKind mode identifier], Nothing, 0)

validateGraphEdge ::
     PreparedCollectiveContribution
  -> PrimitiveContributionMode
  -> Set RawNodeId
  -> RawEdge
  -> ([CollectiveStrategyContributionIssue], Maybe (Int, RawEdge), Int)
validateGraphEdge prepared mode nodes edge
  | rawEdgeRelation edge /= modeRelationName mode =
    ([ContributionGraphEdgeModeMismatch mode edge], Nothing, 0)
  | Just endpoint <- missingEndpoint =
    ([ContributionGraphEdgeEndpointNotListed edge endpoint], Nothing, 0)
  | otherwise =
    case lookupContributionOccurrence mode edge prepared of
      AssertedContributionOccurrence ordinal occurrence ->
        ([], Just (ordinal, occurrence), 1)
      CandidateContributionOccurrence occurrence ->
        ([CandidateContributionGraphEdge occurrence], Nothing, 1)
      MissingContributionOccurrence occurrence ->
        ([ContributionGraphEdgeOccurrenceNotFound occurrence], Nothing, 1)
  where
    missingEndpoint
      | Set.notMember (rawEdgeFrom edge) nodes = Just (rawEdgeFrom edge)
      | Set.notMember (rawEdgeTo edge) nodes = Just (rawEdgeTo edge)
      | otherwise = Nothing

validateTopology ::
     [RawNodeId]
  -> [RawEdge]
  -> [(RawNodeId, RawNodeId)]
  -> [RawNodeId]
  -> RawNodeId
  -> ([CollectiveStrategyContributionIssue], Int, Int, Int)
validateTopology nodes edges ownedNodes participants target =
  (connectivityIssues ++ reachabilityIssues, nodeVisits, edgeVisits, insertions)
  where
    undirected = foldl' insertUndirected Map.empty edges
    reverseDirected = foldl' insertReverse Map.empty edges
    insertions = 2 * length edges + length edges
    (weaklyReached, weakNodeVisits, weakEdgeVisits) =
      case nodes of
        [] -> (Set.empty, 0, 0)
        first:_ -> traverseGraph undirected [first]
    connectivityIssues =
      [ DisconnectedContributionPrimitiveGraph
      | Set.size weaklyReached /= length nodes
      ]
    targetNodes = [node | (node, owner) <- ownedNodes, owner == target]
    (canReachTarget, reverseNodeVisits, reverseEdgeVisits) =
      traverseGraph reverseDirected targetNodes
    nodesByOwner =
      Map.fromListWith (++) [(owner, [node]) | (node, owner) <- ownedNodes]
    reachabilityIssues =
      [ ContributionGraphParticipantCannotReachTarget participant
      | participant <- participants
      , let represented = Map.findWithDefault [] participant nodesByOwner
      , not (null represented)
      , not (any (`Set.member` canReachTarget) represented)
      ]
    nodeVisits = weakNodeVisits + reverseNodeVisits
    edgeVisits = weakEdgeVisits + reverseEdgeVisits

traverseGraph ::
     Map RawNodeId [RawNodeId] -> [RawNodeId] -> (Set RawNodeId, Int, Int)
traverseGraph adjacency = go Set.empty 0 0
  where
    go visited nodeVisits edgeVisits [] = (visited, nodeVisits, edgeVisits)
    go visited nodeVisits edgeVisits (node:rest)
      | Set.member node visited = go visited nodeVisits edgeVisits rest
      | otherwise =
        let successors = Map.findWithDefault [] node adjacency
         in go
              (Set.insert node visited)
              (nodeVisits + 1)
              (edgeVisits + length successors)
              (successors ++ rest)

insertUndirected ::
     Map RawNodeId [RawNodeId] -> RawEdge -> Map RawNodeId [RawNodeId]
insertUndirected index edge =
  Map.insertWith (++) from [to] (Map.insertWith (++) to [from] index)
  where
    from = rawEdgeFrom edge
    to = rawEdgeTo edge

insertReverse ::
     Map RawNodeId [RawNodeId] -> RawEdge -> Map RawNodeId [RawNodeId]
insertReverse index edge =
  Map.insertWith (++) (rawEdgeTo edge) [rawEdgeFrom edge] index

evaluationErrors ::
     ContributionEvaluation -> [CollectiveStrategyContributionError]
evaluationErrors (ContributionEvaluation structural issues _ _)
  | claimCommitment claim == Asserted =
    map (AssertedCollectiveContributionIssue identifier) issues
  | otherwise = []
  where
    claim = structuralClaim structural
    identifier = rawContributionId (claimedProposition claim)

contributionWitness ::
     ContributionEvaluation -> Maybe CollectiveStrategyContribution
contributionWitness (ContributionEvaluation structural issues rationales graph)
  | null issues
  , Just asserted <- FanIn.liftAssertedClosedFanIn (structuralFanIn structural)
  , Just nonEmptyRationales <- rationales
  , Just validatedGraph <- graph =
    Just
      (CollectiveStrategyContribution
         (FanIn.assertedFanInId asserted)
         (FanIn.assertedFanInParticipants asserted)
         (FanIn.assertedFanInTarget asserted)
         (FanIn.assertedFanInEvidence asserted)
         nonEmptyRationales
         validatedGraph)
  | otherwise = Nothing

candidateAssessment ::
     ContributionEvaluation -> Maybe CandidateCollectiveStrategyContribution
candidateAssessment (ContributionEvaluation structural issues _ _)
  | claimCommitment claim == Candidate =
    Just (CandidateCollectiveStrategyContribution claim issues)
  | otherwise = Nothing
  where
    claim = structuralClaim structural

blockedCandidateAssessment ::
     StructuralContribution -> Maybe CandidateCollectiveStrategyContribution
blockedCandidateAssessment structural
  | claimCommitment claim == Candidate =
    Just
      (CandidateCollectiveStrategyContribution
         claim
         [CollectiveContributionSemanticEvaluationBlocked])
  | otherwise = Nothing
  where
    claim = structuralClaim structural

structuralClaim ::
     StructuralContribution -> Claim RawCollectiveStrategyContribution
structuralClaim (StructuralContribution claim _) = claim

structuralFanIn ::
     StructuralContribution
  -> FanIn.StructurallyValidCollectiveFanIn CollectiveContributionEvidenceRef
structuralFanIn (StructuralContribution _ fanIn) = fanIn

assessedEvaluations ::
     CollectiveStrategyContributionAssessment -> [ContributionEvaluation]
assessedEvaluations (CollectiveStrategyContributionAssessment _ evaluations _ _ _) =
  evaluations

rawGraphMode ::
     RawContributionEvidenceGraph
  -> (PrimitiveContributionMode, RawBoundContributionGraph)
rawGraphMode rawGraph =
  case rawGraph of
    RawKeyResultContributionGraph graph -> (KeyResultContributionGraph, graph)
    RawActionContributionGraph graph -> (ActionContributionGraph, graph)

mkGraphWitness ::
     PrimitiveContributionMode
  -> NonEmpty RawNodeId
  -> NonEmpty (Int, RawEdge)
  -> JointContributionRationaleRef
  -> Text.Text
  -> ValidatedContributionGraph
mkGraphWitness mode nodes occurrences rationale provenance =
  case mode of
    KeyResultContributionGraph ->
      ValidatedKeyResultContributionGraph nodes occurrences rationale provenance
    ActionContributionGraph ->
      ValidatedActionContributionGraph nodes occurrences rationale provenance

modePrimitive :: PrimitiveContributionMode -> Primitive
modePrimitive mode =
  case mode of
    KeyResultContributionGraph -> KeyResult
    ActionContributionGraph -> Action

modeRelationName :: PrimitiveContributionMode -> RelationName
modeRelationName mode =
  case mode of
    KeyResultContributionGraph ->
      relationNameFor contributesStrategyKeyResultToKeyResult
    ActionContributionGraph -> relationNameFor contributesStrategyActionToAction

sameIdentifierSet :: [RawNodeId] -> [RawNodeId] -> Bool
sameIdentifierSet left right =
  noDuplicates left
    && noDuplicates right
    && Set.fromList left == Set.fromList right

noDuplicates :: Ord value => [value] -> Bool
noDuplicates values = Set.size (Set.fromList values) == length values

duplicates :: Ord value => [value] -> [value]
duplicates = map head . filter ((> 1) . length) . group . sort

blankRationaleReference :: JointContributionRationaleRef -> Bool
blankRationaleReference =
  Text.null . Text.strip . jointContributionRationaleRefText

normalized :: Text.Text -> Text.Text
normalized = Text.strip

firstOfThree :: (first, second, third) -> first
firstOfThree (first, _, _) = first

secondOfThree :: (first, second, third) -> second
secondOfThree (_, second, _) = second

thirdOfThree :: (first, second, third) -> third
thirdOfThree (_, _, third) = third
