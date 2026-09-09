module ProjectionOpaqueConstructor where

import qualified O2I.ArchiMate.Profile.Projection as Projection

forgedProjection :: Projection.ProfileProjection profile document
forgedProjection = Projection.ProfileProjection undefined

forgedAssessment :: Projection.ProfileProjectionAssessment profile document
forgedAssessment = Projection.ProfileProjectionAssessment undefined

forgedEvidence :: Projection.ProfileDiagnosticEvidence profile document
forgedEvidence = Projection.ProfileDiagnosticEvidence undefined

forgedContractEvidence :: Projection.ProfileContractEvidence profile document
forgedContractEvidence = Projection.ProfileContractEvidence undefined

forgedClassificationEvidence ::
     Projection.ProfileClassificationEvidence profile document
forgedClassificationEvidence =
  Projection.ProfileClassificationEvidence undefined

forgedMappingProvenance :: Projection.ProfileMappingProvenance profile document
forgedMappingProvenance = Projection.ProfileMappingProvenance undefined

forgedInvariantEvidence :: Projection.ProfileInvariantEvidence profile document
forgedInvariantEvidence = Projection.ProfileInvariantEvidence undefined

forgedProfileEvidence :: Projection.ProfileEvidence profile document kind
forgedProfileEvidence = Projection.ProfileEvidence undefined
