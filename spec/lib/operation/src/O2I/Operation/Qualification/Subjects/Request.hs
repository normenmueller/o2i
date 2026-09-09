{-# LANGUAGE ExplicitNamespaces #-}

-- | Closed requests for selected-View qualification-subject discovery.
module O2I.Operation.Qualification.Subjects.Request
  ( type QualificationSubjectsRequest
  , qualificationSubjectsRequest
  , qualificationSubjectsModelInput
  , qualificationSubjectsViewSelector
  , qualificationSubjectsAdapterId
  , qualificationSubjectsSupplementalInputs
  , foldQualificationSubjectsRequest
  ) where

import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.Qualification.Subjects.Request.Internal
import O2I.Operation.View (ViewSelector)

-- | Request qualification-subject discovery for one selected View.
qualificationSubjectsRequest ::
     InputSource
  -> ViewSelector
  -> Maybe AdapterId
  -> [InputSource]
  -> QualificationSubjectsRequest
qualificationSubjectsRequest = QualificationSubjectsRequest

-- | Exact physical model source retained by the request.
qualificationSubjectsModelInput :: QualificationSubjectsRequest -> InputSource
qualificationSubjectsModelInput (QualificationSubjectsRequest model _ _ _) =
  model

-- | Exact mandatory View selector retained without normalization.
qualificationSubjectsViewSelector ::
     QualificationSubjectsRequest -> ViewSelector
qualificationSubjectsViewSelector (QualificationSubjectsRequest _ view _ _) =
  view

-- | Optional exact compiled Adapter identifier.
qualificationSubjectsAdapterId ::
     QualificationSubjectsRequest -> Maybe AdapterId
qualificationSubjectsAdapterId (QualificationSubjectsRequest _ _ adapter _) =
  adapter

-- | Exact supplemental sources retained in request order.
qualificationSubjectsSupplementalInputs ::
     QualificationSubjectsRequest -> [InputSource]
qualificationSubjectsSupplementalInputs (QualificationSubjectsRequest _ _ _ supplements) =
  supplements

-- | Consume the complete immutable request without exposing its constructor.
foldQualificationSubjectsRequest ::
     (InputSource -> ViewSelector -> Maybe AdapterId -> [InputSource] -> result)
  -> QualificationSubjectsRequest
  -> result
foldQualificationSubjectsRequest consume (QualificationSubjectsRequest model view adapter supplements) =
  consume model view adapter supplements
