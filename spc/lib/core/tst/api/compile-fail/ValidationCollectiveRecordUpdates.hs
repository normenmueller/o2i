module ValidationCollectiveRecordUpdates where

import qualified O2I.Validation as Validation

rewriteCollectiveStrategyRealization ::
     Validation.CollectiveStrategyRealization
  -> Validation.CollectiveStrategyRealization
rewriteCollectiveStrategyRealization realization =
  realization
    { Validation.collectiveRealizationId =
        Validation.collectiveRealizationId realization
    }

rewriteCandidateCollectiveStrategyRealization ::
     Validation.CandidateCollectiveStrategyRealization
  -> Validation.CandidateCollectiveStrategyRealization
rewriteCandidateCollectiveStrategyRealization candidate =
  candidate
    { Validation.candidateCollectiveClaim =
        Validation.candidateCollectiveClaim candidate
    }

rewriteCollectiveStrategyRealizationAssessment ::
     Validation.CollectiveStrategyRealizationAssessment
  -> Validation.CollectiveStrategyRealizationAssessment
rewriteCollectiveStrategyRealizationAssessment assessment =
  assessment
    { Validation.collectiveStrategyRealizations =
        Validation.collectiveStrategyRealizations assessment
    }
