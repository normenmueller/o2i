-- | View-scoped semantic dependency closure.
module O2I.Inspection.Scope
  ( ClosedScopeSummary(..)
  , ScopeDefect(..)
  , ScopeIssue(..)
  , ScopeResult(..)
  , SemanticallyClosedScope
  , scopeDefectSpec
  , closeScope
  ) where

import O2I.Inspection.Scope.Internal
