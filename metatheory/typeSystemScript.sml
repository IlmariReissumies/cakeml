(* Theorems about type_e, type_es, and type_funs *)
open preamble MiniMLTheory MiniMLTerminationTheory rich_listTheory;

val _ = new_theory "typeSystem";

val all_distinct_map_inj = Q.prove (
`!f l. (!x y. (f x = f y) ⇒ (x = y)) ⇒ (ALL_DISTINCT (MAP f l) = ALL_DISTINCT l)`,
Induct_on `l` >>
rw [] >>
res_tac >>
rw [MEM_MAP] >>
metis_tac []);

val mem_lem = Q.prove (
`!x y l. MEM (x,y) l ⇒ ∃z. (x = FST z) ∧ z ∈ set l`,
induct_on `l` >>
rw [] >>
metis_tac [FST]);

val lookup_zip_map = Q.prove (
`!x env keys vals res f res'.
  (LENGTH keys = LENGTH vals) ∧ (env = ZIP (keys,vals)) ∧ (lookup x env = res) ⇒
  (lookup x (ZIP (keys,MAP f vals)) = OPTION_MAP f res)`,
recInduct lookup_ind >>
rw [lookup_def] >>
cases_on `keys` >>
cases_on `vals` >>
fs []);

val option_map_eqns = Q.prove (
`(!f. option_map f NONE = NONE) ∧
 (!f x. option_map f (SOME x) = SOME (f x))`,
rw [option_map_def]);

(* TODO: Move these definitions to miniML.lem? *)
(* Check that the dynamic and static constructor environments are consistent *)
val consistent_con_env_def = Define `
  (consistent_con_env [] [] = T) ∧
  (consistent_con_env ((cn, (n, tn'))::envC) ((cn', (tvs, ts, tn))::tenvC) =
    (cn = cn') ∧
    (tn = tn') ∧
    (LENGTH ts = n) ∧
    consistent_con_env envC tenvC) ∧
  (consistent_con_env _ _ = F)`;

val tenv_ok_def = Define `
(tenv_ok Empty = T) ∧
(tenv_ok (Bind_tvar n tenv) = tenv_ok tenv) ∧
(tenv_ok (Bind_name x tvs t tenv) = 
  check_freevars (tvs + num_tvs tenv) [] t ∧ tenv_ok tenv)`;

val same_module_def = Define `
(same_module (Short x) (Short y) = T) ∧
(same_module (Long mn1 x) (Long mn2 y) = (mn1 = mn2)) ∧
(same_module _ _ = F)`;

val tenvC_ok_def = Define `
tenvC_ok tenvC = 
ALL_DISTINCT (MAP FST tenvC) ∧
EVERY (\(cn,tvs,ts,tn). same_module cn tn ∧ EVERY (check_freevars 0 tvs) ts) tenvC`;

val tenvM_ok_def = Define `
tenvM_ok tenvM = EVERY (\(mn,tenv). tenv_ok (bind_var_list2 tenv Empty)) tenvM`;

val consistent_mod_env_def = Define `
(consistent_mod_env tenvS tenvC [] [] = T) ∧
(consistent_mod_env tenvS tenvC ((mn,env)::menv) ((mn',tenv)::tenvM) =
  (mn = mn') ∧
  ¬(MEM mn (MAP FST tenvM)) ∧
  type_env tenvM tenvC tenvS env (bind_var_list2 tenv Empty) ∧
  consistent_mod_env tenvS tenvC menv tenvM) ∧
(consistent_mod_env tenvS tenvC _ _ = F)`;

val disjoint_env_def = Define `
  disjoint_env e1 e2 =
    DISJOINT (set (MAP FST e1)) (set (MAP FST e2))`;

val tenvC_ok_lookup = Q.store_thm ("tenvC_ok_lookup",
`!tenvC cn tvs ts tn.
  tenvC_ok tenvC ∧ (lookup cn tenvC = SOME (tvs,ts,tn))
  ⇒
  EVERY (check_freevars 0 tvs) ts`,
induct_on `tenvC` >>
rw [] >>
PairCases_on `h` >>
fs [tenvC_ok_def] >>
every_case_tac >>
rw [] >>
fs [] >>
metis_tac []);

val tenvM_ok_lookup = Q.store_thm ("tenvM_ok_lookup",
`!n tenvM tenvC tenv.
  tenvM_ok tenvM ∧
  (lookup n tenvM = SOME tenv) ⇒
  tenv_ok (bind_var_list2 tenv Empty)`,
induct_on `tenvM` >>
rw [lookup_def, tenvM_ok_def] >>
PairCases_on `h` >>
fs [lookup_def] >>
every_case_tac >>
fs [] >>
metis_tac [tenvM_ok_def]);

val lookup_con_ok = Q.store_thm ("lookup_con_ok",
`!tenvC cn tvs ts tn.
  tenvC_ok tenvC ∧ (lookup cn tenvC = SOME (tvs,ts,tn))
  ⇒
  EVERY (check_freevars 0 tvs) ts`,
rw [lookup_def] >>
every_case_tac >>
fs [] >>
metis_tac [tenvM_ok_lookup, tenvC_ok_lookup]);

(* Constructors in their type environment are also in their execution
 * environment *)
val consistent_con_env_thm = Q.store_thm ("consistent_con_env_thm",
`∀cenv tenvC.
  consistent_con_env cenv tenvC 
  ⇒
  ((lookup cn tenvC = SOME (tvs, ts, tn)) ⇒ 
     (∃ns. (lookup cn cenv = SOME (LENGTH ts, tn))))
  ∧
  ((lookup cn tenvC = NONE) ⇒ (lookup cn cenv = NONE))`,
recInduct (fetch "-" "consistent_con_env_ind") >>
rw [lookup_def, consistent_con_env_def] >>
rw []);

val type_es_length = Q.store_thm ("type_es_length",
`∀tenvM tenvC tenv es ts.
  type_es tenvM tenvC tenv es ts ⇒ (LENGTH es = LENGTH ts)`,
induct_on `es` >>
rw [Once type_e_cases] >>
rw [] >>
metis_tac []);

val type_ps_length = Q.store_thm ("type_ps_length",
`∀tvs tenvC ps ts tenv.
  type_ps tvs tenvC ps ts tenv ⇒ (LENGTH ps = LENGTH ts)`,
induct_on `ps` >>
rw [Once type_p_cases] >>
rw [] >>
metis_tac []);

val lookup_in = Q.store_thm ("lookup_in",
`!x e v. (lookup x e = SOME v) ⇒ MEM v (MAP SND e)`,
induct_on `e` >>
rw [lookup_def] >>
cases_on `h` >>
fs [lookup_def] >>
every_case_tac >>
fs [] >>
metis_tac []);

val lookup_in2 = Q.store_thm ("lookup_in2",
`!x e v. (lookup x e = SOME v) ⇒ MEM x (MAP FST e)`,
induct_on `e` >>
rw [lookup_def] >>
cases_on `h` >>
fs [lookup_def] >>
every_case_tac >>
fs [] >>
metis_tac []);

val lookup_disjoint = Q.store_thm ("lookup_disjoint",
`!x v e e'. (lookup x e = SOME v) ∧ disjoint_env e e' ⇒
  (lookup x (merge e' e) = SOME v)`,
induct_on `e'` >>
rw [disjoint_env_def, merge_def, lookup_def] >>
cases_on `h` >>
fs [merge_def, lookup_def] >>
fs [Once DISJOINT_SYM, DISJOINT_INSERT] >>
`q ≠ x` by metis_tac [lookup_in2] >>
fs [disjoint_env_def] >>
metis_tac [DISJOINT_SYM]);

val lookup_con_disjoint = Q.store_thm ("lookup_con_disjoint",
`!x v tenvC1 tenvC2.
  (lookup x tenvC1 = SOME v) ∧
  disjoint_env tenvC1 tenvC2
  ⇒
  (lookup x (merge tenvC2 tenvC1) = SOME v)`,
metis_tac [lookup_disjoint]);

val lookup_notin = Q.store_thm ("lookup_notin",
`!x e. (lookup x e = NONE) = ~MEM x (MAP FST e)`,
induct_on `e` >>
rw [lookup_def] >>
cases_on `h` >>
fs [lookup_def] >>
every_case_tac >>
fs []);

val bind_var_list_append = Q.store_thm ("bind_var_list_append",
`!n te1 te2 te3.
  bind_var_list n (te1++te2) te3 = bind_var_list n te1 (bind_var_list n te2 te3)`,
induct_on `te1` >>
rw [bind_var_list_def] >>
PairCases_on `h` >>
rw [bind_var_list_def]);

val check_freevars_subst_single = Q.store_thm ("check_freevars_subst_single",
`!dbmax tvs t tvs' ts.
  (LENGTH tvs = LENGTH ts) ∧
  check_freevars dbmax tvs t ∧
  EVERY (check_freevars dbmax tvs') ts
  ⇒
  check_freevars dbmax tvs' (type_subst (ZIP (tvs,ts)) t)`,
recInduct check_freevars_ind >>
rw [check_freevars_def, type_subst_def, EVERY_MAP] >|
[every_case_tac >>
     fs [check_freevars_def, lookup_notin] >|
     [imp_res_tac MAP_ZIP >>
          fs [],
      imp_res_tac lookup_in >>
          imp_res_tac MAP_ZIP >>
          fs [EVERY_MEM]],
 fs [EVERY_MEM]]);

val type_uop_cases = Q.store_thm ("type_uop_cases",
`∀uop t1 t2.
  type_uop uop t1 t2 =
  ((uop = Opref) ∧ (t2 = Tref t1)) ∨
  ((uop = Opderef) ∧ (t1 = Tref t2))`,
rw [type_uop_def, Tint_def, Tbool_def, Tunit_def, Tref_def] >>
cases_on `uop` >>
rw [] >>
cases_on `t1` >>
rw [] >>
cases_on `l` >>
rw [] >>
cases_on `t'` >>
rw [] >>
cases_on `t` >>
rw [] >>
metis_tac []);

val type_op_cases = Q.store_thm ("type_op_cases",
`!op t1 t2 t3.
  type_op op t1 t2 t3 =
  ((∃op'. op = Opn op') ∧ (t1 = Tint) ∧ (t2 = Tint) ∧ (t3 = Tint)) ∨
  ((∃op'. op = Opb op') ∧ (t1 = Tint) ∧ (t2 = Tint) ∧ (t3 = Tbool)) ∨
  ((op = Opapp) ∧ (t1 = Tfn t2 t3)) ∨
  ((op = Equality) ∧ (t1 = t2) ∧ (t3 = Tbool)) ∨
  ((op = Opassign) ∧ (t1 = Tref t2) ∧ (t3 = Tunit))`,
rw [type_op_def, Tfn_def, Tint_def, Tbool_def, Tunit_def, Tref_def] >>
cases_on `op` >>
rw [] >>
cases_on `t1` >>
rw [] >|
[cases_on `t2` >>
     fs [],
 cases_on `t2` >>
     fs [],
 cases_on `t2` >>
     rw [] >>
     cases_on `t'` >>
     rw [] >>
     every_case_tac,
 cases_on `t2` >>
     fs [],
 cases_on `t2` >>
     fs [],
 cases_on `t2` >>
     rw [] >>
     cases_on `t'` >>
     rw [] >>
     every_case_tac,
 cases_on `t` >>
     rw []  >>
     every_case_tac >>
     metis_tac [],
 cases_on `t` >>
     rw []  >>
     every_case_tac >>
     metis_tac []]);

val check_freevars_subst_list = Q.store_thm ("check_freevars_subst_list",
`!dbmax tvs tvs' ts ts'.
  (LENGTH tvs = LENGTH ts) ∧
  EVERY (check_freevars dbmax tvs) ts' ∧
  EVERY (check_freevars dbmax tvs') ts
  ⇒
  EVERY (check_freevars dbmax tvs') (MAP (type_subst (ZIP (tvs,ts))) ts')`,
induct_on `ts'` >>
rw [] >>
metis_tac [check_freevars_subst_single]);

val deBruijn_subst_check_freevars = Q.store_thm ("deBruijn_subst_check_freevars",
`!tvs tvs' t ts n.
  check_freevars tvs tvs' t ∧
  EVERY (check_freevars tvs tvs') ts
  ⇒
  check_freevars tvs tvs' (deBruijn_subst 0 ts t)`,
ho_match_mp_tac check_freevars_ind >>
rw [check_freevars_def, deBruijn_subst_def, EVERY_MAP] >>
fs [EVERY_MEM] >>
fs [MEM_EL] >-
metis_tac [] >>
decide_tac);

val deBruijn_subst_check_freevars2 = Q.store_thm ("deBruijn_subst_check_freevars2",
`!tvs tvs' t ts n tvs''.
  check_freevars (LENGTH ts) tvs' t ∧
  EVERY (check_freevars tvs tvs') ts
  ⇒
  check_freevars tvs tvs' (deBruijn_subst 0 ts t)`,
ho_match_mp_tac check_freevars_ind >>
rw [check_freevars_def, deBruijn_subst_def, EVERY_MAP] >>
fs [EVERY_MEM] >>
fs [MEM_EL] >>
rw [] >>
metis_tac []);

val check_freevars_add = Q.store_thm ("check_freevars_add",
`(!tvs tvs' t. check_freevars tvs tvs' t ⇒ 
  !tvs''. tvs'' ≥ tvs ⇒ check_freevars tvs'' tvs' t)`,
ho_match_mp_tac check_freevars_ind >>
rw [check_freevars_def] >-
metis_tac [MEM_EL, EVERY_MEM] >>
decide_tac);

val check_freevars_subst_inc = Q.store_thm ("check_freevars_subst_inc",
`∀tvs tvs2 t.
  check_freevars tvs tvs2 t ⇒
  ∀tvs' targs tvs1.
  (tvs = LENGTH targs + tvs') ∧
  EVERY (check_freevars (tvs1 + tvs') tvs2) targs
  ⇒
  check_freevars (tvs1 + tvs') tvs2
     (deBruijn_subst 0 targs (deBruijn_inc (LENGTH targs) tvs1 t))`,
ho_match_mp_tac check_freevars_ind >>
rw [check_freevars_def, deBruijn_inc_def, deBruijn_subst_def, EVERY_MAP] >>
fs [EVERY_MEM] >>
cases_on `n < LENGTH targs` >>
rw [deBruijn_subst_def, check_freevars_def] >>
fs [MEM_EL] >-
metis_tac [] >-
metis_tac [] >>
decide_tac);

val type_e_freevars_lem2 = Q.prove (
`!tenvE targs n t inc.
  EVERY (check_freevars (inc + num_tvs tenvE) []) targs ∧
  (lookup_tenv n inc tenvE = SOME (LENGTH targs,t)) ∧
  tenv_ok tenvE
  ⇒ 
  check_freevars (inc + num_tvs tenvE) [] (deBruijn_subst 0 targs t)`,
induct_on `tenvE` >>
rw [check_freevars_def, num_tvs_def, lookup_tenv_def, tenv_ok_def] >>
metis_tac [deBruijn_subst_check_freevars, arithmeticTheory.ADD_ASSOC,
           check_freevars_subst_inc]);

val deBruijn_inc0 = Q.store_thm ("deBruijn_inc0",
`(!t sk. deBruijn_inc sk 0 t = t) ∧
 (!ts sk. MAP (deBruijn_inc sk 0) ts = ts)`,
ho_match_mp_tac t_induction >>
rw [deBruijn_inc_def] >>
metis_tac []);

val num_tvs_bvl2 = Q.store_thm ("num_tvs_bvl2",
`!tenv1 tenv2. num_tvs (bind_var_list2 tenv1 tenv2) = num_tvs tenv2`,
ho_match_mp_tac bind_var_list2_ind >>
rw [num_tvs_def, bind_var_list2_def, bind_tenv_def]);

val type_e_freevars_lem3 = Q.prove (
`!tenv tenv' targs n t inc.
  EVERY (check_freevars (num_tvs tenv') []) targs ∧
  (lookup n tenv = SOME (LENGTH targs,t)) ∧
  tenv_ok (bind_var_list2 tenv Empty)
  ⇒ 
  check_freevars (num_tvs tenv') [] (deBruijn_subst 0 targs t)`,
induct_on `tenv` >>
rw [lookup_def, tenv_ok_def, bind_var_list2_def] >>
PairCases_on `h` >>
rw [] >>
fs [lookup_def, tenv_ok_def, bind_var_list2_def, bind_tenv_def] >>
cases_on `h0 = n` >>
fs [] >>
rw [] >>
metis_tac [deBruijn_subst_check_freevars2, arithmeticTheory.ADD_0, num_tvs_bvl2, num_tvs_def]);

val type_e_freevars_lem4 = Q.prove (
`!tenvM tenv targs n t.
  EVERY (check_freevars (num_tvs tenv) []) targs ∧
  (t_lookup_var_id n tenvM tenv = SOME (LENGTH targs,t)) ∧
  tenvM_ok tenvM ∧
  tenv_ok tenv
  ⇒ 
  check_freevars (num_tvs tenv) [] (deBruijn_subst 0 targs t)`,
rw [t_lookup_var_id_def] >>
every_case_tac >>
fs [] >>
imp_res_tac tenvM_ok_lookup >>
metis_tac [type_e_freevars_lem3,type_e_freevars_lem2,arithmeticTheory.ADD]);

val num_tvs_bind_var_list = Q.store_thm ("num_tvs_bind_var_list",
`!tvs env tenvE. num_tvs (bind_var_list tvs env tenvE) = num_tvs tenvE`,
induct_on `env` >>
rw [num_tvs_def, bind_var_list_def] >>
PairCases_on `h` >>
rw [bind_var_list_def, bind_tenv_def, num_tvs_def]);

val tenv_ok_bind_var_list_funs = Q.store_thm ("tenv_ok_bind_var_list_funs",
`!funs tenvM tenvC env tenvE tvs env'.
  type_funs tenvM tenvC (bind_var_list 0 env' tenvE) funs env ∧
  tenv_ok tenvE
  ⇒
  tenv_ok (bind_var_list 0 env tenvE)`,
induct_on `funs` >>
rw [] >>
qpat_assum `type_funs x0 x1 x2 x3 x4` (ASSUME_TAC o SIMP_RULE (srw_ss()) [Once type_e_cases]) >>
fs [] >>
rw [check_freevars_def, bind_tenv_def, bind_var_list_def, tenv_ok_def] >>
fs [check_freevars_def, num_tvs_bind_var_list] >>
metis_tac []);

val tenv_ok_bind_var_list_tvs = Q.store_thm ("tenv_ok_bind_var_list_tvs",
`!funs tenvM tenvC env tenvE tvs env'.
  type_funs tenvM tenvC (bind_var_list 0 env' (bind_tvar tvs tenvE)) funs env ∧
  tenv_ok tenvE
  ⇒
  tenv_ok (bind_var_list tvs env tenvE)`,
induct_on `funs` >>
rw [] >>
qpat_assum `type_funs x0 x1 x2 x3 x4` (ASSUME_TAC o SIMP_RULE (srw_ss()) [Once type_e_cases]) >>
fs [] >>
rw [check_freevars_def, bind_tenv_def, bind_var_list_def, tenv_ok_def] >>
cases_on `tvs = 0` >>
fs [check_freevars_def, num_tvs_bind_var_list, bind_tvar_def, num_tvs_def] >>
metis_tac []);

val tenv_ok_bind_var_list = Q.store_thm ("tenv_ok_bind_var_list",
`!tenvE env.
  tenv_ok tenvE ∧ EVERY (check_freevars (num_tvs tenvE) []) (MAP SND env)
  ⇒
  tenv_ok (bind_var_list 0 env tenvE)`,
induct_on `env` >>
rw [tenv_ok_def, bind_var_list_def] >>
PairCases_on `h` >>
rw [bind_tenv_def, tenv_ok_def, bind_var_list_def] >>
fs [num_tvs_bind_var_list]);

val type_p_freevars = Q.store_thm ("type_p_freevars",
`(!tvs tenvC p t env'. 
   type_p tvs tenvC p t env' ⇒ 
   check_freevars tvs [] t ∧
   EVERY (check_freevars tvs []) (MAP SND env')) ∧
 (!tvs tenvC ps ts env'. 
   type_ps tvs tenvC ps ts env' ⇒ 
   EVERY (check_freevars tvs []) ts ∧
   EVERY (check_freevars tvs []) (MAP SND env'))`,
ho_match_mp_tac type_p_ind >>
rw [check_freevars_def, bind_tenv_def, Tbool_def, Tint_def, Tunit_def, Tref_def,
    tenv_ok_def, bind_tvar_def, bind_var_list_def] >>
metis_tac []);

val type_e_freevars = Q.store_thm ("type_e_freevars",
`(!tenvM tenvC tenvE e t. 
   type_e tenvM tenvC tenvE e t ⇒ 
   tenvM_ok tenvM ∧
   tenv_ok tenvE ⇒
   check_freevars (num_tvs tenvE) [] t) ∧
 (!tenvM tenvC tenvE es ts. 
   type_es tenvM tenvC tenvE es ts ⇒
   tenvM_ok tenvM ∧
   tenv_ok tenvE ⇒
   EVERY (check_freevars (num_tvs tenvE) []) ts) ∧
 (!tenvM tenvC tenvE funs env. 
   type_funs tenvM tenvC tenvE funs env ⇒
   tenvM_ok tenvM ∧
   tenv_ok tenvE ⇒
   EVERY (check_freevars (num_tvs tenvE) []) (MAP SND env))`,
ho_match_mp_tac type_e_strongind >>
rw [check_freevars_def, bind_tenv_def, num_tvs_def, type_uop_cases, type_op_cases,
    tenv_ok_def, bind_tvar_def, bind_var_list_def, Tbool_def, Tint_def, Tfn_def,
    Tunit_def, Tref_def] >>
fs [check_freevars_def] >|
[metis_tac [deBruijn_subst_check_freevars],
 metis_tac [type_e_freevars_lem4, arithmeticTheory.ADD],
 cases_on `pes` >>
     fs [RES_FORALL, num_tvs_bind_var_list] >>
     qpat_assum `!x. P x` (ASSUME_TAC o Q.SPEC `(FST h, SND h)`) >>
     fs [] >>
     metis_tac [type_p_freevars, tenv_ok_bind_var_list],
 metis_tac [tenv_ok_bind_var_list_funs, num_tvs_bind_var_list],
 metis_tac [tenv_ok_bind_var_list_tvs, num_tvs_bind_var_list, bind_tvar_def]]);

(* Recursive functions have function type *)
val type_funs_Tfn = Q.store_thm ("type_funs_Tfn",
`∀tenvM tenvC tenv funs tenv' tvs t n.
  type_funs tenvM tenvC tenv funs tenv' ∧
  (lookup n tenv' = SOME t)
  ⇒
  ∃t1 t2. (t = Tfn t1 t2) ∧ check_freevars (num_tvs tenv) [] (Tfn t1 t2)`,
induct_on `funs` >>
rw [] >>
qpat_assum `type_funs tenvM tenvC tenv funspat tenv'`
      (ASSUME_TAC o SIMP_RULE (srw_ss()) [Once type_e_cases]) >>
rw [] >>
fs [lookup_def, emp_def, bind_def] >>
cases_on `fn = n` >>
fs [deBruijn_subst_def, check_freevars_def] >>
metis_tac [type_e_freevars, bind_tenv_def, num_tvs_def]);

(* Recursive functions can be looked up in the execution environment. *)
val type_funs_lookup = Q.store_thm ("type_funs_lookup",
`∀fn env tenvM tenvC funs env' n e tenv.
  MEM (fn,n,e) funs ∧
  type_funs tenvM tenvC tenv funs env'
  ⇒
  (∃t. lookup fn env' = SOME t)`,
Induct_on `funs` >>
rw [] >>
pop_assum (ASSUME_TAC o SIMP_RULE (srw_ss()) [Once type_e_cases]) >>
fs [] >>
fs [lookup_def, bind_def] >>
rw [] >>
metis_tac []);

(* Functions in the type environment can be found *)
val type_funs_find_recfun = Q.store_thm ("type_funs_find_recfun",
`∀fn env tenvM tenvC funs tenv' e tenv t.
  (lookup fn tenv' = SOME t) ∧
  type_funs tenvM tenvC tenv funs tenv'
  ⇒
  (∃n e. find_recfun fn funs = SOME (n,e))`,
Induct_on `funs` >>
rw [] >>
pop_assum (ASSUME_TAC o SIMP_RULE (srw_ss()) [Once type_e_cases]) >>
fs [] >>
fs [lookup_def, bind_def, emp_def] >>
rw [Once find_recfun_def] >>
metis_tac []);

val type_recfun_lookup = Q.store_thm ("type_recfun_lookup",
`∀fn funs n e tenvM tenvC tenv tenv' tvs t1 t2.
  (find_recfun fn funs = SOME (n,e)) ∧
  type_funs tenvM tenvC tenv funs tenv' ∧
  (lookup fn tenv' = SOME (Tfn t1 t2))
  ⇒
  type_e tenvM tenvC (bind_tenv n 0 t1 tenv) e t2 ∧
  check_freevars (num_tvs tenv) [] (Tfn t1 t2)`,
induct_on `funs` >>
rw [Once find_recfun_def] >>
qpat_assum `type_funs tenvM tenvC tenv (h::funs) tenv'`
            (ASSUME_TAC o SIMP_RULE (srw_ss ()) [Once type_e_cases]) >>
rw [] >>
fs [] >>
cases_on `fn' = fn` >>
fs [Tfn_def, lookup_def, bind_def, deBruijn_subst_def] >>
rw [check_freevars_def] >>
metis_tac [bind_tenv_def, num_tvs_def, type_e_freevars, type_funs_Tfn,
           EVERY_DEF, Tfn_def, check_freevars_def]);

(* No duplicate function definitions in a single let rec *)
val type_funs_distinct = Q.store_thm ("type_funs_distinct",
`∀tenvM tenvC tenv funs tenv'.
  type_funs tenvM tenvC tenv funs tenv'
  ⇒
  ALL_DISTINCT (MAP (λ(x,y,z). x) funs)`,
induct_on `funs` >>
rw [] >>
pop_assum (ASSUME_TAC o SIMP_RULE (srw_ss()) [Once type_e_cases]) >>
fs [] >>
rw [MEM_MAP] >|
[PairCases_on `y` >>
     rw [] >>
     CCONTR_TAC >>
     fs [] >>
     rw [] >>
     metis_tac [type_funs_lookup, optionTheory.NOT_SOME_NONE],
 metis_tac []]);

val build_rec_env_help_lem = Q.prove (
`∀funs env funs' tvs.
FOLDR (λ(f,x,e) env'. bind f (Recclosure env funs' f) env') env' funs =
merge (MAP (λ(fn,n,e). (fn, Recclosure env funs' fn)) funs) env'`,
Induct >>
rw [merge_def, bind_def] >>
PairCases_on `h` >>
rw []);

(* Alternate definition for build_rec_env *)
val build_rec_env_merge = Q.store_thm ("build_rec_env_merge",
`∀funs funs' env env' tvs.
  build_rec_env tvs funs env env' =
  merge (MAP (λ(fn,n,e). (fn, Recclosure env funs fn)) funs) env'`,
rw [build_rec_env_def, build_rec_env_help_lem]);

val deBruijn_subst_tenvE_def = Define `
(deBruijn_subst_tenvE targs Empty = Empty) ∧
(deBruijn_subst_tenvE targs (Bind_tvar tvs env) = 
  Bind_tvar tvs (deBruijn_subst_tenvE targs env)) ∧
(deBruijn_subst_tenvE targs (Bind_name x tvs t env) =
  Bind_name x tvs (deBruijn_subst (tvs + num_tvs env) 
                                  (MAP (deBruijn_inc 0 (tvs + num_tvs env)) targs)
                                  t)
       (deBruijn_subst_tenvE targs env))`;

val db_merge_def = Define `
(db_merge Empty e = e) ∧
(db_merge (Bind_tvar tvs e1) e2 = Bind_tvar tvs (db_merge e1 e2)) ∧
(db_merge (Bind_name x tvs t e1) e2 = Bind_name x tvs t (db_merge e1 e2))`;

val num_tvs_db_merge = Q.prove (
`!e1 e2. num_tvs (db_merge e1 e2) = num_tvs e1 + num_tvs e2`,
induct_on `e1` >>
rw [num_tvs_def, db_merge_def] >>
decide_tac);

val num_tvs_deBruijn_subst_tenvE = Q.prove (
`!targs tenvE. num_tvs (deBruijn_subst_tenvE targs tenvE) = num_tvs tenvE`,
induct_on `tenvE` >>
rw [deBruijn_subst_tenvE_def, num_tvs_def]);

val bind_tvar_rewrites = Q.store_thm ("bind_tvar_rewrites",
`(!tvs e1 e2. 
   db_merge (bind_tvar tvs e1) e2 = bind_tvar tvs (db_merge e1 e2)) ∧
 (!tvs e. num_tvs (bind_tvar tvs e) = tvs + num_tvs e) ∧
 (!n inc tvs e. lookup_tenv n inc (bind_tvar tvs e) = lookup_tenv n (inc+tvs) e) ∧
 (!tvs e. tenv_ok (bind_tvar tvs e) = tenv_ok e) ∧
 (!targs tvs e.
   deBruijn_subst_tenvE targs (bind_tvar tvs e) =
   bind_tvar tvs (deBruijn_subst_tenvE targs e))`,
rw [bind_tvar_def, deBruijn_subst_tenvE_def, db_merge_def, num_tvs_def,
    lookup_tenv_def, tenv_ok_def]);

val lookup_tenv_db_merge = Q.prove (
`!n inc e1 e2.
  lookup_tenv n inc (db_merge e1 e2) =
  case lookup_tenv n inc e1 of
    | SOME t => SOME t
    | NONE =>
        lookup_tenv n (inc + num_tvs e1) e2`,
induct_on `e1` >>
rw [lookup_tenv_def, db_merge_def, num_tvs_def] >>
every_case_tac >>
srw_tac [ARITH_ss] []);

val tenv_ok_db_merge = Q.prove (
`!e1 e2. tenv_ok (db_merge e1 e2) ⇒ tenv_ok e2`,
induct_on `e1` >>
rw [tenv_ok_def, db_merge_def]);

val check_freevars_deBruijn_inc = Q.prove (
`!tvs tvs' t. check_freevars tvs tvs' t ⇒ 
  !n n'. check_freevars (n+tvs) tvs' (deBruijn_inc n' n t)`,
ho_match_mp_tac check_freevars_ind >>
rw [check_freevars_def, deBruijn_inc_def] >>
fs [EVERY_MAP, EVERY_MEM] >>
rw [check_freevars_def] >>
decide_tac);

val check_freevars_lem = Q.prove (
`!l tvs' t.
  check_freevars l tvs' t ⇒
  !targs n1 tvs.
    (l = n1 + (LENGTH targs)) ∧
    EVERY (check_freevars tvs tvs') targs
     ⇒
     check_freevars (n1 + tvs) tvs'
       (deBruijn_subst n1 (MAP (deBruijn_inc 0 n1) targs) t)`,
ho_match_mp_tac check_freevars_ind >>
rw [deBruijn_inc_def, deBruijn_subst_def, check_freevars_def] >|
[fs [EVERY_MAP, EVERY_MEM] >>
     metis_tac [],
 rw [check_freevars_def] >|
     [fs [EVERY_MEM, MEM_EL] >>
          `n - n1 < LENGTH targs` by decide_tac >>
          rw [EL_MAP] >>
          metis_tac [check_freevars_deBruijn_inc, MEM_EL, 
                     arithmeticTheory.ADD_COMM, arithmeticTheory.ADD_ASSOC],
      decide_tac,
      decide_tac,
      decide_tac]]);

val type_subst_deBruijn_subst_single = Q.prove (
`!s t tvs tvs' ts ts' inc.
  (LENGTH tvs = LENGTH ts) ∧
  check_freevars 0 tvs t ∧
  (s = (ZIP (tvs,ts))) ⇒
  (deBruijn_subst inc ts' (type_subst (ZIP (tvs,ts)) t) =
   type_subst (ZIP (tvs,MAP (\t. deBruijn_subst inc ts' t) ts)) t)`,
recInduct type_subst_ind >>
rw [deBruijn_subst_def, deBruijn_inc_def, type_subst_def, check_freevars_def] >|
[every_case_tac >>
     fs [deBruijn_subst_def, deBruijn_inc_def] >|
     [imp_res_tac MAP_ZIP >>
          fs [lookup_notin],
      metis_tac [lookup_zip_map, optionTheory.OPTION_MAP_DEF, optionTheory.NOT_SOME_NONE],
      `lookup tv (ZIP (tvs, MAP (λt. deBruijn_subst inc ts' t) ts)) =
       OPTION_MAP (λt. deBruijn_subst inc ts' t) (SOME x)`
                     by metis_tac [lookup_zip_map] >>
          fs []],
 rw [rich_listTheory.MAP_EQ_f, MAP_MAP_o] >>
     fs [EVERY_MEM] >>
     metis_tac []]);

val type_subst_deBruijn_subst_list = Q.store_thm ("type_subst_deBruijn_subst_list",
`!t tvs tvs' ts ts' ts'' inc.
  (LENGTH tvs = LENGTH ts) ∧
  EVERY (check_freevars 0 tvs) ts'' ⇒
  (MAP (deBruijn_subst inc ts') (MAP (type_subst (ZIP (tvs,ts))) ts'') =
   MAP (type_subst (ZIP (tvs,MAP (\t. deBruijn_subst inc ts' t) ts))) ts'')`,
induct_on `ts''` >>
rw [] >>
metis_tac [type_subst_deBruijn_subst_single]);

val type_subst_deBruijn_inc_single = Q.prove (
`!s t ts tvs inc sk.
  (LENGTH tvs = LENGTH ts) ∧
  (s = (ZIP (tvs,ts))) ∧
  check_freevars 0 tvs t ⇒
  (deBruijn_inc sk inc (type_subst s t) =
   type_subst (ZIP (tvs, MAP (\t. deBruijn_inc sk inc t) ts)) t)`,
recInduct type_subst_ind >>
rw [deBruijn_inc_def, type_subst_def, check_freevars_def] >|
[every_case_tac >>
     rw [deBruijn_inc_def] >|
     [imp_res_tac MAP_ZIP >>
          fs [lookup_notin],
      metis_tac [lookup_zip_map, optionTheory.OPTION_MAP_DEF, optionTheory.NOT_SOME_NONE],
      `lookup tv (ZIP (tvs, MAP (λt. deBruijn_inc sk inc t) ts)) =
       OPTION_MAP (λt. deBruijn_inc sk inc t) (SOME x)`
                     by metis_tac [lookup_zip_map] >>
          fs []],
 rw [rich_listTheory.MAP_EQ_f, MAP_MAP_o] >>
     fs [EVERY_MEM] >>
     metis_tac []]);

val type_subst_deBruijn_inc_list = Q.store_thm ("type_subst_deBruijn_inc_list",
`!ts' ts tvs inc sk.
  (LENGTH tvs = LENGTH ts) ∧
  EVERY (check_freevars 0 tvs) ts' ⇒
  (MAP (deBruijn_inc sk inc) (MAP (type_subst (ZIP (tvs,ts))) ts') =
   MAP (type_subst (ZIP (tvs, MAP (\t. deBruijn_inc sk inc t) ts))) ts')`,
induct_on `ts'` >>
rw [] >>
metis_tac [type_subst_deBruijn_inc_single]);

val lookup_tenv_subst_none = Q.prove (
`!n inc e.
 (lookup_tenv n inc e = NONE) ⇒ 
 (lookup_tenv n inc (deBruijn_subst_tenvE targs e) = NONE)`,
induct_on `e` >>
rw [deBruijn_subst_tenvE_def, lookup_tenv_def]);

val deBruijn_inc_deBruijn_inc = Q.prove (
`!sk i2 t i1. 
  deBruijn_inc sk i1 (deBruijn_inc sk i2 t) = deBruijn_inc sk (i1 + i2) t`,
ho_match_mp_tac deBruijn_inc_ind >>
rw [deBruijn_inc_def] >>
rw [] >-
decide_tac >-
decide_tac >>
induct_on `ts` >>
fs []);

val lookup_tenv_inc_some = Q.prove (
`!n inc e tvs t inc2.
   (lookup_tenv n inc e = SOME (tvs, t)) 
   ⇒
   ?t'. (t = deBruijn_inc tvs inc t') ∧
        (lookup_tenv n inc2 e = SOME (tvs, deBruijn_inc tvs inc2 t'))`,
induct_on `e` >>
rw [deBruijn_inc_def, lookup_tenv_def] >>
rw [] >>
metis_tac [deBruijn_inc_deBruijn_inc]);

val nil_deBruijn_inc = Q.store_thm ("nil_deBruijn_inc",
`∀skip tvs t. 
  (check_freevars skip [] t ∨ check_freevars skip [] (deBruijn_inc skip tvs t))
  ⇒ 
  (deBruijn_inc skip tvs t = t)`,
ho_match_mp_tac deBruijn_inc_ind >>
rw [deBruijn_inc_def, check_freevars_def] >-
decide_tac >-
(induct_on `ts` >>
     rw [] >>
     metis_tac []) >-
(induct_on `ts` >>
     rw [] >>
     metis_tac []) >>
metis_tac []);

val nil_deBruijn_subst = Q.store_thm ("nil_deBruijn_subst",
`∀skip tvs t. check_freevars skip [] t ⇒ (deBruijn_subst skip tvs t = t)`,
ho_match_mp_tac deBruijn_subst_ind >>
rw [deBruijn_subst_def, check_freevars_def] >>
induct_on `ts'` >>
rw []);

val type_e_subst_lem1 = Q.prove (
`!e n inc t.
  (num_tvs e = 0) ∧
  tenv_ok e ∧
  (lookup_tenv n inc e = SOME (tvs, deBruijn_inc tvs inc t))
  ⇒
  check_freevars tvs [] t`,
induct_on `e` >>
rw [lookup_tenv_def, num_tvs_def, tenv_ok_def] >|
[metis_tac [arithmeticTheory.ADD, arithmeticTheory.ADD_COMM],
 `check_freevars n [] t0` 
          by metis_tac [arithmeticTheory.ADD, arithmeticTheory.ADD_COMM] >>
     fs [nil_deBruijn_inc] >>
     rw [] >>
     metis_tac [nil_deBruijn_inc],
 metis_tac [arithmeticTheory.ADD, arithmeticTheory.ADD_COMM]]);

val deBruijn_subst2 = Q.store_thm ("deBruijn_subst2",
`(!t sk targs targs' tvs'.
  check_freevars (LENGTH targs) [] t ⇒
  (deBruijn_subst sk (MAP (deBruijn_inc 0 sk) targs') (deBruijn_subst 0 targs t) =
   deBruijn_subst 0 (MAP (deBruijn_subst sk (MAP (deBruijn_inc 0 sk) targs')) targs) t)) ∧
 (!ts sk targs targs' tvs'.
  EVERY (check_freevars (LENGTH targs) []) ts ⇒
  (MAP (deBruijn_subst sk (MAP (deBruijn_inc 0 sk) targs')) (MAP (deBruijn_subst 0 targs) ts) =
  (MAP (deBruijn_subst 0 (MAP (deBruijn_subst sk (MAP (deBruijn_inc 0 sk) targs')) targs)) ts)))`,
ho_match_mp_tac t_induction >>
rw [deBruijn_subst_def, deBruijn_inc_def] >>
fs [EL_MAP, MAP_MAP_o, combinTheory.o_DEF] >>
rw [] >>
full_simp_tac (srw_ss()++ARITH_ss) [deBruijn_subst_def, check_freevars_def] >>
metis_tac []);

val type_e_subst_lem3 = Q.store_thm ("type_e_subst_lem3",
`∀tvs tvs2 t.
  check_freevars tvs tvs2 t ⇒
  ∀tvs' targs n.
  (tvs = n + LENGTH targs) ∧
  EVERY (check_freevars tvs' tvs2) targs
  ⇒
  check_freevars (n + tvs') tvs2
     (deBruijn_subst n (MAP (deBruijn_inc 0 n) targs) t)`,
ho_match_mp_tac check_freevars_ind >>
rw [check_freevars_def, deBruijn_inc_def, deBruijn_subst_def, EVERY_MAP] >>
fs [EVERY_MEM] >>
rw [] >>
full_simp_tac (srw_ss()++ARITH_ss) [check_freevars_def, EL_MAP, MEM_EL] >>
`n - n' < LENGTH targs` by decide_tac >>
metis_tac [check_freevars_deBruijn_inc]);

val type_e_subst_lem4 = Q.prove (
`!sk i2 t i1. 
  deBruijn_inc sk i1 (deBruijn_inc 0 (sk + i2) t) = deBruijn_inc 0 (i1 + (sk + i2)) t`,
ho_match_mp_tac deBruijn_inc_ind >>
rw [deBruijn_inc_def] >>
rw [] >-
decide_tac >-
decide_tac >>
induct_on `ts` >>
rw []);

val type_e_subst_lem5 = Q.prove (
`(!t n inc n' targs.
   deBruijn_inc n inc 
         (deBruijn_subst (n + n') (MAP (deBruijn_inc 0 (n + n')) targs) t) =
   deBruijn_subst (n + inc + n') (MAP (deBruijn_inc 0 (n + inc + n')) targs) 
         (deBruijn_inc n inc t)) ∧
 (!ts n inc n' targs.
   MAP (deBruijn_inc n inc)
         (MAP (deBruijn_subst (n + n') (MAP (deBruijn_inc 0 (n + n')) targs)) ts) =
   MAP (deBruijn_subst (n + inc + n') (MAP (deBruijn_inc 0 (n + inc + n')) targs))
         (MAP (deBruijn_inc n inc) ts))`,
ho_match_mp_tac t_induction >>
rw [deBruijn_subst_def, deBruijn_inc_def] >>
rw [] >>
full_simp_tac (srw_ss()++ARITH_ss) [EL_MAP] >>
metis_tac [type_e_subst_lem4]);

val lookup_tenv_freevars = Q.prove (
`!e n inc t tvs.
  tenv_ok e ∧
  (lookup_tenv n inc e = SOME (tvs, t))
  ⇒
  check_freevars (tvs+inc+num_tvs e) [] t`,
induct_on `e` >>
rw [lookup_tenv_def, num_tvs_def, tenv_ok_def] >|
[metis_tac [arithmeticTheory.ADD_ASSOC],
 imp_res_tac check_freevars_deBruijn_inc >>
     metis_tac [arithmeticTheory.ADD_ASSOC, arithmeticTheory.ADD_COMM],
 metis_tac []]);

val lookup_tenv_deBruijn_subst_tenvE = Q.prove (
`∀n e targs tvs t inc.
  (lookup_tenv n inc e = SOME (tvs,t)) 
  ⇒
  (lookup_tenv n inc (deBruijn_subst_tenvE targs e) = 
     SOME (tvs, deBruijn_subst (tvs+inc+num_tvs e) (MAP (deBruijn_inc 0 (tvs+inc+num_tvs e)) targs) t))`,
induct_on `e` >>
rw [lookup_tenv_def,deBruijn_subst_tenvE_def, deBruijn_inc_def, num_tvs_def] >>
metis_tac [arithmeticTheory.ADD_ASSOC, type_e_subst_lem5]);

val subst_inc_cancel = Q.prove (
`(!t ts inc. 
  deBruijn_subst 0 ts (deBruijn_inc 0 (inc + LENGTH ts) t)
  =
  deBruijn_inc 0 inc t) ∧
 (!ts' ts inc. 
  MAP (deBruijn_subst 0 ts) (MAP (deBruijn_inc 0 (inc + LENGTH ts)) ts')
  =
  MAP (deBruijn_inc 0 inc) ts')`,
ho_match_mp_tac t_induction >>
rw [deBruijn_subst_def, deBruijn_inc_def] >>
full_simp_tac (srw_ss()++ARITH_ss) [] >>
metis_tac []);

val type_e_subst_lem7 = Q.prove (
`(!t sk targs targs' tvs' tvs''.
  (deBruijn_subst sk (MAP (deBruijn_inc 0 sk) targs') (deBruijn_subst 0 targs t) =
   deBruijn_subst 0 (MAP (deBruijn_subst sk (MAP (deBruijn_inc 0 sk) targs')) targs) 
     (deBruijn_subst (LENGTH targs + sk) (MAP (deBruijn_inc 0 (LENGTH targs + sk)) targs') t))) ∧
 (!ts sk targs targs' tvs' tvs''.
  (MAP (deBruijn_subst sk (MAP (deBruijn_inc 0 sk) targs')) (MAP (deBruijn_subst 0 targs) ts) =
  (MAP (deBruijn_subst 0 (MAP (deBruijn_subst sk (MAP (deBruijn_inc 0 sk) targs')) targs))
       (MAP (deBruijn_subst (LENGTH targs + sk) (MAP (deBruijn_inc 0 (LENGTH targs + sk)) targs')) ts))))`,
ho_match_mp_tac t_induction >>
rw [deBruijn_subst_def, deBruijn_inc_def] >>
fs [EL_MAP, MAP_MAP_o, combinTheory.o_DEF] >>
rw [] >>
full_simp_tac (srw_ss()++ARITH_ss) [EL_MAP, deBruijn_subst_def, check_freevars_def] >>
metis_tac [subst_inc_cancel, LENGTH_MAP]);

val lookup_freevars = Q.store_thm ("lookup_freevars",
`!n tenv tvs t.
  tenv_ok (bind_var_list2 tenv Empty) ∧
  (lookup n tenv = SOME (tvs, t))
  ⇒
  check_freevars tvs [] t`,
induct_on `tenv` >>
rw [lookup_def] >>
PairCases_on `h` >>
fs [lookup_def, bind_var_list2_def, tenv_ok_def, bind_tenv_def] >>
every_case_tac >>
fs [] >>
metis_tac [num_tvs_bvl2, arithmeticTheory.ADD_0, num_tvs_def]);

val type_p_subst = Q.store_thm ("type_p_subst",
`(!n tenvC p t tenv. type_p n tenvC p t tenv ⇒
    !targs' inc tvs targs.
    tenvC_ok tenvC ∧
    (n = inc + LENGTH targs) ∧
    EVERY (check_freevars tvs []) targs ∧
    (targs' = MAP (deBruijn_inc 0 inc) targs)
    ⇒
    type_p (inc + tvs) tenvC 
           p
           (deBruijn_subst inc targs' t)
           (MAP (\(x,t). (x, deBruijn_subst inc targs' t)) tenv)) ∧
 (!n tenvC ps ts tenv. type_ps n tenvC ps ts tenv ⇒
    !targs' inc targs tvs.
    tenvC_ok tenvC ∧
    (n = inc + LENGTH targs) ∧
    EVERY (check_freevars tvs []) targs ∧
    (targs' = MAP (deBruijn_inc 0 inc) targs)
    ⇒
    type_ps (inc +  tvs) tenvC 
           ps
           (MAP (deBruijn_subst inc targs') ts)
           (MAP (\(x,t). (x, deBruijn_subst inc targs' t)) tenv))`,
ho_match_mp_tac type_p_strongind >>
rw [] >>
ONCE_REWRITE_TAC [type_p_cases] >>
rw [deBruijn_subst_def, option_map_eqns, Tint_def,
    Tbool_def, Tunit_def, Tref_def] >|
[metis_tac [check_freevars_lem],
 rw [EVERY_MAP] >>
     fs [EVERY_MEM] >>
     rw [] >>
     metis_tac [check_freevars_lem, EVERY_MEM],
 metis_tac [type_subst_deBruijn_subst_list, lookup_con_ok],
 metis_tac []]); 

val deBruijn_subst_E_bind_var_list = Q.store_thm ("deBruijn_subst_E_bind_var_list",
`!tenv1 tenv2 tvs. 
  deBruijn_subst_tenvE targs (bind_var_list tvs tenv1 tenv2) 
  =
  bind_var_list tvs 
          (MAP (\(x,t). (x, deBruijn_subst (tvs + num_tvs tenv2) (MAP (deBruijn_inc 0 (tvs + num_tvs tenv2)) targs) t)) tenv1) 
          (deBruijn_subst_tenvE targs tenv2)`,
induct_on `tenv1` >>
rw [bind_var_list_def] >>
PairCases_on `h` >>
rw [bind_var_list_def, deBruijn_subst_tenvE_def, bind_tenv_def, num_tvs_bind_var_list]);

val db_merge_bind_var_list = Q.store_thm ("db_merge_bind_var_list",
`!tenv1 tenv2 tenv3 tvs.
  db_merge (bind_var_list tvs tenv1 tenv2) tenv3
  =
  bind_var_list tvs tenv1 (db_merge tenv2 tenv3)`,
induct_on `tenv1` >>
rw [bind_var_list_def] >>
PairCases_on `h` >>
rw [bind_var_list_def, db_merge_def, bind_tenv_def]);

val type_e_subst = Q.store_thm ("type_e_subst",
`(!tenvM tenvC tenvE e t. type_e tenvM tenvC tenvE e t ⇒
    !tenvE1 targs tvs targs'.
      (num_tvs tenvE2 = 0) ∧
      tenvM_ok tenvM ∧
      tenvC_ok tenvC ∧
      tenv_ok tenvE ∧
      (EVERY (check_freevars tvs []) targs) ∧
      (tenvE = db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2)) ∧
      (targs' = MAP (deBruijn_inc 0 (num_tvs tenvE1)) targs)
      ⇒
      type_e tenvM tenvC (db_merge (deBruijn_subst_tenvE targs tenvE1) (bind_tvar tvs tenvE2)) 
                   e
                   (deBruijn_subst (num_tvs tenvE1) targs' t)) ∧
 (!tenvM tenvC tenvE es ts. type_es tenvM tenvC tenvE es ts ⇒
    !tenvE1 targs tvs targs'.
      (num_tvs tenvE2 = 0) ∧
      tenvM_ok tenvM ∧
      tenvC_ok tenvC ∧
      tenv_ok tenvE ∧
      (EVERY (check_freevars tvs []) targs) ∧
      (tenvE = db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2)) ∧
      (targs' = MAP (deBruijn_inc 0 (num_tvs tenvE1)) targs)
      ⇒
    type_es tenvM tenvC (db_merge (deBruijn_subst_tenvE targs tenvE1) (bind_tvar tvs tenvE2))
                  es
                  (MAP (deBruijn_subst (num_tvs tenvE1) targs') ts)) ∧
 (!tenvM tenvC tenvE funs env. type_funs tenvM tenvC tenvE funs env ⇒
    !tenvE1 targs tvs targs'.
      (num_tvs tenvE2 = 0) ∧
      tenvM_ok tenvM ∧
      tenvC_ok tenvC ∧
      tenv_ok tenvE ∧
      (EVERY (check_freevars tvs []) targs) ∧
      (tenvE = db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2)) ∧
      (targs' = MAP (deBruijn_inc 0 (num_tvs tenvE1)) targs)
      ⇒
      type_funs tenvM tenvC (db_merge (deBruijn_subst_tenvE targs tenvE1) (bind_tvar tvs tenvE2)) 
                      funs 
                      (MAP (\(x,t). (x, deBruijn_subst (num_tvs tenvE1) targs' t)) env))`,
ho_match_mp_tac type_e_strongind >>
rw [] >>
ONCE_REWRITE_TAC [type_e_cases] >>
rw [deBruijn_subst_def, deBruijn_subst_tenvE_def, 
    bind_tvar_rewrites, bind_tenv_def, num_tvs_def, option_map_eqns,
    num_tvs_db_merge, num_tvs_deBruijn_subst_tenvE] >>
fs [deBruijn_subst_def, deBruijn_subst_tenvE_def, 
    bind_tvar_rewrites, bind_tenv_def, num_tvs_def, option_map_eqns,
    num_tvs_db_merge, num_tvs_deBruijn_subst_tenvE, tenv_ok_def,
    Tbool_def, Tint_def, Tunit_def, Tref_def, Tfn_def] >>
`tenv_ok tenvE2` by metis_tac [tenv_ok_db_merge, bind_tvar_def, tenv_ok_def] >|
[metis_tac [check_freevars_lem],
 qpat_assum `!tenvE1' targs' tvs'. P tenvE1' targs' tvs' ⇒
        type_e tenvM tenvC
          (db_merge (deBruijn_subst_tenvE targs' tenvE1')
             (bind_tvar tvs' tenvE2))
          e'
          (deBruijn_subst (num_tvs tenvE1')
             (MAP (deBruijn_inc 0 (num_tvs tenvE1')) targs') t)`
        (MP_TAC o Q.SPECL [`Bind_name var 0 Tint tenvE1`,
                           `targs`,
                           `tvs`]) >>
     rw [db_merge_def, Tint_def] >>
     fs [EVERY_MAP, EVERY_MEM, deBruijn_subst_tenvE_def, num_tvs_def,
         check_freevars_def, db_merge_def, deBruijn_subst_def],
 fs [EVERY_MAP, EVERY_MEM] >>
     rw [] >>
     metis_tac [check_freevars_lem, EVERY_MEM],
 metis_tac [type_subst_deBruijn_subst_list, lookup_con_ok],
 cases_on `n` >>
     fs [t_lookup_var_id_def] >|
     [imp_res_tac lookup_tenv_freevars >>
          fs [lookup_tenv_db_merge] >>
          cases_on `lookup_tenv a 0 tenvE1` >>
          fs [lookup_tenv_def, bind_tvar_rewrites, num_tvs_deBruijn_subst_tenvE] >>
          rw [] >|
          [imp_res_tac lookup_tenv_subst_none >>
               rw [] >>
               imp_res_tac lookup_tenv_inc_some >>
               rw [] >>
               pop_assum (ASSUME_TAC o Q.SPEC `num_tvs tenvE1 + tvs'`) >>
               fs [] >>
               rw [] >>
               imp_res_tac type_e_subst_lem1 >>
               fs [nil_deBruijn_inc] >>
               qexists_tac `(MAP (deBruijn_subst (num_tvs tenvE1) (MAP (deBruijn_inc 0 (num_tvs tenvE1)) targs')) targs)` >>
               rw [] >-
               metis_tac [deBruijn_subst2] >>
               fs [EVERY_MAP, EVERY_MEM, MEM_MAP] >>
               rw [] >>
               metis_tac [type_e_subst_lem3, EVERY_MEM],
           imp_res_tac lookup_tenv_deBruijn_subst_tenvE >>
               fs [] >>
               rw [] >>
               fs [nil_deBruijn_subst, num_tvs_db_merge, bind_tvar_rewrites] >>
               fs [EVERY_MAP, EVERY_MEM] >>
               rw [] >>
               qexists_tac `(MAP (deBruijn_subst (num_tvs tenvE1) (MAP (deBruijn_inc 0 (num_tvs tenvE1)) targs')) targs)`  >>
               rw [] >>
               fs [MEM_MAP] >>
               metis_tac [type_e_subst_lem3, EVERY_MEM, type_e_subst_lem7]],
      cases_on `lookup s tenvM` >>
          fs [] >>
          rw [] >>
          qexists_tac `MAP (deBruijn_subst (num_tvs tenvE1) (MAP (deBruijn_inc 0 (num_tvs tenvE1)) targs')) targs` >>
          rw [] >|
          [match_mp_tac (hd (CONJUNCTS deBruijn_subst2)) >>
               rw [] >>
               metis_tac [tenvM_ok_lookup, lookup_freevars, arithmeticTheory.ADD, arithmeticTheory.ADD_0],
           fs [EVERY_MAP, EVERY_MEM] >>
               rw [] >>
               metis_tac [type_e_subst_lem3, EVERY_MEM]]],
 qpat_assum `!tenvE1' targs' tvs'. P tenvE1' targs' tvs'` 
           (ASSUME_TAC o Q.SPEC `Bind_name n 0 t1 tenvE1`) >>
     fs [num_tvs_def, deBruijn_subst_tenvE_def, db_merge_def] >>
     metis_tac [type_e_subst_lem3],
 fs [type_uop_cases] >>
     rw [deBruijn_subst_def, Tref_def] >>
     fs [deBruijn_subst_def, Tref_def],
 fs [type_op_cases] >>
     rw [] >>
     fs [Tfn_def, Tint_def, Tunit_def, Tbool_def, Tref_def, deBruijn_subst_def] >>
     metis_tac [],
 fs [RES_FORALL] >>
     qexists_tac `deBruijn_subst (num_tvs tenvE1) (MAP (deBruijn_inc 0 (num_tvs tenvE1)) targs) t` >>
     rw [] >>
     PairCases_on `x` >>
     fs [MEM_MAP] >>
     qpat_assum `!x. MEM x pes ⇒ P x` (MP_TAC o Q.SPEC `(x0,x1)`) >>
     rw [] >>
     qexists_tac `MAP (\(x,t). (x, deBruijn_subst (num_tvs tenvE1) (MAP (deBruijn_inc 0 (num_tvs tenvE1)) targs) t))
                      tenv'` >>
     rw [] >-
     metis_tac [type_p_subst] >>
     pop_assum (MATCH_MP_TAC o 
                SIMP_RULE (srw_ss()) [num_tvs_bind_var_list, deBruijn_subst_E_bind_var_list,
                                      db_merge_bind_var_list] o
                Q.SPECL [`bind_var_list 0 tenv' tenvE1`, `targs`, `tvs`]) >>
     rw [] >>
     match_mp_tac tenv_ok_bind_var_list >>
     rw [num_tvs_db_merge, bind_tvar_rewrites] >>
     metis_tac [type_p_freevars],
 disj1_tac >>
     rw [] >>
     qexists_tac `deBruijn_subst (tvs + num_tvs tenvE1)
                        (MAP (deBruijn_inc 0 (tvs + num_tvs tenvE1)) targs) t` >>
     rw [] >|
     [qpat_assum `∀tenvE1' targs' tvs''.
                     EVERY (check_freevars tvs'' []) targs' ∧
                     (bind_tvar tvs
                        (db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2)) =
                      db_merge tenvE1' (bind_tvar (LENGTH targs') tenvE2)) ⇒
                     type_e tenvM tenvC
                       (db_merge (deBruijn_subst_tenvE targs' tenvE1')
                          (bind_tvar tvs'' tenvE2))
                       e
                       (deBruijn_subst (num_tvs tenvE1')
                          (MAP (deBruijn_inc 0 (num_tvs tenvE1')) targs') t)`
                (MP_TAC o Q.SPECL [`bind_tvar tvs tenvE1`, `targs`, `tvs'`]) >>
          rw [bind_tvar_rewrites] >>
          fs [MAP_MAP_o, combinTheory.o_DEF, deBruijn_inc_deBruijn_inc] >>
          metis_tac [],
      qpat_assum `∀tenvE1' targs' tvs''.
                     check_freevars (tvs + (num_tvs tenvE1 + LENGTH targs)) [] t ∧
                     EVERY (check_freevars tvs'' []) targs' ∧
                     (Bind_name n tvs t
                        (db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2)) =
                      db_merge tenvE1' (bind_tvar (LENGTH targs') tenvE2)) ⇒
                     type_e tenvM tenvC
                       (db_merge (deBruijn_subst_tenvE targs' tenvE1')
                          (bind_tvar tvs'' tenvE2))
                       e'
                       (deBruijn_subst (num_tvs tenvE1')
                          (MAP (deBruijn_inc 0 (num_tvs tenvE1')) targs') t')`
                 (MP_TAC o 
                  Q.SPECL [`Bind_name n tvs t tenvE1`, `targs`, `tvs'`]) >>
          rw [bind_tvar_rewrites, db_merge_def, deBruijn_subst_tenvE_def, 
              num_tvs_def] >>
          imp_res_tac type_e_freevars >>
          fs [tenv_ok_def, num_tvs_def, bind_tvar_rewrites, num_tvs_db_merge] >>
          fs [MAP_MAP_o, combinTheory.o_DEF, deBruijn_inc_deBruijn_inc] >>
          metis_tac [arithmeticTheory.ADD, arithmeticTheory.ADD_ASSOC, arithmeticTheory.ADD_COMM]],
 disj2_tac >>
     rw [] >>
     qexists_tac `deBruijn_subst (num_tvs tenvE1)
                        (MAP (deBruijn_inc 0 (num_tvs tenvE1)) targs) t` >>
     fs [deBruijn_inc0] >>
     rw [] >>
     qpat_assum `∀tenvE1' targs' tvs'.
                     check_freevars (skip' + LENGTH targs) [] t ∧
                     EVERY (check_freevars tvs' []) targs' ∧
                     (Bind_name n 0 t
                        (db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2)) =
                      db_merge tenvE1' (bind_tvar (LENGTH targs') tenvE2)) ⇒
                     type_e tenvM tenvC
                       (db_merge (deBruijn_subst_tenvE targs' tenvE1')
                          (bind_tvar tvs' tenvE2))
                       e'
                       (deBruijn_subst (num_tvs tenvE1')
                          (MAP (deBruijn_inc 0 (num_tvs tenvE1')) targs') t')`
                 (MP_TAC o 
                  Q.SPECL [`Bind_name n 0 t tenvE1`, `targs`, `tvs`]) >>
     rw [bind_tvar_rewrites, db_merge_def, deBruijn_subst_tenvE_def, 
         num_tvs_def] >>
     imp_res_tac type_e_freevars >>
     fs [tenv_ok_def, num_tvs_def, bind_tvar_rewrites, num_tvs_db_merge] >>
     metis_tac [arithmeticTheory.ADD, arithmeticTheory.ADD_ASSOC, arithmeticTheory.ADD_COMM],
 qexists_tac `MAP (λ(x,t').
                 (x,
                  deBruijn_subst (tvs + num_tvs tenvE1)
                    (MAP (deBruijn_inc 0 (tvs + num_tvs tenvE1)) targs)
                    t')) env` >>
     rw [] >|
     [qpat_assum `∀tenvE1' targs' tvs''.
                     tenv_ok
                       (bind_var_list 0 env
                          (bind_tvar tvs
                             (db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2)))) ∧
                     EVERY (check_freevars tvs'' []) targs' ∧
                     (bind_var_list 0 env
                        (bind_tvar tvs
                           (db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2))) =
                      db_merge tenvE1' (bind_tvar (LENGTH targs') tenvE2)) ⇒
                     type_funs tenvM tenvC
                       (db_merge (deBruijn_subst_tenvE targs' tenvE1')
                          (bind_tvar tvs'' tenvE2))
                       funs
                       (MAP
                          (λ(x,t).
                             (x,
                              deBruijn_subst (num_tvs tenvE1')
                                (MAP (deBruijn_inc 0 (num_tvs tenvE1')) targs') t))
                          env)`
                 (MP_TAC o 
                  Q.SPECL [`bind_var_list 0 env (bind_tvar tvs tenvE1)`, `targs`, `tvs'`]) >>
          rw [bind_tvar_rewrites, db_merge_bind_var_list, num_tvs_bind_var_list, 
              deBruijn_subst_E_bind_var_list] >>
          pop_assum match_mp_tac >>
          match_mp_tac tenv_ok_bind_var_list_funs >>
          rw [bind_tvar_rewrites] >>
          metis_tac [],
      qpat_assum `∀tenvE1' targs' tvs''.
                     tenv_ok
                       (bind_var_list tvs env
                          (db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2))) ∧
                     EVERY (check_freevars tvs'' []) targs' ∧
                     (bind_var_list tvs env
                        (db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2)) =
                      db_merge tenvE1' (bind_tvar (LENGTH targs') tenvE2)) ⇒
                     type_e tenvM tenvC
                       (db_merge (deBruijn_subst_tenvE targs' tenvE1')
                          (bind_tvar tvs'' tenvE2))
                       e
                       (deBruijn_subst (num_tvs tenvE1')
                          (MAP (deBruijn_inc 0 (num_tvs tenvE1')) targs') t)`
                 (MP_TAC o 
                  Q.SPECL [`bind_var_list tvs env tenvE1`, `targs`, `tvs'`]) >>
          rw [num_tvs_bind_var_list, deBruijn_subst_E_bind_var_list, db_merge_bind_var_list] >>
          pop_assum match_mp_tac >>
          match_mp_tac tenv_ok_bind_var_list_tvs >>
          metis_tac []],
 fs [check_freevars_def] >>
     qpat_assum `∀tenvE1' targs' tvs'.
               check_freevars (num_tvs tenvE1 + LENGTH targs) [] t1 ∧
               EVERY (check_freevars tvs' []) targs' ∧
               (Bind_name n 0 t1
                  (db_merge tenvE1 (bind_tvar (LENGTH targs) tenvE2)) =
                db_merge tenvE1' (bind_tvar (LENGTH targs') tenvE2)) ⇒
               type_e tenvM tenvC
                 (db_merge (deBruijn_subst_tenvE targs' tenvE1')
                    (bind_tvar tvs' tenvE2))
                 e
                 (deBruijn_subst (num_tvs tenvE1')
                    (MAP (deBruijn_inc 0 (num_tvs tenvE1')) targs') t)`
                 (MP_TAC o 
                  Q.SPECL [`Bind_name n 0 t1 tenvE1`, `targs`, `tvs`]) >>
     rw [deBruijn_subst_tenvE_def, db_merge_def, num_tvs_def] >|
     [metis_tac [check_freevars_lem],
      metis_tac [check_freevars_lem],
      fs [lookup_notin, MAP_MAP_o, combinTheory.o_DEF, LIST_TO_SET_MAP] >>
          CCONTR_TAC >>
          fs [] >>
          PairCases_on `x'` >>
          fs [] >>
          rw [] >>
          fs [] >>
          metis_tac [mem_lem]]]);

val check_ctor_tenv_dups_helper1 = Q.prove (
`∀tenvC l y z.
  (!x. MEM x l ⇒ (λ(n,ts). lookup (mk_id mn n) tenvC = NONE) x)
  ⇒
  DISJOINT (set (MAP (λx. FST ((λ(cn,ts). (mk_id mn cn,y,ts,mk_id mn z)) x)) l))
           (set (MAP FST tenvC))`,
induct_on `l` >>
rw [] >>
cases_on `h` >>
fs [] >>
`(λ(n,ts). lookup (mk_id mn n) tenvC = NONE) (q,r)` by metis_tac [] >>
fs [] >>
metis_tac [lookup_notin]);

val check_ctor_tenv_dups_helper2 = Q.prove (
`!mn tds tenvC.
  (∀((tvs,tn,condefs)::set tds) ((n,ts)::set condefs). lookup (mk_id mn n) tenvC = NONE) ⇒
    disjoint_env tenvC (build_ctor_tenv mn tds)`,
induct_on `tds` >>
rw [build_ctor_tenv_def, disjoint_env_def] >|
[fs [RES_FORALL] >>
     cases_on `h` >>
     fs [] >>
     cases_on `r` >>
     fs [] >>
     `(λ(tvs,tn,condefs).
         ∀x. MEM x condefs ⇒ (λ(n,ts). lookup (mk_id mn n) tenvC = NONE) x) (q,q',r')`
                by metis_tac [] >>
     fs [MAP_MAP_o, combinTheory.o_DEF] >>
     metis_tac [check_ctor_tenv_dups_helper1],
 fs [RES_FORALL] >>
     `disjoint_env tenvC (build_ctor_tenv mn tds)` by metis_tac [] >>
     fs [disjoint_env_def, build_ctor_tenv_def] >>
     metis_tac [DISJOINT_SYM]]);

val check_ctor_tenv_dups = Q.store_thm ("check_ctor_tenv_dups",
`!tenvC tds.
  check_ctor_tenv mn tenvC tds ⇒ disjoint_env tenvC (build_ctor_tenv mn tds)`,
rw [check_ctor_tenv_def, check_dup_ctors_def] >>
metis_tac [check_ctor_tenv_dups_helper2, RES_FORALL]);

val consistent_con_append = Q.prove (
`!envC tenvC.
  consistent_con_env envC tenvC ⇒
    ∀envC' tenvC'.
      consistent_con_env envC' tenvC'
      ⇒
      consistent_con_env (envC++envC') (tenvC++tenvC')`,
ho_match_mp_tac (fetch "-" "consistent_con_env_ind") >>
rw [consistent_con_env_def] >>
rw []);

val extend_consistent_con = Q.store_thm ("extend_consistent_con",
`!envC tenvC tds.
  consistent_con_env envC tenvC
  ⇒
  consistent_con_env (build_tdefs mn tds ++ envC)
                     (build_ctor_tenv mn tds ++ tenvC)`,
induct_on `tds` >>
rw [build_tdefs_def, build_ctor_tenv_def] >>
cases_on `h` >>
cases_on `r` >>
fs [] >>
`!x. (!cn ts. MEM (cn,ts) r' ⇒ MEM (cn,ts) x) ⇒
  consistent_con_env
  (MAP (λ(conN,ts). (mk_id mn conN,LENGTH ts,mk_id mn q')) r')
  (MAP (λ(cn,ts). (mk_id mn cn,q,ts,mk_id mn q')) r')`
            by (Induct_on `r'` >>
                rw [consistent_con_env_def] >>
                PairCases_on `h` >>
                fs [] >>
                rw [consistent_con_env_def] >>
                metis_tac []) >>
fs [build_ctor_tenv_def, build_tdefs_def] >>
metis_tac [consistent_con_append, APPEND_ASSOC]);

val check_dup_ctors_disj = Q.store_thm ("check_dup_ctors_disj",
`!tenvC tds.
  check_dup_ctors mn tenvC tds ⇒ disjoint_env tenvC (build_ctor_tenv mn tds)`,
rw [check_dup_ctors_def] >>
metis_tac [check_ctor_tenv_dups_helper2]);

val consistent_con_env_destruct_help = Q.prove (
`!l x y q q' l'.
  consistent_con_env
    (MAP (λ(conN,ts). (conN,LENGTH ts,{cn | (cn,ts) | MEM (cn,ts) l'})) l ++ x)
    (MAP (\(cn,ts). (cn,q,ts,q')) l ++ y)
  ⇒
  consistent_con_env x y`,
induct_on `l` >>
rw [] >>
cases_on `h` >>
fs [consistent_con_env_def] >>
metis_tac []);

val lookup_append = Q.store_thm ("lookup_append",
`!x e1 e2.
  lookup x (e1++e2) =
     case lookup x e1 of
        | NONE => lookup x e2
        | SOME v => SOME v`,
induct_on `e1` >>
rw [lookup_def] >>
every_case_tac >>
PairCases_on `h` >>
fs [lookup_def] >>
rw [] >>
fs []);

val lookup_append_none = Q.store_thm ("lookup_append_none",
`!x e1 e2. 
  (lookup x (e1++e2) = NONE) = (lookup x e1 = NONE) ∧ (lookup x e2 = NONE)`,
rw [lookup_append] >>
eq_tac >>
rw [] >>
cases_on `lookup x e1` >>
rw [] >>
fs []);

val lookup_reverse_none = Q.store_thm ("lookup_reverse_none",
`!x tenvC.
  (lookup x (REVERSE tenvC) = NONE) = (lookup x tenvC = NONE)`,
induct_on `tenvC` >>
rw [] >>
cases_on `h` >>
rw [lookup_def,lookup_append_none]);

val lookup_none_lem = Q.prove (
`!x h0 h1 h2 h3.
  (lookup x (MAP (λ(cn,ts). (mk_id mn cn,h0,ts,mk_id mn h1)) h2) = NONE)
  = 
  (lookup x (MAP (λ(conN,ts). (mk_id mn conN,LENGTH ts,mk_id mn h3)) h2) = NONE)`,
induct_on `h2` >>
rw [lookup_def] >>
PairCases_on `h` >>
rw [lookup_def]);

val lookup_none = Q.store_thm ("lookup_none",
`!tds tenvC envC x.
  !x. (lookup x (build_ctor_tenv mn tds) = NONE) =
      (lookup x (build_tdefs mn tds) = NONE)`,
Induct >>
rw [] >-
fs [build_ctor_tenv_def, build_tdefs_def, lookup_def] >>
rw [build_ctor_tenv_def, build_tdefs_def, lookup_def] >>
PairCases_on `h` >>
rw [lookup_append_none] >>
eq_tac >>
rw [] >|
[metis_tac [lookup_none_lem],
 metis_tac [build_ctor_tenv_def, build_tdefs_def, lookup_reverse_none],
 metis_tac [lookup_none_lem],
 metis_tac [build_ctor_tenv_def, build_tdefs_def, lookup_reverse_none]]);

val build_ctor_tenv_empty = Q.store_thm ("build_ctor_tenv_empty",
`build_ctor_tenv mn [] = []`,
rw [build_ctor_tenv_def]);

val build_ctor_tenv_cons = Q.prove (
`∀tvs tn ctors tds.
  build_ctor_tenv mn ((tvs,tn,ctors)::tds) =
    MAP (λ(cn,ts). (mk_id mn cn,tvs,ts,mk_id mn tn)) ctors ++ build_ctor_tenv mn tds`,
rw [build_ctor_tenv_def]);

val lemma = Q.prove (
`!f a b c. (\(x,y,z). f x y z) (a,b,c) = f a b c`,
rw []);

val every_conj_tup3 = Q.prove (
`!P Q l.
  EVERY (\(x,y,z). P x y z ∧ Q x y z) l =
  EVERY (\(x,y,z). P x y z) l ∧
  EVERY (\(x,y,z). Q x y z) l`,
induct_on `l` >>
rw [] >>
cases_on `h` >>
cases_on `r` >>
rw [] >>
metis_tac []);

val build_tdefs_cons = Q.prove (
`!tvs tn ctors tds.
  build_tdefs mn ((tvs,tn,ctors)::tds) =
    (MAP (\(conN,ts). (mk_id mn conN, LENGTH ts, mk_id mn tn))
        ctors) ++ build_tdefs mn tds`,
rw [build_tdefs_def]);

val check_dup_ctors_cons = Q.prove (
`!tvs ts ctors tds tenvC.
  check_dup_ctors mn tenvC ((tvs,ts,ctors)::tds)
  ⇒
  check_dup_ctors mn tenvC tds`,
induct_on `tds` >>
rw [check_dup_ctors_def, LET_THM, RES_FORALL] >-
metis_tac [] >-
metis_tac [] >>
PairCases_on `h` >>
fs [] >>
pop_assum MP_TAC >>
pop_assum (fn _ => all_tac) >>
induct_on `ctors` >>
rw [] >>
PairCases_on `h` >>
fs []);

val check_ctor_tenv_cons = Q.prove (
`!tvs ts ctors tds tenvC.
  check_ctor_tenv mn tenvC ((tvs,ts,ctors)::tds) ⇒
  check_ctor_tenv mn tenvC tds`,
rw [check_ctor_tenv_def] >>
metis_tac [check_dup_ctors_cons]);

val lookup_type = Q.prove (
`!x ctors tn tvs ts tn' tvs'.
  (lookup x (MAP (λ(cn,ts). (cn,tvs,ts,tn)) ctors) = SOME (tvs',ts,tn'))
  ⇒
  (tn = tn')`,
induct_on `ctors` >>
rw [lookup_def] >>
cases_on `h` >>
fs [lookup_def] >>
every_case_tac >>
fs [] >>
rw [] >>
metis_tac []);

val type_p_bvl = Q.store_thm ("type_p_bvl",
`(!tvs tenvC p t tenv. type_p tvs tenvC p t tenv ⇒
  !tenv'. tenv_ok tenv' ⇒ tenv_ok (bind_var_list tvs tenv tenv')) ∧
 (!tvs tenvC ps ts tenv. type_ps tvs tenvC ps ts tenv ⇒
  !tenv'. tenv_ok tenv' ⇒ tenv_ok (bind_var_list tvs tenv tenv'))`,
ho_match_mp_tac type_p_ind >>
rw [bind_var_list_def, tenv_ok_def, bind_tenv_def, num_tvs_def,
    bind_var_list_append] >>
`tvs + num_tvs tenv' ≥ tvs` by decide_tac >>
metis_tac [check_freevars_add]);

val deBruijn_subst_id = Q.store_thm ("deBruijn_subst_id",
`(!t n. check_freevars n [] t ⇒ (deBruijn_subst 0 (MAP Tvar_db (COUNT_LIST n)) t = t)) ∧
 (!ts n. EVERY (check_freevars n []) ts ⇒ (MAP (deBruijn_subst 0 (MAP Tvar_db (COUNT_LIST n))) ts = ts))`,
Induct >>
rw [deBruijn_subst_def, LENGTH_COUNT_LIST, EL_MAP, EL_COUNT_LIST,
    check_freevars_def] >>
metis_tac []);

val tenv_ok_bvl2 = Q.store_thm ("tenv_ok_bvl2",
`!tenv tenv'. 
  tenv_ok (bind_var_list2 tenv Empty) ∧ tenv_ok tenv'
  ⇒
  tenv_ok (bind_var_list2 tenv tenv')`,
ho_match_mp_tac bind_var_list2_ind >>
rw [bind_var_list2_def, tenv_ok_def, bind_tenv_def, num_tvs_bvl2, num_tvs_def] >>
`tvs + num_tvs tenv' ≥ tvs` by decide_tac >>
metis_tac [check_freevars_add]);

val bvl2_lookup = Q.store_thm ("bvl2_lookup",
`!n tenv. lookup n tenv = lookup_tenv n 0 (bind_var_list2 tenv Empty)`,
ho_match_mp_tac lookup_ind >>
rw [lookup_def, bind_var_list2_def, lookup_tenv_def] >>
cases_on `n''` >>
rw [bind_var_list2_def, lookup_tenv_def, bind_tenv_def, deBruijn_inc0]);

val freevars_t_lookup_var_id = Q.store_thm ("freevars_t_lookup_var_id",
`!tenvM tenv tvs n t.
  (t_lookup_var_id n tenvM tenv = SOME (tvs,t)) ∧
  tenvM_ok tenvM ∧
  tenv_ok tenv
  ⇒ 
  check_freevars (num_tvs tenv + tvs) [] t`,
rw [t_lookup_var_id_def] >>
every_case_tac >>
fs [] >|
[imp_res_tac lookup_tenv_freevars >>
     full_simp_tac (srw_ss()++ARITH_ss) [],
 imp_res_tac tenvM_ok_lookup >>
     imp_res_tac lookup_freevars >>
     `num_tvs tenv + tvs ≥ tvs` by decide_tac >>
     metis_tac [check_freevars_add]]);

val lookup_tenv_inc = Q.store_thm ("lookup_tenv_inc",
`!tvs l tenv n t.
  tenv_ok tenv ∧
  (num_tvs tenv = 0)
  ⇒
  ((lookup_tenv n 0 tenv = SOME (l,t))
   =
   (lookup_tenv n tvs tenv = SOME (l,t)))`,
induct_on `tenv` >>
rw [lookup_tenv_def, num_tvs_def, tenv_ok_def] >>
eq_tac >>
rw [] >>
fs [] >>
metis_tac [nil_deBruijn_inc, deBruijn_inc0]);

val bvl2_append = Q.store_thm ("bvl2_append",
`!tenv1 tenv3 tenv2.
  (bind_var_list2 (tenv1 ++ tenv2) tenv3 = 
   bind_var_list2 tenv1 (bind_var_list2 tenv2 tenv3))`,
ho_match_mp_tac bind_var_list2_ind >>
rw [bind_var_list2_def]);

val bvl2_to_bvl = Q.store_thm ("bvl2_to_bvl",
`!tvs tenv tenv'. bind_var_list2 (tenv_add_tvs tvs tenv) tenv' = bind_var_list tvs tenv tenv'`,
ho_match_mp_tac bind_var_list_ind >>
rw [bind_var_list_def, bind_var_list2_def, tenv_add_tvs_def]);

val type_funs_tenv_ok = Q.store_thm ("type_funs_tenv_ok",
`!funs tenvM tenvC env tenvE tvs env'.
  (num_tvs tenvE = 0) ∧
  type_funs tenvM tenvC (bind_var_list 0 env' (bind_tvar tvs tenvE)) funs env
  ⇒
  tenv_ok (bind_var_list tvs env Empty)`,
induct_on `funs` >>
rw [] >>
qpat_assum `type_funs x0 x1 x2 x3 x4` (ASSUME_TAC o SIMP_RULE (srw_ss()) [Once type_e_cases]) >>
fs [] >>
rw [check_freevars_def, bind_tenv_def, bind_var_list_def, tenv_ok_def] >>
cases_on `tvs = 0` >>
fs [check_freevars_def, num_tvs_bind_var_list, bind_tvar_def, num_tvs_def] >>
metis_tac [arithmeticTheory.ADD_0]);

val check_ctor_tenvC_ok_lem = Q.prove (
`!mn tenvC c. check_ctor_tenv mn tenvC c ⇒ 
  EVERY (\(cn,tvs,ts,tn). same_module cn tn ∧ EVERY (check_freevars 0 tvs) ts) (build_ctor_tenv mn c)`,
induct_on `c` >>
rw [build_ctor_tenv_def, tenvC_ok_def] >>
PairCases_on `h` >>
fs [check_ctor_tenv_def, EVERY_MAP] >|
[fs [EVERY_MEM] >>
     rw [] >>
     PairCases_on `x` >>
     fs [] >>
     rw [] >>
     res_tac >>
     fs [],
 fs [EVERY_MEM] >>
     rw [] >>
     PairCases_on `e` >>
     fs [MEM_FLAT, MEM_MAP] >>
     rw [] >>
     PairCases_on `y` >>
     fs [MEM_MAP] >>
     PairCases_on `y` >>
     fs [] >>
     rw [] >>
     res_tac >>
     fs [] >>
     res_tac >>
     fs []] >>
cases_on `mn` >>
rw [same_module_def, mk_id_def]);

val check_ctor_foldr_flat_map = Q.store_thm ("check_ctor_foldr_flat_map",
`!c. (let x2 = [] in
       FOLDR
         (λ(tvs,tn,condefs) x2.
            FOLDR (λ(n,ts) x2. n::x2) x2 condefs) x2 c)
    =
    FLAT (MAP (\(tvs,tn,condefs). (MAP (λ(n,ts). n)) condefs) c)`,
induct_on `c` >>
rw [LET_THM] >>
PairCases_on `h` >>
fs [LET_THM] >>
pop_assum (fn _ => all_tac) >>
induct_on `h2` >>
rw [] >>
PairCases_on `h` >>
rw []);

val check_ctor_tenvC_ok_lem2 = Q.prove (
`!c. 
  ALL_DISTINCT (FLAT (MAP (λ(p1,p1',p2). MAP (λ(p1'',p2). p1'') p2) c))
  ⇒
  ALL_DISTINCT (FLAT (MAP (λ(p1,p1',p2). MAP (λ(p1'',p2). mk_id mn p1'') p2) c))`,
rw [] >>
`FLAT (MAP (λ(p1,p1',p2). MAP (λ(p1'',p2). mk_id mn p1'') p2) c) =
 MAP (mk_id mn) (FLAT (MAP (λ(p1,p1',p2). MAP (λ(p1'',p2). p1'') p2) c))`
        by (rw [MAP_FLAT, MAP_MAP_o, combinTheory.o_DEF] >>
            pop_assum (fn _ => all_tac) >>
            induct_on `c` >>
            rw [] >>
            PairCases_on `h` >>
            rw [MAP_MAP_o, combinTheory.o_DEF] >>
            pop_assum (fn _ => all_tac) >>
            induct_on `h2` >>
            rw [] >>
            PairCases_on `h` >>
            rw []) >>
rw [] >>
`!(x:'c) y. (mk_id mn x = mk_id mn y) ⇒ (x = y)`
        by (cases_on `mn` >>
            rw [mk_id_def]) >>
metis_tac [all_distinct_map_inj]);

val check_ctor_tenvC_ok = Q.store_thm ("check_ctor_tenvC_ok",
`!mn tenvC c. check_ctor_tenv mn tenvC c ⇒ tenvC_ok (build_ctor_tenv mn c)`,
rw [tenvC_ok_def] >|
[fs [build_ctor_tenv_def, check_ctor_tenv_def, check_dup_ctors_def, RES_FORALL,
     MAP_FLAT, MAP_MAP_o, combinTheory.o_DEF, 
     LAMBDA_PROD, check_ctor_foldr_flat_map, check_ctor_tenvC_ok_lem2],
 metis_tac [check_ctor_tenvC_ok_lem]]);

val type_d_tenv_ok = Q.store_thm ("type_d_tenv_ok",
`!tvs tenvM tenvC tenv d tenvC' tenv' tenvM'' tenvC''.
  type_d tvs tenvM tenvC tenv d tenvC' tenv' ∧
  (num_tvs tenv = 0)
  ⇒
  tenv_ok (bind_var_list2 tenv' Empty)`,
rw [type_d_cases] >>
`tenv_ok Empty` by rw [tenv_ok_def] >>
imp_res_tac type_p_bvl >>
rw [bvl2_to_bvl] >|
[metis_tac [type_funs_tenv_ok],
 rw [bind_var_list2_def, emp_def, tenv_ok_def]]);

val type_ds_tenv_ok = Q.store_thm ("type_ds_tenv_ok",
`!tvs tenvM tenvC tenv ds tenvC' tenv'.
  type_ds tvs tenvM tenvC tenv ds tenvC' tenv' ⇒
  (num_tvs tenv = 0) ⇒
  tenv_ok (bind_var_list2 tenv' Empty)`,
ho_match_mp_tac type_ds_ind >>
rw [] >|
[rw [bind_var_list2_def, tenv_ok_def, emp_def],
 imp_res_tac type_d_tenv_ok >>
     fs [bvl2_append, merge_def, num_tvs_bvl2] >>
     metis_tac [tenv_ok_bvl2]]);

val type_d_tenvC_ok = Q.store_thm ("type_d_tenvC_ok",
`!tvs tenvM tenvC tenv d tenvC' tenv' tenvM'' tenvC''.
  type_d tvs tenvM tenvC tenv d tenvC' tenv'
  ⇒
  tenvC_ok tenvC' ∧
  disjoint_env tenvC' tenvC`,
rw [type_d_cases] >>
imp_res_tac type_p_bvl >>
rw [bvl2_to_bvl] >|
[rw [tenvC_ok_def, emp_def],
 rw [emp_def, disjoint_env_def],
 rw [tenvC_ok_def, emp_def],
 rw [emp_def, disjoint_env_def],
 rw [tenvC_ok_def, emp_def],
 rw [emp_def, disjoint_env_def],
 metis_tac [check_ctor_tenvC_ok],
 metis_tac [check_ctor_tenv_dups, disjoint_env_def, DISJOINT_SYM]]);

val type_ds_tenvC_ok = Q.store_thm ("type_ds_tenvC_ok",
`!tvs tenvM tenvC tenv ds tenvC' tenv'.
  type_ds tvs tenvM tenvC tenv ds tenvC' tenv' ⇒
  tenvC_ok tenvC' ∧
  disjoint_env tenvC' tenvC`,
ho_match_mp_tac type_ds_ind >>
rw [] >|
[rw [tenvC_ok_def, emp_def],
 rw [disjoint_env_def, emp_def],
 imp_res_tac type_d_tenvC_ok >>
     fs [bvl2_append, merge_def, num_tvs_bvl2, tenvC_ok_def, merge_def,
         ALL_DISTINCT_APPEND, disjoint_env_def, DISJOINT_DEF, EXTENSION] >>
     rw [] >>
     metis_tac [],
 imp_res_tac type_d_tenvC_ok >>
     fs [num_tvs_bvl2, merge_def, disjoint_env_def, DISJOINT_DEF, EXTENSION] >>
     rw [] >>
     metis_tac [type_d_tenvC_ok]]);

val type_specs_tenv_ok = Q.store_thm ("type_specs_tenv_ok",
`!tvs tenvC tenv specs tenvC' tenv'.
  type_specs tvs tenvC tenv specs tenvC' tenv' ⇒
  tenv_ok (bind_var_list2 tenv Empty) ⇒
  tenv_ok (bind_var_list2 tenv' Empty)`,
ho_match_mp_tac type_specs_ind >>
rw [] >>
qpat_assum `A ⇒ B` match_mp_tac >>
rw [bind_def, bind_var_list2_def, bind_tenv_def, tenv_ok_def, num_tvs_bvl2,
    num_tvs_def] >>
match_mp_tac check_freevars_subst_single >>
rw [rich_listTheory.LENGTH_COUNT_LIST, EVERY_MAP] >>
rw [EVERY_MEM] >>
fs [rich_listTheory.MEM_COUNT_LIST, check_freevars_def] >>
metis_tac [check_freevars_add, DECIDE ``!x:num. x ≥ 0``]);

val type_specs_tenvC_ok = Q.store_thm ("type_specs_tenvC_ok",
`!tvs tenvC tenv specs tenvC' tenv'.
  type_specs tvs tenvC tenv specs tenvC' tenv' ⇒
  tenvC_ok tenvC ⇒
  tenvC_ok tenvC'`,
ho_match_mp_tac type_specs_ind >>
rw [] >>
qpat_assum `A ⇒ B` match_mp_tac >>
fs [tenvC_ok_def, merge_def] >>
rw [] >|
[rw [ALL_DISTINCT_APPEND] >>
     imp_res_tac check_ctor_tenvC_ok >>
     fs [tenvC_ok_def] >>
     imp_res_tac check_ctor_tenv_dups >>
     fs [disjoint_env_def, DISJOINT_DEF, EXTENSION] >>
     metis_tac [],
 metis_tac [tenvC_ok_def, check_ctor_tenvC_ok]]);

val _ = export_theory ();

