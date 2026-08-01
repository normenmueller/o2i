module CollectiveRecordUpdates where

import qualified O2I.ArchiMate.Profile as Profile

rewriteCollective :: Profile.CollectiveContract -> Profile.CollectiveContract
rewriteCollective collective =
  collective
    { Profile.collectiveCarrier = Profile.collectiveCarrier collective
    , Profile.collectiveSegments = Profile.collectiveSegments collective
    , Profile.collectiveContributors = Profile.collectiveContributors collective
    , Profile.collectiveTarget = Profile.collectiveTarget collective
    , Profile.collectiveJunctionChains =
        Profile.collectiveJunctionChains collective
    }

rewriteCarrier ::
     Profile.CollectiveCarrierContract -> Profile.CollectiveCarrierContract
rewriteCarrier carrier =
  carrier
    { Profile.collectiveCarrierKind = Profile.collectiveCarrierKind carrier
    , Profile.collectiveCarrierType = Profile.collectiveCarrierType carrier
    , Profile.collectiveCarrierElement =
        Profile.collectiveCarrierElement carrier
    , Profile.collectiveJunctionType = Profile.collectiveJunctionType carrier
    , Profile.collectiveCommitmentKey = Profile.collectiveCommitmentKey carrier
    , Profile.collectiveFitEvidenceKey =
        Profile.collectiveFitEvidenceKey carrier
    }

rewriteSegment ::
     Profile.CollectiveSegmentContract -> Profile.CollectiveSegmentContract
rewriteSegment segment =
  segment
    { Profile.collectiveSegmentRepresentation =
        Profile.collectiveSegmentRepresentation segment
    , Profile.collectiveSegmentLabel = Profile.collectiveSegmentLabel segment
    , Profile.collectiveSegmentMetadata =
        Profile.collectiveSegmentMetadata segment
    }

rewriteContributors ::
     Profile.CollectiveContributorsContract
  -> Profile.CollectiveContributorsContract
rewriteContributors contributors =
  contributors
    { Profile.collectiveContributorCardinality =
        Profile.collectiveContributorCardinality contributors
    , Profile.collectiveContributorsDistinct =
        Profile.collectiveContributorsDistinct contributors
    }

rewriteTarget ::
     Profile.CollectiveTargetContract -> Profile.CollectiveTargetContract
rewriteTarget target =
  target
    { Profile.collectiveTargetCardinality =
        Profile.collectiveTargetCardinality target
    , Profile.collectiveTargetDistinctFromContributors =
        Profile.collectiveTargetDistinctFromContributors target
    }
