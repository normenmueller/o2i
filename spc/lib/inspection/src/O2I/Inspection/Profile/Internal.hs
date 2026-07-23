{-# LANGUAGE GADTs #-}

-- | Internal representation of opaque profile artifacts.
module O2I.Inspection.Profile.Internal
  ( O2IProfileVersion(..)
  , profileVersionText
  , O2IProfileVersionError(..)
  , mkO2IProfileVersion
  , o2iProfileVersionLiteral
  , ObservedO2IProfile(..)
  , ResolvedO2IProfile(..)
  , resolveProfileVersion
  , ProfileSnapshot
  , profileSnapshot
  , snapshotFact
  , DefectApplicability(..)
  , DeferredProfileDefect(..)
  , RootProjection(..)
  , PersistedDependencyReason(..)
  , IndexedProfileFact(..)
  , indexOccurrence
  , indexNode
  , indexEdge
  , indexCollectiveStrategyRealization
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
import qualified Data.Text as Text
import O2I (Claim, RawCollectiveStrategyRealization, RawEdge, RawNode)
import O2I.Inspection.Cardinality
import O2I.Inspection.Diagnostic
import O2I.Inspection.Provenance
import O2I.Inspection.View

-- | Normative concrete-profile version.
newtype O2IProfileVersion = O2IProfileVersion
  { unO2IProfileVersion :: Text
  } deriving (Eq, Ord, Show)

-- | Why profile-version text cannot be represented in a report.
data O2IProfileVersionError =
  EmptyO2IProfileVersion
  deriving (Eq, Ord, Show)

-- | Validate report-visible O2I profile-version text.
mkO2IProfileVersion :: Text -> Either O2IProfileVersionError O2IProfileVersion
mkO2IProfileVersion value
  | Text.null value = Left EmptyO2IProfileVersion
  | otherwise = Right (O2IProfileVersion value)

-- | Construct a profile version from a statically non-empty character sequence.
o2iProfileVersionLiteral :: NonEmpty Char -> O2IProfileVersion
o2iProfileVersionLiteral = O2IProfileVersion . Text.pack . NonEmpty.toList

-- | Read the validated O2I profile version.
profileVersionText :: O2IProfileVersion -> Text
profileVersionText (O2IProfileVersion version) = version

-- | Exact root profile-marker cardinality observed by an adapter.
data ObservedO2IProfile
  = NoO2IProfile
  | OneO2IProfile Text
  | MultipleO2IProfiles (AtLeastTwo Text)
  deriving (Eq, Show)

-- | Successfully resolved normative profile version.
newtype ResolvedO2IProfile = ResolvedO2IProfile
  { resolvedProfileVersion :: O2IProfileVersion
    -- ^ Exact normative profile version accepted by the contract.
  } deriving (Eq, Ord, Show)

-- | Mark the version accepted by one adapter-owned profile contract.
resolveProfileVersion :: O2IProfileVersion -> ResolvedO2IProfile
resolveProfileVersion = ResolvedO2IProfile

-- | Exactly one source-located observation produced by an adapter.
newtype ProfileSnapshot location fact = ProfileSnapshot
    -- | Recover the single source-located fact carried by the snapshot.
  { snapshotFact :: Located location fact
  } deriving (Eq, Show)

-- | Bind one complete adapter observation to the projection boundary.
profileSnapshot :: Located location fact -> ProfileSnapshot location fact
profileSnapshot = ProfileSnapshot

-- | Reachability condition for one adapter-owned profile defect.
data DefectApplicability
  = GlobalProfileDefect
  | ReachedProfileDefect (NonEmpty OccurrenceId)
  deriving (Eq, Show)

-- | Adapter defect retained until Inspection knows whether it is reached.
data DeferredProfileDefect location defect = DeferredProfileDefect
  { defectApplicability :: DefectApplicability
  , deferredDefect :: Located location defect
  } deriving (Eq, Show)

-- | Total root projection produced by a notation profile.
data RootProjection location defect
  = RootUnprojectable ObservedO2IProfile (NonEmpty (Located location defect))
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
  | PersistedCollectiveRealizationSegment
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Format-neutral persisted facts consumed by semantic scope closure.
data IndexedProfileFact location
  = IndexedOccurrence OccurrenceId location
  | IndexedNode OccurrenceId (Claim RawNode) location
  | IndexedEdge OccurrenceId (Claim RawEdge) location
  | IndexedCollectiveStrategyRealization
      OccurrenceId
      RawCollectiveStrategyRealization
      [OccurrenceId]
      OccurrenceId
      location
  | IndexedSeed OccurrenceId OccurrenceId
  | IndexedDependency OccurrenceId OccurrenceId InclusionReason
  | IndexedReference
      OccurrenceId
      (ReferenceOccurrence location)
      [OccurrenceId]
      InclusionReason
  deriving (Eq, Show)

-- | Index one persisted occurrence and its exact location.
indexOccurrence :: OccurrenceId -> location -> IndexedProfileFact location
indexOccurrence = IndexedOccurrence

-- | Index one projectable O2I node declaration.
indexNode ::
     OccurrenceId -> Claim RawNode -> location -> IndexedProfileFact location
indexNode = IndexedNode

-- | Index one projectable O2I relation declaration.
indexEdge ::
     OccurrenceId -> Claim RawEdge -> location -> IndexedProfileFact location
indexEdge = IndexedEdge

-- | Index one collective claim and its resolved participant occurrences.
indexCollectiveStrategyRealization ::
     OccurrenceId
  -> RawCollectiveStrategyRealization
  -> [OccurrenceId]
  -> OccurrenceId
  -> location
  -> IndexedProfileFact location
indexCollectiveStrategyRealization = IndexedCollectiveStrategyRealization

-- | Index one direct View presentation and its persisted target.
indexPresentation :: OccurrenceId -> OccurrenceId -> IndexedProfileFact location
indexPresentation = IndexedSeed

-- | Index one adapter-observed persisted semantic dependency.
indexDependency ::
     OccurrenceId
  -> OccurrenceId
  -> PersistedDependencyReason
  -> IndexedProfileFact location
indexDependency source target reason =
  IndexedDependency source target (persistedInclusionReason reason)

-- | Index one persisted reference and all of its exact resolution matches.
indexReference ::
     OccurrenceId
  -> ReferenceOccurrence location
  -> [OccurrenceId]
  -> PersistedDependencyReason
  -> IndexedProfileFact location
indexReference source reference matches reason =
  IndexedReference source reference matches (persistedInclusionReason reason)

-- | Add one dependency discovered by the core-owned conservative macro
-- interpreter. This constructor remains internal to Inspection.
indexMacroDependency ::
     OccurrenceId -> OccurrenceId -> IndexedProfileFact location
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
    PersistedCollectiveRealizationSegment -> CollectiveRealizationSegment

-- | Total normalized output of one adapter-owned profile projection.
data ProfileProjection location defect = ProfileProjection
  { projectedRoot :: RootProjection location defect
  , projectedFacts :: [IndexedProfileFact location]
  , projectedDefects :: [DeferredProfileDefect location defect]
  } deriving (Eq, Show)

-- | Pure profile projection and total defect normalization supplied by an
-- adapter package.
data O2IProfileContract location fact defect = O2IProfileContract
  { projectProfileSnapshot :: ProfileSnapshot location fact -> ProfileProjection
                                                                 location
                                                                 defect
  , profileDefectSpec :: defect -> DiagnosticSpec
  }

-- | Opaque successful root projection retaining adapter-owned existential
-- facts and defects until scope closure.
data ResolvedProfileProjection location fact defect = ResolvedProfileProjection
  { resolvedProfileSnapshot :: ProfileSnapshot location fact
  , resolvedProjectedFacts :: [IndexedProfileFact location]
  , resolvedDeferredDefects :: [DeferredProfileDefect location defect]
  }

-- | Total root-profile resolution executed by Inspection.
data ProfileResolution location fact defect
  = ProfileRejected ObservedO2IProfile (NonEmpty (Located location defect))
  | ProfileResolved
      ResolvedO2IProfile
      (ResolvedProfileProjection location fact defect)

-- | Execute root-profile resolution while retaining local deferred defects.
resolveRootProfile ::
     O2IProfileContract location fact defect
  -> ProfileSnapshot location fact
  -> ProfileResolution location fact defect
resolveRootProfile contract snapshot =
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
              { resolvedProfileSnapshot = snapshot
              , resolvedProjectedFacts = projectedFacts projection
              , resolvedDeferredDefects = localDefects
              }
  where
    projection = projectProfileSnapshot contract snapshot
    (globalDefectList, localDefects) =
      foldr partitionDefect ([], []) (projectedDefects projection)
    partitionDefect deferred (globals, locals) =
      case defectApplicability deferred of
        GlobalProfileDefect -> (deferredDefect deferred : globals, locals)
        ReachedProfileDefect _ -> (globals, deferred : locals)

-- | Opaque existential index binding one exact View and profile projection.
data ProfileIndex where
  ProfileIndex
    :: (defect -> DiagnosticSpec)
    -> ResolvedView SourceLocation
    -> ResolvedProfileProjection SourceLocation fact defect
    -> ProfileIndex

-- | Hide adapter-owned profile types in one Inspection-owned index.
buildProfileIndex ::
     ResolvedView SourceLocation
  -> O2IProfileContract location fact defect
  -> ResolvedProfileProjection SourceLocation fact defect
  -> ProfileIndex
buildProfileIndex view contract projection =
  ProfileIndex (profileDefectSpec contract) view projection
