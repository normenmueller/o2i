{-# LANGUAGE GADTs #-}

-- | Internal representation of opaque profile artifacts.
module O2I.Inspection.Profile.Internal
  ( O2IProfileVersion(..)
  , ObservedO2IProfile(..)
  , ResolvedO2IProfile(..)
  , resolveProfileVersion
  , ObservedProfileFacts(..)
  , DefectApplicability(..)
  , DeferredProfileDefect(..)
  , RootProjection(..)
  , PersistedDependencyReason(..)
  , IndexedProfileFact(..)
  , indexOccurrence
  , indexNode
  , indexEdge
  , indexPresentation
  , indexDependency
  , indexReference
  , indexMacroDependency
  , ProfileProjection(..)
  , O2IProfileContract(..)
  , ResolvedProfileProjection(..)
  , ProfileResolution(..)
  , resolveRootProfile
  , ProfileIndex(..)
  , buildProfileIndex
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I (RawEdge, RawNode)
import O2I.Inspection.Diagnostic
import O2I.Inspection.Provenance
import O2I.Inspection.View

-- | Normative concrete-profile version.
newtype O2IProfileVersion = O2IProfileVersion
  { profileVersionText :: Text
  } deriving (Eq, Ord, Show)

-- | Exact root profile-marker cardinality observed by an adapter.
data ObservedO2IProfile
  = NoO2IProfile
  | OneO2IProfile Text
  | MultipleO2IProfiles (NonEmpty Text)
  deriving (Eq, Show)

-- | Successfully resolved normative profile version.
newtype ResolvedO2IProfile = ResolvedO2IProfile
  { resolvedProfileVersion :: O2IProfileVersion
    -- ^ Exact normative profile version accepted by the contract.
  } deriving (Eq, Ord, Show)

-- | Mark the version accepted by one adapter-owned profile contract.
resolveProfileVersion :: O2IProfileVersion -> ResolvedO2IProfile
resolveProfileVersion = ResolvedO2IProfile

-- | Complete source-located observations owned by one adapter.
newtype ObservedProfileFacts fact = ObservedProfileFacts
  { observedProfileFacts :: [Located fact]
  } deriving (Eq, Show)

-- | Reachability condition for one adapter-owned profile defect.
data DefectApplicability
  = GlobalProfileDefect
  | ReachedProfileDefect (NonEmpty OccurrenceId)
  deriving (Eq, Show)

-- | Adapter defect retained until Inspection knows whether it is reached.
data DeferredProfileDefect defect = DeferredProfileDefect
  { defectApplicability :: DefectApplicability
  , deferredDefect :: Located defect
  } deriving (Eq, Show)

-- | Total root projection produced by a notation profile.
data RootProjection defect
  = RootUnprojectable ObservedO2IProfile (NonEmpty (Located defect))
  | RootProjectable ObservedO2IProfile ResolvedO2IProfile
  deriving (Eq, Show)

-- | Persisted semantic dependencies an adapter may project without owning
-- macrorelation rules.
data PersistedDependencyReason
  = PersistedRelationshipEndpoint
  | PersistedContextOwnership
  | PersistedPerformanceDimensionMembership
  | PersistedSituationDependency
  | PersistedNeedDependency
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Format-neutral persisted facts consumed by semantic scope closure.
data IndexedProfileFact
  = IndexedOccurrence OccurrenceId SourceLocation
  | IndexedNode OccurrenceId RawNode SourceLocation
  | IndexedEdge OccurrenceId RawEdge SourceLocation
  | IndexedSeed OccurrenceId OccurrenceId
  | IndexedDependency OccurrenceId OccurrenceId InclusionReason
  | IndexedReference
      OccurrenceId
      ReferenceOccurrence
      [OccurrenceId]
      InclusionReason
  deriving (Eq, Show)

-- | Index one persisted occurrence and its exact location.
indexOccurrence :: OccurrenceId -> SourceLocation -> IndexedProfileFact
indexOccurrence = IndexedOccurrence

-- | Index one projectable O2I node declaration.
indexNode :: OccurrenceId -> RawNode -> SourceLocation -> IndexedProfileFact
indexNode = IndexedNode

-- | Index one projectable O2I relation declaration.
indexEdge :: OccurrenceId -> RawEdge -> SourceLocation -> IndexedProfileFact
indexEdge = IndexedEdge

-- | Index one direct View presentation and its persisted target.
indexPresentation :: OccurrenceId -> OccurrenceId -> IndexedProfileFact
indexPresentation = IndexedSeed

-- | Index one adapter-observed persisted semantic dependency.
indexDependency ::
     OccurrenceId
  -> OccurrenceId
  -> PersistedDependencyReason
  -> IndexedProfileFact
indexDependency source target reason =
  IndexedDependency source target (persistedInclusionReason reason)

-- | Index one persisted reference and all of its exact resolution matches.
indexReference ::
     OccurrenceId
  -> ReferenceOccurrence
  -> [OccurrenceId]
  -> PersistedDependencyReason
  -> IndexedProfileFact
indexReference source reference matches reason =
  IndexedReference source reference matches (persistedInclusionReason reason)

-- | Add one dependency discovered by the core-owned conservative macro
-- interpreter. This constructor remains internal to Inspection.
indexMacroDependency :: OccurrenceId -> OccurrenceId -> IndexedProfileFact
indexMacroDependency source target =
  IndexedDependency source target MacroPremise

persistedInclusionReason :: PersistedDependencyReason -> InclusionReason
persistedInclusionReason reason =
  case reason of
    PersistedRelationshipEndpoint -> RelationshipEndpoint
    PersistedContextOwnership -> ContextOwnership
    PersistedPerformanceDimensionMembership -> PerformanceDimensionMembership
    PersistedSituationDependency -> SituationDependency
    PersistedNeedDependency -> NeedDependency

-- | Total normalized output of one adapter-owned profile projection.
data ProfileProjection defect = ProfileProjection
  { projectedRoot :: RootProjection defect
  , projectedFacts :: [IndexedProfileFact]
  , projectedDefects :: [DeferredProfileDefect defect]
  } deriving (Eq, Show)

-- | Pure profile projection and total defect normalization supplied by an
-- adapter package.
data O2IProfileContract fact defect = O2IProfileContract
  { projectProfileFacts :: ObservedProfileFacts fact -> ProfileProjection defect
  , profileDefectSpec :: defect -> DiagnosticSpec
  }

-- | Opaque successful root projection retaining adapter-owned existential
-- facts and defects until scope closure.
data ResolvedProfileProjection fact defect = ResolvedProfileProjection
  { resolvedObservedFacts :: ObservedProfileFacts fact
  , resolvedProjectedFacts :: [IndexedProfileFact]
  , resolvedDeferredDefects :: [DeferredProfileDefect defect]
  }

-- | Total root-profile resolution executed by Inspection.
data ProfileResolution fact defect
  = ProfileRejected ObservedO2IProfile (NonEmpty (Located defect))
  | ProfileResolved ResolvedO2IProfile (ResolvedProfileProjection fact defect)

-- | Execute root-profile resolution while retaining local deferred defects.
resolveRootProfile ::
     O2IProfileContract fact defect
  -> ObservedProfileFacts fact
  -> ProfileResolution fact defect
resolveRootProfile contract observations =
  case projectedRoot projection of
    RootUnprojectable observed rootDefects ->
      ProfileRejected
        observed
        (foldr NonEmpty.cons rootDefects globalDefectList)
    RootProjectable observed resolved ->
      case NonEmpty.nonEmpty globalDefectList of
        Just defects -> ProfileRejected observed defects
        Nothing ->
          ProfileResolved
            resolved
            ResolvedProfileProjection
              { resolvedObservedFacts = observations
              , resolvedProjectedFacts = projectedFacts projection
              , resolvedDeferredDefects = localDefects
              }
  where
    projection = projectProfileFacts contract observations
    (globalDefectList, localDefects) =
      foldr partitionDefect ([], []) (projectedDefects projection)
    partitionDefect deferred (globals, locals) =
      case defectApplicability deferred of
        GlobalProfileDefect -> (deferredDefect deferred : globals, locals)
        ReachedProfileDefect _ -> (globals, deferred : locals)

-- | Opaque existential index binding one exact View and profile projection.
data ProfileIndex where
  ProfileIndex
    :: O2IProfileContract fact defect
    -> ResolvedView
    -> ResolvedProfileProjection fact defect
    -> ProfileIndex

-- | Hide adapter-owned profile types in one Inspection-owned index.
buildProfileIndex ::
     ResolvedView
  -> O2IProfileContract fact defect
  -> ResolvedProfileProjection fact defect
  -> ProfileIndex
buildProfileIndex view contract projection =
  ProfileIndex contract view projection
