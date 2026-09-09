{-# LANGUAGE ExplicitNamespaces #-}

-- | Closed common authority carried by every completed Operation report.
--
-- This is the natural seven-operation report contract, not a generic report
-- framework: it has no payload parameter, public constructor, or extension
-- point. Capability modules continue to own their exact report payloads.
module O2I.Operation.Report
  ( type ReportOperation
  , foldReportOperation
  , type ReportContract
  , foldReportContract
  , type ReportAuthority
  , foldReportAuthority
  , type ReportEnvelope
  , foldReportEnvelope
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Report.Internal
import O2I.Operation.Schema
  ( SchemaAuthority
  , SchemaVariant
  , machineSchemaAuthority
  )

-- | Eliminate the exact closed seven-operation vocabulary.
foldReportOperation ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> ReportOperation
  -> result
foldReportOperation views subjects validate trace qualify readiness assess operation =
  case operation of
    ViewsReportOperation -> views
    QualificationSubjectsReportOperation -> subjects
    ValidateReportOperation -> validate
    TraceReportOperation -> trace
    QualifyReportOperation -> qualify
    ReadinessReportOperation -> readiness
    AssessReportOperation -> assess

-- | Eliminate every closed contract-authority shape and all exact fields.
foldReportContract ::
     (Text -> Text -> Text -> result)
  -> result
  -> result
  -> (Text -> Text -> Text -> result)
  -> ReportContract
  -> result
foldReportContract operation adapter profile core contract =
  case contract of
    OperationReportContract identity version digest ->
      operation identity version digest
    AdapterReportContract -> adapter
    ProfileReportContract -> profile
    CoreReportContract identity version digest -> core identity version digest

-- | Eliminate View authority or a non-empty prepared contract chain.
foldReportAuthority ::
     (AdapterId -> result)
  -> (NonEmpty ReportContract -> result)
  -> ReportAuthority
  -> result
foldReportAuthority view prepared authority =
  case authority of
    ViewReportAuthority adapter -> view adapter
    PreparedReportAuthority contracts -> prepared contracts

-- | Consume exact Schema authority, selected variant, operation, tool, and
-- contract authority from one indivisible report envelope.
foldReportEnvelope ::
     (SchemaAuthority -> SchemaVariant -> ReportOperation -> ToolDescriptor -> ReportAuthority -> result)
  -> ReportEnvelope
  -> result
foldReportEnvelope consume (ReportEnvelope schema variant operation tool authority) =
  consume (machineSchemaAuthority schema) variant operation tool authority
