-- | Executed package-external observation of the complete report envelope.
module OperationReportPublicObserver
  ( ObservedSchemaAuthority(..)
  , ObservedReportOperation(..)
  , ObservedToolDescriptor(..)
  , ObservedReportContract(..)
  , ObservedReportAuthority(..)
  , ObservedReportEnvelope(..)
  , observeReportEnvelope
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Operation.Adapter (adapterIdText)
import O2I.Operation.Machine (foldToolDescriptor)
import O2I.Operation.Report
  ( ReportContract
  , ReportEnvelope
  , foldReportAuthority
  , foldReportContract
  , foldReportEnvelope
  , foldReportOperation
  )
import O2I.Operation.Schema
  ( foldSchemaAuthority
  , schemaDigestText
  , schemaIdentityText
  , schemaVariantText
  , schemaVersionValue
  )

-- | Exact Schema authority observed through public projections.
data ObservedSchemaAuthority =
  ObservedSchemaAuthority Text Natural Text
  deriving (Eq, Show)

-- | The sole closed seven-operation identity observed through its public fold.
data ObservedReportOperation
  = ObservedViewsReportOperation
  | ObservedQualificationSubjectsReportOperation
  | ObservedValidateReportOperation
  | ObservedTraceReportOperation
  | ObservedQualifyReportOperation
  | ObservedReadinessReportOperation
  | ObservedAssessReportOperation
  deriving (Eq, Show)

-- | Exact composition metadata observed through its public fold.
data ObservedToolDescriptor =
  ObservedToolDescriptor Text Text
  deriving (Eq, Show)

-- | Every closed contract-authority arm with all exact fields.
data ObservedReportContract
  = ObservedOperationReportContract Text Text Text
  | ObservedAdapterReportContract
  | ObservedProfileReportContract
  | ObservedCoreReportContract Text Text Text
  deriving (Eq, Show)

-- | Both report-authority shapes with original non-empty cardinality.
data ObservedReportAuthority
  = ObservedViewReportAuthority Text
  | ObservedPreparedReportAuthority (NonEmpty ObservedReportContract)
  deriving (Eq, Show)

-- | Every field of one indivisible public report envelope.
data ObservedReportEnvelope =
  ObservedReportEnvelope
    ObservedSchemaAuthority
    Text
    ObservedReportOperation
    ObservedToolDescriptor
    ObservedReportAuthority
  deriving (Eq, Show)

-- | Observe every field through public Operation folds only.
observeReportEnvelope :: ReportEnvelope -> ObservedReportEnvelope
observeReportEnvelope =
  foldReportEnvelope $ \schema variant operation tool authority ->
    ObservedReportEnvelope
      (foldSchemaAuthority
         (\identity version digest ->
            ObservedSchemaAuthority
              (schemaIdentityText identity)
              (schemaVersionValue version)
              (schemaDigestText digest))
         schema)
      (schemaVariantText variant)
      (foldReportOperation
         ObservedViewsReportOperation
         ObservedQualificationSubjectsReportOperation
         ObservedValidateReportOperation
         ObservedTraceReportOperation
         ObservedQualifyReportOperation
         ObservedReadinessReportOperation
         ObservedAssessReportOperation
         operation)
      (foldToolDescriptor ObservedToolDescriptor tool)
      (foldReportAuthority
         (ObservedViewReportAuthority . adapterIdText)
         (ObservedPreparedReportAuthority . fmap observeReportContract)
         authority)

observeReportContract :: ReportContract -> ObservedReportContract
observeReportContract =
  foldReportContract
    ObservedOperationReportContract
    ObservedAdapterReportContract
    ObservedProfileReportContract
    ObservedCoreReportContract
