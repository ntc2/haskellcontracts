module Translation where

import Debug.Trace

import qualified Haskell as H
import qualified FOL as F
import Control.Monad.State
import Data.Char (toUpper)
import Data.Maybe (fromJust)
import Data.List (sort,partition)
-- Type signatures:
-- eTrans :: H.Expression -> Fresh F.Term
-- dTrans :: H.Definition -> Fresh F.Formula
-- sTrans :: H.Expression -> H.Contract -> Fresh F.Formula
-- tTrans :: H.DataType -> Fresh [F.Formula]
-- trans  :: [H.DefGeneral] -> [F.Formula (F.Term F.Variable)]

type Fresh = State (String,Int,[F.Formula (F.Term F.Variable)])



-- Expression
-------------

eTrans :: H.Expression -> Fresh (F.Term F.Variable)
eTrans (H.Var v) = return $ (F.Var $ F.Regular v)
eTrans (H.Fun f) = return $ (F.Var $ F.Regular f)
eTrans (H.App e1 e2) = do 
  t1 <- eTrans e1
  t2 <- eTrans e2 
  return $ F.App [t1,t2] -- TODO modifier H.App
eTrans H.BAD = return $ F.Var $ F.BAD
eTrans (H.Con d) = return $ F.Var $ F.Regular d
eTrans (H.Sat e c) = do 
  ts <- sTrans (H.Var "x") c
  te <- eTrans $ H.App (H.Var "satC") (H.Var "x")
  let fe = F.Forall [F.Var $ F.Regular "x"] $ F.Iff ts $ F.Eq (F.Var $ F.Regular "true") te
  modify (\(a,b,c) ->(a,b,fe:c))
  eTrans e


-- A little helper function for later
eTransfxi f vs = eTrans $ H.apps (H.Fun f:map H.Var vs)



-- Definition
-------------

dTrans :: H.Definition -> Fresh (F.Formula (F.Term F.Variable))
dTrans (H.Let f vs e) = do
  et <- eTrans e                      
  ft <- eTrans $ H.Var f
  return $ F.Forall vvs $ F.Eq (F.App (ft:vvs)) (F.Weak $ et)
  where vvs = map (F.Var . F.Regular) vs

dTrans (H.LetCase f vs e pes) = do
  et <- eTrans e
  ft <- eTrans $ H.Var f
  let zedify ei pi = foldl (\e (v,z) -> H.subst e (H.Var $ extractVR z) (v)) ei (take (length (tail pi)) $ zip (tail pi) zs)
      extractVR (F.Var (F.Regular v)) = v 
      arities = map (\p -> (head p, length $ tail p)) $ map fst pes :: [(String,Int)]
      zs = [F.Var $ F.Regular $ "Zdef" ++ show x | x <- [1..(foldl1 max [snd y | y <- arities])]]
  tpieis <- sequence [eTrans (zedify ei pi) | (pi,ei) <- pes]
  let vvs = map (F.Var . F.Regular) vs
      eq9 = [(et `F.Eq` (F.App ((F.Var $ F.Regular $ head pi):(take (length pi - 1) [ z | (v,z) <- zip (tail pi) zs ])))) `F.Implies` (F.App (ft:vvs) `F.Eq` (F.Weak $ tpiei)) | ((pi,ei),tpiei) <- zip pes tpieis]
      eq10 = (et `F.Eq` (F.Var F.BAD)) `F.Implies` (F.App (ft:vvs) `F.Eq` F.Var F.BAD)
      eq11 = (F.And $ (F.Not $ et `F.Eq` F.Var F.BAD):bigAndSel ) `F.Implies` eq12
      eq12 = (F.App (ft:vvs) `F.Eq` F.Var F.UNR)
      bigAndSel = [F.Not $ et `F.Eq` F.Weak (F.App ((F.Var (F.Regular di)):[F.App [(F.Var . F.Regular) ("sel_"++(show i)++"_"++di),et] | i <- [1..ai]])) | (di,ai) <- arities] 
  return $ F.Forall (vvs ++ zs) $ F.And (eq9++[eq10,eq11])

test = (H.LetCase "head" ["xyz"] (H.Var "xyz") [(["nil"],H.BAD),(["cons","a","b"],H.Var "a")])
-- t = putStrLn $ (trans test) >>= (F.simplify) >>= F.toTPTP


-- Contract satisfaction
------------------------

sTrans :: H.Expression -> H.Contract -> Fresh (F.Formula (F.Term F.Variable))
sTrans e H.Any = return F.True

sTrans e (H.Pred x u) =  do
  et <- eTrans e
  ut' <- eTrans u'
  return $ F.Or [(et `F.Eq` F.Var F.UNR) ,F.And [F.CF $ et ,(F.Not $ F.Eq (F.Var F.BAD) $ ut') , F.Not $ ut' `F.Eq` (F.Var $ F.Regular "false")]] -- The data constructor False.
  where u' = H.subst u e x

sTrans e (H.AppC x c1 c2) = do
  (s,k,fs) <- get
  put (s,k+1,fs)
  let freshX = s++(show k) 
      c2' = H.substC c2 (H.Var freshX) x
  f1 <- sTrans (H.Var freshX) c1
  f2 <- sTrans (H.App e (H.Var freshX)) c2'
  return $ F.Forall [F.Var $ F.Regular $ freshX] (f1 `F.Implies` f2)





-- Data constructors
--------------------

tTrans :: H.DataType -> Fresh [F.Formula (F.Term F.Variable)]
tTrans d = liftM5 (+++++) (s1 d) (s2 d) (s3 d) (s4 d) (s5 d)
  where (+++++) a b c d e = a ++ b ++ c ++ d ++ e

s1 :: H.DataType -> Fresh [F.Formula (F.Term F.Variable)]
s1 (H.Data _ dns) = sequence $ map s1D dns

-- It's the set S1 but for only one data constructor
s1D :: (String,Int,H.Contract) -> Fresh (F.Formula (F.Term F.Variable))
s1D (d,a,c) = do
  (s,k,fs) <- get
  put (s,k+1,fs)
  let xs = map (\n -> s++"_"++(show n)) [1..a]
  return $ F.Forall (map (F.Var . F.Regular) xs) $ F.And [F.Eq (F.Var $ F.Regular x) $ F.App [(F.Var $ F.Regular ("sel_"++(show k)++"_"++d)) , F.App $ (F.Var $ F.Regular d) : map (F.Var . F.Regular) xs] | (x,k) <- zip xs [1..a]]


s2 :: H.DataType -> Fresh [F.Formula (F.Term F.Variable)]
s2 (H.Data _ dns) = sequence $ map s2D [(a,b) | a <- dns, b <- dns, a < b]

-- It's S2 for a pair of data constructors.
s2D :: ((String,Int,H.Contract),(String,Int,H.Contract)) -> Fresh (F.Formula (F.Term F.Variable))
s2D ((d1,a1,c1),(d2,a2,c2)) = do
  (s,k,fs) <- get
  put (s,k+2,fs)
  let xs1 = map (\n -> s++(show k)++"_"++(show n)) [1..a1]
      xs2 = map (\n -> s++(show $ k + 1)++"_"++(show n)) [1..a2]
  return $ F.Forall (map (F.Var . F.Regular) (xs1 ++ xs2)) $ F.Not $ F.Eq (F.App $ (F.Var . F.Regular) d1 : map (F.Var . F.Regular) xs1) (F.App $ (F.Var . F.Regular) d2 : map (F.Var . F.Regular) xs2)


s3 :: H.DataType -> Fresh [F.Formula (F.Term F.Variable)]
s3 (H.Data _ dns) = sequence $ map s3D dns

-- It's S3 but only for one data constructor
s3D :: (String,Int,H.Contract) -> Fresh (F.Formula (F.Term F.Variable))
s3D (d,a,c) = do
  (s,k,fs) <- get
  put (s,k+1,fs)
  let xs = map (\n -> s++(show k)++"_"++(show n)) [1..a]
  if xs /= [] 
    then (return $ F.Forall (map (F.Var . F.Regular) xs) $ F.Iff (F.CF $ F.App $ (F.Var . F.Regular) d : map (F.Var . F.Regular) xs) (F.And [F.CF (F.Var $ F.Regular x) | x <- xs]))
    else return $ F.CF $ F.App [F.Var $ F.Regular d]

s4 :: H.DataType -> Fresh [F.Formula (F.Term F.Variable)]
s4 (H.Data _ dns) = sequence $ map s4D dns

s4D :: (String,Int,H.Contract) -> Fresh (F.Formula (F.Term F.Variable))
s4D (d,a,c) = do
  (s,k,fs) <- get
  put (s,k+1,fs) 
  let xs = map (\n -> s++(show k)++"_"++(show n)) [1..a]
  et <- eTrans $ H.apps $ H.Var d : (map H.Var xs)
  if xs /= [] 
    then (return $ F.Forall (map (F.Var . F.Regular) xs) $ F.Not (et `F.Eq` (F.Var F.UNR)))
    else return $ F.Not ((F.Var $ F.Regular d) `F.Eq` F.Var F.UNR)

s5 :: H.DataType -> Fresh [F.Formula (F.Term F.Variable)]
s5 (H.Data _ dns) = sequence $ map s5D dns

s5D :: (String,Int,H.Contract) -> Fresh (F.Formula (F.Term F.Variable))
s5D (d,a,c) = do
  (s,k,fs) <- get
  put (s,k+1,fs)
  let xs = map (\n -> s++(show k)++"_"++(show n)) [1..a]
      cs = H.toList c
      dapp = H.apps [H.Var x | x <- d:xs]
  sxs <- sequence $ [sTrans (H.Var xi) ci | (xi,ci) <- zip xs cs]
  st <- sTrans dapp c
  return $ F.Forall (map (F.Var . F.Regular) xs) $ F.Iff st (F.And sxs)







-- Final translation
--------------------

trans :: [H.DefGeneral] -> String -> [F.Formula (F.Term F.Variable)]
trans ds fcheck = aux fcheck ds

isContToCheck fcheck (H.ContSat (H.Satisfies v c)) = v==fcheck
isContToCheck _ _ = False


aux fcheck ds = map F.Not [evalState (sTrans (H.Var v) c) ("Z",0,[])] ++ [evalState (sTrans (H.Var v') c) ("Zp",0,[])] ++ concatMap treat ds' ++ footer
  where ([H.ContSat (H.Satisfies v c)],ds') = partition (isContToCheck fcheck) ds
        treat (H.DataType t) = evalState (tTrans t) ("D",0,[])
        treat (H.Def d@(H.Let x xs e)) = [if x == v then evalState (dTrans $ H.Let x xs (H.subst e (H.Var v') x)) ("O",0,[]) else evalState (dTrans d) ("P",0,[])] ++ (
                                         if x == v then [evalState (dTrans $ H.Let v' xs (H.subst e (H.Var v') x)) ("O",0,[])] else [])
        treat (H.Def d@(H.LetCase x xs e pes)) = [if x == v then evalState (dTrans $ H.LetCase x xs (H.subst e (H.Var v') x) (map (\(p,e) -> (p,H.subst e (H.Var v') x)) pes)) ("O",0,[]) else evalState (dTrans d) ("P",0,[])] ++ (
                                                 if x == v then [evalState (dTrans $ H.LetCase v' xs (H.subst e (H.Var v') x) (map (\(p,e) -> (p,H.subst e (H.Var v') x)) pes)) ("O",0,[])] else [])
        treat (H.ContSat (H.Satisfies x y)) = [evalState (sTrans (H.Var x) y) ("Y",0,[])]
        v' = v++"p"
        footer = [(F.Forall (map (F.Var . F.Regular) ["F","X"]) $ (F.And [F.CF $ F.Var $ F.Regular "X", F.CF $ F.Var $ F.Regular "F"]) `F.Implies` (F.CF $ (F.App [(F.Var $ F.Regular "F"), (F.Var $ F.Regular "X")]))),F.Not $ F.CF $ F.Var $ F.BAD,F.CF $ F.Var $ F.UNR]


-- aux fcheck ds = map F.Not [evalState (sTrans (H.Var v) c) ("Z",0)] ++ [evalState (sTrans (H.Var v') c) ("Zp",0)] ++ concatMap treat ds' ++ footer
--   where ([H.ContSat (H.Satisfies v c)],ds') = partition (isContToCheck fcheck) ds
--         treat (H.DataType t) = evalState (tTrans t) ("D",0)
--         treat (H.Def d@(H.Let x xs e)) = [if x == v then dTrans $ H.Let x xs (H.subst e (H.Var v') x) else dTrans d]
--         treat (H.Def d@(H.LetCase x xs e pes)) = [if x == v then dTrans $ H.LetCase x xs (H.subst e (H.Var v') x) (map (\(p,e) -> (p,H.subst e (H.Var v') x)) pes) else dTrans d]
--         treat (H.ContSat (H.Satisfies x y)) = [evalState (sTrans (H.Var x) y) ("Y",0)]
--         v' = v++"p"
--         footer = [(F.Forall (map (F.Var . F.Regular) ["F","X"]) $ (F.And [F.CF $ F.Var $ F.Regular "X", F.CF $ F.Var $ F.Regular "F"]) `F.Implies` (F.CF $ (F.App [(F.Var $ F.Regular "F"), (F.Var $ F.Regular "X")]))),F.Not $ F.CF $ F.Var $ F.BAD,F.CF $ F.Var $ F.UNR]



-- okFromd :: H.Definition -> H.Contract
-- okFromd (H.Let _ vs _) = foldl (\c _ -> H.AppC "dummy" c H.ok) H.ok vs
