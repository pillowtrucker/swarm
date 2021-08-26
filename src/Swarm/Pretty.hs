{-# LANGUAGE OverloadedStrings #-}

module Swarm.Pretty where

import           Data.String               (fromString)
import           Data.Text                 (Text)
import           Prettyprinter
import           Prettyprinter.Render.Text

import           Swarm.AST
import           Swarm.Typecheck
import           Swarm.Types

class PrettyPrec a where
  prettyPrec :: Int -> a -> Doc ann   -- can replace with custom ann type later if desired

ppr :: PrettyPrec a => a -> Doc ann
ppr = prettyPrec 0

renderPretty :: PrettyPrec a => a -> Text
renderPretty = renderStrict . layoutPretty defaultLayoutOptions . ppr

pparens :: Bool -> Doc ann -> Doc ann
pparens True  = parens
pparens False = id

instance PrettyPrec Type where
  prettyPrec _ TyUnit         = "()"
  prettyPrec _ TyInt          = "int"
  prettyPrec _ TyDir          = "dir"
  prettyPrec _ TyString       = "string"
  prettyPrec p (TyCmd ty)     = pparens (p > 1) $ "cmd" <+> prettyPrec 2 ty
  prettyPrec p (ty1 :->: ty2) = pparens (p > 0) $
    prettyPrec 1 ty1 <+> "->" <+> prettyPrec 0 ty2

instance PrettyPrec Direction where
  prettyPrec _ Lt    = "left"
  prettyPrec _ Rt    = "right"
  prettyPrec _ Back  = "back"
  prettyPrec _ Fwd   = "forward"
  prettyPrec _ North = "north"
  prettyPrec _ South = "south"
  prettyPrec _ East  = "east"
  prettyPrec _ West  = "west"

instance PrettyPrec Const where
  prettyPrec _ Wait    = "wait"
  prettyPrec _ Move    = "move"
  prettyPrec _ Turn    = "turn"
  prettyPrec _ Harvest = "harvest"
  prettyPrec _ Repeat  = "repeat"
  prettyPrec _ Build   = "build"
  prettyPrec _ Run     = "run"

instance PrettyPrec Term where
  prettyPrec _ TUnit         = "()"
  prettyPrec _ (TConst c)    = ppr c
  prettyPrec _ (TDir d)      = ppr d
  prettyPrec _ (TInt n)      = pretty n
  prettyPrec _ (TString s)   = fromString (show s)
  prettyPrec _ (TVar s)      = pretty s
  prettyPrec _ (TLam x mty body) =
    "\\" <> pretty x <> maybe "" ((":" <>) . ppr) mty <> "." <+> ppr body
  prettyPrec p (TApp t1 t2)  = pparens (p > 10) $
    prettyPrec 10 t1 <+> prettyPrec 11 t2
  prettyPrec _ (TLet x mty t1 t2) =
    sep $
      ["let", pretty x] ++
      maybe [] (\ty -> [":", ppr ty]) mty ++
      ["=", ppr t1, "in", ppr t2]
  prettyPrec p (TBind Nothing t1 t2) = pparens (p > 0) $
    prettyPrec 1 t1 <> ";" <+> prettyPrec 0 t2
  prettyPrec p (TBind (Just x) t1 t2) = pparens (p > 0) $
    pretty x <+> "<-" <+> prettyPrec 1 t1  <> ";" <+> prettyPrec 0 t2
  prettyPrec _ TNop          = braces emptyDoc

instance PrettyPrec TypeErr where
  prettyPrec _ (NotFunTy t ty) =
    sep
    [ "Expecting a function type, but"
    , ppr t
    , "has type"
    , ppr ty
    , "instead."
    ]
  prettyPrec _ (NotCmdTy t ty) =
    sep
    [ "Expecting a command type, but"
    , ppr t
    , "has type"
    , ppr ty
    , "instead."
    ]
  prettyPrec _ (Mismatch t expected inferred) =
    vsep $
      [ "Type mismatch when checking expression" <+> squotes (ppr t)
      , "Expected type:" <+> ppr expected
      , "Actual type:" <+> ppr inferred
      ]
  prettyPrec _ (UnboundVar x) =
    "Unbound variable" <+> pretty x
  prettyPrec _ (CantInfer t) =
    "Can't infer the type of" <+> ppr t
