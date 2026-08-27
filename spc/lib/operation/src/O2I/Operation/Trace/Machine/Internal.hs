{-# LANGUAGE OverloadedStrings #-}

-- | Private canonical projection of opaque Core Trace results.
module O2I.Operation.Trace.Machine.Internal
  ( traceAssessmentFragment
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Identity
  ( ModelIdentity
  , OccurrenceIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , CanonicalMember
  , arrayFragment
  , closedObjectFragment
  , requiredMember
  , textFragment
  )
import qualified O2I.Trace as Trace

-- | Project one Core-owned Trace result without exposing a generic encoder.
traceAssessmentFragment :: Trace.TraceAssessment scope -> CanonicalFragment
traceAssessmentFragment assessment =
  case Trace.traceRootTraces assessment of
    [] ->
      closedObjectFragment
        [ requiredMember "kind" (textFragment "no-asserted-root")
        , requiredMember
            "graphIdentity"
            (modelIdentityFragment
               (Trace.traceAssessmentGraphIdentity assessment))
        , requiredMember "disposition" (textFragment "rejected")
        ]
    roots ->
      closedObjectFragment
        [ requiredMember "kind" (textFragment "root-traces")
        , requiredMember
            "graphIdentity"
            (modelIdentityFragment
               (Trace.traceAssessmentGraphIdentity assessment))
        , requiredMember
            "disposition"
            (textFragment
               (if all rootComplete roots
                  then "accepted"
                  else "rejected"))
        , requiredMember "roots" (arrayFragment (map rootFragment roots))
        ]

rootComplete :: Trace.RootTrace scope -> Bool
rootComplete root = Trace.rootTraceDisposition root == Trace.RootTraceComplete

rootFragment :: Trace.RootTrace scope -> CanonicalFragment
rootFragment root =
  closedObjectFragment
    [ requiredMember
        "graphIdentity"
        (modelIdentityFragment (Trace.rootTraceGraphIdentity root))
    , requiredMember
        "intervention"
        (modelIdentityFragment (Trace.rootTraceIntervention root))
    , requiredMember "need" (modelIdentityFragment (Trace.rootTraceNeed root))
    , requiredMember
        "rootSupport"
        (occurrenceArray (NonEmpty.toList (Trace.rootTraceSupport root)))
    , requiredMember
        "result"
        (Trace.foldRootTrace completeFragment partialFragment root)
    ]

completeFragment :: Trace.CompleteWitness scope -> CanonicalFragment
completeFragment witness =
  closedObjectFragment
    [ requiredMember "kind" (textFragment "complete-witness")
    , requiredMember
        "identity"
        (traceIdentityFragment (Trace.completeTraceIdentity witness))
    , requiredMember
        "relationSupport"
        (supportArray (Trace.completeRelationSupport witness))
    , requiredMember
        "ownershipSupport"
        (supportArray (Trace.completeOwnershipSupport witness))
    ]

partialFragment :: Trace.PartialTrace scope -> CanonicalFragment
partialFragment partial =
  closedObjectFragment
    [ requiredMember "kind" (textFragment "partial-trace")
    , requiredMember
        "variableProjections"
        (arrayFragment
           (map projectionFragment (Trace.partialVariableProjections partial)))
    , requiredMember
        "relationSupport"
        (supportArray (Trace.partialRelationSupport partial))
    , requiredMember
        "ownershipSupport"
        (supportArray (Trace.partialOwnershipSupport partial))
    , requiredMember
        "gaps"
        (arrayFragment
           (map gapFragment (NonEmpty.toList (Trace.partialGaps partial))))
    ]

traceIdentityFragment :: Trace.TraceIdentity -> CanonicalFragment
traceIdentityFragment identity =
  closedObjectFragment
    [ requiredMember
        "graphIdentity"
        (modelIdentityFragment (Trace.traceIdentityGraphIdentity identity))
    , requiredMember
        "bindings"
        (arrayFragment
           (map bindingFragment (Trace.traceIdentityBindings identity)))
    ]

bindingFragment :: (Trace.TraceVariable, ModelIdentity) -> CanonicalFragment
bindingFragment (variable, identity) =
  closedObjectFragment
    [ requiredMember "variable" (textFragment (Trace.traceVariableId variable))
    , requiredMember "identity" (modelIdentityFragment identity)
    ]

projectionFragment :: Trace.TraceVariableProjection -> CanonicalFragment
projectionFragment projection =
  closedObjectFragment
    [ requiredMember
        "variable"
        (textFragment
           (Trace.traceVariableId (Trace.traceProjectionVariable projection)))
    , requiredMember
        "identities"
        (modelIdentityArray (Trace.traceProjectionValues projection))
    ]

supportArray :: [Trace.TraceSlotSupport] -> CanonicalFragment
supportArray = arrayFragment . map supportFragment

supportFragment :: Trace.TraceSlotSupport -> CanonicalFragment
supportFragment support =
  closedObjectFragment
    (slotMembers (Trace.traceSupportSlot support)
       <> [ requiredMember
              "occurrences"
              (occurrenceArray (Trace.traceSupportOccurrences support))
          ])

gapFragment :: Trace.TraceGap -> CanonicalFragment
gapFragment =
  Trace.foldTraceGap
    (\slot endpoints disposition ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "bound-slot")
         , requiredMember "slot" (slotFragment slot)
         , requiredMember "disposition" (gapDispositionFragment disposition)
         , requiredMember "endpoints" (boundEndpointsFragment endpoints)
         ])
    (\slot established unresolved disposition ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "unbound-slot")
         , requiredMember "slot" (slotFragment slot)
         , requiredMember "disposition" (gapDispositionFragment disposition)
         , requiredMember
             "establishedBindings"
             (arrayFragment (map bindingFragment established))
         , requiredMember
             "unresolvedVariables"
             (arrayFragment
                (map
                   (textFragment . Trace.traceVariableId)
                   (NonEmpty.toList unresolved)))
         ])
    (\slots disposition ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "global-consistency-obstruction")
         , requiredMember "disposition" (gapDispositionFragment disposition)
         , requiredMember
             "slots"
             (arrayFragment (map slotFragment (NonEmpty.toList slots)))
         ])

boundEndpointsFragment :: Trace.TraceBoundEndpoints -> CanonicalFragment
boundEndpointsFragment endpoints =
  arrayFragment
    [ bindingFragment
        ( Trace.traceBoundSourceVariable endpoints
        , Trace.traceBoundSourceIdentity endpoints)
    , bindingFragment
        ( Trace.traceBoundTargetVariable endpoints
        , Trace.traceBoundTargetIdentity endpoints)
    ]

slotFragment :: Trace.TraceSlot -> CanonicalFragment
slotFragment = closedObjectFragment . slotMembers

slotMembers :: Trace.TraceSlot -> [CanonicalMember]
slotMembers slot =
  [ requiredMember "slotKind" (textFragment (slotKindText slot))
  , requiredMember "slotId" (textFragment (Trace.traceSlotId slot))
  , requiredMember
      "ruleId"
      (textFragment (coreRuleIdText (Trace.traceSlotRuleId slot)))
  ]

slotKindText :: Trace.TraceSlot -> Text
slotKindText slot =
  case slot of
    Trace.RelationTraceSlot _ -> "relation"
    Trace.OwnershipTraceSlot _ -> "ownership"

gapDispositionFragment :: Trace.TraceGapDisposition -> CanonicalFragment
gapDispositionFragment disposition =
  textFragment
    $ case disposition of
        Trace.MissingSupport -> "missing-support"
        Trace.CandidateOnlySupport -> "candidate-only"
        Trace.GloballyInconsistentSupport -> "globally-inconsistent"

modelIdentityArray :: [ModelIdentity] -> CanonicalFragment
modelIdentityArray = arrayFragment . map modelIdentityFragment

modelIdentityFragment :: ModelIdentity -> CanonicalFragment
modelIdentityFragment = textFragment . modelIdentityText

occurrenceArray :: [OccurrenceIdentity] -> CanonicalFragment
occurrenceArray = arrayFragment . map (textFragment . occurrenceIdentityText)
