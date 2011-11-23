{-# LANGUAGE DeriveDataTypeable, NamedFieldPuns #-}
module ThmProver where

import Data.Typeable
import Data.Data
import Data.List (isInfixOf)

import Haskell as H
import FOL as F

data ThmProverConf = ThmProverConf
  { path :: FilePath
  , opts :: [String]
  , unsat  :: String -> Bool
  , theory :: Theory
  }

data Theory = Theory
  { showFormula :: F.LabeledFormula -> String
  , header :: [H.DefGeneral] -> String
  , fileExtension :: String
  , footer :: String
  }

fof :: Theory
fof = Theory {
        showFormula = F.toTPTP
      , header = const ""
      , fileExtension = "tptp"
      , footer = ""
      }
smt2 :: Theory
smt2 = Theory {
           showFormula = F.toSMTLIB . unlabel
         , header = F.showDefsSMTLIB
         , fileExtension = "smt2"
         , footer = "(check-sat)"
         }

unlabel (LabeledFormula _ e) = e

data ThmProver
  = Equinox
  | SPASS
  | Vampire32
  | Vampire64
  | E
  | Z3
  deriving (Show, Data, Typeable, Bounded, Enum, Eq)

provers :: [(ThmProver, ThmProverConf)]
provers = [ (Equinox, ThmProverConf
                        "equinox"
                        []
                        ("Unsatisfiable" `isInfixOf`)
                        fof
            )
          , (SPASS, ThmProverConf
                      "SPASS"
                      ["-PProblem=0","-PGiven=0","-TPTP"]
                      ("Proof found" `isInfixOf`)
                      fof
            )
          -- I can't locate any vampire usage docs, and '-h' and
          -- '--help' don't work :P From the CASC competition page I
          -- found that '-t <time>' can be used to time limit vampire.
          -- Experience shows that, by default, vampire has a 60
          -- second time limit.
          , (Vampire32, ThmProverConf
                          "vampire_lin32"
                          ["--mode", "casc" ,"--input_file"]
                          ("SZS status Unsatisfiable" `isInfixOf`)
                          fof
            )
          , (Vampire64, ThmProverConf
                          "vampire_lin64"
                          ["--mode", "casc" ,"--input_file"]
                          ("SZS status Unsatisfiable" `isInfixOf`)
                          fof
            )
          , (E, ThmProverConf
                  "eprover"
                  ["--tstp-format","-s"]
                  ("Unsatisfiable" `isInfixOf`)
                  fof
            )
          , (Z3, ThmProverConf
                   "z3"
                   ["-nw","-smt2"]
                   ("unsat" `isInfixOf`)
                   smt2
            )
          ]
