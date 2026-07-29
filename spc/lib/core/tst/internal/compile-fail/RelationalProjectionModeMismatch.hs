{-# LANGUAGE DataKinds #-}

module RelationalProjectionModeMismatch where

import Data.List.NonEmpty (NonEmpty)
import O2I.Validation.Relational.Internal

invalidCrossModeComposition ::
     Projection
       'EndpointOccurrenceProjection
       scope
       shape
       (NonEmpty ProjectedPremise)
  -> Premise (PremiseKey scope token) from to
  -> Projection
       'ErasedPremiseProjection
       scope
       ('SnocPremise shape token from to)
       (NonEmpty ProjectedPremise)
invalidCrossModeComposition = appendProjectedPremise
