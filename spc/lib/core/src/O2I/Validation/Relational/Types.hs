-- | Safe authoring surface for private typed relational rules.
--
-- Rule authors can declare typed domains, receive abstract variable and
-- premise handles from the constructive DSL, compile connected plans, and
-- combine total projections. Executor state, matched occurrences, plan
-- destruction, and occurrence construction remain outside this module.
module O2I.Validation.Relational.Types
  ( Domain
  , emptyDomain
  , singletonDomain
  , domainFromList
  , domainInsert
  , domainToAscList
  , domainSize
  , domainMember
  , Bound
  , Premise
  , ProjectedPremise
  , projectedPremiseOrdinal
  , projectedPremiseEdge
  , projectedPremiseRawFrom
  , projectedPremiseRelationCode
  , projectedPremiseRelationName
  , projectedPremiseRawTo
  , Projection
  , projectPremise
  , appendProjectedPremise
  , Plan
  , CompiledPlan
  , rootAtom
  , extendForward
  , extendBackward
  , constrainExisting
  , finish
  ) where

import O2I.Validation.Relational.Internal
