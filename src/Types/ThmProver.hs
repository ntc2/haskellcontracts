{-# LANGUAGE DeriveDataTypeable, NamedFieldPuns #-}

-- Types used in the ThmProver module.  Moved here to avoid cyclic
-- dependencies.
module Types.ThmProver where

import Data.Typeable
import Data.Data

import Types.Haskell as H
import Types.FOL as F

data CaseQs = Project | Quantify | Hybrid
              deriving (Show, Data, Typeable, Bounded, Enum, Eq)

data Conf = Conf { keep_tmps    :: Bool
                 , only_check   :: [String] 
                 , dry_run      :: Bool 
                 , engine       :: ThmProver
                 , idirs        :: [FilePath] -- "Include" directories
                 , file         :: FilePath

                 , ghci         :: Bool
                 , type_check   :: Bool

                 , no_min       :: Bool
                 , no_ptr       :: Bool
                 , case_qs      :: CaseQs
                 , case_implies :: Bool
                 , unrolls      :: Int
                 } deriving (Show, Data, Typeable)

data ThmProverConf = ThmProverConf
  { path   :: FilePath
  , opts   :: [String]
  , unsat  :: String -> Bool
  , theory :: Theory
  }

data Theory = Theory
  { showFormula   :: [F.LabeledFormula] -> String
  , header        :: Conf -> [H.TopLevelStatement] -> String
  , fileExtension :: String
  , footer        :: String
  }

data ThmProver
  = Equinox
  | SPASS
  | Vampire32
  | Vampire64
  | E
  | Z3
  | Coq
  deriving (Show, Data, Typeable, Bounded, Enum, Eq)
