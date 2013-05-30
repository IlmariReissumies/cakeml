(*Generated by Lem from bigStep.lem.*)
open bossLib Theory Parse res_quanTheory
open fixedPointTheory finite_mapTheory listTheory pairTheory pred_setTheory
open integerTheory set_relationTheory sortingTheory stringTheory wordsTheory

val _ = numLib.prefer_num();



open SmallStepTheory SemanticPrimitivesTheory ElabTheory AstTheory TokensTheory LibTheory

val _ = new_theory "BigStep"

(*open Lib*)
(*open Ast*) 
(*open SemanticPrimitives*)

(* To get the definition of expression divergence to use in defining definition
 * divergence *)
(*open SmallStep*)

(* ------------------------ Big step semantics -------------------------- *)
(*val evaluate : envM -> envC -> store -> envE -> exp -> store * result v -> bool*)
(*val evaluate_list : envM -> envC -> store -> envE -> list exp -> store * result (list v) -> bool*)
(*val evaluate_match : envM -> envC -> store -> envE -> v -> list (pat * exp) -> store * result v -> bool*)
(*val evaluate_dec : option modN -> envM -> envC -> store -> envE -> dec -> store * result (envC * envE) -> bool*)
(*val evaluate_decs : option modN -> envM -> envC -> store -> envE -> list dec -> store * result (envC * envE) -> bool*)
(*val evaluate_prog : envM -> envC -> store -> envE -> prog -> store * result (envM * envC * envE) -> bool*)

val _ = Hol_reln `

(! menv cenv env l s.
T
==>
evaluate menv cenv s env (Lit l) (s, Rval (Litv l)))

/\

(! menv cenv env err s.
T
==>
evaluate menv cenv s env (Raise err) (s, Rerr (Rraise err)))

/\

(! menv cenv s1 s2 env e1 e2 v var.
(evaluate menv cenv s1 env e1 (s2, Rval v))
==>
evaluate menv cenv s1 env (Handle e1 var e2) (s2, Rval v))

/\

(! menv cenv s1 s2 env e1 e2 n var bv.
(evaluate menv cenv s1 env e1 (s2, Rerr (Rraise (Int_error n))) /\
evaluate menv cenv s2 (bind var (Litv (IntLit n)) env) e2 bv)
==>
evaluate menv cenv s1 env (Handle e1 var e2) bv)

/\

(! menv cenv s1 s2 env e1 e2 var err.
(evaluate menv cenv s1 env e1 (s2, Rerr err) /\
((err = Rtype_error) \/ (err = Rraise Bind_error) \/ (err = Rraise Div_error)))
==>
evaluate menv cenv s1 env (Handle e1 var e2) (s2, Rerr err))

/\

(! menv cenv env cn es vs s s'.
(
do_con_check cenv cn ( LENGTH es) /\
evaluate_list menv cenv s env es (s', Rval vs))
==>
evaluate menv cenv s env (Con cn es) (s', Rval (Conv cn vs)))

/\

(! menv cenv env cn es s. ( ~  (do_con_check cenv cn ( LENGTH es)))
==>
evaluate menv cenv s env (Con cn es) (s, Rerr Rtype_error))

/\

(! menv cenv env cn es err s s'.
(
do_con_check cenv cn ( LENGTH es) /\
evaluate_list menv cenv s env es (s', Rerr err))
==>
evaluate menv cenv s env (Con cn es) (s', Rerr err))

/\

(! menv cenv env n v s.
(lookup_var_id n menv env = SOME v)
==>
evaluate menv cenv s env (Var n) (s, Rval v))

/\

(! menv cenv env n s.
(lookup_var_id n menv env = NONE)
==>
evaluate menv cenv s env (Var n) (s, Rerr Rtype_error))

/\

(! menv cenv env n e s.
T
==>
evaluate menv cenv s env (Fun n e) (s, Rval (Closure env n e)))

/\

(! menv cenv env uop e v v' s1 s2 s3.
(evaluate menv cenv s1 env e (s2, Rval v) /\
(
do_uapp s2 uop v = SOME (s3,v')))
==>
evaluate menv cenv s1 env (Uapp uop e) (s3, Rval v'))

/\

(! menv cenv env uop e v s1 s2.
(evaluate menv cenv s1 env e (s2, Rval v) /\
(
do_uapp s2 uop v = NONE))
==>
evaluate menv cenv s1 env (Uapp uop e) (s2, Rerr Rtype_error))

/\

(! menv cenv env uop e err s s'.
(evaluate menv cenv s env e (s', Rerr err))
==>
evaluate menv cenv s env (Uapp uop e) (s', Rerr err))

/\

(! menv cenv env op e1 e2 v1 v2 env' e3 bv s1 s2 s3 s4.
(evaluate menv cenv s1 env e1 (s2, Rval v1) /\
evaluate menv cenv s2 env e2 (s3, Rval v2) /\
(
do_app s3 env op v1 v2 = SOME (s4, env', e3)) /\
evaluate menv cenv s4 env' e3 bv)
==>
evaluate menv cenv s1 env (App op e1 e2) bv)

/\

(! menv cenv env op e1 e2 v1 v2 s1 s2 s3.
(evaluate menv cenv s1 env e1 (s2, Rval v1) /\
evaluate menv cenv s2 env e2 (s3, Rval v2) /\
(
do_app s3 env op v1 v2 = NONE))
==>
evaluate menv cenv s1 env (App op e1 e2) (s3, Rerr Rtype_error))

/\

(! menv cenv env op e1 e2 v1 err s1 s2 s3.
(evaluate menv cenv s1 env e1 (s2, Rval v1) /\
evaluate menv cenv s2 env e2 (s3, Rerr err))
==>
evaluate menv cenv s1 env (App op e1 e2) (s3, Rerr err))

/\

(! menv cenv env op e1 e2 err s s'.
(evaluate menv cenv s env e1 (s', Rerr err))
==>
evaluate menv cenv s env (App op e1 e2) (s', Rerr err))

/\

(! menv cenv env op e1 e2 v e' bv s1 s2.
(evaluate menv cenv s1 env e1 (s2, Rval v) /\
(
do_log op v e2 = SOME e') /\
evaluate menv cenv s2 env e' bv)
==>
evaluate menv cenv s1 env (Log op e1 e2) bv)

/\

(! menv cenv env op e1 e2 v s1 s2.
(evaluate menv cenv s1 env e1 (s2, Rval v) /\
(
do_log op v e2 = NONE))
==>
evaluate menv cenv s1 env (Log op e1 e2) (s2, Rerr Rtype_error))

/\

(! menv cenv env op e1 e2 err s s'.
(evaluate menv cenv s env e1 (s', Rerr err))
==>
evaluate menv cenv s env (Log op e1 e2) (s', Rerr err))

/\

(! menv cenv env e1 e2 e3 v e' bv s1 s2.
(evaluate menv cenv s1 env e1 (s2, Rval v) /\
(
do_if v e2 e3 = SOME e') /\
evaluate menv cenv s2 env e' bv)
==>
evaluate menv cenv s1 env (If e1 e2 e3) bv)

/\

(! menv cenv env e1 e2 e3 v s1 s2.
(evaluate menv cenv s1 env e1 (s2, Rval v) /\
(
do_if v e2 e3 = NONE))
==>
evaluate menv cenv s1 env (If e1 e2 e3) (s2, Rerr Rtype_error))

/\

(! menv cenv env e1 e2 e3 err s s'.
(evaluate menv cenv s env e1 (s', Rerr err))
==>
evaluate menv cenv s env (If e1 e2 e3) (s', Rerr err))

/\

(! menv cenv env e pes v bv s1 s2.
(evaluate menv cenv s1 env e (s2, Rval v) /\
evaluate_match menv cenv s2 env v pes bv)
==>
evaluate menv cenv s1 env (Mat e pes) bv)

/\

(! menv cenv env e pes err s s'.
(evaluate menv cenv s env e (s', Rerr err))
==>
evaluate menv cenv s env (Mat e pes) (s', Rerr err))

/\

(! menv cenv env n e1 e2 v bv s1 s2.
(evaluate menv cenv s1 env e1 (s2, Rval v) /\
evaluate menv cenv s2 (bind n v env) e2 bv)
==>
evaluate menv cenv s1 env (Let n e1 e2) bv)

/\

(! menv cenv env n e1 e2 err s s'.
(evaluate menv cenv s env e1 (s', Rerr err))
==>
evaluate menv cenv s env (Let n e1 e2) (s', Rerr err))

/\

(! menv cenv env funs e bv s. ( ALL_DISTINCT ( MAP (\ (x,y,z) . x) funs) /\
evaluate menv cenv s (build_rec_env funs env env) e bv)
==>
evaluate menv cenv s env (Letrec funs e) bv)

/\

(! menv cenv env funs e s. ( ~  ( ALL_DISTINCT ( MAP (\ (x,y,z) . x) funs)))
==>
evaluate menv cenv s env (Letrec funs e) (s, Rerr Rtype_error))

/\

(! menv cenv env s.
T
==>
evaluate_list menv cenv s env [] (s, Rval []))

/\

(! menv cenv env e es v vs s1 s2 s3.
(evaluate menv cenv s1 env e (s2, Rval v) /\
evaluate_list menv cenv s2 env es (s3, Rval vs))
==>
evaluate_list menv cenv s1 env (e ::es) (s3, Rval (v ::vs)))

/\

(! menv cenv env e es err s s'.
(evaluate menv cenv s env e (s', Rerr err))
==>
evaluate_list menv cenv s env (e ::es) (s', Rerr err))

/\

(! menv cenv env e es v err s1 s2 s3.
(evaluate menv cenv s1 env e (s2, Rval v) /\
evaluate_list menv cenv s2 env es (s3, Rerr err))
==>
evaluate_list menv cenv s1 env (e ::es) (s3, Rerr err))

/\

(! menv cenv env v s.
T
==>
evaluate_match menv cenv s env v [] (s, Rerr (Rraise Bind_error)))

/\

(! menv cenv env v p e pes env' bv s. ( ALL_DISTINCT (pat_bindings p []) /\
(pmatch cenv s p v env = Match env') /\
evaluate menv cenv s env' e bv)
==>
evaluate_match menv cenv s env v ((p,e) ::pes) bv)

/\

(! menv cenv env v p e pes bv s. ( ALL_DISTINCT (pat_bindings p []) /\
(pmatch cenv s p v env = No_match) /\
evaluate_match menv cenv s env v pes bv)
==>
evaluate_match menv cenv s env v ((p,e) ::pes) bv)

/\

(! menv cenv env v p e pes s.
(pmatch cenv s p v env = Match_type_error)
==>
evaluate_match menv cenv s env v ((p,e) ::pes) (s, Rerr Rtype_error))

/\

(! menv cenv env v p e pes s. ( ~  ( ALL_DISTINCT (pat_bindings p [])))
==>
evaluate_match menv cenv s env v ((p,e) ::pes) (s, Rerr Rtype_error))`;


val _ = Hol_reln `

(! mn menv cenv env p e v env' s1 s2.
(
evaluate menv cenv s1 env e (s2, Rval v) /\ ALL_DISTINCT (pat_bindings p []) /\
(pmatch cenv s2 p v emp = Match env'))
==>
evaluate_dec mn menv cenv s1 env (Dlet p e) (s2, Rval (emp, env')))

/\

(! mn menv cenv env p e v s1 s2.
(
evaluate menv cenv s1 env e (s2, Rval v) /\ ALL_DISTINCT (pat_bindings p []) /\
(pmatch cenv s2 p v emp = No_match))
==>
evaluate_dec mn menv cenv s1 env (Dlet p e) (s2, Rerr (Rraise Bind_error)))

/\

(! mn menv cenv env p e v s1 s2.
(
evaluate menv cenv s1 env e (s2, Rval v) /\ ALL_DISTINCT (pat_bindings p []) /\
(pmatch cenv s2 p v emp = Match_type_error))
==>
evaluate_dec mn menv cenv s1 env (Dlet p e) (s2, Rerr Rtype_error))

/\

(! mn menv cenv env p e s. ( ~  ( ALL_DISTINCT (pat_bindings p [])))
==>
evaluate_dec mn menv cenv s env (Dlet p e) (s, Rerr Rtype_error))

/\

(! mn menv cenv env p e err s s'.
(
evaluate menv cenv s env e (s', Rerr err) /\ ALL_DISTINCT (pat_bindings p []))
==>
evaluate_dec mn menv cenv s env (Dlet p e) (s', Rerr err))

/\

(! mn menv cenv env funs s. ( ALL_DISTINCT ( MAP (\ (x,y,z) . x) funs))
==>
evaluate_dec mn menv cenv s env (Dletrec funs) (s, Rval (emp, build_rec_env funs env emp)))

/\

(! mn menv cenv env funs s. ( ~  ( ALL_DISTINCT ( MAP (\ (x,y,z) . x) funs)))
==>
evaluate_dec mn menv cenv s env (Dletrec funs) (s, Rerr Rtype_error))

/\

(! mn menv cenv env tds s.
(
check_dup_ctors mn cenv tds)
==>
evaluate_dec mn menv cenv s env (Dtype tds) (s, Rval (build_tdefs mn tds, emp)))

/\

(! mn menv cenv env tds s. ( ~  (check_dup_ctors mn cenv tds))
==>
evaluate_dec mn menv cenv s env (Dtype tds) (s, Rerr Rtype_error))`;

val _ = Hol_reln `

(! mn menv cenv s env.
T
==>
evaluate_decs mn menv cenv s env [] (s, Rval (emp, emp)))

/\

(! mn menv cenv s1 s2 env d ds e.
(
evaluate_dec mn menv cenv s1 env d (s2, Rerr e))
==>
evaluate_decs mn menv cenv s1 env (d ::ds) (s2, Rerr e))

/\

(! mn menv cenv s1 s2 s3 env d ds new_tds new_env r.
(
evaluate_dec mn menv cenv s1 env d (s2, Rval (new_tds,new_env)) /\
evaluate_decs mn menv (merge new_tds cenv) s2 (merge new_env env) ds (s3, r))
==>
evaluate_decs mn menv cenv s1 env (d ::ds) (s3, combine_dec_result new_tds new_env r))`;


val _ = Hol_reln `

(! menv cenv s env.
T
==>
evaluate_prog menv cenv s env [] (s, Rval (emp, emp, emp)))

/\

(! menv cenv s1 s2 s3 env d ds new_tds new_env r.
(
evaluate_dec NONE menv cenv s1 env d (s2, Rval (new_tds,new_env)) /\
evaluate_prog menv (merge new_tds cenv) s2 (merge new_env env) ds (s3, r))
==>
evaluate_prog menv cenv s1 env (Tdec d ::ds) (s3, combine_mod_result emp new_tds new_env r))

/\

(! menv cenv s1 s2 env d ds e.
(
evaluate_dec NONE menv cenv s1 env d (s2, Rerr e))
==>
evaluate_prog menv cenv s1 env (Tdec d ::ds) (s2, Rerr e))

/\

(! menv cenv s1 s2 s3 env ds1 ds2 mn specs new_tds new_env r. ( ~  ( MEM mn ( MAP FST menv)) /\
evaluate_decs (SOME mn) menv cenv s1 env ds1 (s2, Rval (new_tds,new_env)) /\
evaluate_prog (bind mn new_env menv) (merge new_tds cenv) s2 env ds2 (s3, r))
==>
evaluate_prog menv cenv s1 env (Tmod mn specs ds1 ::ds2) (s3, combine_mod_result [(mn,new_env)] new_tds emp r))

/\

(! menv cenv s1 s2 env mn specs ds1 ds2 e. ( ~  ( MEM mn ( MAP FST menv)) /\
evaluate_decs (SOME mn) menv cenv s1 env ds1 (s2, Rerr e))
==>
evaluate_prog menv cenv s1 env (Tmod mn specs ds1 ::ds2) (s2, Rerr e))

/\

(! menv cenv s env mn specs ds1 ds2. ( MEM mn ( MAP FST menv))
==>
evaluate_prog menv cenv s env (Tmod mn specs ds1 ::ds2) (s, Rerr Rtype_error))`;


(*val dec_diverges : envM -> envC -> store -> envE -> dec -> bool*)
(*val decs_diverges : option modN -> envM -> envC -> store -> envE -> decs -> bool*)
(*val prog_diverges : envM -> envC -> store -> envE -> prog -> bool*)

val _ = Define `
 (dec_diverges menv cenv st env d =  
((case d of
      Dlet p e => ALL_DISTINCT (pat_bindings p []) /\ e_diverges menv cenv st env e
    | Dletrec funs => F
    | Dtype tds => F
  )))`;


val _ = Hol_reln `

(! mn menv cenv st env d ds.
(
dec_diverges menv cenv st env d)
==>
decs_diverges mn menv cenv st env (d ::ds)) 

/\

(! mn menv cenv s1 s2 env d ds new_tds new_env.
(
evaluate_dec mn menv cenv s1 env d (s2, Rval (new_tds, new_env)) /\
decs_diverges mn menv (merge new_tds cenv) s2 (merge new_env env) ds)
==>
decs_diverges mn menv cenv s1 env (d ::ds))`;

val _ = Hol_reln `

(! menv cenv st env d ds.
(
dec_diverges menv cenv st env d)
==>
prog_diverges menv cenv st env (Tdec d ::ds))

/\

(! menv cenv s1 s2 env d ds new_tds new_env.
(
evaluate_dec NONE menv cenv s1 env d (s2, Rval (new_tds, new_env)) /\
prog_diverges menv (merge new_tds cenv) s2 (merge new_env env) ds)
==>
prog_diverges menv cenv s1 env (Tdec d ::ds)) 

/\

(! menv cenv s1 env ds1 ds2 mn specs. ( ~  ( MEM mn ( MAP FST menv)) /\
decs_diverges (SOME mn) menv cenv s1 env ds1)
==>
prog_diverges menv cenv s1 env (Tmod mn specs ds1 ::ds2))

/\

(! menv cenv s1 s2 env ds1 ds2 mn specs new_tds new_env. ( ~  ( MEM mn ( MAP FST menv)) /\
evaluate_decs (SOME mn) menv cenv s1 env ds1 (s2, Rval (new_tds,new_env)) /\
prog_diverges (bind mn new_env menv) (merge new_tds cenv) s2 env ds2)
==>
prog_diverges menv cenv s1 env (Tmod mn specs ds1 ::ds2))`;
val _ = export_theory()

