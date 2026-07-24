{-# LANGUAGE OverloadedStrings #-}

-- | Closed decoding contract for explicit proposition commitment.
module O2I.Adapter.AMX.Internal.Profile.Commitment
  ( CommitmentResolution
  , decodeCommitment
  , resolvedCommitment
  , commitmentResolutionDefects
  , forbiddenCommitmentDefects
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I (Commitment(..))
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Profile.Model (displayId)
import O2I.Adapter.AMX.Internal.Profile.Property
import O2I.Adapter.AMX.Internal.Types
import O2I.Inspection.Provenance

-- | Total result of decoding exactly one direct @o2i.commitment@.
data CommitmentResolution
  = CommitmentResolved Commitment
  | CommitmentRejected (NonEmpty (Located SourcePosition AMXProfileDefect))

-- | Decode one proposition carrier without defaults or inferred commitment.
decodeCommitment :: AMXElement -> CommitmentResolution
decodeCommitment element =
  case directProperties "o2i.commitment" element of
    [] ->
      CommitmentRejected
        (Located (amxElementLocation element) (MissingCommitment identifier)
           :| [])
    [(property, value)] ->
      case value of
        "candidate" -> CommitmentResolved Candidate
        "asserted" -> CommitmentResolved Asserted
        _ ->
          CommitmentRejected
            (Located
               (propertyLocation "o2i.commitment" property)
               (InvalidCommitment identifier value)
               :| [])
    first:rest ->
      CommitmentRejected
        (Located
           (propertyLocation "o2i.commitment" (fst first))
           (DuplicateCommitment identifier (snd first :| map snd rest))
           :| [])
  where
    identifier = displayId element

-- | Project a decoded commitment only from an accepted resolution.
resolvedCommitment :: CommitmentResolution -> Maybe Commitment
resolvedCommitment resolution =
  case resolution of
    CommitmentResolved commitment -> Just commitment
    CommitmentRejected _ -> Nothing

-- | Project every precise defect from a rejected resolution.
commitmentResolutionDefects ::
     CommitmentResolution -> [Located SourcePosition AMXProfileDefect]
commitmentResolutionDefects resolution =
  case resolution of
    CommitmentResolved _ -> []
    CommitmentRejected defects -> NonEmpty.toList defects

-- | Reject commitment metadata on a non-propositional syntax constituent.
forbiddenCommitmentDefects ::
     Text -> AMXElement -> [Located SourcePosition AMXProfileDefect]
forbiddenCommitmentDefects syntaxRole element =
  [ Located
    (propertyLocation "o2i.commitment" property)
    (ForbiddenCommitment (displayId element) syntaxRole)
  | (property, _) <- directProperties "o2i.commitment" element
  ]
