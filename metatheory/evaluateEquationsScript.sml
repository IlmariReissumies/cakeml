open preamble MiniMLTheory

val _ = new_theory "evaluateEquations"

(* functional equations for evaluate *)

val evaluate_raise = Q.store_thm (
"evaluate_raise",
`!menv cenv s env err bv.
  (evaluate menv cenv s env (Raise err) bv = (bv = (s, Rerr (Rraise err))))`,
rw [Once evaluate_cases]);

val evaluate_lit = Q.store_thm(
"evaluate_lit",
`!menv cenv s env l r.
  (evaluate menv cenv s env (Lit l) r = (r = (s,Rval (Litv l))))`,
rw [Once evaluate_cases]);

val evaluate_var = store_thm(
"evaluate_var",
``∀menv cenv s env n r. evaluate menv cenv s env (Var n) r =
  (∃v topt. (lookup_var_id n menv env = SOME v) ∧ (r = (s, Rval v))) ∨
  ((lookup_var_id n menv env = NONE) ∧ (r = (s, Rerr Rtype_error)))``,
rw [Once evaluate_cases] >>
metis_tac [])

val evaluate_fun = store_thm(
"evaluate_fun",
``∀menv cenv s env n topt e r. 
  evaluate menv cenv s env (Fun n topt e) r = (r = (s, Rval (Closure env n topt e)))``,
rw [Once evaluate_cases])

val _ = export_rewrites["evaluate_raise","evaluate_lit","evaluate_fun"];

val evaluate_con = Q.store_thm(
"evaluate_con",
`!menv cenv env cn es r s1.
  (evaluate menv cenv s1 env (Con cn es) r =
   if do_con_check cenv cn (LENGTH es) then
     (∃err s2. evaluate_list menv cenv s1 env es (s2, Rerr err) ∧
            (r = (s2, Rerr err))) ∨
     (∃vs s2. evaluate_list menv cenv s1 env es (s2, Rval vs) ∧
           (r = (s2, Rval (Conv cn vs))))
   else (r = (s1, Rerr Rtype_error)))`,
rw [Once evaluate_cases] >>
metis_tac []);

val evaluate_app = store_thm(
"evaluate_app",
``∀menv cenv s1 env op e1 e2 r. evaluate menv cenv s1 env (App op e1 e2) r =
  (∃v1 v2 env' e s2 s3 s4. 
     evaluate menv cenv s1 env e1 (s2, Rval v1) ∧ 
     (evaluate menv cenv s2 env e2 (s3, Rval v2)) ∧
                  (do_app s3 env op v1 v2 = SOME (s4,env',e)) ∧
                  evaluate menv cenv s4 env' e r) ∨
  (∃v1 v2 s2 s3. 
     evaluate menv cenv s1 env e1 (s2, Rval v1) ∧ 
     (evaluate menv cenv s2 env e2 (s3, Rval v2)) ∧
           (do_app s3 env op v1 v2 = NONE) ∧
           (r = (s3, Rerr Rtype_error))) ∨
  (∃v1 err s2 s3. evaluate menv cenv s1 env e1 (s2, Rval v1) ∧ (evaluate menv cenv s2 env e2 (s3, Rerr err)) ∧
            (r = (s3, Rerr err))) ∨
  (∃err s. evaluate menv cenv s1 env e1 (s, Rerr err) ∧
         (r = (s, Rerr err)))``,
rw[Once evaluate_cases] >>
metis_tac [])

val evaluate'_raise = store_thm(
"evaluate'_raise",
``∀env s err r. evaluate' s env (Raise err) r = (r = (s, Rerr (Rraise err)))``,
rw [Once evaluate'_cases])

val evaluate'_lit = store_thm(
"evaluate'_lit",
``∀s env l r. evaluate' s env (Lit l) r = (r = (s, Rval (Litv l)))``,
rw [Once evaluate'_cases])

val evaluate'_fun = store_thm(
"evaluate'_fun",
``∀s env n topt e r. 
  evaluate' s env (Fun n topt e) r = (r = (s, Rval (Closure env n topt e)))``,
rw [Once evaluate'_cases])

val _ = export_rewrites["evaluate'_raise","evaluate'_lit","evaluate'_fun"]

val evaluate'_con = store_thm(
"evaluate'_con",
``∀s env cn es r. evaluate' s env (Con cn es) r =
  (∃err s2. evaluate_list' s env es (s2, Rerr err) ∧ (r = (s2, Rerr err))) ∨
  (∃vs s2. evaluate_list' s env es (s2, Rval vs) ∧ (r = (s2, Rval (Conv cn vs))))``,
rw [Once evaluate'_cases] >>
metis_tac [])

val evaluate'_var = store_thm(
"evaluate'_var",
``∀s env n r. evaluate' s env (Var n) r =
  (∃n' v. (n = Short n') ∧
          (((lookup n' env = SOME v) ∧ (r = (s, Rval v))) ∨
           ((lookup n' env = NONE) ∧ (r = (s, Rerr Rtype_error)))))``,
rw [Once evaluate'_cases] >>
cases_on `n` >>
fs [] >>
metis_tac [])

val evaluate_list'_thm = store_thm(
"evaluate_list'_thm",
``∀s env r.
  (evaluate_list' s env [] r = (r = (s, Rval []))) ∧
  (∀e es. evaluate_list' s env (e::es) r =
   (∃v vs s2 s3. evaluate' s env e (s2, Rval v) ∧ 
                 evaluate_list' s2 env es (s3, Rval vs) ∧ 
                 (r = (s3, Rval (v::vs)))) ∨
   (∃err s2. evaluate' s env e (s2, Rerr err) ∧
          (r = (s2, Rerr err))) ∨
   (∃v err s2 s3. evaluate' s env e (s2, Rval v) ∧ evaluate_list' s2 env es (s3, Rerr err) ∧
            (r = (s3, Rerr err))))``,
rw[] >-
  rw[Once evaluate'_cases] >>
rw[EQ_IMP_THM] >- (
  pop_assum (mp_tac o (SIMP_RULE (srw_ss()) [Once evaluate'_cases])) >>
  rw [] >> metis_tac[] ) >>
rw[Once evaluate'_cases] >>
metis_tac [])

val evaluate'_app = store_thm(
"evaluate'_app",
``∀s env op e1 e2 r. evaluate' s env (App op e1 e2) r =
  (∃v1 v2 env' e s2 s3 s4. 
                  evaluate' s env e1 (s2, Rval v1) ∧ 
                  (evaluate' s2 env e2 (s3, Rval v2)) ∧
                  (do_app s3 env op v1 v2 = SOME (s4, env',e)) ∧
                  evaluate' s4 env' e r) ∨
  (∃v1 v2 s2 s3. 
           evaluate' s env e1 (s2, Rval v1) ∧ (evaluate' s2 env e2 (s3, Rval v2)) ∧
           (do_app s3 env op v1 v2 = NONE) ∧
           (r = (s3, Rerr Rtype_error))) ∨
  (∃v1 err s2 s3. evaluate' s env e1 (s2, Rval v1) ∧ (evaluate' s2 env e2 (s3, Rerr err)) ∧
            (r = (s3, Rerr err))) ∨
  (∃err s2. evaluate' s env e1 (s2, Rerr err) ∧
         (r = (s2, Rerr err)))``,
rw[Once evaluate'_cases] >>
metis_tac [])

val evaluate'_log = store_thm(
"evaluate'_log",
``∀s env lg e1 e2 r. evaluate' s env (Log lg e1 e2) r =
  (∃v1 env' e s2. 
     evaluate' s env e1 (s2, Rval v1) ∧ (do_log lg v1 e2 = SOME e) ∧ 
     (evaluate' s2 env e r)) ∨
  (∃v1 s2. evaluate' s env e1 (s2, Rval v1) ∧ (do_log lg v1 e2 = NONE) ∧ (r = (s2, Rerr Rtype_error))) ∨
  (∃err s2. evaluate' s env e1 (s2, Rerr err) ∧ (r = (s2, Rerr err)))``,
rw[Once evaluate'_cases] >>
metis_tac [])

val _ = export_theory ()
