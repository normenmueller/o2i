{-# LANGUAGE GADTs #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Private lossless representation of prepared owner diagnostics.
module O2I.Operation.Diagnostic.Internal
  ( DiagnosticSeverity(..)
  , DiagnosticDisposition(..)
  , PreparedDiagnostic(..)
  , SupplementalDiagnosticGroup(..)
  , PreparedDiagnosticDocument(..)
  ) where

import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Projection as Profile
import O2I.Operation.Acquisition (AcquiredSupplementalSource)
import O2I.Operation.Diagnostic.Owner.Source.Internal
  ( PreparedAuthority
  , SupplementalOwnerBindingEvidence
  )
import qualified O2I.Semantics as Semantics
import qualified O2I.Structure as Structure

-- | Closed impact derived from the retained producer branch.
data DiagnosticSeverity
  = InfoSeverity
  | ErrorSeverity
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Every post-preparation owner diagnostic is a model finding.
data DiagnosticDisposition =
  ModelFinding
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | One exact owner value retained until encoding.
--
-- The authority, Profile and document parameters prevent evidence from two
-- preparation runs from being combined through the public API. Structure and
-- Semantics scopes remain existential inside their exact evidence values.
data PreparedDiagnostic authority profile document where
  ProfileActivationDiagnostic
    :: !(Closure.ActivationProvenance profile document)
    -> PreparedDiagnostic authority profile document
  ProfileRejectionDiagnostic
    :: !(Profile.ProfileDiagnosticEvidence profile document)
    -> PreparedDiagnostic authority profile document
  ProfileClassificationDiagnostic
    :: !(Profile.ProfileClassificationEvidence profile document)
    -> PreparedDiagnostic authority profile document
  ProfileMappingDiagnostic
    :: !(Profile.ProfileMappingProvenance profile document)
    -> PreparedDiagnostic authority profile document
  ProfileInvariantDiagnostic
    :: !(Profile.ProfileInvariantEvidence profile document)
    -> PreparedDiagnostic authority profile document
  StructureRejectionDiagnostic
    :: !(Structure.StructureEvidence scope)
    -> PreparedDiagnostic authority profile document
  SemanticsRejectionDiagnostic
    :: !(Semantics.SemanticDiagnosticEvidence scope)
    -> PreparedDiagnostic authority profile document

type role PreparedDiagnostic nominal nominal nominal

-- | All Binding findings for one exact acquired supplemental source.
data SupplementalDiagnosticGroup authority profile document where
  SupplementalDiagnosticGroup
    :: !AcquiredSupplementalSource
    -> ![SupplementalOwnerBindingEvidence scope inputs]
    -> SupplementalDiagnosticGroup authority profile document

type role SupplementalDiagnosticGroup nominal nominal nominal

-- | One authority-once, existentially sealed v2 machine subject.
data PreparedDiagnosticDocument where
  PreparedDiagnosticDocument
    :: !(PreparedAuthority authority profile document)
    -> ![PreparedDiagnostic authority profile document]
    -> ![SupplementalDiagnosticGroup authority profile document]
    -> PreparedDiagnosticDocument
