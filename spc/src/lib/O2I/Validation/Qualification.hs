{-# LANGUAGE DataKinds #-}

-- | Formal admissibility of proposed Need qualifications.
--
-- This validation stage checks a proposal against an already semantically
-- valid O2I model. It neither accepts subject-matter relevance nor persists the
-- proposed macrorelation and its Primitive evidence.
module O2I.Validation.Qualification
  ( RawNeedQualificationProposal(..)
  , NeedQualificationSourceReference
  , NeedQualificationCandidate
  , NeedQualificationError(..)
  , needQualificationCandidateStrategy
  , needQualificationCandidateNeed
  , needQualificationCandidateKeyResult
  , needQualificationCandidateObjective
  , needQualificationCandidateRationale
  , needQualificationCandidateSourceReference
  , needQualificationSourceReferenceText
  , validateNeedQualificationProposal
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Validation (Validation(..))
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Semantics

-- | Unchecked proposal to qualify one situated Need against one Strategy.
--
-- The submitter identifies the candidate Strategy, the situated Need, the
-- Strategy Key Result proposed to translate into the Need Objective, the
-- domain rationale, and its source reference. Validation never derives
-- semantic fit from labels or text similarity.
data RawNeedQualificationProposal = RawNeedQualificationProposal
  { rawNeedQualificationCandidateStrategy :: RawNodeId
    -- ^ Strategy proposed as the qualifying Strategy.
  , rawNeedQualificationNeed :: RawNodeId
    -- ^ Situated Need proposed for qualification.
  , rawNeedQualificationStrategyKeyResult :: RawNodeId
    -- ^ Listed Strategy Key Result proposed as qualification evidence.
  , rawNeedQualificationNeedObjective :: RawNodeId
    -- ^ Objective owned by the submitted Need.
  , rawNeedQualificationRationale :: Text
    -- ^ Explicit domain rationale for the proposed translation.
  , rawNeedQualificationSourceReference :: Text
    -- ^ Source reference supporting the submitted rationale.
  } deriving (Eq, Show)

-- | Validated nonblank source reference for a Need qualification proposal.
--
-- The reference identifies supporting material without asserting its truth,
-- authority, or evidentiary strength.
newtype NeedQualificationSourceReference =
  NeedQualificationSourceReference Text
  deriving (Eq, Show)

-- | Structurally and relationally admissible Need qualification proposal.
--
-- A candidate can be presented for subject-matter acceptance. It neither
-- establishes semantic truth nor persists @Strategy --qualifies--> Need@ or
-- its Primitive evidence.
data NeedQualificationCandidate = NeedQualificationCandidate
  { validatedNeedQualificationCandidateStrategy :: ContextRef 'Strategy
  , validatedNeedQualificationCandidateNeed :: ContextRef 'Need
  , validatedNeedQualificationCandidateKeyResult :: NodeId
      ('PrimitiveKind 'Strategy 'KeyResult)
  , validatedNeedQualificationCandidateObjective :: NodeId
      ('PrimitiveKind 'Need 'Objective)
  , validatedNeedQualificationCandidateRationale :: Text
  , validatedNeedQualificationCandidateSourceReference :: NeedQualificationSourceReference
  } deriving (Eq, Show)

-- | Violations that prevent a proposal from becoming a candidate.
data NeedQualificationError
  = UnknownNeedQualificationStrategy RawNodeId
    -- ^ The candidate Strategy identifier is unknown.
  | NeedQualificationStrategyKindMismatch RawNodeId NodeKindValue
    -- ^ The candidate Strategy identifier denotes another node kind.
  | UnknownNeedQualificationNeed RawNodeId
    -- ^ The proposed Need identifier is unknown.
  | NeedQualificationNeedKindMismatch RawNodeId NodeKindValue
    -- ^ The proposed Need identifier denotes another node kind.
  | UnknownNeedQualificationKeyResult RawNodeId
    -- ^ The proposed Strategy Key Result identifier is unknown.
  | NeedQualificationKeyResultMismatch RawNodeId NodeKindValue (Maybe RawNodeId)
    -- ^ The proposed evidence has the wrong kind or owning Strategy.
  | UnlistedNeedQualificationKeyResult RawNodeId RawNodeId
    -- ^ The Key Result is not part of the Strategy's validated formulation.
  | UnknownNeedQualificationObjective RawNodeId
    -- ^ The proposed Need Objective identifier is unknown.
  | NeedQualificationObjectiveMismatch RawNodeId NodeKindValue (Maybe RawNodeId)
    -- ^ The proposed Objective has the wrong kind or owning Need.
  | EmptyNeedQualificationRationale
    -- ^ The proposal provides no domain rationale.
  | EmptyNeedQualificationSourceReference
    -- ^ The proposal provides no source for its domain rationale.
  | NeedQualificationRelationAlreadyModeled RawNodeId RawNodeId
    -- ^ The proposed Strategy-to-Need macrorelation already exists.
  | NeedQualificationTranslationAlreadyModeled RawNodeId RawNodeId
    -- ^ The proposed Key-Result-to-Objective evidence already exists.
  deriving (Eq, Show)

-- | Read the candidate Strategy established by proposal validation.
needQualificationCandidateStrategy ::
     NeedQualificationCandidate -> ContextRef 'Strategy
needQualificationCandidateStrategy = validatedNeedQualificationCandidateStrategy

-- | Read the situated Need established by proposal validation.
needQualificationCandidateNeed :: NeedQualificationCandidate -> ContextRef 'Need
needQualificationCandidateNeed = validatedNeedQualificationCandidateNeed

-- | Read the listed Strategy Key Result proposed as qualification evidence.
needQualificationCandidateKeyResult ::
     NeedQualificationCandidate -> NodeId ('PrimitiveKind 'Strategy 'KeyResult)
needQualificationCandidateKeyResult =
  validatedNeedQualificationCandidateKeyResult

-- | Read the Need Objective proposed as the translation target.
needQualificationCandidateObjective ::
     NeedQualificationCandidate -> NodeId ('PrimitiveKind 'Need 'Objective)
needQualificationCandidateObjective =
  validatedNeedQualificationCandidateObjective

-- | Read the nonblank domain rationale supplied with the proposal.
needQualificationCandidateRationale :: NeedQualificationCandidate -> Text
needQualificationCandidateRationale =
  validatedNeedQualificationCandidateRationale

-- | Read the validated source reference supplied with the proposal.
needQualificationCandidateSourceReference ::
     NeedQualificationCandidate -> NeedQualificationSourceReference
needQualificationCandidateSourceReference =
  validatedNeedQualificationCandidateSourceReference

-- | Read the normalized text of a Need qualification source reference.
needQualificationSourceReferenceText :: NeedQualificationSourceReference -> Text
needQualificationSourceReferenceText (NeedQualificationSourceReference reference) =
  reference

-- | Validate a Need qualification proposal without deciding subject-matter fit.
--
-- Call this function after the Need is fully situated and before modeling the
-- proposed @translates-into@ and @qualifies@ relations. It checks that the
-- Strategy is completely formulated, the proposed Key Result belongs to that
-- formulation, the Objective belongs to the Need, the rationale and source
-- reference are nonblank, and neither proposed relation already exists.
--
-- Failure returns no candidate and accumulates every detected formal error.
-- All errors must be resolved before resubmission; validation makes no
-- subject-matter acceptance decision and leaves the graph unchanged.
--
-- A successful candidate enters this follow-up process:
--
-- 1. Authorized subject-matter reviewers assess the rationale and source for
--    domain legitimacy.
-- 2. Rejection leaves the graph unchanged.
-- 3. Acceptance models both
--    @Key Result \@ Strategy --translates-into--> Objective \@ Need@ and
--    @Strategy --qualifies--> Need@.
-- 4. The resulting graph is validated again as an O2I model.
-- 5. 'qualifyingStrategies' must then return the qualifying Strategy; only
--    then is the situated Need effect-relevant.
--
-- An organization-specific Strategic Fit Evaluation (SFE) may use this formal
-- check as one gate. O2I neither defines nor automates an SFE, and this function
-- makes no subject-matter acceptance decision.
validateNeedQualificationProposal ::
     SemanticallyValidModel
  -> RawNeedQualificationProposal
  -> Validation (NonEmpty NeedQualificationError) NeedQualificationCandidate
validateNeedQualificationProposal semantic proposal =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure failures
    Nothing ->
      Success
        NeedQualificationCandidate
          { validatedNeedQualificationCandidateStrategy = mkContextRef strategy
          , validatedNeedQualificationCandidateNeed = mkContextRef need
          , validatedNeedQualificationCandidateKeyResult = mkNodeId keyResult
          , validatedNeedQualificationCandidateObjective = mkNodeId objective
          , validatedNeedQualificationCandidateRationale =
              rawNeedQualificationRationale proposal
          , validatedNeedQualificationCandidateSourceReference =
              NeedQualificationSourceReference sourceReference
          }
  where
    graph = modelGraph semantic
    strategy = rawNeedQualificationCandidateStrategy proposal
    need = rawNeedQualificationNeed proposal
    keyResult = rawNeedQualificationStrategyKeyResult proposal
    objective = rawNeedQualificationNeedObjective proposal
    strategyErrors = contextProposalErrors graph strategy Strategy
    needErrors = contextProposalErrors graph need Need
    keyResultReferenceErrors =
      primitiveProposalErrors graph keyResult strategy Strategy KeyResult
    keyResultErrors =
      keyResultReferenceErrors
        ++ [ error'
           | null strategyErrors && null keyResultReferenceErrors
           , error' <- unlistedKeyResultErrors semantic strategy keyResult
           ]
    objectiveErrors =
      primitiveProposalErrors graph objective need Need Objective
    rationaleErrors =
      [ EmptyNeedQualificationRationale
      | Text.null (Text.strip (rawNeedQualificationRationale proposal))
      ]
    sourceReference = Text.strip (rawNeedQualificationSourceReference proposal)
    sourceReferenceErrors =
      [EmptyNeedQualificationSourceReference | Text.null sourceReference]
    existingRelationErrors =
      [ NeedQualificationRelationAlreadyModeled strategy need
      | hasEdge graph strategy (relationNameFor qualifiesNeed) need
      ]
        ++ [ NeedQualificationTranslationAlreadyModeled keyResult objective
           | hasEdge
               graph
               keyResult
               (relationNameFor translatesStrategyKeyResultToNeedObjective)
               objective
           ]
    errors =
      strategyErrors
        ++ needErrors
        ++ keyResultErrors
        ++ objectiveErrors
        ++ rationaleErrors
        ++ sourceReferenceErrors
        ++ existingRelationErrors

contextProposalErrors ::
     WellFormedGraph -> RawNodeId -> Context -> [NeedQualificationError]
contextProposalErrors graph identifier expected =
  case lookupNode graph identifier of
    Nothing
      | expected == Strategy -> [UnknownNeedQualificationStrategy identifier]
      | otherwise -> [UnknownNeedQualificationNeed identifier]
    Just node
      | someNodeKind node == ContextNodeKind expected -> []
      | expected == Strategy ->
        [NeedQualificationStrategyKindMismatch identifier (someNodeKind node)]
      | otherwise ->
        [NeedQualificationNeedKindMismatch identifier (someNodeKind node)]

primitiveProposalErrors ::
     WellFormedGraph
  -> RawNodeId
  -> RawNodeId
  -> Context
  -> Primitive
  -> [NeedQualificationError]
primitiveProposalErrors graph identifier expectedOwner context primitive =
  case lookupNode graph identifier of
    Nothing
      | primitive == KeyResult -> [UnknownNeedQualificationKeyResult identifier]
      | otherwise -> [UnknownNeedQualificationObjective identifier]
    Just node
      | someNodeKind node == PrimitiveNodeKind context primitive
          && someNodeOwner node == Just expectedOwner -> []
      | primitive == KeyResult ->
        [ NeedQualificationKeyResultMismatch
            identifier
            (someNodeKind node)
            (someNodeOwner node)
        ]
      | otherwise ->
        [ NeedQualificationObjectiveMismatch
            identifier
            (someNodeKind node)
            (someNodeOwner node)
        ]

unlistedKeyResultErrors ::
     SemanticallyValidModel
  -> RawNodeId
  -> RawNodeId
  -> [NeedQualificationError]
unlistedKeyResultErrors semantic strategy keyResult =
  case Map.lookup strategy (strategyFormulations semantic) of
    Just formulation
      | keyResult
          `elem` NonEmpty.toList
                   (rawFormulationKeyResults
                      (strategyFormulationData formulation)) -> []
    _ -> [UnlistedNeedQualificationKeyResult strategy keyResult]
