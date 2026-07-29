{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module RelationalOccurrenceOrderMismatch where

import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types

invalidOccurrenceOrder :: CompiledPlan ()
invalidOccurrenceOrder =
  rootAtom
    (singletonDomain (mkNodeId (RawNodeId "strategy")))
    directsIntervention
    (singletonDomain (mkNodeId (RawNodeId "intervention")))
    (\strategy intervention firstPremise ->
       constrainExisting
         strategy
         directsIntervention
         intervention
         (\secondPremise ->
            finish
              (appendOccurrence
                 (projectOccurrence secondPremise (\_ _ -> ()))
                 firstPremise)))
