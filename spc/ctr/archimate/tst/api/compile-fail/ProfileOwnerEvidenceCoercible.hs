module ProfileOwnerEvidenceCoercible where

import Data.Coerce (coerce)
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Projection as Projection

coerceActivationProfile ::
     Closure.ActivationProvenance firstProfile document
  -> Closure.ActivationProvenance secondProfile document
coerceActivationProfile = coerce

coerceActivationDocument ::
     Closure.ActivationProvenance profile firstDocument
  -> Closure.ActivationProvenance profile secondDocument
coerceActivationDocument = coerce

coerceClosureProfile ::
     Closure.ClosureProvenance firstProfile document
  -> Closure.ClosureProvenance secondProfile document
coerceClosureProfile = coerce

coerceClosureDocument ::
     Closure.ClosureProvenance profile firstDocument
  -> Closure.ClosureProvenance profile secondDocument
coerceClosureDocument = coerce

coerceDiagnosticProfile ::
     Projection.ProfileDiagnosticEvidence firstProfile document
  -> Projection.ProfileDiagnosticEvidence secondProfile document
coerceDiagnosticProfile = coerce

coerceDiagnosticDocument ::
     Projection.ProfileDiagnosticEvidence profile firstDocument
  -> Projection.ProfileDiagnosticEvidence profile secondDocument
coerceDiagnosticDocument = coerce

coerceContractProfile ::
     Projection.ProfileContractEvidence firstProfile document
  -> Projection.ProfileContractEvidence secondProfile document
coerceContractProfile = coerce

coerceContractDocument ::
     Projection.ProfileContractEvidence profile firstDocument
  -> Projection.ProfileContractEvidence profile secondDocument
coerceContractDocument = coerce

coerceAssessmentProfile ::
     Projection.ProfileProjectionAssessment firstProfile document
  -> Projection.ProfileProjectionAssessment secondProfile document
coerceAssessmentProfile = coerce

coerceAssessmentDocument ::
     Projection.ProfileProjectionAssessment profile firstDocument
  -> Projection.ProfileProjectionAssessment profile secondDocument
coerceAssessmentDocument = coerce

coerceProjectionProfile ::
     Projection.ProfileProjection firstProfile document
  -> Projection.ProfileProjection secondProfile document
coerceProjectionProfile = coerce

coerceProjectionDocument ::
     Projection.ProfileProjection profile firstDocument
  -> Projection.ProfileProjection profile secondDocument
coerceProjectionDocument = coerce

coerceClassificationProfile ::
     Projection.ProfileClassificationEvidence firstProfile document
  -> Projection.ProfileClassificationEvidence secondProfile document
coerceClassificationProfile = coerce

coerceClassificationDocument ::
     Projection.ProfileClassificationEvidence profile firstDocument
  -> Projection.ProfileClassificationEvidence profile secondDocument
coerceClassificationDocument = coerce

coerceMappingProfile ::
     Projection.ProfileMappingProvenance firstProfile document
  -> Projection.ProfileMappingProvenance secondProfile document
coerceMappingProfile = coerce

coerceMappingDocument ::
     Projection.ProfileMappingProvenance profile firstDocument
  -> Projection.ProfileMappingProvenance profile secondDocument
coerceMappingDocument = coerce

coerceInvariantProfile ::
     Projection.ProfileInvariantEvidence firstProfile document
  -> Projection.ProfileInvariantEvidence secondProfile document
coerceInvariantProfile = coerce

coerceInvariantDocument ::
     Projection.ProfileInvariantEvidence profile firstDocument
  -> Projection.ProfileInvariantEvidence profile secondDocument
coerceInvariantDocument = coerce

coerceEvidenceProfile ::
     Projection.ProfileEvidence firstProfile document kind
  -> Projection.ProfileEvidence secondProfile document kind
coerceEvidenceProfile = coerce

coerceEvidenceDocument ::
     Projection.ProfileEvidence profile firstDocument kind
  -> Projection.ProfileEvidence profile secondDocument kind
coerceEvidenceDocument = coerce

coerceEvidenceKind ::
     Projection.ProfileEvidence profile document firstKind
  -> Projection.ProfileEvidence profile document secondKind
coerceEvidenceKind = coerce
