module SemanticsInternalModule where

import O2I.Semantics.Index

exposeIndex :: SemanticIndex scope -> SemanticIndex scope
exposeIndex = id
