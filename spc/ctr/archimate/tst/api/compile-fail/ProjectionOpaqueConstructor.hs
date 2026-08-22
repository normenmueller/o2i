module ProjectionOpaqueConstructor where

import qualified O2I.ArchiMate.Profile.Projection as Projection

forgedProjection :: Projection.ProfileProjection profile document
forgedProjection = Projection.ProfileProjection undefined

forgedAssessment :: Projection.ProfileProjectionAssessment profile document
forgedAssessment = Projection.ProfileProjectionAssessment undefined

forgedEvidence :: Projection.ProfileDiagnosticEvidence profile document
forgedEvidence = Projection.ProfileDiagnosticEvidence undefined
