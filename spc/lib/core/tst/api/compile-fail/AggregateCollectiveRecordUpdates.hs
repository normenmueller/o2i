module AggregateCollectiveRecordUpdates where

import qualified O2I

rewriteCollectiveStrategyRealization ::
     O2I.CollectiveStrategyRealization -> O2I.CollectiveStrategyRealization
rewriteCollectiveStrategyRealization realization =
  realization
    {O2I.collectiveRealizationId = O2I.collectiveRealizationId realization}

rewriteCandidateCollectiveStrategyRealization ::
     O2I.CandidateCollectiveStrategyRealization
  -> O2I.CandidateCollectiveStrategyRealization
rewriteCandidateCollectiveStrategyRealization candidate =
  candidate
    {O2I.candidateCollectiveClaim = O2I.candidateCollectiveClaim candidate}

rewriteCollectiveStrategyRealizationAssessment ::
     O2I.CollectiveStrategyRealizationAssessment
  -> O2I.CollectiveStrategyRealizationAssessment
rewriteCollectiveStrategyRealizationAssessment assessment =
  assessment
    { O2I.collectiveStrategyRealizations =
        O2I.collectiveStrategyRealizations assessment
    }
