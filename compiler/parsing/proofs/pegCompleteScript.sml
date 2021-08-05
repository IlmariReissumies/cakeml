(*
  Completeness proof for the parser. If a successful parse exists,
  then the parser will find one.
*)
open preamble
     pegTheory grammarTheory pegSoundTheory
     gramTheory gramPropsTheory cmlPEGTheory cmlNTPropsTheory

val _ = temp_delsimps ["lift_disj_eq", "lift_imp_disj"]

val _ = new_theory "pegComplete"
val _ = set_grammar_ancestry ["pegSound"]

val bindNT0_lemma = REWRITE_RULE [GSYM mkNd_def] bindNT0_def
val _ = augment_srw_ss [rewrites [bindNT0_lemma]]

fun SRULE ths = SIMP_RULE (srw_ss()) ths

val option_case_eq = Q.prove(
  ‘(option_CASE optv n sf = v) ⇔
     optv = NONE ∧ n = v ∨ ∃v0. optv = SOME v0 ∧ sf v0 = v’,
  Cases_on `optv` >> simp[]);
Theorem MAP_EQ_CONS[local]:
  MAP f l = h::t <=> ∃h0 t0. l = h0::t0 ∧ f h0 = h ∧ MAP f t0 = t
Proof metis_tac[MAP_EQ_CONS]
QED

val peg_det = CONJUNCT1 peg_deterministic

fun PULLV v t = let
  val (bv,b) = dest_abs(rand t)
in
  if bv ~~ v then ALL_CONV
  else BINDER_CONV (PULLV v) THENC SWAP_VARS_CONV
end t

fun REFINE_EXISTS_TAC t (asl, w) = let
  val (qvar, body) = dest_exists w
  val ctxt = free_varsl (w::asl)
  val qvars = op_set_diff aconv (free_vars t) ctxt
  val newgoal = subst [qvar |-> t] body
  fun chl [] ttac = ttac
    | chl (h::t) ttac = X_CHOOSE_THEN h (chl t ttac)
in
  SUBGOAL_THEN
    (list_mk_exists(rev qvars, newgoal))
    (chl (rev qvars) (fn th => Tactic.EXISTS_TAC t THEN ACCEPT_TAC th))
    (asl, w)
end


fun unify_firstconj k th (g as (asl,w)) = let
  val (exvs, body) = strip_exists w
  val c = hd (strip_conj body)
  val (favs, fabody) = strip_forall (concl th)
  val con = #2 (dest_imp fabody)
  val theta = Unify.simp_unify_terms (op_set_diff aconv (free_vars c) exvs) c con
  fun inst_exvs theta =
      case theta of
          [] => ALL_TAC
        | {redex,residue} :: rest =>
          if tmem redex exvs andalso
             HOLset.isEmpty (HOLset.intersection (FVL [residue] empty_tmset, HOLset.addList(empty_tmset,exvs)))
          then
            if HOLset.isEmpty (HOLset.intersection (FVL [residue] empty_tmset, HOLset.addList(empty_tmset,favs))) then
              CONV_TAC (PULLV redex) THEN EXISTS_TAC residue THEN
              inst_exvs rest
            else CONV_TAC (PULLV redex) THEN REFINE_EXISTS_TAC residue THEN
                 inst_exvs rest
          else inst_exvs rest
  fun inst_favs theta th =
      case theta of
          [] => k th
        | {redex,residue} :: rest =>
          if tmem redex favs then
            inst_favs rest (th |> CONV_RULE (PULLV redex) |> SPEC residue)
          else inst_favs rest th
in
  inst_exvs theta THEN inst_favs theta th
end g

Theorem seql_cons:
  ∀x. peg_eval G (i0, seql (h::t) f) x ⇔
        ∃r. peg_eval G (i0, h) r ∧
            ((∃fl fe. r = Failure fl fe ∧ x = r) ∨
             (∃i1 rh eo1 r2.
                r = Success i1 rh eo1 ∧
                peg_eval G (i1, seql t I) r2 ∧
                ((∃fl fe. r2 = Failure fl fe ∧ x = r2) ∨
                 ∃i rt eopt2.
                   r2 = Success i rt eopt2 ∧
                   x = Success i (f (rh ++ rt)) eopt2)))
Proof
  simp[pegSoundTheory.peg_eval_seql_CONS] >> gen_tac >> eq_tac >> rw[] >>
  rpt (dxrule_then assume_tac (cj 1 peg_deterministic)) >> simp[]
QED

Theorem seql_cons_SOME:
  peg_eval G (i0, seql (h::t) f) (Success i r eo) ⇔
  ∃i1 rh rt eo1.
    peg_eval G (i0, h) (Success i1 rh eo1) ∧
    peg_eval G (i1, seql t I) (Success i rt eo) ∧
    r = f (rh ++ rt)
Proof
  dsimp[seql_cons] >> metis_tac[]
QED

Theorem choicel_cons:
  peg_eval G (i0, cmlPEG$choicel (h::t)) x ⇔
    ∃r. peg_eval G (i0, h) r ∧
        ((∃i ptl eo. r = Success i ptl eo ∧ x = r) ∨
         (∃res2 fl1 fe1 i ptl eopt fl2 fe2.
            r = Failure fl1 fe1 ∧
            peg_eval G (i0,choicel t) res2 ∧
            (res2 = Success i ptl eopt ∧
             x = Success i ptl (optmax MAXerr (SOME (fl1,fe1)) eopt) ∨
             res2 = Failure fl2 fe2 ∧
             x = UNCURRY Failure (MAXerr (fl1, fe1) (fl2,fe2)))))
Proof
  simp[peg_eval_choicel_CONS] >> eq_tac >> rw[] >>
  rpt (dxrule_then assume_tac (cj 1 peg_deterministic)) >> simp[]
QED

Theorem choicel_cons_NONE:
  peg_eval G (i0, cmlPEG$choicel (h::t))
           (Failure fl fe : ((α#locs)list,γ list,δ)pegresult) ⇔
    ∃fl1 fe1 fl2 fe2.
      peg_eval G (i0, h) (Failure fl1 fe1) ∧
      peg_eval G (i0, choicel t) (Failure fl2 fe2) ∧
      Failure fl fe : ((α#locs)list,γ list,δ)pegresult =
      UNCURRY Failure (MAXerr (fl1,fe1) (fl2,fe2))
Proof
  dsimp[choicel_cons] >> metis_tac[]
QED

Theorem peg_eval_tok_CONS_NONE[simp]:
  peg_eval G (h::t, tok P f) (Failure fl fe) ⇔
    ∃tk l. h = (tk,l) ∧ fl = l ∧ fe = G.tokFALSE ∧ ¬P tk
Proof
  Cases_on ‘h’ >> simp[peg_eval_tok_NONE] >> metis_tac[]
QED

Theorem peg_eval_tok =
        SIMP_CONV (srw_ss()) [Once peg_eval_cases, EXISTS_PROD]
                  “peg_eval G (i0, tok P f) r”

Theorem peg_eval_tok_NIL[simp]:
  peg_eval G ([], tok P f) r ⇔ r = Failure (Locs EOFpt EOFpt) G.tokEOF
Proof
  simp[peg_eval_tok]
QED

val _ = augment_srw_ss [rewrites [
  peg_eval_tok_SOME, tokeq_def, bindNT_def, mktokLf_def,
  pegf_def, peg_eval_seq_SOME, pnt_def, peg_eval_try,
  try_def]]

val has_length = assert (can (find_term (same_const listSyntax.length_tm)) o
                         concl)

val peg_eval_choice_NONE =
  ``peg_eval G (i, choice s1 s2 f) (Failure fl fe)``
    |> SIMP_CONV (srw_ss()) [Once peg_eval_cases]

Theorem peg_eval_tokSymP_NONE[simp]:
  peg_eval G (i, tokSymP P) (Failure fl fe) ⇔
    (∀l tk t. i = (tk, l)::t ⇒
              (∀s. tk = SymbolT s ⇒ ¬P s ∧ fl = l ∧ fe = G.tokFALSE) ∧
              ((∀s. tk ≠ SymbolT s) ⇒ fl = l ∧ fe = G.tokFALSE)) ∧
    (i = [] ⇒ fl = Locs EOFpt EOFpt ∧ fe = G.tokEOF)
Proof
  simp[tokSymP_def, peg_eval_tok_NONE, EXISTS_PROD] >> Cases_on ‘i’ >> simp[] >>
  rename [‘hdi = (_,_)’] >> Cases_on ‘hdi’ >> simp[] >> metis_tac[]
QED

val disjImpI = Q.prove(`~p \/ q ⇔ p ⇒ q`, DECIDE_TAC)

Theorem ptree_head_eq_tok0[local]:
  (ptree_head pt = TOK tk) ⇔ (?l. pt = Lf (TOK tk,l))
Proof Cases_on `pt` >> Cases_on `p` >> simp[]
QED

Theorem ptree_head_eq_tok[simp] =
  CONJ ptree_head_eq_tok0
       (CONV_RULE (LAND_CONV (REWR_CONV EQ_SYM_EQ)) ptree_head_eq_tok0);

open NTpropertiesTheory
val cmlPEG_total =
    peg_eval_total |> Q.GEN `G` |> Q.ISPEC `cmlPEG`
                             |> C MATCH_MP PEG_wellformed

Theorem FLAT_EQ_CONS[local]:
  ∀ll h t.
     FLAT ll = h::t ⇔
     ∃p t0 s. ll = p ++ [h::t0] ++ s ∧
              EVERY ((=) []) p ∧ FLAT (t0::s) = t
Proof
  Induct >> simp[] >> rpt gen_tac >>
  rename [`list0 ++ FLAT ll = h::t`] >>
  Cases_on `list0` >> simp[]
  >- (eq_tac >> rw[]
      >- (rename [`[]::(pfx ++ [h::t0] ++ sfx)`] >>
          map_every qexists_tac [`[]::pfx`, `t0`, `sfx`] >> simp[]) >>
      rename [`EVERY ((=) []) pfx`] >> Cases_on `pfx` >> rfs[] >>
      metis_tac[]) >>
  eq_tac >> rw[]
  >- (qexists_tac `[]` >> simp[])
  >- (rename [`EVERY ((=) []) pfx`] >> Cases_on `pfx` >> rfs[] >> rw[]) >>
  rename [`EVERY ((=) []) pfx`] >> Cases_on `pfx` >- fs[] >>
  full_simp_tac bool_ss [EVERY_DEF] >> rw[] >> fs[]
QED

Theorem rfirstSet_nonempty_fringe:
   ∀pt t l rest.
     real_fringe pt = (TOK t, l) :: rest ∧ valid_lptree G pt ⇒
     t ∈ firstSet G [ptree_head pt]
Proof
  rw[] >>
  ‘∃r'. ptree_fringe pt = TOK t :: r'’ by simp[ptree_fringe_real_fringe] >>
  metis_tac[firstSet_nonempty_fringe, valid_lptree_def]
QED

Theorem peg_respects_firstSets:
   ∀N i0 t l.
      t ∉ firstSet cmlG [NT N] ∧ ¬peg0 cmlPEG (nt N I) ∧
      nt N I ∈ Gexprs cmlPEG ⇒
      ∃fl fe.
        peg_eval cmlPEG ((t,l)::i0, nt N I) (Failure fl fe)
Proof
  rpt gen_tac >> CONV_TAC CONTRAPOS_CONV >> simp[] >>
  Cases_on `nt N I ∈ Gexprs cmlPEG` >> simp[] >>
  drule_then (qspec_then `(t,l)::i0` $ qxchl [`r`] assume_tac) cmlPEG_total >>
  pop_assum (assume_tac o MATCH_MP (CONJUNCT1 peg_deterministic)) >>
  simp[] >>
  Cases_on ‘r’ >> simp[] >> rename [‘_ = Success i ptl eo’] >>
  `∃pt. ptl = [pt] ∧ ptree_head pt = NT N ∧ valid_lptree cmlG pt ∧
        MAP (TK ## I) ((t,l)::i0) = real_fringe pt ++ MAP (TK ## I) i`
    by metis_tac [peg_sound] >>
  rveq >> Cases_on `peg0 cmlPEG (nt N I)` >> simp[] >>
  `LENGTH i < LENGTH ((t,l)::i0)` by metis_tac [not_peg0_LENGTH_decreases] >>
  `real_fringe pt = [] ∨
   ∃tk tkl rest : (token # locs) list.
     real_fringe pt = (TK tk, tkl) :: MAP (TK ## I) rest`
    by (Cases_on `real_fringe pt` >> gvs[MAP_EQ_APPEND, MAP_EQ_CONS])
   >- (fs[] >> pop_assum kall_tac >>
       first_x_assum (mp_tac o Q.AP_TERM `LENGTH`) >> simp[]) >>
  gvs[] >> metis_tac [rfirstSet_nonempty_fringe]
QED

val fFail_def = new_specification(
  "fFail_def", ["fFAIL1", "fFAIL2"],
  SRULE [GSYM RIGHT_EXISTS_IMP_THM, SKOLEM_THM] peg_respects_firstSets);

Theorem peg_respects_firstSets_rwt =
        fFail_def |> SPEC_ALL |> UNDISCH_ALL |> MATCH_MP peg_det
                                             |> DISCH_ALL

Theorem peg_eval_NIL_NT:
  peg_eval cmlPEG ([], nt N I) (Success i r eo) ⇒
  nullableNT cmlG N ∧ i = []
Proof
  strip_tac >> drule_then strip_assume_tac peg_sound >> gvs[] >>
  CCONTR_TAC >> drule_all rfringe_length_not_nullable >> simp[]
QED

Theorem not_nullable_input_CONS:
  ¬nullableNT cmlG N ⇒ peg_eval cmlPEG (i0, nt N I) (Success i r eo) ⇒
  ∃ht l t. i0 = (ht,l)::t ∧ LENGTH i ≤ LENGTH t
Proof
  rpt strip_tac >> Cases_on ‘i0’ >- (drule peg_eval_NIL_NT >> simp[]) >>
  rename [‘peg_eval _ (h::_, _) _’] >>
  Cases_on ‘h’ >> simp[] >> drule_then strip_assume_tac peg_sound >>
  gvs[APPEND_EQ_CONS, MAP_EQ_APPEND] >> drule_all rfringe_length_not_nullable >>
  simp[]
QED

Theorem not_nullable_seql_input_CONS:
  ¬nullableNT cmlG N ⇒
  peg_eval cmlPEG (i0, seql (nt N I :: rest) f) (Success i r eo) ⇒
  ∃ht l t. i0 = (ht,l)::t ∧ LENGTH i ≤ LENGTH t
Proof
  csimp[seql_cons] >> rw[] >>
  drule_all_then strip_assume_tac not_nullable_input_CONS >> simp[] >>
  rpt (dxrule length_no_greater) >> simp[]
QED

Definition sym2peg_def:
  sym2peg (TOK tk) = tokeq tk ∧
  sym2peg (NT N) = nt N I
End

Theorem not_peg0_peg_eval_NIL_NONE:
   ¬peg0 G sym ∧ sym ∈ Gexprs G ∧ wfG G ⇒
   ∃fl fe. peg_eval G ([], sym) (Failure fl fe)
Proof
  strip_tac >>
  `∃r. peg_eval G ([], sym) r`
    by metis_tac [peg_eval_total] >>
  Cases_on `r` >> simp[SF SFY_ss] >>
  drule_all not_peg0_LENGTH_decreases >> simp[]
QED

val list_case_lemma = Q.prove(
  `([x] = case a of [] => [] | h::t => f h t) ⇔
    (a ≠ [] ∧ [x] = f (HD a) (TL a))`,
  Cases_on `a` >> simp[]);

(* only the subs = [x] and subs = [x;y] cases are relevant *)
Definition left_insert1_def:
  (left_insert1 pt (Lf (tk, l)) = Lf (tk, merge_locs (ptree_loc pt) l)) ∧
  (left_insert1 pt (Nd (n,l0) subs) =
     case subs of
         [] => Nd (n, merge_locs (ptree_loc pt) l0) [pt]
       | [x] => mkNd n [mkNd n [pt]; x]
       | x::xs => mkNd n (left_insert1 pt x :: xs))
End

open grammarTheory

Theorem left_insert1_FOLDL:
   left_insert1 pt (FOLDL (λa b. mkNd (mkNT P) [a; b]) acc arg) =
    FOLDL (λa b. mkNd (mkNT P) [a; b]) (left_insert1 pt acc) arg
Proof
  qid_spec_tac `acc` >> Induct_on `arg` >>
  fs[left_insert1_def,mkNd_def,ptree_list_loc_def]
QED

val _ = export_rewrites ["grammar.ptree_loc_def"]

Theorem ptree_loc_mkNd[simp]:
   ptree_loc (mkNd n subs) = ptree_list_loc subs
Proof
  simp[mkNd_def]
QED

Theorem merge_list_locs_HDLAST:
   ∀h. merge_list_locs (h::t) = merge_locs h (LAST (h::t))
Proof
  Induct_on ‘t’ >> simp[] >> Cases_on ‘t’ >> simp[]
QED

Theorem ptree_loc_left_insert1:
   ∀subpt pt.
      valid_locs pt ⇒
        ptree_loc (left_insert1 subpt pt) =
        merge_locs (ptree_loc subpt) (ptree_loc pt)
Proof
  ho_match_mp_tac left_insert1_ind >> simp[left_insert1_def, ptree_loc_def] >>
  rw[] >> Cases_on `subs` >> simp[] >> fs[] >> rename [`list_CASE t`] >>
  Cases_on `t` >>
  fs[mkNd_def, ptree_list_loc_def, locationTheory.merge_list_locs_def,
     merge_list_locs_HDLAST] >>
  rename [`MAP ptree_loc t2`] >> Cases_on ‘t2’ >> simp[]
QED

Definition leftLoc_def[simp]: leftLoc (Locs l1 _) = l1
End
Definition rightLoc_def[simp]: rightLoc (Locs _ l2) = l2
End

Theorem merge_locs_LR:
   merge_locs l1 l2 = Locs (leftLoc l1) (rightLoc l2)
Proof
  map_every Cases_on [‘l1’, ‘l2’] >> simp[locationTheory.merge_locs_def]
QED

Theorem leftLoc_merge_locs[simp]:
   leftLoc (merge_locs l1 l2) = leftLoc l1
Proof
  simp[merge_locs_LR]
QED

Theorem rightLoc_merge_locs[simp]:
   rightLoc (merge_locs l1 l2) = rightLoc l2
Proof
  simp[merge_locs_LR]
QED

(* two valid parse-trees with the same head, and the same fringes, which
   are all tokens, must be identical. *)

(* Problem with Eapp is that it's left-recursive in the grammar :

     Eapp ::= Eapp Ebase | Ebase

   but the PEG parses it by calling Ebase >> rpt Ebase, and then doing
   a FOLDL on the resulting list to assemble it into a valid parse-tree.

   Then, when it comes time to prove completeness (eapp_completeness
   below), we know that we have a valid Eapp parse-tree, but we expand
   the PEG invocation out into Ebase >> rpt Ebase, and do an induction on the
   length of the token-list to be consumed.  The gist of it all is that we
   end up wanting to know that if we've generated an Eapp to our right, then
   we can insert an Ebase from its left, generating a valid tree.

   This next result says that if we have a parse tree (i.e., with an
   Eapp (pt) to the left, and an Ebase bpt to the right, then we can
   "reassociate", giving us an Ebase (bpt') sitting to the left and an
   Eapp (pt') sitting to the right, such that left-inserting the
   former into the latter gives us back what we started with.
*)

Theorem eapp_reassociated:
   ∀pt bpt pf bf.
      valid_lptree cmlG pt ∧ ptree_head pt = NN nEapp ∧
      real_fringe pt = MAP (TK ## I) pf ∧
      valid_lptree cmlG bpt ∧ ptree_head bpt = NN nEbase ∧
      real_fringe bpt = MAP (TK ## I) bf ⇒
      ∃pt' bpt'.
        valid_lptree cmlG pt' ∧ valid_lptree cmlG bpt' ∧
        leftLoc (ptree_loc bpt') = leftLoc (ptree_loc pt) ∧
        rightLoc (ptree_loc pt') = rightLoc (ptree_loc bpt) ∧
        ptree_head pt' = NN nEapp ∧ ptree_head bpt' = NN nEbase ∧
        real_fringe bpt' ++ real_fringe pt' = MAP (TK ## I) (pf ++ bf) ∧
        mkNd (mkNT nEapp) [pt; bpt] = left_insert1 bpt' pt'
Proof
  simp[valid_lptree_def] >>
  ho_match_mp_tac grammarTheory.ptree_ind >>
  simp[MAP_EQ_CONS, cmlG_applied, cmlG_FDOM, FORALL_PROD, EXISTS_PROD] >>
  qx_gen_tac `subs` >> rpt strip_tac >>
  gvs[MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM]
  >- (rename [`[Nd _ [pt0; bpt0]; bpt]`,
              `ptree_head pt0 = NN nEapp`, `ptree_head bpt = NN nEbase`,
              `real_fringe pt0 = MAP _ pf`,
              `real_fringe bpt0 = MAP _ bf0`] >>
      first_x_assum $ qspec_then ‘bpt0’ (FREEZE_THEN drule_all) >>
      disch_then (qxchl [`ppt'`, `bpt'`] strip_assume_tac) >>
      map_every qexists_tac [`mkNd (mkNT nEapp) [ppt'; bpt]`, `bpt'`] >>
      dsimp[cmlG_FDOM, cmlG_applied, left_insert1_def, mkNd_def,
            ptree_list_loc_def, ptree_loc_def, ptree_loc_left_insert1] >>
      fs[mkNd_def, ptree_list_loc_def, merge_locs_LR]) >>
  rename [`[Nd _ [bpt0]; bpt]`] >>
  map_every qexists_tac [`mkNd (mkNT nEapp) [bpt]`, `bpt0`] >>
  dsimp[cmlG_applied, cmlG_FDOM, left_insert1_def, mkNd_def,
        ptree_list_loc_def, ptree_loc_def,
        locationTheory.merge_list_locs_def]
QED

Definition leftmost_def:
  leftmost (Lf s) = Lf s ∧
  leftmost (Nd (n,l) args) =
    if args ≠ [] ∧ n = mkNT nTbase then HD args
    else
      case args of
          [] => Nd (n,l) args
        | h::_ => leftmost h
End

(* pt is a Tbase, and n will be DType all the way down *)
Definition left_insert2_def[simp]:
  (left_insert2 pt (Lf (tk, l)) = Lf (tk, merge_locs (ptree_loc pt) l)) ∧
  (left_insert2 pt (Nd (n, l0) subs) =
     case subs of
         [] => Nd(n,merge_locs (ptree_loc pt) l0) [pt]
       | [Nd _ (* nTbase *) [tyop]] => mkNd n [mkNd n [pt]; tyop]
       | x::ys => mkNd n (left_insert2 pt x :: ys))
End

Theorem ptree_loc_left_insert2:
   ∀bpt dpt.
     valid_locs dpt ⇒
       ptree_loc (left_insert2 bpt dpt) =
       merge_locs (ptree_loc bpt) (ptree_loc dpt)
Proof
  ho_match_mp_tac left_insert2_ind >> rw[] >>
  rename [`MAP ptree_loc subs`] >> Cases_on `subs` >> fs[] >>
  rename [`list_CASE t`] >> reverse (Cases_on `t`) >> fs[]
  >- (simp[ptree_list_loc_def, merge_list_locs_HDLAST] >>
      rename [`MAP ptree_loc t2`] >> Cases_on `t2` >> simp[]) >>
  rename [`parsetree_CASE pt`] >> Cases_on `pt` >> fs[ptree_list_loc_def] >>
  rename [`list_CASE ptl`] >> Cases_on `ptl` >> fs[ptree_list_loc_def] >>
  rename [`list_CASE ptl'`] >> Cases_on `ptl'` >> fs[ptree_list_loc_def] >>
  rename [`Nd nl _`] >> Cases_on `nl` >> fs[]
QED

Theorem left_insert2_FOLDL:
   left_insert2 pt (FOLDL (λa b. mkNd (mkNT P) [a; b]) acc arg) =
    FOLDL (λa b. mkNd (mkNT P) [a; b]) (left_insert2 pt acc) arg
Proof
  qid_spec_tac `acc` >> Induct_on `arg` >> simp[] >> simp[mkNd_def]
QED

(* the situation with DType is similar to that with Eapp and Ebase.

   The grammar rules are

      DType ::= DType TyOp | Tbase

   and the PEG handles this by grabbing a TBase, and then a sequence
   of TyOps (think something like "num list option").

   The reassociated theorem to come states that if we have a good
   DType (num list) followed by a TyOp (option), then it's possible to
   recast this as a Tbase (num) followed by a DType (list option).
   This latter is bogus as an SML type, but is fine syntax because
   "list" is both a valid TyOp and thus a Tbase as well. The
   left_insert2 function does the work to turn something like

    DType -+- DType -- TBase -- TyOp -- "list"
           |
           `- TyOp  -- "option"

   into

    DType -+- DType --- DType --- TBase -- TyOp -- "num"
           |         |
           |         `- TyOp  -- "list"
           |
           `- TyOp -- "option"
*)

Theorem dtype_reassociated:
   ∀pt bpt pf bf.
      valid_lptree cmlG pt ∧ ptree_head pt = NN nDType ∧
      real_fringe pt = MAP (TK ## I) pf ∧
      valid_lptree cmlG bpt ∧ ptree_head bpt = NN nTyOp ∧
      real_fringe bpt = MAP (TK ## I) bf ⇒
      ∃pt' bpt'.
        valid_lptree cmlG pt' ∧ valid_lptree cmlG bpt' ∧
        valid_lptree cmlG (leftmost pt') ∧
        ptree_head (leftmost pt') = NN nTyOp ∧
        ptree_head pt' = NN nDType ∧ ptree_head bpt' = NN nTbase ∧
        real_fringe bpt' ++ real_fringe pt' = MAP (TK ## I) (pf ++ bf) ∧
        leftLoc (ptree_loc bpt') = leftLoc (ptree_loc pt) ∧
        rightLoc (ptree_loc pt') = rightLoc (ptree_loc bpt) ∧
        mkNd (mkNT nDType) [pt; bpt] = left_insert2 bpt' pt'
Proof
  ho_match_mp_tac grammarTheory.ptree_ind >> conj_tac
  >- dsimp[FORALL_PROD] >>
  simp[Once FORALL_PROD, MAP_EQ_CONS, cmlG_applied, cmlG_FDOM,
       valid_lptree_def] >>
  qx_gen_tac `subs` >> strip_tac >>
  map_every qx_gen_tac [`bpt`, `pf`, `bf`] >> strip_tac >>
  gvs[MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM, MAP_EQ_CONS, cmlG_FDOM,
      cmlG_applied]
  >- (rename [`[bpt0; oppt0]`, `ptree_head bpt0 = NN nDType`,
              `ptree_head oppt0 = NN nTyOp`,
              `real_fringe bpt0 = MAP _ bpf0`,
              `real_fringe oppt0 = MAP _ opf0`,
              `MAP _ bpf0 ++ MAP _ opf0 ++ MAP _ bf`,
              `real_fringe bpt = MAP _ bf`] >>
      first_x_assum (qspec_then `oppt0` (FREEZE_THEN drule_all)) >>
      simp[] >> disch_then (qxchl [`ppt'`, `bpt'`] strip_assume_tac) >>
      map_every qexists_tac [`mkNd (mkNT nDType) [ppt'; bpt]`, `bpt'`] >>
      dsimp[cmlG_FDOM, cmlG_applied, left_insert2_def, leftmost_def,
            mkNd_def, ptree_list_loc_def, ptree_loc_left_insert2,
            merge_locs_LR] >>
      fs[mkNd_def, ptree_list_loc_def, merge_locs_LR]) >>
  rename [‘ptree_head bpt0 = NN nTbase’] >>
  map_every qexists_tac
    [`mkNd (mkNT nDType) [mkNd (mkNT nTbase) [bpt]]`, `bpt0`] >>
  dsimp[cmlG_applied, cmlG_FDOM, left_insert2_def, leftmost_def, mkNd_def,
        ptree_list_loc_def]
QED

(*
  The next reassociation scenario is the general story of a left-associative
  binary operator, such that the rule is of the form

    P ::= P SEP C | C

  Imagine you have a valid P-tree to the right, and a single C to the left.
  You can insert that C-tree into the valid P-tree in the leftmost position,
  generating a new, valid P-tree.
*)


Definition left_insert_def:
  (left_insert (Lf (tk,l)) p sep c = Lf (tk,merge_locs (ptree_loc c) l)) ∧
  (left_insert (Nd (n,l) subs) p sep c =
     if n <> p then Nd (n,merge_locs (ptree_loc c) l) subs
     else
       case subs of
           [c0] => mkNd p [mkNd p [c]; sep; c0]
         | [p'; s'; c'] => mkNd p [left_insert p' p sep c; s'; c']
         | _ => Nd (n, merge_locs (ptree_loc c) l) subs)
End


Theorem left_insert_mkNd[simp]:
   (left_insert (mkNd n [c0]) n sep c = mkNd n [mkNd n [c]; sep; c0]) ∧
   (left_insert (mkNd n [p'; s'; c']) n sep c =
      mkNd n [left_insert p' n sep c; s'; c'])
Proof
  simp[left_insert_def, mkNd_def, ptree_list_loc_def]
QED

Theorem ptree_loc_left_insert:
   ∀bpt n sep c.
     valid_locs bpt ⇒
       ptree_loc (left_insert bpt n sep c) =
       merge_locs (ptree_loc c) (ptree_loc bpt)
Proof
  ho_match_mp_tac (theorem "left_insert_ind") >> simp[left_insert_def] >>
  simp[FORALL_PROD] >> rw[] >>
  rpt (rename [`list_CASE subtl`] >>
       Cases_on `subtl` >> simp[ptree_list_loc_def])
QED

Theorem lassoc_reassociated:
   ∀G P SEP C ppt spt cpt pf sf cf.
      G.rules ' P = {[NT P; SEP; C]; [C]} ⇒
      valid_lptree G ppt ∧ ptree_head ppt = NT P ∧
        real_fringe ppt = MAP (TOK ## I) pf ∧
      valid_lptree G spt ∧ ptree_head spt = SEP ∧
        real_fringe spt = MAP (TOK ## I) sf ∧
      valid_lptree G cpt ∧ ptree_head cpt = C ∧
        real_fringe cpt = MAP (TOK ## I) cf ⇒
      ∃cpt' spt' ppt'.
        valid_lptree G ppt' ∧ ptree_head ppt' = NT P ∧
        valid_lptree G spt' ∧ ptree_head spt' = SEP ∧
        valid_lptree G cpt' ∧ ptree_head cpt' = C ∧
        real_fringe cpt' ++ real_fringe spt' ++ real_fringe ppt' =
          MAP (TOK ## I) (pf ++ sf ++ cf) ∧
        leftLoc (ptree_loc cpt') = leftLoc (ptree_loc ppt) ∧
        rightLoc (ptree_loc ppt') = rightLoc (ptree_loc cpt) ∧
        mkNd P [ppt; spt; cpt] = left_insert ppt' P spt' cpt'
Proof
  rpt gen_tac >> strip_tac >>
  map_every qid_spec_tac [`cf`, `sf`, `pf`, `cpt`, `spt`, `ppt`] >>
  ho_match_mp_tac grammarTheory.ptree_ind >>
  simp[MAP_EQ_SING, valid_lptree_def] >>
  conj_tac >- dsimp[FORALL_PROD] >>
  qx_gen_tac `subs` >> strip_tac >>
  simp[MAP_EQ_CONS, FORALL_PROD] >>
  reverse (rpt strip_tac) >> gvs[]
  >- (qpat_x_assum `!x. PP x` kall_tac >>
      rename1 `real_fringe c0pt = MAP _ pf` >>
      map_every qexists_tac [`c0pt`, `spt`, `mkNd P [cpt]`] >>
      simp[] >> simp[mkNd_def]) >>
  gvs [MAP_EQ_APPEND] >>
  rename [`ptree_head ppt = NT P`, `[ppt; s0pt; c0pt]`,
          `ptree_head s0pt = ptree_head spt`,
          `ptree_head cpt = ptree_head c0pt`,
          `real_fringe ppt = MAP _ pf`,
          `real_fringe s0pt = MAP _ sf0`,
          `real_fringe c0pt = MAP _ cf0`] >>
  first_x_assum (fn th =>
    qspec_then `ppt` (mp_tac o REWRITE_RULE []) th >>
    disch_then (mp_tac o assert (is_forall o concl))) >>
  simp[] >>
  disch_then (qspecl_then [`s0pt`, `c0pt`, `sf0`, `cf0`] mp_tac) >>
  simp[] >>
  disch_then (qxchl [`cpt'`, `spt'`, `ppt'`] strip_assume_tac) >>
  map_every qexists_tac [`cpt'`, `spt'`, `mkNd P [ppt'; spt; cpt]`] >>
  simp[DISJ_IMP_THM, FORALL_AND_THM, left_insert_def] >>
  simp[ptree_list_loc_def] >>
  fs[mkNd_def, ptree_list_loc_def, ptree_loc_left_insert] >>
  simp[merge_locs_LR]
QED

Theorem left_insert_mk_linfix:
   left_insert (mk_linfix N acc arg) N s c =
    mk_linfix N (left_insert acc N s c) arg
Proof
  qid_spec_tac `acc` >> completeInduct_on `LENGTH arg` >> rw[] >>
  full_simp_tac (srw_ss() ++ DNF_ss)[] >>
  `arg = [] ∨ ∃h1 t. arg = h1::t` by (Cases_on `arg` >> simp[])
  >- simp[mk_linfix_def] >>
  `t = [] ∨ ∃h2 t2. t = h2::t2` by (Cases_on `t` >> simp[])
  >- simp[mk_linfix_def] >>
  rw[] >> simp[mk_linfix_def, left_insert_def]
QED

val elim_disjineq = Q.prove( `p \/ x ≠ y ⇔ (x = y ⇒ p)`, DECIDE_TAC)
val elim_det = Q.prove(`(!x. P x ⇔ (x = y)) ==> P y`, METIS_TAC[])

Theorem peg_seql_NONE_det:
   peg_eval G (i0, seql syms f) (Failure fl fe) ⇒
    ∀f' r. peg_eval G (i0, seql syms f') r ⇔ r = (Failure fl fe)
Proof
  Induct_on `syms` >> simp[seql_cons] >> rpt strip_tac >>
  rpt (first_x_assum (assume_tac o MATCH_MP peg_det)) >> simp[]
QED

fun has_const c = assert (Lib.can (find_term (same_const c)) o concl)

Theorem firstSet_respect_peg_eval_not_success:
  t ∉ firstSet cmlG [NT N] ∧ ¬peg0 cmlPEG (nt N I) ∧ nt N I ∈ Gexprs cmlPEG ⇒
  ¬peg_eval cmlPEG ((t,l)::i0, nt N I) (Success i r e0)
Proof
  rpt strip_tac >>
  ‘∃fl fe. peg_eval cmlPEG ((t,l)::i0, nt N I) (Failure fl fe)’
     suffices_by (first_assum (assume_tac o MATCH_MP peg_det) >> simp[]) >>
  simp[peg_respects_firstSets]
QED

Theorem eOR_wrongtok:
   ¬peg_eval cmlPEG ((RaiseT,loc)::i0, nt (mkNT nElogicOR) I) (Success i r eo) ∧
   ¬peg_eval cmlPEG ((FnT,loc)::i0, nt (mkNT nElogicOR) I) (Success i r eo) ∧
   ¬peg_eval cmlPEG ((CaseT,loc)::i0, nt (mkNT nElogicOR) I) (Success i r eo) ∧
   ¬peg_eval cmlPEG ((IfT,loc)::i0, nt (mkNT nElogicOR) I) (Success i r eo)
Proof
  simp[firstSet_respect_peg_eval_not_success]
QED

Theorem peg_eval_seqempty:
  peg_eval G (i0, seq e1 (empty []) f) r =
  ∃r0. peg_eval G (i0, e1) r0 ∧
       ((∃fl fe. r0 = Failure fl fe ∧ r = r0) ∨
        (∃i r00 eo. r0 = Success i r00 eo ∧ r = Success i (f r00 []) NONE))
Proof
  simp[SimpLHS, Once peg_eval_cases] >> dsimp[] >> metis_tac[]
QED

Theorem peg_eval_NT:
  peg_eval G (i0, nt N f) r ⇔
    ∃r0. r = resultmap f r0 ∧ N ∈ FDOM G.rules ∧ peg_eval G (i0, G.rules ' N) r0
Proof
  simp[Once peg_eval_cases] >> metis_tac[]
QED

Theorem nE'_nE:
  ∀i0 i r eo.
    peg_eval cmlPEG (i0, nt (mkNT nE') I) (Success i r eo) ∧
    (i ≠ [] ⇒ FST (HD i) ≠ HandleT) ⇒
    ∃r'. peg_eval cmlPEG (i0, nt (mkNT nE) I) (Success i r' eo)
Proof
  gen_tac >> completeInduct_on `LENGTH i0` >> gen_tac >> strip_tac >>
  full_simp_tac (srw_ss() ++ DNF_ss) [AND_IMP_INTRO] >>
  simp[peg_eval_NT_SOME] >> REWRITE_TAC[cmlpeg_rules_applied] >>
  qmatch_goalsub_abbrev_tac
    ‘choicel (_ :: pegf (pnt nEhandle) _ :: iteblock)’ >>
  simp[Once choicel_cons, SimpL “$==>”, seql_cons] >> rpt strip_tac >>
  gvs[] >~
  [‘peg_eval _ (_, tok ($= RaiseT) _) (Failure _ _)’]
  >- (qpat_x_assum ‘peg_eval _ (_, tok _ _) (Failure _ _)’ $
        mp_then Any assume_tac peg_det >>
      simp[Once choicel_cons, seql_cons] >>
      simp[Once choicel_cons, peg_eval_seqempty] >>
      simp[Once peg_eval_NT, cmlpeg_rules_applied, FDOM_cmlPEG] >>
      RULE_ASSUM_TAC (ONCE_REWRITE_RULE [choicel_cons]) >> gvs[]
      >- (dxrule_then assume_tac peg_det >> simp[seql_cons] >>
          simp[Once choicel_cons, seql_cons] >> Cases_on ‘i’ >> gs[] >>
          simp[peg_eval_tok] >- simp[Once choicel_cons] >>
          rename [‘FST h ≠ HandleT’] >> Cases_on ‘h’ >> gvs[] >>
          simp[choicel_cons]) >>
      gvs[peg_eval_seqempty] >> dxrule_then assume_tac peg_det >>
      simp[seql_cons] >>
      gvs[choicel_cons, seql_cons, PULL_EXISTS] >>
      qmatch_asmsub_abbrev_tac ‘Abbrev (_ = seql _ _ :: fncaseblock)’ >>
      simp[Abbr‘iteblock’, choicel_cons,
           Once seql_cons, peg_eval_tok] >>
      RM_ALL_ABBREVS_TAC >>
      qmatch_goalsub_abbrev_tac ‘seql (nt (mkNT nE) I :: thenb)’ >>
      simp[seql_cons] >>
      drule_then assume_tac length_no_greater >>
      dxrule_then assume_tac peg_det >> gs[] >>
      qmatch_asmsub_abbrev_tac ‘Abbrev (_ = _ :: _ :: elseb)’ >>
      simp[Abbr‘thenb’, peg_eval_tok, seql_cons] >>
      drule_then assume_tac length_no_greater >>
      dxrule_then assume_tac peg_det >> gs[] >>
      simp[Abbr‘elseb’, peg_eval_tok, seql_cons] >>
      first_x_assum $ drule_at (Pos $ el 2) >> simp[] >>
      strip_tac >> dxrule_then assume_tac peg_det >> simp[]) >~
  [‘peg_eval _ ((RaiseT, _)::_, _) _’]
  >- gvs[choicel_cons, eOR_wrongtok, seql_cons] >~
  [‘peg_eval _ (_, nt (mkNT nE') I) (Success _ _ _)’]
  >- (simp[choicel_cons, peg_eval_tok, seql_cons] >>
      first_x_assum $ drule_at (Pos $ el 2) >> simp[] >> strip_tac >>
      dxrule_then assume_tac peg_det >> simp[])
QED

Theorem nE'_bar_nE:
   ∀i0 i i' r r' eo eo'.
        peg_eval cmlPEG (i0, nt (mkNT nE) I) (Success i r eo) ∧
        (i ≠ [] ⇒ FST (HD i) ≠ BarT ∧ FST (HD i) ≠ HandleT) ∧ i' ≠ [] ∧
        peg_eval cmlPEG (i0, nt (mkNT nE') I) (Success i' r' eo') ⇒
        FST (HD i') ≠ BarT
Proof
  gen_tac >> completeInduct_on `LENGTH i0` >> rpt strip_tac >>
  full_simp_tac (srw_ss() ++ DNF_ss) [AND_IMP_INTRO] >> rw[] >>
  rpt (qpat_x_assum `peg_eval X Y Z` mp_tac) >>
  simp[peg_eval_NT_SOME] >>
  simp_tac std_ss [cmlpeg_rules_applied] >>
  simp_tac std_ss [Once choicel_cons] >> strip_tac
  >- ((* raise case *)
      simp_tac (list_ss ++ DNF_ss) [Once choicel_cons] >>
      simp_tac (list_ss ++ DNF_ss) [seql_cons] >>
      simp[] >> gvs[seql_cons] >> conj_tac
      >- (simp[elim_disjineq] >> rpt strip_tac >> gvs[] >>
          metis_tac[DECIDE “x < SUC x”]) >>
      simp[choicel_cons, peg_eval_tok, peg_eval_seqempty, eOR_wrongtok,
           FORALL_result, seql_cons]) >>
  gvs[] >>
  dxrule_then assume_tac peg_seql_NONE_det >>
  qabbrev_tac
  ‘ifb = λn : (token,MMLnonT,
               (token,MMLnonT,locs)parsetree list,string)pegsym.
           seql [tok ($= IfT) mktokLf; nt (mkNT nE) I;
                 tok ($= ThenT) mktokLf; nt (mkNT nE) I;
                 tok ($= ElseT) mktokLf; n]’ >> gvs[] >>
  qpat_x_assum `peg_eval cmlPEG X Y` mp_tac >>
  simp_tac std_ss [Once choicel_cons, pegf_def, peg_eval_seq_SOME,
                   peg_eval_empty, peg_eval_seq_NONE, pnt_def] >>
  strip_tac
  >- ((* handle case *)
      gvs[] >> pop_assum mp_tac >>
      simp[Once peg_eval_NT_SOME, elim_disjineq, disjImpI] >>
      simp[cmlpeg_rules_applied, seql_cons] >> rw[] >>
      simp[Once choicel_cons] >> simp[Once FORALL_result] >>
      simp[Once seql_cons, peg_eval_tok] >> simp[Once FORALL_result] >>
      drule_then strip_assume_tac
                 (MATCH_MP not_nullable_input_CONS nullable_ElogicOR) >>
      gvs[] >> rename [‘ht = RaiseT’] >> Cases_on ‘ht = RaiseT’ >> simp[]
      >- gvs[eOR_wrongtok] >>
      simp[seql_cons, peg_eval_tok] >> simp[Once choicel_cons] >>
      qpat_x_assum ‘peg_eval _ (_ :: _, nt (mkNT nElogicOR) I) _’
                   (mp_then (Pos hd) assume_tac peg_det) >>
      simp[peg_eval_seqempty] >> simp[elim_disjineq] >> rpt strip_tac >>
      gvs[choicel_cons]>> gvs[seql_cons, peg_eval_tok]) >> gvs[] >>
  rename [
      ‘peg_eval _ (i0, choicel [_; seql _ _; seql _ _]) (Success _ _ _)’] >>
  ‘∃ht l t. i0 = (ht,l) :: t ∧ ht ∈ {IfT; FnT; CaseT}’
    by (Cases_on ‘i0’ >> gvs[]
        >- gvs[choicel_cons, seql_cons_SOME, peg_eval_tok, Abbr‘ifb’] >>
        rename [‘peg_eval _ (h::t, _) _’] >> Cases_on ‘h’ >> simp[] >>
        CCONTR_TAC >> gvs[choicel_cons, Abbr‘ifb’, seql_cons, peg_eval_tok]) >>
  reverse (gvs[])
  >- ((* CaseT *) simp[choicel_cons, seql_cons, Abbr‘ifb’, peg_eval_tok,
                       peg_eval_seqempty] >>
      simp[FORALL_result, eOR_wrongtok])
  >- ((* FnT *)simp[choicel_cons, seql_cons, Abbr‘ifb’, peg_eval_tok,
                       peg_eval_seqempty] >>
      simp[FORALL_result, eOR_wrongtok]) >>
  (* if then else *)
  simp[Once choicel_cons, seql_cons, peg_eval_tok] >>
  simp[Once choicel_cons, peg_eval_seqempty] >>
  simp[FORALL_result, eOR_wrongtok] >>
  simp[elim_disjineq] >> rpt strip_tac >> simp[disjImpI] >> rpt strip_tac >>
  pop_assum mp_tac >>
  simp[choicel_cons, Abbr‘ifb’] >>
  simp[FORALL_result] >> gvs[] >>
  qpat_x_assum ‘peg_eval _ ((IfT,_)::_, choicel _) (Success _ _ _)’ mp_tac >>
  simp[Once choicel_cons] >> strip_tac >> gvs[]
  >- (pop_assum mp_tac >> simp[SimpL “$==>”, seql_cons_SOME, PULL_EXISTS] >>
      rpt gen_tac >> strip_tac >> gvs[] >>
      rpt (qpat_x_assum ‘peg_eval _ (_, nt (mkNT nE) I) (Success _ _ _)’
             (fn th => assume_tac (MATCH_MP length_no_greater th) >>
              mp_then (Pos hd) assume_tac peg_det th)) >>
      simp[seql_cons_SOME] >> simp[elim_disjineq] >> rpt strip_tac >> gvs[] >>
      first_x_assum $ drule_at (Pos last) >> simp[]) >>
  pop_assum mp_tac >>
  simp[choicel_cons, seql_cons, SimpL “$==>”, peg_eval_tok]
QED

Definition nestoppers_def:
  nestoppers =
     UNIV DIFF ({AndalsoT; ArrowT; BarT; ColonT; HandleT; OrelseT;
                 AlphaT "before"} ∪
                firstSet cmlG [NN nMultOps] ∪
                firstSet cmlG [NN nRelOps] ∪
                firstSet cmlG [NN nListOps] ∪
                firstSet cmlG [NN nAddOps] ∪
                firstSet cmlG [NN nCompOps] ∪
                firstSet cmlG [NN nEbase] ∪ firstSet cmlG [NN nTyOp])
End

Definition stoppers_def:
  (stoppers nAndFDecls = nestoppers DELETE AndT) ∧
  (stoppers nDconstructor =
     UNIV DIFF ({StarT; OfT; ArrowT; LparT} ∪ firstSet cmlG [NN nTyOp] ∪
                {TyvarT s | T})) ∧
  (stoppers nDecl =
     nestoppers DIFF ({BarT; StarT; AndT; OfT} ∪ {TyvarT s | T})) ∧
  (stoppers nDecls =
     nestoppers DIFF
     ({BarT; StarT; AndT; SemicolonT; FunT; ValT; DatatypeT; OfT; ExceptionT;
       TypeT; LocalT} ∪ {TyvarT s | T})) ∧
  (stoppers nDType = UNIV DIFF firstSet cmlG [NN nTyOp]) ∧
  (stoppers nDtypeCons =
     UNIV DIFF ({ArrowT; BarT; StarT; OfT; LparT} ∪ firstSet cmlG [NN nTyOp] ∪
                {TyvarT s | T})) ∧
  (stoppers nDtypeDecl =
     UNIV DIFF ({ArrowT; BarT; StarT; OfT; LparT} ∪ firstSet cmlG [NN nTyOp] ∪
                {TyvarT s | T})) ∧
  (stoppers nDtypeDecls =
     UNIV DIFF ({AndT; ArrowT; BarT; StarT; OfT; LparT} ∪ {TyvarT s | T} ∪
                firstSet cmlG [NN nTyOp])) ∧
  (stoppers nE = nestoppers) ∧
  (stoppers nE' = BarT INSERT nestoppers) ∧
  (stoppers nEadd =
     UNIV DIFF (firstSet cmlG [NN nMultOps] ∪
                firstSet cmlG [NN nAddOps] ∪
                firstSet cmlG [NN nEbase])) ∧
  (stoppers nEapp = UNIV DIFF firstSet cmlG [NN nEbase]) ∧
  (stoppers nEbefore =
     UNIV DIFF ({AlphaT "before"} ∪
                firstSet cmlG [NN nCompOps] ∪
                firstSet cmlG [NN nRelOps] ∪
                firstSet cmlG [NN nListOps] ∪
                firstSet cmlG [NN nMultOps] ∪
                firstSet cmlG [NN nAddOps] ∪
                firstSet cmlG [NN nEbase])) ∧
  (stoppers nEcomp =
     UNIV DIFF (firstSet cmlG [NN nCompOps] ∪
                firstSet cmlG [NN nRelOps] ∪
                firstSet cmlG [NN nListOps] ∪
                firstSet cmlG [NN nMultOps] ∪
                firstSet cmlG [NN nAddOps] ∪
                firstSet cmlG [NN nEbase])) ∧
  (stoppers nEhandle = nestoppers) ∧
  (stoppers nElist1 = nestoppers DELETE CommaT) ∧
  (stoppers nElist2 = nestoppers DELETE CommaT) ∧
  (stoppers nElistop = UNIV DIFF (firstSet cmlG [NN nMultOps] ∪
                                  firstSet cmlG [NN nAddOps] ∪
                                  firstSet cmlG [NN nListOps] ∪
                                  firstSet cmlG [NN nEbase])) ∧
  (stoppers nElogicAND =
     UNIV DIFF ({AndalsoT; ColonT; ArrowT; AlphaT "before"} ∪
                firstSet cmlG [NN nCompOps] ∪
                firstSet cmlG [NN nRelOps] ∪
                firstSet cmlG [NN nListOps] ∪
                firstSet cmlG [NN nMultOps] ∪
                firstSet cmlG [NN nAddOps] ∪
                firstSet cmlG [NN nEbase]∪ firstSet cmlG [NN nTyOp])) ∧
  (stoppers nElogicOR =
     UNIV DIFF ({AndalsoT; ColonT; ArrowT; OrelseT; AlphaT "before"} ∪
                firstSet cmlG [NN nCompOps] ∪
                firstSet cmlG [NN nRelOps] ∪
                firstSet cmlG [NN nListOps] ∪
                firstSet cmlG [NN nMultOps] ∪
                firstSet cmlG [NN nAddOps] ∪
                firstSet cmlG [NN nEbase] ∪ firstSet cmlG [NN nTyOp])) ∧
  (stoppers nEmult =
     UNIV DIFF (firstSet cmlG [NN nEbase] ∪
                firstSet cmlG [NN nMultOps])) ∧
  (stoppers nErel =
     UNIV DIFF (firstSet cmlG [NN nRelOps] ∪
                firstSet cmlG [NN nListOps] ∪
                firstSet cmlG [NN nMultOps] ∪
                firstSet cmlG [NN nAddOps] ∪
                firstSet cmlG [NN nEbase])) ∧
  (stoppers nEseq = nestoppers DELETE SemicolonT) ∧
  (stoppers nEtyped =
     UNIV DIFF ({ColonT; ArrowT; AlphaT "before"} ∪
                firstSet cmlG [NN nCompOps] ∪
                firstSet cmlG [NN nListOps] ∪
                firstSet cmlG [NN nRelOps] ∪
                firstSet cmlG [NN nMultOps] ∪
                firstSet cmlG [NN nAddOps] ∪
                firstSet cmlG [NN nEbase] ∪ firstSet cmlG [NN nTyOp])) ∧
  (stoppers nFDecl = nestoppers) ∧
  (stoppers nLetDec = nestoppers DELETE AndT) ∧
  (stoppers nLetDecs = nestoppers DIFF {AndT; FunT; ValT; SemicolonT}) ∧
  (stoppers nNonETopLevelDecs = ∅) ∧
  (stoppers nOptTypEqn =
     UNIV DIFF ({ArrowT; StarT; EqualsT} ∪ firstSet cmlG [NN nTyOp])) ∧
  (stoppers nPcons =
     UNIV DIFF ({LparT; UnderbarT; LbrackT; SymbolT "::"; OpT} ∪
                { IntT i | T } ∪ { StringT s | T } ∪ { CharT c | T } ∪
                firstSet cmlG [NN nV] ∪ firstSet cmlG [NN nConstructorName])) ∧
  (stoppers nPConApp =
     UNIV DIFF ({LparT; UnderbarT; LbrackT; OpT} ∪ { IntT i | T } ∪
                { StringT s | T } ∪ { CharT c | T } ∪
                firstSet cmlG [NN nV] ∪ firstSet cmlG [NN nConstructorName])) ∧
  (stoppers nPapp =
     UNIV DIFF ({LparT; UnderbarT; LbrackT; OpT} ∪ { IntT i | T } ∪
                { StringT s | T } ∪ { CharT c | T } ∪
                firstSet cmlG [NN nV] ∪ firstSet cmlG [NN nConstructorName])) ∧
  (stoppers nPattern =
     UNIV DIFF ({LparT; UnderbarT; LbrackT; ColonT; ArrowT; StarT; OpT} ∪
                { AlphaT s | T } ∪ { SymbolT s | T } ∪ { LongidT s1 s2 | T } ∪
                { IntT i | T } ∪ { StringT s | T } ∪ { CharT c | T } ∪
                firstSet cmlG [NN nV] ∪ firstSet cmlG [NN nConstructorName])) ∧
  (stoppers nPatternList =
     UNIV DIFF ({CommaT; LparT; UnderbarT; LbrackT; ColonT; ArrowT; StarT; OpT}∪
                { AlphaT s | T } ∪ { SymbolT s | T } ∪ { LongidT s1 s2 | T } ∪
                {IntT i | T} ∪ { StringT s | T } ∪ { CharT c | T } ∪
                firstSet cmlG [NN nV] ∪ firstSet cmlG [NN nConstructorName])) ∧
  (stoppers nPbaseList1 = UNIV DIFF firstSet cmlG [NN nPbase]) ∧
  (stoppers nPE = nestoppers) ∧
  (stoppers nPE' = BarT INSERT nestoppers) ∧
  (stoppers nPEs = nestoppers) ∧
  (stoppers nPType = UNIV DIFF ({StarT} ∪ firstSet cmlG [NN nTyOp])) ∧
  (stoppers nSpecLine =
     UNIV DIFF ({ArrowT; AndT; BarT; StarT; OfT; EqualsT; LparT} ∪
                firstSet cmlG [NN nTyOp] ∪ {TyvarT s | T})) ∧
  (stoppers nSpecLineList =
     UNIV DIFF ({ValT; DatatypeT; TypeT; ExceptionT; SemicolonT;
                 ArrowT; AndT; BarT; StarT; OfT; EqualsT; LparT} ∪
                firstSet cmlG [NN nTyOp] ∪ {TyvarT s | T})) ∧
  (stoppers nTbaseList =
     UNIV DIFF ({LparT} ∪ firstSet cmlG [NN nTyOp] ∪ {TyvarT s | T})) ∧
  (stoppers nTopLevelDec =
     nestoppers DIFF ({LparT; BarT; StarT; AndT; OfT} ∪ {TyvarT s | T})) ∧
  (stoppers nTopLevelDecs = ∅) ∧
  (stoppers nType = UNIV DIFF ({ArrowT; StarT} ∪ firstSet cmlG [NN nTyOp])) ∧
  (stoppers nTypeAbbrevDec =
     UNIV DIFF ({ArrowT; StarT} ∪ firstSet cmlG [NN nTyOp])) ∧
  (stoppers nTypeDec =
     UNIV DIFF ({AndT; ArrowT; StarT; BarT; OfT; LparT} ∪ {TyvarT s | T} ∪
                firstSet cmlG [NN nTyOp])) ∧
  (stoppers nTypeList1 =
     UNIV DIFF ({CommaT; ArrowT; StarT} ∪ firstSet cmlG [NN nTyOp])) ∧
  (stoppers nTypeList2 =
     UNIV DIFF ({CommaT; ArrowT; StarT} ∪ firstSet cmlG [NN nTyOp])) ∧
  (stoppers nTyVarList = {RparT}) ∧
  (stoppers nOptionalSignatureAscription = UNIV DELETE SealT) ∧
  (stoppers _ = UNIV)
End

val normlist = REWRITE_TAC [GSYM APPEND_ASSOC, listTheory.APPEND]


Theorem left_insert1_mkNd:
   left_insert1 pt1 (mkNd (mkNT nEapp) [pt2]) =
   mkNd (mkNT nEapp) [mkNd (mkNT nEapp) [pt1]; pt2]
Proof
  simp[mkNd_def, left_insert1_def]
QED

Theorem eapp_complete:
   (∀pt' pfx' sfx' N.
       LENGTH pfx' < LENGTH master ∧ valid_lptree cmlG pt' ∧
       mkNT N ∈ FDOM cmlPEG.rules ∧
       ptree_head pt' = NN N ∧ real_fringe pt' = MAP (TK ## I) pfx' ∧
       (sfx' ≠ [] ⇒ FST (HD sfx') ∈ stoppers N) ⇒
       ∃eo.
         peg_eval cmlPEG (pfx' ++ sfx', nt(mkNT N)I) (Success sfx' [pt'] eo)) ∧
    (∀pt' sfx'.
       valid_lptree cmlG pt' ∧ ptree_head pt' = NN nEbase ∧
       real_fringe pt' = MAP (TK ## I) master ∧
       (sfx' ≠ [] ⇒ FST (HD sfx') ∈ stoppers nEbase) ⇒
       ∃eo.
       peg_eval cmlPEG (master ++ sfx', nt (mkNT nEbase) I)
                (Success sfx' [pt'] eo))
    ⇒
     ∀pfx apt sfx.
       IS_SUFFIX master pfx ∧ valid_lptree cmlG apt ∧
       ptree_head apt = NN nEapp ∧ real_fringe apt = MAP (TK ## I) pfx ∧
       (sfx ≠ [] ⇒ FST (HD sfx) ∈ stoppers nEapp) ⇒
       ∃eo.
         peg_eval cmlPEG (pfx ++ sfx, nt (mkNT nEapp) I) (Success sfx [apt] eo)
Proof
  strip_tac >>
  simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, (*list_case_lemma, *)
       peg_eval_rpt, GSYM LEFT_EXISTS_AND_THM, GSYM RIGHT_EXISTS_AND_THM,
       valid_lptree_thm] >>
  gen_tac >>
  completeInduct_on ‘LENGTH pfx’ >> qx_gen_tac ‘pfx’ >> strip_tac >>
  rveq >> fs[GSYM RIGHT_FORALL_IMP_THM] >>
  map_every qx_gen_tac [‘apt’, ‘sfx’] >> strip_tac >>
  ‘∃subs. apt = mkNd (mkNT nEapp) subs’
    by metis_tac[ptree_head_NT_mkNd] >>
  fs[MAP_EQ_CONS, MAP_EQ_APPEND, cmlG_FDOM, cmlG_applied, valid_lptree_thm] >>
  rw[] >>
  fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >> rw[]
  >- ((* complicated "step case", where production was Eapp -> Eapp Ebase *)
      rename [‘ptree_head apt = NN nEapp’,
              ‘real_fringe apt = MAP _ af’,
              ‘ptree_head bpt = NN nEbase’,
              ‘real_fringe bpt = MAP _ bf’] >>
      qspecl_then [‘apt’, ‘bpt’, ‘af’, ‘bf’] mp_tac eapp_reassociated >>
      simp[MAP_EQ_APPEND, GSYM LEFT_EXISTS_AND_THM, GSYM RIGHT_EXISTS_AND_THM]>>
      disch_then (qxchl [‘apt'’, ‘bpt'’, ‘bf'’, ‘af'’] strip_assume_tac) >>
      drule (MATCH_MP rfringe_length_not_nullable nullable_Ebase) >>
      drule (MATCH_MP rfringe_length_not_nullable nullable_Eapp) >>
      simp[] >> ntac 2 strip_tac >>
      ‘LENGTH (af ++ bf) ≤ LENGTH master’
        by (Q.UNDISCH_THEN ‘af ++ bf = bf' ++ af'’ SUBST_ALL_TAC >>
            fs[IS_SUFFIX_compute] >>
            imp_res_tac rich_listTheory.IS_PREFIX_LENGTH >> fs[]) >>
      ‘LENGTH af + LENGTH bf = LENGTH bf' + LENGTH af'’
        by metis_tac [listTheory.LENGTH_APPEND] >> simp[] >> gvs[] >>
      ‘LENGTH bf' < LENGTH master’ by simp[] >>
      ‘mkNT nEbase ∈ FDOM cmlPEG.rules’ by simp[FDOM_cmlPEG] >>
      first_x_assum $ drule_then (drule_then $ dxrule) >> simp[stoppers_def] >>
      disch_then $ qspec_then ‘af' ++ sfx’ strip_assume_tac >>
      dxrule_then assume_tac peg_det >> gvs[] >>
      simp[seql_cons_SOME, PULL_EXISTS, AllCaseEqs()] >>
      ‘LENGTH af' < LENGTH af' + LENGTH bf'’ by simp[] >>
      ‘IS_SUFFIX master af'’ by (gvs[IS_SUFFIX_compute, REVERSE_APPEND] >>
                                 gvs[IS_PREFIX_APPEND]) >>
      first_x_assum $ drule_all_then strip_assume_tac >>
      gvs[seql_cons_SOME,AllCaseEqs()] >> simp[peg_eval_rpt, PULL_EXISTS] >>
      simp[Once peg_eval_list] >>
      qpat_x_assum ‘peg_eval _ (_, nt (mkNT nEbase) I) _’
                   $ mp_then (Pos hd) assume_tac peg_det >>
      simp[PULL_EXISTS] >> gvs[peg_eval_rpt] >> first_assum $ irule_at Any >>
      simp[left_insert1_FOLDL, left_insert1_mkNd]) >>
  (* "base case", where Eapp -> Ebase is the production used *)
  rename [‘ptree_head bpt = NN nEbase’] >>
  simp[seql_cons_SOME, peg_eval_rpt, PULL_EXISTS, AllCaseEqs()] >>
  irule_at Any $ cj 1 FOLDL >> irule_at Any peg_eval_list_nil >>
  simp[LEFT_EXISTS_AND_THM, RIGHT_EXISTS_AND_THM] >> conj_tac >~
  [‘peg_eval _ _ (Failure _ _)’]
  >- (Cases_on ‘sfx’
      >- (mp_then (Pos hd) mp_tac not_peg0_peg_eval_NIL_NONE peg0_nEbase >>
          simp[] >> disch_then $ strip_assume_tac >> pop_assum $ irule_at Any)>>
      gvs[] >> rename [‘FST h ∈ stoppers nEapp’] >> Cases_on ‘h’ >>
      irule peg_respects_firstSets >> gvs[stoppers_def]) >>
  qpat_x_assum ‘IS_SUFFIX _ _ ’ mp_tac >> simp[IS_SUFFIX_compute] >>
  strip_tac >> drule IS_PREFIX_LENGTH >> simp[] >>
  simp[DECIDE “x:num ≤ y ⇔ x = y ∨ x < y”, DISJ_IMP_THM, stoppers_def] >>
  strip_tac >>
  ‘pfx = master’
    by metis_tac[IS_PREFIX_LENGTH_ANTI, REVERSE_11, LENGTH_REVERSE] >>
  gvs[stoppers_def]
QED

Theorem peg_respects_firstSets':
   peg_eval cmlPEG ((t,l) :: rest, nt N I) (Success sfx res eo) ∧
   nt N I ∈ Gexprs cmlPEG ∧ ¬peg0 cmlPEG (nt N I) ⇒
   t ∈ firstSet cmlG [NT N]
Proof
  strip_tac >>
  mp_tac (CONV_RULE (STRIP_QUANT_CONV CONTRAPOS_CONV) peg_respects_firstSets) >>
  disch_then (qspecl_then [`N`, `rest`, `t`, `l`] mp_tac) >> simp[] >>
  disch_then irule >> strip_tac >>
  drule_then assume_tac peg_det >> simp[]
QED

Theorem nUQConstructorName_input_monotone:
   peg_eval cmlPEG (i0, nt (mkNT nUQConstructorName) I) (Success i r eo) ⇒
   peg_eval cmlPEG (i0 ++ sfx, nt (mkNT nUQConstructorName) I)
     (Success (i ++ sfx) r eo)
Proof
  simp[peg_eval_NT_SOME] >>
  simp[cmlpeg_rules_applied, peg_UQConstructorName_def, PULL_EXISTS]
QED

Theorem nConstructorName_input_monotone:
   peg_eval cmlPEG (i0, nt (mkNT nConstructorName) I) (Success i r eo) ⇒
   peg_eval cmlPEG (i0 ++ sfx, nt (mkNT nConstructorName) I)
     (Success (i ++ sfx) r eo)
Proof
  simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >> strip_tac >> rveq >>
  simp[] >> gvs[choicel_cons, peg_eval_seqempty] >~
  [‘peg_eval _ (_, nt (mkNT nUQConstructorName) I) (Success _ _ _)’]
  >- (dsimp[EXISTS_PROD] >> metis_tac[nUQConstructorName_input_monotone]) >>
  dsimp[optmax_def] >>
  gvs[peg_eval_NT] >> gvs[cmlpeg_rules_applied, peg_UQConstructorName_def]
QED

Theorem peg_eval_NT_NONE =
  “peg_eval cmlPEG (i0, nt (mkNT n) I) (Failure fl fe)”
     |> SIMP_CONV (srw_ss()) [Once peg_eval_cases]

Theorem nConstructorName_NONE_input_monotone:
   peg_eval cmlPEG ((tk,l) :: i, nt (mkNT nConstructorName) I) (Failure fl fe) ⇒
   peg_eval cmlPEG
            ((tk,l) :: (i ++ sfx), nt (mkNT nConstructorName) I)
            (Failure fl fe)
Proof
  simp[peg_eval_NT_NONE] >>
  simp[cmlpeg_rules_applied, FDOM_cmlPEG, EXISTS_PROD, peg_eval_seq_NONE,
       peg_eval_tok_NONE, choicel_cons_NONE] >>
  simp[peg_eval_NT_NONE] >>
  simp[cmlpeg_rules_applied, FDOM_cmlPEG, EXISTS_PROD, peg_eval_seq_NONE,
       peg_eval_tok_NONE, peg_UQConstructorName_def]
QED

Theorem nV_input_monotone:
   peg_eval cmlPEG (i0, nt (mkNT nV) I) (Success i r eo) ⇒
   peg_eval cmlPEG (i0 ++ sfx, nt (mkNT nV) I) (Success (i ++ sfx) r eo)
Proof
  simp[peg_eval_NT_SOME] >>
  simp[cmlpeg_rules_applied, peg_V_def, peg_eval_seqempty,
       choicel_cons, optmax_def, peg_eval_tok_NONE] >>
  strip_tac >>
  gvs[peg_eval_tok_NONE, peg_eval_tok_SOME, peg_eval_tok, tokSymP_def] >>
  rename [‘FST h = SymbolT _’] >> Cases_on ‘h’ >> gvs[]
QED

Theorem nOpID_input_monotone:
   peg_eval cmlPEG (i0, nt (mkNT nOpID) I) (Success i r eo) ⇒
   peg_eval cmlPEG (i0 ++ sfx, nt (mkNT nOpID) I) (Success (i ++ sfx) r eo)
Proof
  simp[peg_eval_NT_SOME] >>
  simp[cmlpeg_rules_applied, peg_eval_seq_NONE, choicel_cons] >>
  strip_tac >> gvs[peg_eval_tok, optmax_def, peg_eval_seqempty]
QED

Theorem nUQTyOp_input_monotone:
   peg_eval cmlPEG (i0, nt (mkNT nUQTyOp) I) (Success i r eo) ⇒
   peg_eval cmlPEG (i0 ++ sfx, nt (mkNT nUQTyOp) I) (Success (i++sfx) r eo)
Proof
  simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied, peg_eval_seq_NONE]
QED

Theorem nUQTyOp_input_monotone' =
  nUQTyOp_input_monotone |> UNDISCH_ALL |> MATCH_MP peg_det |> DISCH_ALL

Theorem nTyOp_input_monotone:
   peg_eval cmlPEG (i0, nt (mkNT nTyOp) I) (Success i r eo) ⇒
   peg_eval cmlPEG (i0 ++ sfx, nt (mkNT nTyOp) I) (Success (i++sfx) r eo)
Proof
  simp[peg_eval_NT_SOME] >>
  simp[cmlpeg_rules_applied, peg_eval_seq_NONE, choicel_cons] >>
  strip_tac >> gvs[]
  >- (drule_then assume_tac nUQTyOp_input_monotone' >> simp[]) >>
  rename [‘isLongidT tk’] >> Cases_on `tk` >> gvs[peg_eval_tok, optmax_def] >>
  dsimp[] >>
  simp[peg_eval_NT_NONE] >>
  simp[cmlpeg_rules_applied, peg_eval_tok_NONE, peg_eval_seq_NONE]
QED

Theorem nTyOp_input_monotone' =
  nTyOp_input_monotone |> UNDISCH_ALL |> MATCH_MP peg_det |> DISCH_ALL

Theorem nTyOplist_input_monotone:
  ∀pts res i0 i sfx.
    peg_eval_list cmlPEG (i0, nt (mkNT nTyOp) I) (i, pts, res) ∧
    (i = [] ∧ sfx ≠ [] ⇒ FST (HD sfx) ∈ stoppers nDType) ⇒
    ∃res'.
      peg_eval_list cmlPEG (i0 ++ sfx, nt (mkNT nTyOp) I) (i ++ sfx, pts, res')
Proof
  Induct
  >- (ONCE_REWRITE_TAC [peg_eval_list] >> simp[] >> rpt strip_tac >> gvs[] >>
      rename [‘peg_eval _ (i ++ sfx, _) _’] >>
      Cases_on ‘i’ >> simp[]
      >- (Cases_on `sfx` >- simp[not_peg0_peg_eval_NIL_NONE] >> gvs[] >>
          rename [‘FST tkl ∈ _’] >> Cases_on `tkl` >>
          gvs[peg_respects_firstSets, stoppers_def]) >>
      qpat_x_assum ‘peg_eval _ _ _’ mp_tac >>
      simp[peg_eval_NT_NONE] >>
      simp[cmlpeg_rules_applied, peg_eval_seq_NONE, peg_eval_tok_NONE] >>
      simp[peg_eval_NT_NONE, choicel_cons_NONE] >>
      simp[cmlpeg_rules_applied, peg_eval_seq_NONE, peg_eval_tok_NONE,
           PULL_EXISTS] >> rename [‘h::t = []’] >>
      Cases_on ‘h’ >> simp[MAXerr_def]) >>
  ONCE_REWRITE_TAC [peg_eval_list] >> rpt strip_tac >> gvs[] >>
  dxrule_then assume_tac nTyOp_input_monotone' >> gvs[] >>
  first_x_assum irule >> metis_tac[]
QED

Triviality peg_eval_TyOp_LparT[simp]:
  peg_eval cmlPEG ((LparT, loc)::i0, nt (mkNT nTyOp) I) (Success i r eo) ⇔ F
Proof
  simp[] >> strip_tac >> dxrule peg_respects_firstSets' >> simp[]
QED

Theorem Type_input_monotone:
   ∀N i0 i r sfx eo.
     N ∈ {nTypeList2; nTypeList1; nType; nPType; nDType; nTbase} ∧
     (i ≠ [] ⇒ FST (HD i) ∈ stoppers N) ∧
     (i = [] ∧ sfx ≠ [] ⇒ FST (HD sfx) ∈ stoppers N) ∧
     peg_eval cmlPEG (i0, nt (mkNT N) I) (Success i r eo) ⇒
     peg_eval cmlPEG (i0 ++ sfx, nt (mkNT N) I) (Success (i ++ sfx) r eo)
Proof
  ntac 2 gen_tac >> ‘?iN. iN = (i0,N)’ by simp[] >> pop_assum mp_tac >>
  map_every qid_spec_tac [‘i0’, ‘N’, ‘iN’] >>
  qispl_then [‘measure (LENGTH:(token # locs) list->num) LEX
               measure (NT_rank o mkNT)’]
             (ho_match_mp_tac o
              SIMP_RULE (srw_ss()) [pairTheory.WF_LEX,
                                    prim_recTheory.WF_measure])
             relationTheory.WF_INDUCTION_THM >>
  simp_tac (bool_ss ++ DNF_ss) [LEX_DEF, UNCURRY, FST, SND, o_THM,
                                prim_recTheory.measure_thm] >>
  qx_genl_tac [‘N’, ‘i0’, ‘i’, ‘r’, ‘sfx’, ‘eo’] >> strip_tac >> simp[] >>
  strip_tac >> rveq >> qpat_x_assum ‘peg_eval _ _ _’ mp_tac >~
  [‘peg_eval _ (_, nt (mkNT nTypeList2) I)’]
  >- (simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
      dsimp[EXISTS_PROD, seql_cons_SOME] >> rpt strip_tac >> gvs[] >>
      rename [
        ‘peg_eval _ (i0, _) (Success ((CommaT,cl)::i1) r1 eo1)’,
        ‘peg_eval _ (i1, _) (Success i r2 eo2)’] >>
      ‘peg_eval cmlPEG (i0 ++ sfx, nt (mkNT nType) I)
                       (Success (((CommaT,cl)::i1) ++ sfx) r1 eo1)’
        by simp[NT_rank_def, stoppers_def] >> gvs[] >>
      first_x_assum $ irule_at Any >> first_x_assum $ irule_at Any >>
      first_x_assum $ irule_at Any >> simp[] >>
      drule_at (Pos last) not_peg0_LENGTH_decreases >> simp[] >>
      gvs[stoppers_def]) >~
  [‘peg_eval _ (_, nt (mkNT nTypeList1) I)’]
  >- (simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
      dsimp[EXISTS_PROD, seql_cons_SOME, choicel_cons] >> rpt strip_tac >>
      gvs[] >~
      [‘peg_eval _ (i0, _) (Success ((CommaT,cl)::i1) r1 eo1)’,
       ‘peg_eval _ (i1, _) (Success i r2 eo2)’]
      >- (‘peg_eval cmlPEG (i0 ++ sfx, nt (mkNT nType) I)
                           (Success (((CommaT,cl)::i1) ++ sfx) r1 eo1)’
            by simp[NT_rank_def, stoppers_def] >>
          dxrule_then assume_tac peg_det >> simp[] >>
          first_x_assum $ irule_at Any >> simp[] >>
          first_assum $ irule_at Any >>
          rpt (dxrule_at (Pos last) not_peg0_LENGTH_decreases) >> simp[]) >~
      [‘peg_eval _ (i0, nt (mkNT nType) I) (Success i r1 eo1)’,
       ‘peg_eval _ (i, seql _ _) (Failure _ _)’]
      >- (‘peg_eval cmlPEG (i0 ++ sfx, nt (mkNT nType) I)
           (Success (i ++ sfx) r1 eo1)’
            by gvs[NT_rank_def, stoppers_def] >>
          dxrule_then assume_tac peg_det >> simp[] >>
          Cases_on ‘i’ >> gvs[]
          >- (Cases_on ‘sfx’ >> gvs[seql_cons] >> simp[peg_eval_tok] >>
              rename [‘FST h ∈ stoppers nTypeList1’] >> Cases_on ‘h’ >>
              gvs[stoppers_def]) >>
          rename [‘FST h ∈ stoppers nTypeList1’] >> Cases_on ‘h’ >>
          gvs[stoppers_def] >> simp[peg_eval_tok, seql_cons])) >~
  [‘peg_eval _ (_, nt (mkNT nType) I) _ ⇒
    peg_eval _ (_, nt (mkNT nType) I) _’]
  >- (simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
      dsimp[EXISTS_PROD, seql_cons_SOME] >> rpt strip_tac >> gvs[] >>
      ‘NT_rank (mkNT nPType) < NT_rank (mkNT nType)’ by simp[NT_rank_def] >>
      first_x_assum dxrule >> simp[] >> disch_then $ irule_at Any >>
      first_assum $ irule_at Any>>
      gvs[choicel_cons, seql_cons_SOME, PULL_EXISTS] >~
      [‘peg_eval _ _ (Success ((ArrowT,_)::_) _ _)’]
      >- (first_x_assum $ irule_at Any >> simp[] >>
          first_x_assum $ irule_at Any >> simp[stoppers_def] >>
          drule_at (Pos last) not_peg0_LENGTH_decreases >> simp[]) >~
      [‘peg_eval _ (i, seql _ _) (Failure _ _)’]
      >- (Cases_on ‘i’ >> gvs[seql_cons] >~
          [‘peg_eval _ _ (Success [] _ _)’]
          >- (Cases_on ‘sfx’ >> fs[] >> rename [‘FST h ∈ stoppers nType’] >>
              Cases_on ‘h’ >> gvs[peg_eval_tok, stoppers_def]) >~
          [‘tk ≠ ArrowT’] >- gvs[peg_eval_tok, stoppers_def] >~
          [‘ArrowT ∈ stoppers nType’] >- gs[stoppers_def])) >~
  [‘peg_eval _ (_, nt (mkNT nPType) I) _ ⇒
    peg_eval _ (_, nt (mkNT nPType) I) _’]
  >- (simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
      dsimp[EXISTS_PROD, seql_cons_SOME] >> rpt strip_tac >> gvs[] >>
      ‘NT_rank (mkNT nDType) < NT_rank (mkNT nPType)’ by simp[NT_rank_def] >>
      first_x_assum dxrule >> simp[] >> disch_then $ irule_at Any >>
      first_assum $ irule_at Any >>
      gvs[choicel_cons, seql_cons_SOME, PULL_EXISTS] >~
      [‘peg_eval _ _ (Success ((StarT,_)::_) _ _)’]
      >- (first_x_assum $ irule_at Any >> simp[] >>
          first_x_assum $ irule_at Any >> simp[stoppers_def] >>
          drule_at (Pos last) not_peg0_LENGTH_decreases >> simp[]) >~
      [‘peg_eval _ (_, seql [tok ($= StarT) _; _] _) _’]
      >- (gvs[seql_cons, peg_eval_tok] >~
          [‘StarT ∈ stoppers nPType’] >- gs[stoppers_def] >~
          [‘t ∈ stoppers nDType’, ‘t ∈ stoppers nPType’] >- gs[stoppers_def] >~
          [‘peg_eval _ _ (Success [] _ _)’]
          >- (Cases_on ‘sfx’ >> gvs[] >>
              rename [‘FST h ∈ stoppers nPType’] >>
              Cases_on ‘h’ >> gvs[stoppers_def]))) >~
  [‘peg_eval _ (_, nt (mkNT nDType) I) _ ⇒
    peg_eval _ (_, nt (mkNT nDType) I) _’]
  >- (simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
      dsimp[EXISTS_PROD, seql_cons_SOME] >> rpt strip_tac >> gvs[] >>
      first_x_assum $ irule_at Any >> simp[NT_rank_def] >>
      first_assum $ irule_at Any >>
      gvs[peg_eval_rpt, PULL_EXISTS] >>
      drule_all_then strip_assume_tac nTyOplist_input_monotone >>
      first_assum $ irule_at Any >> simp[stoppers_def]) >~
  [‘peg_eval _ (_, nt (mkNT nTbase) I) _ ⇒
    peg_eval _ (_, nt (mkNT nTbase) I) _’]
  >- (simp[SimpL “$==>”, peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
      simp[Once choicel_cons] >> rpt strip_tac >> gvs[seql_cons_SOME] >~
      [‘peg_eval _ ((LparT,l0)::_, _) _’]
      >- (simp[peg_eval_NT_SOME] >>
          dsimp[cmlpeg_rules_applied, Once choicel_cons, seql_cons_SOME,
                peg_eval_tok_SOME] >> disj1_tac >>
          first_x_assum $ drule_at (Pos last) >> simp[] >>
          disch_then $ irule_at Any >> simp[stoppers_def]) >>
      pop_assum mp_tac >> simp[Once choicel_cons] >> strip_tac >> gvs[] >~
      [‘peg_eval _ (i0, seql (tok ($= LparT) _ :: _) _) (Success i ptl e0)’]
      >- (‘NT_rank (mkNT nFQV) < NT_rank (mkNT nTbase)’ by simp[NT_rank_def] >>
          first_x_assum $ dxrule_then kall_tac >>
          gvs[seql_cons_SOME, peg_eval_tok_SOME] >>
          qpat_x_assum ‘peg_eval _ (_, seql _ _) _’ mp_tac >>
          simp[Once seql_cons, peg_eval_tok] >> strip_tac >> gvs[] >>
          gvs[seql_cons] >~
          [‘peg_eval _ (i1, nt (mkNT nTypeList2) _) (Success _ _ _)’,
           ‘peg_eval _ (i1, nt (mkNT nType) _) (Failure _ _)’]
          >- (qpat_x_assum ‘peg_eval _ (_, nt (mkNT nTypeList2) _) _’ mp_tac >>
              simp[SimpL “$==>”, peg_eval_NT_SOME] >>
              simp[cmlpeg_rules_applied, seql_cons_SOME] >>
              qpat_x_assum ‘peg_eval _ (_, nt (mkNT nType) _) (Failure _ _)’
                           (mp_then (Pos hd) assume_tac peg_det) >>
              simp[]) >~
          [‘peg_eval _ (i1, nt (mkNT nTypeList2) I) (Success (_ :: i2) pt eo2)’,
           ‘peg_eval _ (i1, nt (mkNT nType) I) (Success i1' pt' eo1')’]
          >- (qpat_x_assum ‘peg_eval _ (_, nt (mkNT nTypeList2) _) _’ mp_tac >>
              simp[SimpL “$==>”, peg_eval_NT_SOME] >>
              simp[cmlpeg_rules_applied, seql_cons_SOME] >> rpt strip_tac >>
              gvs[] >>
              qpat_x_assum ‘peg_eval _ (_, nt (mkNT nType) _)
                            (Success ((CommaT, _) :: _) _ _)’
                           (mp_then (Pos hd) assume_tac peg_det) >>
              gvs[] >>
              simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied]>>
              pop_assum (first_assum o resolve_then (Pos last) assume_tac o
                         iffRL) >>
              gvs[stoppers_def] >>
              pop_assum (C (resolve_then (Pos hd) assume_tac) peg_det) >>
              first_assum (C (resolve_then (Pos last) assume_tac)
                           not_peg0_LENGTH_decreases o iffRL) >>
              gvs[DECIDE “SUC (x + y) < z + y ⇔ SUC x < z”] >>
              dxrule_then assume_tac nTyOp_input_monotone' >>
              first_assum (drule_at (Pos last)) >>
              simp_tac (srw_ss()) [stoppers_def] >> simp[] >>
              disch_then (C (resolve_then (Pos hd) assume_tac) peg_det) >>
              simp[Once choicel_cons, seql_cons, peg_eval_tok] >>
              simp[Once choicel_cons, seql_cons, peg_eval_tok] >>
              simp[Once peg_eval_NT, cmlpeg_rules_applied, seql_cons,
                   peg_eval_tok])) >>
      qpat_x_assum ‘peg_eval _ (_, choicel _) _’ mp_tac >>
      simp[choicel_cons, peg_eval_seqempty, peg_eval_tok] >>
      rpt strip_tac >> gvs[] >~
      [‘¬isTyvarT t’]
      >- (drule peg_respects_firstSets' >> simp[] >>
          dxrule_then assume_tac nTyOp_input_monotone' >>
          strip_tac >> gvs[] >> simp[peg_eval_NT] >>
          simp[cmlpeg_rules_applied, seql_cons, choicel_cons,
               peg_eval_tok, optmax_def, peg_eval_seqempty] >>
          gvs[seql_cons, peg_eval_tok]) >~
      [‘isTyvarT t’]
      >- (Cases_on ‘t’ >> gvs[] >> simp[peg_eval_NT] >>
          simp[cmlpeg_rules_applied, seql_cons, choicel_cons, peg_eval_tok] >>
          gvs[seql_cons, peg_eval_tok]) >~
      [‘peg_eval _ ([], nt (mkNT nTyOp) I) (Success _ _ _)’]
      >- (drule_at (Pos last) not_peg0_LENGTH_decreases >> simp[]))
QED

Theorem Pattern_input_monotone0[local]:
  ∀N i0 rlist b i r l sfx eo res.
    (N ∈ {nPbase; nPtuple; nPattern; nPapp; nPatternList; nPcons} ∧ ¬b ∧
     (i ≠ [] ⇒ FST (HD i) ∈ stoppers N) ∧
     (i = [] ∧ sfx ≠ [] ⇒ FST (HD sfx) ∈ stoppers N) ∧
     peg_eval cmlPEG (i0, nt (mkNT N) I) (Success i r eo) ⇒
     peg_eval cmlPEG (i0 ++ sfx, nt (mkNT N) I) (Success (i ++ sfx) r eo)) ∧
    (N = nPbase ∧ b ∧
     (i ≠ [] ⇒ FST (HD i) ∉ firstSet cmlG [NN nPbase]) ∧
     (i = [] ∧ sfx ≠ [] ⇒ FST (HD sfx) ∉ firstSet cmlG [NN nPbase]) ∧
     peg_eval_list cmlPEG (i0, nt (mkNT N) I) (i, rlist, l, res) ⇒
     ∃res'.
       peg_eval_list cmlPEG (i0 ++ sfx, nt (mkNT N) I) (i ++ sfx, rlist, res'))
Proof
  ntac 4 gen_tac >> ‘?iN. iN = (i0,b,rlist,N)’ by simp[] >> pop_assum mp_tac >>
  map_every qid_spec_tac [‘b’, ‘rlist’, ‘i0’, ‘N’, ‘iN’] >>
  qispl_then [‘measure (LENGTH:(token # locs) list->num) LEX
               measure (λb. if b then 1 else 0) LEX
               measure (LENGTH:mlptree list list -> num) LEX
               measure (NT_rank o mkNT)’]
             (ho_match_mp_tac o
              SIMP_RULE (srw_ss()) [pairTheory.WF_LEX,
                                    prim_recTheory.WF_measure])
             relationTheory.WF_INDUCTION_THM >>
  simp_tac (bool_ss ++ DNF_ss) [LEX_DEF, UNCURRY, FST, SND, o_THM,
                                prim_recTheory.measure_thm] >>
  simp_tac (srw_ss()) [] >> conj_tac
  >- (
  qx_genl_tac [‘N’, ‘i0’, ‘rlist’, ‘i’, ‘r’, ‘sfx’, ‘eo’] >> strip_tac >>
  simp[] >>
  strip_tac >> rveq >> qpat_x_assum ‘peg_eval _ _ _’ mp_tac
  >- (simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, SimpL “$==>”] >>
      simp[Once choicel_cons] >> rpt strip_tac >> gvs[] >~
      [‘peg_eval cmlPEG (_, nt (mkNT nV) I) (Success _ _ _)’]
      >- (simp[peg_eval_NT_SOME] >>
          simp[cmlpeg_rules_applied, Once choicel_cons] >>
          dxrule_then assume_tac nV_input_monotone >>
          pop_assum (C (resolve_then (Pos hd) assume_tac) peg_det) >>
          simp[]) >> pop_assum mp_tac >>
      simp[Once choicel_cons] >> rpt strip_tac >> gvs[] >~
      [‘peg_eval _ (i0, nt (mkNT nConstructorName) I) (Success _ _ _)’,
       ‘peg_eval _ (i0, nt (mkNT nV) I) (Failure fl1 fe1)’]
      >- (Cases_on ‘i0’
          >- (drule_at (Pos last) not_peg0_LENGTH_decreases >> simp[]) >>
          rename [‘peg_eval cmlPEG (tl::_, nt (mkNT nConstructorName) I)’] >>
          ‘∃tk loc. tl = (tk,loc)’ by (Cases_on ‘tl’ >> simp[]) >> rveq >>
          drule peg_respects_firstSets' >> simp[] >> strip_tac >>
          dxrule_then assume_tac nConstructorName_input_monotone >>
          pop_assum (C (resolve_then (Pos hd) assume_tac) peg_det) >> gvs[] >>
          ‘∀rest i j k.
             ¬peg_eval cmlPEG ((tk,loc)::rest, nt (mkNT nV) I) (Success i j k)’
            by (rpt strip_tac >> drule peg_respects_firstSets' >> simp[] >>
                gvs[firstSet_nConstructorName, firstSet_nV]) >>
          simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
          simp[Once choicel_cons, EXISTS_result] >>
          simp[Once choicel_cons] >>
          ‘∃r. peg_eval cmlPEG ((tk,loc)::(t ++ sfx), nt (mkNT nV) I) r’
            by (irule peg_eval_total >> simp[]) >> Cases_on ‘r’ >> gvs[] >>
          first_assum $ irule_at Any) >> pop_assum mp_tac >>
      simp[Once choicel_cons, EXISTS_result] >> rpt strip_tac >> gvs[] >~
      [‘isInt itk’]
      >- (Cases_on ‘itk’ >> gvs[] >>
          simp[peg_eval_NT_SOME] >>
          simp[cmlpeg_rules_applied, Once choicel_cons, EXISTS_result,
               EXISTS_OR_THM] >> disj2_tac >> simp[PULL_EXISTS] >>
          irule_at Any fFail_def >> simp[] >>
          simp[Once choicel_cons, EXISTS_result, EXISTS_OR_THM] >> disj2_tac >>
          simp[PULL_EXISTS] >> irule_at Any fFail_def >> simp[] >>
          simp[Once choicel_cons, peg_eval_tok]) >> pop_assum mp_tac >>
      simp[Once choicel_cons, EXISTS_result] >> rpt strip_tac >> gvs[] >~
      [‘isString tk’]
      >- (Cases_on ‘tk’ >> gvs[] >>
          simp[peg_eval_NT_SOME] >>
          simp[cmlpeg_rules_applied,
               Once choicel_cons, peg_respects_firstSets_rwt] >>
          simp[Once choicel_cons, peg_respects_firstSets_rwt] >>
          simp[Once choicel_cons, peg_eval_tok] >>
          simp[Once choicel_cons, peg_eval_tok]) >> pop_assum mp_tac >>
      simp[Once choicel_cons, EXISTS_result] >> rpt strip_tac >> gvs[] >~
      [‘isCharT tk’]
      >- (Cases_on ‘tk’ >> gvs[] >>
          simp[peg_eval_NT_SOME] >>
          simp[cmlpeg_rules_applied,
               Once choicel_cons, peg_respects_firstSets_rwt] >>
          simp[Once choicel_cons, peg_respects_firstSets_rwt] >>
          simp[Once choicel_cons, peg_eval_tok] >>
          simp[Once choicel_cons, peg_eval_tok] >>
          simp[Once choicel_cons, peg_eval_tok]) >> pop_assum mp_tac >>
      simp[Once choicel_cons, EXISTS_result] >> rpt strip_tac >> gvs[] >~
      [‘peg_eval cmlPEG (i0, nt (mkNT nPtuple) I) (Success i res eo)’]
      >- (‘∃loc rest. i0 = (LparT,loc)::rest’
             by (qpat_x_assum ‘peg_eval _ (_, nt (mkNT nPtuple) _) _’ mp_tac >>
                 simp[SimpL “$==>”, peg_eval_NT_SOME] >>
                 simp[cmlpeg_rules_applied, choicel_cons, EXISTS_result,
                      seql_cons_SOME] >> rpt strip_tac >> gvs[]) >> gvs[] >>
          simp[peg_eval_NT_SOME] >>
          simp[cmlpeg_rules_applied, peg_eval_tok, peg_respects_firstSets_rwt,
               choicel_cons, seql_cons] >> simp[PULL_EXISTS] >>
          ‘NT_rank (mkNT nPtuple) < NT_rank (mkNT nPbase)’
            by simp[NT_rank_def] >>
          first_x_assum (dxrule_then $ irule_at Any) >> simp[] >>
          first_assum $ irule_at Any >> simp[stoppers_def]) >>
      pop_assum mp_tac >>
      simp[Once choicel_cons, EXISTS_result] >> rpt strip_tac >> gvs[] >~
      [‘peg_eval _ ((UnderbarT, _) :: _, _)’]
      >- (simp[peg_eval_NT_SOME] >>
          simp[cmlpeg_rules_applied, peg_eval_tok, peg_respects_firstSets_rwt,
               choicel_cons, seql_cons]) >> pop_assum mp_tac >>
      simp[choicel_cons, EXISTS_result, seql_cons_SOME] >>
      rpt strip_tac >> gvs[] >~
      [‘peg_eval _ ((OpT,_) :: _, _)’]
      >- (simp[peg_eval_NT_SOME] >>
          simp[cmlpeg_rules_applied, peg_eval_tok, peg_respects_firstSets_rwt,
               choicel_cons, seql_cons] >> simp[EXISTS_result] >>
          irule_at Any nOpID_input_monotone >> first_assum $ irule_at Any) >~
      [‘(LbrackT,_) :: (RbrackT, _) :: _’]
      >- (simp[peg_eval_NT_SOME] >>
          simp[cmlpeg_rules_applied, peg_eval_tok, peg_respects_firstSets_rwt,
               choicel_cons, seql_cons] >> simp[EXISTS_result]) >~
      [‘peg_eval _ (_, nt (mkNT nPatternList) I)(Success ((RbrackT,_)::_) _ _)’]
      >- (simp[peg_eval_NT_SOME] >>
          simp[cmlpeg_rules_applied, peg_eval_tok, peg_respects_firstSets_rwt,
               choicel_cons, seql_cons] >> simp[EXISTS_result] >>
          simp[PULL_EXISTS] >> last_x_assum $ drule_at (Pos last) >> simp[] >>
          simp[stoppers_def] >> metis_tac[])) >~
  [‘peg_eval _ (i0, nt (mkNT nPtuple) I) (Success i r eo) ⇒
    peg_eval _ (i0 ++ sfx, nt (mkNT nPtuple) I) (Success _ r eo)’]
  >- (simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
      simp[choicel_cons, seql_cons_SOME, peg_eval_tok, EXISTS_result] >>
      rpt strip_tac >> gvs[optmax_def] >>
      simp[PULL_EXISTS, seql_cons, peg_eval_tok, peg_respects_firstSets_rwt]>>
      drule_at (Pos last) not_peg0_LENGTH_decreases >> simp[] >> strip_tac >>
      rename [‘SUC (LENGTH i) < LENGTH i1’] >> Cases_on ‘i1’ >> gvs[] >>
      simp[PULL_EXISTS, optmax_def] >> rename [‘h = (_, fl)’] >>
      Cases_on ‘h’ >> gvs[seql_cons, peg_eval_tok] >>
      last_x_assum $ drule_at (Pos last) >> simp[stoppers_def] >> metis_tac[])>~
  [‘peg_eval _ (i0 ++ sfx, nt (mkNT nPattern) I) (Success (i ++ sfx) r _)’]
  >- (simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied, EXISTS_PROD] >>
      simp[choicel_cons, seql_cons_SOME, EXISTS_result] >>
      strip_tac >> gvs[] >~
      [‘peg_eval _ (i, seql _ _) (Failure _ _)’]
      >- (‘NT_rank (mkNT nPcons) < NT_rank (mkNT nPattern)’
            by simp[NT_rank_def] >>
          first_x_assum dxrule >> simp[] >>
          disch_then $ drule_at (Pos last) >> simp[] >>
          disch_then $ irule_at Any >>
          Cases_on ‘i’ >> gvs[]
          >- (Cases_on ‘sfx’ >> gvs[] >> simp[seql_cons, peg_eval_tok] >>
              gvs[stoppers_def] >> rename [‘FST h ≠ ColonT’] >> Cases_on ‘h’ >>
              gvs[]) >>
          rename [‘FST h ∈ stoppers _’] >> Cases_on ‘h’ >>
          gvs[stoppers_def, seql_cons, peg_eval_tok]) >~
      [‘peg_eval _ (i0, nt(mkNT nPcons) I) (Success ((ColonT, l)::i1) _ _)’]
      >- (‘NT_rank (mkNT nPcons) < NT_rank (mkNT nPattern)’
            by simp[NT_rank_def] >>
          first_x_assum dxrule >> simp[] >>
          disch_then $ irule_at Any >> first_assum $ irule_at Any >>
          simp[stoppers_def] >> irule_at Any Type_input_monotone >> simp[] >>
          first_assum $ irule_at Any >> gvs[stoppers_def])) >~
  [‘peg_eval _ (i0,nt (mkNT nPapp) I) (Success i r _) ⇒
    peg_eval _ (_, nt (mkNT nPapp) I) _’]
  >- (simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
      simp[choicel_cons, seql_cons, EXISTS_result] >> strip_tac >>
      simp[PULL_EXISTS] >> gvs[] >~
      [‘peg_eval _ (_, nt (mkNT nConstructorName) _) (Success _ _ _)’]
      >- (dxrule_then assume_tac nConstructorName_input_monotone >>
          pop_assum $ C (resolve_then Any assume_tac) peg_det >>
          gvs[peg_eval_rpt, PULL_EXISTS] >> irule_at Any EQ_REFL >>
          gvs[GSYM RIGHT_EXISTS_IMP_THM, SKOLEM_THM] >>
          first_x_assum $ irule_at Any >> gvs[stoppers_def] >>
          rename [‘peg_eval_list _ (i1, _) (i2,l2,ep)’] >>
          Cases_on ‘ep’ >> gvs[] >> first_x_assum $ irule_at Any >>
          pop_assum (C (resolve_then (Pos last) mp_tac)
                     not_peg0_LENGTH_decreases o iffRL) >> simp[])
      >- (drule_at (Pos last) not_peg0_LENGTH_decreases >> simp[] >>
          strip_tac >> Cases_on ‘i0’ >> gvs[] >>
          rename [‘peg_eval _ (tkl::_, _)’] >> Cases_on ‘tkl’ >> gvs[] >>
          drule_then assume_tac nConstructorName_NONE_input_monotone >>
          pop_assum $ C (resolve_then Any assume_tac) peg_det >> simp[] >>
          ‘NT_rank (mkNT nPbase) < NT_rank (mkNT nPapp)’
            by simp[NT_rank_def] >> first_x_assum dxrule >>
          simp[stoppers_def] >> metis_tac[])) >~
  [‘peg_eval _ (i0 ++ sfx, nt (mkNT nPatternList) I) (Success (i ++ _) _ _)’]
  >- (simp[peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, EXISTS_PROD, PULL_EXISTS, seql_cons_SOME] >>
      rpt strip_tac >> gvs[] >>
      ‘NT_rank (mkNT nPattern) < NT_rank (mkNT nPatternList)’
        by simp[NT_rank_def] >>
      first_x_assum dxrule >> simp[] >> disch_then $ irule_at Any >>
      first_assum $ irule_at Any >> gvs[choicel_cons, seql_cons] >~
      [‘peg_eval _ (_, tok ($= CommaT) _) (Failure _ _)’]
      >- (gvs[peg_eval_tok] >- gvs[stoppers_def] >>
          Cases_on ‘sfx’ >> gvs[] >> rename [‘FST h ∈ stoppers _’] >>
          Cases_on ‘h’ >> gvs[stoppers_def]) >~
      [‘CommaT ∈ stoppers nPatternList’] >- gvs[stoppers_def] >>
      simp[peg_eval_tok, EXISTS_result, stoppers_def] >>
      first_x_assum $ irule_at Any >> simp[] >> first_assum $ irule_at Any >>
      rpt (dxrule_at (Pos last) not_peg0_LENGTH_decreases) >> simp[]) >~
  [‘peg_eval _ (i0 ++ sfx, nt (mkNT nPcons) I) (Success (i ++ sfx) _ _ )’]
  >- (simp[peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, EXISTS_PROD, seql_cons_SOME, PULL_EXISTS] >>
      rpt strip_tac >> gvs[] >>
      ‘NT_rank (mkNT nPapp) < NT_rank (mkNT nPcons)’ by simp[NT_rank_def] >>
      first_x_assum dxrule >> simp[] >> disch_then $ irule_at Any >>
      first_assum $ irule_at Any >> gvs[choicel_cons, seql_cons] >~
      [‘peg_eval _ (_, tok ($= (SymbolT "::")) _) (Failure _ _)’]
      >- (gvs[peg_eval_tok] >- gvs[stoppers_def] >>
          Cases_on ‘sfx’ >> gvs[] >> rename [‘FST h ∈ stoppers _’] >>
          Cases_on ‘h’ >> gvs[stoppers_def]) >~
      [‘SymbolT "::" ∈ stoppers nPcons’] >- gvs[stoppers_def] >>
      simp[peg_eval_tok, EXISTS_result, stoppers_def] >>
      first_x_assum $ irule_at Any >> simp[] >> first_assum $ irule_at Any >>
      rpt (dxrule_at (Pos last) not_peg0_LENGTH_decreases) >> simp[])) >>
  qx_genl_tac [‘i0’, ‘rlist’, ‘i’, ‘l’, ‘sfx’] >> rpt strip_tac >>
  qpat_x_assum ‘peg_eval_list _ _ _’ mp_tac >>
  Cases_on ‘rlist’ >> ONCE_REWRITE_TAC[peg_eval_list] >> simp[]
  >- (rw[] >> Cases_on ‘i’ >> fs[]
      >- (Cases_on ‘sfx’ >> fs[not_peg0_peg_eval_NIL_NONE] >>
          rename [‘FST h ≠ LparT’] >> Cases_on ‘h’ >>
          fs[peg_respects_firstSets_rwt]) >>
      rename [‘FST h ≠ LparT’] >> Cases_on ‘h’ >>
      fs[peg_respects_firstSets_rwt]) >>
  rpt strip_tac >>
  first_x_assum $ irule_at Any >> simp[stoppers_def] >>
  first_assum $ irule_at Any >>
  gvs[SKOLEM_THM, GSYM RIGHT_EXISTS_IMP_THM]>>
  first_x_assum $ irule_at Any >> simp[] >> first_assum $ irule_at Any >>
  drule_at (Pos last) not_peg0_LENGTH_decreases >> simp[]
QED

Theorem Pattern_input_monotone =
  SIMP_RULE bool_ss [FORALL_AND_THM] Pattern_input_monotone0

Theorem extend_Pbase_list:
  ∀results pfx sfx sfx' result e eo.
    peg_eval_list cmlPEG (pfx, nt (mkNT nPbase) I) ([], results, e) ∧
    peg_eval cmlPEG (sfx, nt (mkNT nPbase) I) (Success sfx' result eo) ∧
    (sfx' ≠ [] ⇒ FST (HD sfx') ∉ firstSet cmlG [NN nPbase]) ⇒
    ∃e'. peg_eval_list cmlPEG (pfx ++ sfx, nt (mkNT nPbase) I)
                       (sfx', results ++ [result], e')
Proof
  Induct >> dsimp[Once peg_eval_list]
  >- (rpt strip_tac >> irule_at Any peg_eval_list_cons >>
      first_assum $ irule_at Any >> irule_at Any peg_eval_list_nil >>
      rename [‘peg_eval _ (sfx', nt (mkNT nPbase) I)’] >>
      Cases_on ‘sfx'’
      >- (irule_at Any not_peg0_peg_eval_NIL_NONE >> simp[]) >> gs[] >>
      rename [`FST h ∉ _`] >> Cases_on `h` >> fs[peg_respects_firstSets]) >>
  rpt strip_tac >> fs[] >>
  irule_at Any peg_eval_list_cons >>
  irule_at Any (cj 1 Pattern_input_monotone) >> simp[] >>
  first_assum $ irule_at Any >> simp[stoppers_def] >> first_x_assum irule >>
  simp[] >> metis_tac[]
QED

Theorem papp_complete:
  (∀pt' pfx' N sfx'.
     LENGTH pfx' < LENGTH master ∧ valid_lptree cmlG pt' ∧
     mkNT N ∈ FDOM cmlPEG.rules ∧ ptree_head pt' = NN N ∧
     real_fringe pt' = MAP (TK ## I) pfx' ∧
     (sfx' ≠ [] ⇒ FST (HD sfx') ∈ stoppers N) ⇒
     ∃eo.
       peg_eval cmlPEG (pfx' ++ sfx', nt (mkNT N) I) (Success sfx' [pt'] eo)) ∧
  (∀pt' sfx'.
     valid_lptree cmlG pt' ∧ ptree_head pt' = NN nConstructorName ∧
     real_fringe pt' = MAP (TK ## I) master ⇒
     ∃eo.
       peg_eval cmlPEG (master ++ sfx', nt (mkNT nConstructorName) I)
                (Success sfx' [pt'] eo)) ⇒
  ∀pfx accpt sfx.
    pfx <<= master ∧
    valid_lptree cmlG accpt ∧ ptree_head accpt = NN nPConApp ∧
    real_fringe accpt = MAP (TK ## I) pfx ∧
    (sfx ≠ [] ⇒ FST (HD sfx) ∈ stoppers nPConApp) ⇒
    ∃cpt i bpts eo e.
       peg_eval cmlPEG
                (pfx ++ sfx, nt (mkNT nConstructorName) I)
                (Success i [cpt] eo) ∧
       peg_eval_list cmlPEG (i, nt (mkNT nPbase) I) (sfx, bpts, e) ∧
       accpt =
       FOLDL (λpcpt bpt. bindNT0 nPConApp [pcpt; bpt])
             (mkNd (mkNT nPConApp) [cpt]) (FLAT bpts)
Proof
  strip_tac >> gen_tac >> completeInduct_on ‘LENGTH pfx’ >> rpt strip_tac >>
  rveq >>
  ‘∃subs. accpt = mkNd (mkNT nPConApp) subs’
    by metis_tac[ptree_head_NT_mkNd] >>
  gvs[MAP_EQ_CONS, MAP_EQ_APPEND, cmlG_FDOM, cmlG_applied, valid_lptree_thm]
  >- (rename [‘ptree_head cpt = NN nConstructorName’] >>
      irule_at Any peg_eval_list_nil >> simp[] >>
      simp[RIGHT_EXISTS_AND_THM, LEFT_EXISTS_AND_THM] >> conj_tac >~
      [‘peg_eval _ (sfx, nt (mkNT nPbase) I) (Failure _ _)’]
      >- (Cases_on ‘sfx’ >- simp[not_peg0_peg_eval_NIL_NONE] >>
          gs[stoppers_def] >> rename [‘FST h ≠ LparT’] >> Cases_on ‘h’ >>
          gs[peg_respects_firstSets]) >>
      drule IS_PREFIX_LENGTH >> simp[DECIDE “x:num ≤ y ⇔ x = y ∨ x < y”] >>
      strip_tac >> simp[stoppers_def] >>
      ‘pfx = master’
        by metis_tac[IS_PREFIX_LENGTH_ANTI, REVERSE_11, LENGTH_REVERSE] >>
      gvs[]) >>
  rename [‘ptree_head pcpt = NN nPConApp’, ‘ptree_head bpt = NN nPbase’,
          ‘real_fringe pcpt = MAP _ pcf’, ‘real_fringe bpt = MAP _ bcf’] >>
  first_x_assum (qspec_then ‘LENGTH pcf’ mp_tac) >> simp[] >>
  ‘0 < LENGTH bcf’
    by (qspec_then ‘bpt’ mp_tac
         (MATCH_MP rfringe_length_not_nullable nullable_Pbase) >> simp[]) >>
  simp[] >> disch_then (qspec_then ‘pcf’ mp_tac) >> simp[] >>
  disch_then (qspecl_then [‘pcpt’, ‘[]’] mp_tac) >> simp[] >> impl_tac
  >- (irule IS_PREFIX_TRANS >> qexists_tac ‘pcf ++ bcf’ >> simp[]) >>
  strip_tac >> rveq >>
  first_assum (mp_then (Pos hd)
                       (qspec_then ‘bcf ++ sfx’ mp_tac)
                       nConstructorName_input_monotone) >>
  simp[] >> disch_then $ irule_at Any >> simp[] >>
  first_x_assum (qpat_assum ‘ptree_head _ = NN nPbase’ o
                 mp_then Any mp_tac) >> simp[stoppers_def] >>
  disch_then (qspec_then ‘sfx’ mp_tac) >> impl_tac
  >- (imp_res_tac IS_PREFIX_LENGTH >> fs[] >>
      ‘0 < LENGTH pcf’ suffices_by simp[] >>
      mp_tac (MATCH_MP rfringe_length_not_nullable nullable_PConApp) >>
      disch_then (first_assum o mp_then (Pos hd) mp_tac) >> simp[]) >>
  strip_tac >>
  first_assum (mp_then (Pos (el 2)) mp_tac extend_Pbase_list) >>
  disch_then (first_assum o mp_then (Pos hd) mp_tac) >> gs[stoppers_def] >>
  strip_tac >> dxrule_then assume_tac (cj 2 peg_deterministic) >>
  simp[FOLDL_APPEND]
QED

Theorem leftmost_mkNd_DType[simp]:
   leftmost (mkNd (mkNT nDType) (c::cs)) = leftmost c
Proof
  simp[leftmost_def, mkNd_def]
QED

Theorem leftmost_mkNd_Tbase[simp]:
   leftmost (mkNd (mkNT nTbase) (x::xs)) = x
Proof
  simp[leftmost_def, mkNd_def]
QED

Theorem leftmost_FOLDL:
   leftmost (FOLDL (λa b. mkNd (mkNT nDType) [a;b]) acc args) =
    leftmost acc
Proof
  qid_spec_tac `acc` >> Induct_on `args` >> simp[]
QED

Theorem left_insert2_mkNd[simp]:
   left_insert2 bpt (mkNd (mkNT nDType) [mkNd n [sub]]) =
   mkNd (mkNT nDType) [mkNd (mkNT nDType) [bpt]; sub]
Proof
  simp[left_insert2_def, mkNd_def, ptree_list_loc_def]
QED

Theorem dtype_complete:
  (∀pt' pfx' sfx' N.
     LENGTH pfx' < LENGTH master ∧ valid_lptree cmlG pt' ∧
     mkNT N ∈ FDOM cmlPEG.rules ∧
     ptree_head pt' = NN N ∧ real_fringe pt' = MAP (TK ## I) pfx' ∧
     (sfx' ≠ [] ⇒ FST (HD sfx') ∈ stoppers N) ⇒
     ∃eo.
       peg_eval cmlPEG (pfx' ++ sfx', nt (mkNT N) I) (Success sfx' [pt'] eo)) ∧
  (∀pt' sfx'.
     valid_lptree cmlG pt' ∧ ptree_head pt' = NN nTbase ∧
     real_fringe pt' = MAP (TK ## I) master ∧
     (sfx' ≠ [] ⇒ FST (HD sfx') ∈ stoppers nEbase) ⇒
     ∃eo.
       peg_eval cmlPEG (master ++ sfx',nt (mkNT nTbase) I)
                (Success sfx' [pt'] eo))
  ⇒
  ∀pfx apt sfx.
    IS_SUFFIX master pfx ∧ valid_lptree cmlG apt ∧
    ptree_head apt = NN nDType ∧ real_fringe apt = MAP (TK ## I) pfx ∧
    (sfx ≠ [] ⇒ FST (HD sfx) ∈ stoppers nDType) ⇒
    ∃eo.
      peg_eval cmlPEG (pfx ++ sfx, nt (mkNT nDType) I) (Success sfx [apt] eo)
Proof
  strip_tac >>
  simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, (*list_case_lemma, *)
       peg_eval_rpt, GSYM LEFT_EXISTS_AND_THM, GSYM RIGHT_EXISTS_AND_THM,
       seql_cons_SOME, AllCaseEqs()] >>
  gen_tac >>
  completeInduct_on ‘LENGTH pfx’ >> qx_gen_tac ‘pfx’ >> strip_tac >>
  rveq >> fs[GSYM RIGHT_FORALL_IMP_THM] >>
  qx_genl_tac [‘apt’, ‘sfx’] >> strip_tac >>
  ‘∃subs. apt = mkNd (mkNT nDType) subs’
    by metis_tac[ptree_head_NT_mkNd] >>
  gvs[MAP_EQ_CONS, MAP_EQ_APPEND, cmlG_FDOM, cmlG_applied, valid_lptree_thm,
      DISJ_IMP_THM, FORALL_AND_THM]
  >- (rename [‘ptree_head apt = NN nDType’,
              ‘real_fringe apt = MAP _ af’,
              ‘ptree_head bpt = NN nTyOp’,
              ‘real_fringe bpt = MAP _ bf’] >>
      qspecl_then [‘apt’, ‘bpt’, ‘af’, ‘bf’] mp_tac dtype_reassociated >>
      simp[MAP_EQ_APPEND, GSYM LEFT_EXISTS_AND_THM, GSYM RIGHT_EXISTS_AND_THM]>>
      disch_then (qxchl [‘apt'’, ‘bpt'’, ‘bf'’, ‘af'’] strip_assume_tac) >>
      simp[] >> qexistsl_tac [‘af' ++ sfx’, ‘[bpt']’] >>
      simp[] >>
      ‘LENGTH (af ++ bf) ≤ LENGTH master’
        by (Q.UNDISCH_THEN ‘af ++ bf = bf' ++ af'’ SUBST_ALL_TAC >>
            fs[rich_listTheory.IS_SUFFIX_compute] >>
            imp_res_tac rich_listTheory.IS_PREFIX_LENGTH >> fs[]) >>
      drule_all (MATCH_MP rfringe_length_not_nullable nullable_Tbase) >>
      drule_all (MATCH_MP rfringe_length_not_nullable nullable_DType) >>
      simp[] >> ntac 2 strip_tac >>
      ‘LENGTH (bf' ++ af') ≤ LENGTH master’ by metis_tac[] >> fs[] >>
      ‘LENGTH bf' < LENGTH master’ by simp[] >>
      first_assum (pop_assum o mp_then (Pos hd) strip_assume_tac) >>
      pop_assum (strip_assume_tac o
                 SRULE [GSYM RIGHT_EXISTS_IMP_THM, SKOLEM_THM]) >>
      normlist >> pop_assum $ irule_at Any >> simp[stoppers_def] >>
      first_x_assum (qspecl_then [‘af'’, ‘apt'’, ‘sfx’] mp_tac) >> simp[] >>
      ‘LENGTH af + LENGTH bf = LENGTH bf' + LENGTH af'’
        by metis_tac [listTheory.LENGTH_APPEND] >> simp[] >>
      fs[rich_listTheory.IS_SUFFIX_compute, listTheory.REVERSE_APPEND] >>
      impl_tac >- (drule rich_listTheory.IS_PREFIX_APPEND1 >> simp[]) >>
      strip_tac >>
      rename [‘peg_eval _ (af' ++ sfx, nt (mkNT nTbase) I)
               (Success ii bpt_list eo1)’,
              ‘peg_eval_list _ (ii, nt (mkNT nTyOp) I) (sfx,blist,_)’] >>
      drule peg_sound >> disch_then (qxchl [‘bpt2’] strip_assume_tac) >>
      gvs[leftmost_FOLDL] >>
      ‘∃subs. bpt2 = mkNd (mkNT nTbase) subs’
        by (‘∃f. real_fringe bpt2 = MAP (TK ## I) f’
             suffices_by metis_tac[ptree_head_NT_mkNd] >>
            metis_tac[MAP_EQ_APPEND, MAP_APPEND]) >>
      ‘∃tyoppt. subs = [tyoppt] ∧ ptree_head tyoppt = NN nTyOp ∧
                valid_lptree cmlG tyoppt’
        by (fs[cmlG_applied, cmlG_FDOM, MAP_EQ_CONS] >> rveq >> fs[]) >>
      gvs[] >>
      qexists_tac ‘[tyoppt]::blist’ >>
      simp[left_insert2_FOLDL] >>
      irule_at Any peg_eval_list_cons >>
      first_assum $ irule_at Any >>
      qpat_x_assum ‘peg_eval X Y Z’ mp_tac >>
      simp[SimpL “(==>)”, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      drule_all (MATCH_MP rfringe_length_not_nullable nullable_Tbase) >>
      simp[] >> strip_tac >> fs[cmlG_FDOM, cmlG_applied] >>
      Cases_on ‘af'’ >> fs[] >>
      Cases_on ‘real_fringe tyoppt’ >> gvs[]
      >- (drule_all (MATCH_MP rfringe_length_not_nullable nullable_TyOp) >>
          simp[]) >>
      rename [‘real_fringe tyoppt = (TK ## I) h::tks’] >>
      Cases_on ‘h’ >> fs[] >>
      rename [‘real_fringe tyoppt = (TK h, _) ::tks’] >>
      ‘h ≠ LparT ∧ ¬isTyvarT h’
        by (erule mp_tac
                  (REWRITE_RULE [GSYM AND_IMP_INTRO]
                                rfirstSet_nonempty_fringe)>>
            simp[] >> rpt strip_tac >> rveq >> fs[]) >>
      qpat_x_assum ‘peg_eval _ (_, choicel _) _’ mp_tac >>
      simp[choicel_cons,seql_cons,peg_eval_tok, peg_eval_seqempty] >>
      rpt strip_tac >> gvs[] >> first_assum $ irule_at Any) >>
  rename [‘ptree_head bpt = NN nTbase’] >>
  irule_at Any peg_eval_list_nil >> simp[] >>
  ‘∃fl fe. peg_eval cmlPEG (sfx, nt (mkNT nTyOp) I) (Failure fl fe)’
    by (Cases_on ‘sfx’ >> gvs[stoppers_def, not_peg0_peg_eval_NIL_NONE] >>
        rename [‘FST h ≠ AlphaT _’] >> Cases_on ‘h’ >>
        gs[peg_respects_firstSets_rwt]) >>
  pop_assum $ irule_at Any >>
  gs[rich_listTheory.IS_SUFFIX_compute] >>
  drule rich_listTheory.IS_PREFIX_LENGTH >>
  simp[DECIDE “x:num ≤ y ⇔ x = y ∨ x < y”] >> strip_tac >~
  [‘LENGTH pfx = LENGTH master’]
  >- (‘pfx = master’
        by metis_tac[rich_listTheory.IS_PREFIX_LENGTH_ANTI,
                     REVERSE_11, listTheory.LENGTH_REVERSE] >>
      gvs[GSYM RIGHT_EXISTS_IMP_THM, SKOLEM_THM] >>
      first_x_assum $ irule_at Any >>
      qpat_assum ‘real_fringe _ = MAP _ master’ (REWRITE_TAC o single o SYM) >>
      irule_at Any EQ_REFL >> simp[stoppers_def]) >>
  first_x_assum (pop_assum o mp_then (Pos hd)
                 (strip_assume_tac o SRULE [GSYM RIGHT_EXISTS_IMP_THM,
                                            SKOLEM_THM])) >>
  pop_assum $ irule_at Any >> simp[stoppers_def]
QED

(* could generalise this slightly: allowing for nullable seps, but this would
   require a more complicated condition on the sfx, something like
     (sfx ≠ [] ∧ ¬nullable cmlG [SEP] ⇒ HD sfx ∉ firstSet cmlG [SEP]) ∧
     (sfx ≠ [] ∧ nullable cmlG [SEP] ⇒ HD sfx ∉ firstSet cmlG [C])
   and I can't be bothered with that right now. *)

Theorem peg_linfix_complete:
  (∀n. SEP = NT n ⇒
       ∃nn. n = mkNT nn ∧ nt (mkNT nn) I ∈ Gexprs cmlPEG ∧
            stoppers nn = UNIV) ∧
  (∀n. C = NT n ⇒ ∃nn. n = mkNT nn) ∧
  (∀t. t ∈ firstSet cmlG [SEP] ⇒ t ∉ stoppers P) ∧
  (∀n. C = NT (mkNT n) ⇒
       (∀t. t ∈ firstSet cmlG [SEP] ⇒ t ∈ stoppers n) ∧
       (∀t. t ∈ stoppers P ⇒ t ∈ stoppers n)) ∧
  ¬peg0 cmlPEG (sym2peg C) ∧ ¬nullable cmlG [C] ∧
  ¬peg0 cmlPEG (sym2peg SEP) ∧ ¬nullable cmlG [SEP] ∧
  cmlG.rules ' (mkNT P) = { [NT (mkNT P); SEP; C] ; [C] } ∧
  (∀pt pfx0 sfx.
     LENGTH pfx0 < LENGTH master ∧
     (∀n. ptree_head pt = NT (mkNT n) ∧ sfx ≠ [] ⇒
          FST (HD sfx) ∈ stoppers n) ∧
     valid_lptree cmlG pt ∧ ptree_head pt ∈ {SEP; C} ∧
     real_fringe pt = MAP (TOK ## I) pfx0 ⇒
     ∃eo.
       peg_eval cmlPEG (pfx0 ++ sfx, sym2peg (ptree_head pt))
                (Success sfx [pt] eo)) ∧
  (∀pt sfx.
     valid_lptree cmlG pt ∧ ptree_head pt = C ∧
     (∀n. C = NT (mkNT n) ∧ sfx ≠ [] ⇒ FST (HD sfx) ∈ stoppers n) ∧
     real_fringe pt = MAP (TOK ## I) master ⇒
     ∃eo.
       peg_eval cmlPEG (master ++ sfx, sym2peg C) (Success sfx [pt] eo))
 ⇒
 ∀pfx pt sfx.
   IS_SUFFIX master pfx ∧
   valid_lptree cmlG pt ∧ ptree_head pt = NT (mkNT P) ∧
   (sfx ≠ [] ⇒ FST (HD sfx) ∈ stoppers P) ∧
   real_fringe pt = MAP (TOK ## I) pfx
  ⇒
  ∃eo.
    peg_eval cmlPEG (pfx ++ sfx,
                     peg_linfix (mkNT P) (sym2peg C) (sym2peg SEP))
             (Success sfx [pt] eo)
Proof
  strip_tac >>
  simp[peg_linfix_def, list_case_lemma, peg_eval_rpt] >> dsimp[] >>
  gen_tac >>
  completeInduct_on ‘LENGTH pfx’ >> rpt strip_tac >>
  full_simp_tac (srw_ss() ++ DNF_ss) [] >> rveq >>
  ‘∃subs. pt = mkNd (mkNT P) subs’ by metis_tac [ptree_head_NT_mkNd] >>
  rw[] >> fs[] >>
  Q.UNDISCH_THEN ‘MAP ptree_head subs ∈ cmlG.rules ' (mkNT P)’ mp_tac >>
  simp[MAP_EQ_CONS] >> reverse (rpt strip_tac) >> rveq >> fs[] >~
  [‘real_fringe cpt = MAP _ pfx’]
  >- (irule_at Any peg_eval_list_nil >> simp[mk_linfix_def] >>
      ‘∃fl fe. peg_eval cmlPEG (sfx, sym2peg SEP) (Failure fl fe)’
      by (Cases_on ‘SEP’ >> gs[sym2peg_def]
          >- (Cases_on ‘sfx’ >> gs[] >> rename [‘FST h ∈ stoppers P’] >>
              Cases_on ‘h’ >> gs[] >> strip_tac >> gvs[]) >>
          Cases_on ‘sfx’ >> simp[not_peg0_peg_eval_NIL_NONE] >> gs[] >>
          rename[‘FST h ∈ stoppers P’] >> Cases_on ‘h’ >>
          irule_at Any (iffRL peg_respects_firstSets_rwt) >> gs[] >>
          metis_tac[]) >>
      dxrule_then assume_tac peg_det >> simp[peg_eval_seq_NONE] >>
      Cases_on ‘cpt’
      >- gvs[MAP_EQ_SING, sym2peg_def, PAIR_MAP, PULL_EXISTS] >>
      rename [‘valid_lptree _ (Nd pair subs)’] >> Cases_on ‘pair’ >>
      gs[sym2peg_def] >>
      gs[rich_listTheory.IS_SUFFIX_compute] >>
      drule_then (assume_tac o SRULE[])
                 rich_listTheory.IS_PREFIX_LENGTH >>
      fs[DECIDE “x:num ≤ y ⇔ x < y ∨ x = y”]
      >- (first_x_assum drule >> simp[] >>
          disch_then (strip_assume_tac o
                      SRULE [GSYM RIGHT_EXISTS_IMP_THM, SKOLEM_THM]) >>
          pop_assum $ irule_at Any >> simp[]) >>
      ‘pfx = master’ by
        metis_tac[rich_listTheory.IS_PREFIX_LENGTH_ANTI, REVERSE_11,
                  listTheory.LENGTH_REVERSE] >> gvs[] >>
      gs[SKOLEM_THM, GSYM RIGHT_EXISTS_IMP_THM] >>
      first_x_assum $ irule_at Any >> simp[]) >>
  fs[DISJ_IMP_THM, FORALL_AND_THM] >>
  rename [‘cmlG.rules ' (mkNT P) = {[NN P; ptree_head spt; ptree_head cpt];
                                    [ptree_head cpt]}’,
          ‘ptree_head ppt = NN P’] >>
  fs[MAP_EQ_APPEND] >> rw[] >>
  rename1 ‘real_fringe ppt = MAP _ pf’ >>
  rename1 ‘real_fringe spt = MAP _ sf’ >>
  rename1 ‘real_fringe cpt = MAP _ cf’ >>
  qispl_then [‘cmlG’, ‘mkNT P’, ‘ptree_head spt’, ‘ptree_head cpt’,
              ‘ppt’, ‘spt’, ‘cpt’, ‘pf’, ‘sf’, ‘cf’] mp_tac
    lassoc_reassociated >> simp[MAP_EQ_APPEND] >>
  dsimp[] >>
  map_every qx_gen_tac [‘cpt'’, ‘spt'’, ‘ppt'’]  >> rpt strip_tac >>
  rename1 ‘real_fringe cpt' = MAP _ cf'’ >>
  rename1 ‘real_fringe spt' = MAP _ sf'’ >>
  rename1 ‘real_fringe ppt' = MAP _ pf'’ >>
  qexistsl_tac [‘sf' ++ pf' ++ sfx’, ‘[cpt']’] >>
  ‘0 < LENGTH (MAP (TK ## I) sf') ∧ 0 < LENGTH (MAP (TK ## I) cf')’
    by metis_tac [rfringe_length_not_nullable] >>
  ntac 2 (pop_assum mp_tac) >> simp[] >> ntac 2 strip_tac >>
  ‘∃eo. peg_eval cmlPEG (cf' ++ (sf' ++ pf' ++ sfx), sym2peg (ptree_head cpt))
                 (Success (sf' ++ pf' ++ sfx) [cpt'] eo)’
    by (first_x_assum irule >> simp[] >> gs[IS_SUFFIX_compute] >>
        drule IS_PREFIX_LENGTH >> simp[] >> Cases_on ‘sf'’ >> simp[] >> gs[] >>
        rename1 ‘real_fringe spt' = (TK ## I) s1::MAP (TK ## I) ss’ >>
        ‘∃s1t s1l. s1 = (s1t, s1l)’ by (Cases_on ‘s1’ >> simp[]) >> fs[] >>
        ‘s1t ∈ firstSet cmlG [ptree_head spt']’
          by metis_tac [rfirstSet_nonempty_fringe] >>
        metis_tac[]) >> gs[] >> dxrule_then assume_tac peg_det >> simp[] >>
  irule_at Any peg_eval_list_cons >> simp[peg_eval_seq_SOME, PULL_EXISTS] >>
  ‘∃eo. peg_eval cmlPEG (sf' ++ (pf' ++ sfx), sym2peg (ptree_head spt))
                 (Success (pf' ++ sfx) [spt'] eo)’
    by (first_x_assum irule >> simp[] >> gs[IS_SUFFIX_compute] >>
        drule IS_PREFIX_LENGTH >> simp[] >> Cases_on ‘pf'’ >> gs[] >>
        rpt strip_tac >> last_x_assum drule >> simp[PULL_EXISTS]) >>
  dxrule_then assume_tac peg_det >> gs[] >>
  ‘IS_SUFFIX master pf'’
    by (gs[IS_SUFFIX_compute, REVERSE_APPEND] >>
        metis_tac[IS_PREFIX_APPEND1]) >>
  first_x_assum (pop_assum o mp_then Any mp_tac) >>
  first_assum (disch_then o resolve_then (Pos last) mp_tac) >> simp[] >>
  disch_then $ qspec_then ‘sfx’ mp_tac >> simp[] >>
  qpat_x_assum ‘_ ++ _ = _ ++ _’ (mp_tac o Q.AP_TERM ‘LENGTH’) >> simp[] >>
  rpt strip_tac >> ntac 2 (first_assum $ irule_at Any) >>
  simp[left_insert_mk_linfix] >>
  rename [‘a ≠ []’] >> Cases_on ‘a’ >> gs[mk_linfix_def] >>
  Cases_on ‘ptree_head cpt’ >> gs[sym2peg_def] >>
  dxrule peg_sound >> simp[PULL_EXISTS]
QED

val stdstart =
    simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, MAP_EQ_CONS] >> rw[] >>
    fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >> rw[]

fun note_tac s g = (print (s ^ "\n"); ALL_TAC g)

val list_case_eq = prove_case_eq_thm {
  case_def= TypeBase.case_def_of ``:'a list``,
  nchotomy = TypeBase.nchotomy_of ``:'a list``}

fun hasc cnm t = #1 (dest_const t) = cnm handle HOL_ERR _ => false
fun const_assum0 f cnm k =
  f (k o assert (can (find_term (hasc cnm)) o concl))
val const_assum = const_assum0 first_assum
val const_x_assum = const_assum0 first_x_assum

val pmap_cases =
  rpt ((rename [`(_,_) = (_ ## _) pair`] >> Cases_on `pair` >> fs[] >> rveq)
         ORELSE
       (rename [`(_ ## _) pair = (_,_)`] >> Cases_on `pair` >> fs[] >> rveq))

Theorem pmap_EQ[simp]:
  (x,y) = (f ## g) p ⇔ ∃x0 y0. p = (x0,y0) ∧ x = f x0 ∧ y = g y0
Proof
  Cases_on ‘p’ >> simp[]
QED

Theorem ptPapply0_FOLDL:
   ∀l a pt.
     ptPapply0 a (l ++ [pt]) =
     [bindNT0 nPapp [FOLDL (λpcpt bpt. bindNT0 nPConApp [pcpt; bpt]) a l;
                     pt]]
Proof
  Induct >> simp[ptPapply0_def] >> Cases_on `l` >> simp[ptPapply0_def] >>
  fs[]
QED

Theorem FST_EQ[simp]:
  FST p = x ⇔ ∃y. p = (x,y)
Proof
  Cases_on ‘p’ >> simp[]
QED

Theorem FST_NEQ[simp]:
  FST p ≠ x ⇔ ∃x0 y. p = (x0,y) ∧ x0 ≠ x
Proof Cases_on ‘p’ >> simp[]
QED

Theorem ALL_FST_NEQ[simp]:
  (∀y. p ≠ (x,y)) ⇔ ∃x0 y. p = (x0,y) ∧ x0 ≠ x
Proof Cases_on ‘p’ >> simp[]
QED


Theorem completeness:
  ∀pt N pfx sfx.
    valid_lptree cmlG pt ∧ ptree_head pt = NT (mkNT N) ∧
    mkNT N ∈ FDOM cmlPEG.rules ∧
    (sfx ≠ [] ⇒ FST (HD sfx) ∈ stoppers N) ∧
    real_fringe pt = MAP (TOK ## I) pfx
    ⇒
    ∃eo.
      peg_eval cmlPEG (pfx ++ sfx, nt (mkNT N) I) (Success sfx [pt] eo)
Proof
  ho_match_mp_tac parsing_ind >> qx_gen_tac ‘pt’ >>
  disch_then (strip_assume_tac o SIMP_RULE (srw_ss() ++ DNF_ss) []) >>
  RULE_ASSUM_TAC (SIMP_RULE (srw_ss() ++ CONJ_ss) [AND_IMP_INTRO]) >>
  map_every qx_gen_tac [‘N’, ‘pfx’, ‘sfx’] >> strip_tac >> fs[] >>
  ‘∃subs. pt = mkNd (mkNT N) subs’
    by metis_tac[ptree_head_NT_mkNd] >>
  rveq >> fs[] >>
  rpt (first_x_assum (mp_tac o assert (free_in “cmlG.rules” o concl))) >>
  Cases_on ‘N’ >> simp[cmlG_applied, cmlG_FDOM]
  >- (print_tac "nV" >>
      simp[peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, FDOM_cmlPEG, peg_V_def,
           peg_eval_choice, peg_eval_tok_NONE] >>
      dsimp[MAP_EQ_SING] >> rpt strip_tac >> gvs[MAP_EQ_SING] >>
      simp[mkNd_def, choicel_cons, peg_eval_tok, peg_eval_seqempty,
           tokSymP_def])
  >- (print_tac "nUQTyOp" >>
      simp[MAP_EQ_SING] >> simp[peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, FDOM_cmlPEG,
           peg_eval_choice, peg_eval_tok_NONE] >>
      strip_tac >> gvs[MAP_EQ_SING])
  >- (print_tac "nUQConstructorName" >>
      simp[MAP_EQ_SING, peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, FDOM_cmlPEG, peg_UQConstructorName_def] >>
      strip_tac >> gvs[MAP_EQ_SING])
  >- (print_tac "nTyvarN" >> dsimp[MAP_EQ_SING] >> simp[peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, FDOM_cmlPEG] >> rpt strip_tac >>
      gvs[MAP_EQ_SING])
  >- (print_tac "nTypeName" >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, FDOM_cmlPEG] >>
      rpt strip_tac >> gvs[]
      >- (dsimp[Once choicel_cons] >> DISJ1_TAC >> fs[MAP_EQ_SING] >> rveq >>
          rename [‘ptree_head pt = NN nUQTyOp’] >>
          first_x_assum irule >>
          simp[NT_rank_def] >> fs[mkNd_def, stoppers_def])
      >- (dsimp[Once choicel_cons] >> DISJ2_TAC >>
          gvs[MAP_EQ_CONS] >> simp[peg_eval_seq_NONE] >>
          gvs [MAP_EQ_APPEND, MAP_EQ_SING, MAP_EQ_CONS] >>
          simp[peg_respects_firstSets_rwt] >>
          dsimp[Once choicel_cons] >> disj1_tac >>
          simp[seql_cons_SOME, PULL_EXISTS] >>
          gs[SKOLEM_THM, GSYM RIGHT_EXISTS_IMP_THM] >> normlist >>
          first_assum $ irule_at (Pos hd) >> simp[stoppers_def] >>
          first_x_assum $ irule_at Any >> simp[stoppers_def]) >>
      dsimp[Once choicel_cons] >> disj2_tac >>
      simp[peg_eval_seqempty, PULL_EXISTS] >>
      dsimp[choicel_cons] >> disj2_tac >>
      simp[seql_cons_SOME, PULL_EXISTS] >> csimp[] >>
      dsimp[Once seql_cons, peg_eval_tok] >>
      irule_at Any $ iffRL peg_respects_firstSets_rwt >> simp[] >>
      gvs[MAP_EQ_CONS] >> first_x_assum irule >>
      simp[stoppers_def])
  >- (print_tac "nTypeList2" >> dsimp[MAP_EQ_CONS] >>
      map_every qx_gen_tac [‘typt’, ‘loc’, ‘tylpt’] >> rw[] >>
      gvs[MAP_EQ_APPEND, MAP_EQ_CONS] >> pmap_cases >>
      simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied, FDOM_cmlPEG] >>
      dsimp[seql_cons_SOME] >>
      first_assum $ drule_at (Pat ‘real_fringe typt = _’) >>
      simp_tac (srw_ss()) [] >> asm_simp_tac bool_ss [] >>
      simp_tac (srw_ss()) [] >>
      disch_then (strip_assume_tac o
                  SRULE [GSYM RIGHT_EXISTS_IMP_THM, SKOLEM_THM]) >>
      normlist >> pop_assum $ irule_at Any >> simp[stoppers_def] >>
      first_x_assum $ irule_at Any >> simp[] >> gs[stoppers_def])
  >- (print_tac "nTypeList1" >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> rw[] >>
      gvs[MAP_EQ_APPEND, MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM] >>
      simp[seql_cons_SOME, PULL_EXISTS] >>
      gvs[SKOLEM_THM, GSYM RIGHT_EXISTS_IMP_THM]
      >- (first_x_assum $ irule_at Any >> simp[NT_rank_def] >>
          dsimp[choicel_cons, seql_cons, peg_eval_tok] >> csimp[] >>
          gvs[stoppers_def] >> Cases_on ‘sfx’ >> gvs[]) >>
      normlist >> first_assum $ irule_at Any >> simp[] >>
      simp[stoppers_def] >> dsimp[Once choicel_cons] >> disj1_tac >>
      simp[seql_cons_SOME, peg_eval_tok] >> first_x_assum $ irule_at Any >>
      simp[])
  >- (print_tac "nTypeDec" >> dsimp[MAP_EQ_CONS] >> rw[] >>
      gvs[DISJ_IMP_THM, FORALL_AND_THM, MAP_EQ_CONS] >>
      simp[peg_eval_NT_SOME] >>
      simp[FDOM_cmlPEG, cmlpeg_rules_applied, peg_TypeDec_def] >>
      rename [‘MAP _ pfx = real_fringe dtspt’] >>
      irule_at Any
      (peg_linfix_complete
         |> Q.INST [‘SEP’ |-> ‘TK AndT’, ‘C’ |-> ‘NN nDtypeDecl’,
                    ‘P’ |-> ‘nDtypeDecls’]
         |> SIMP_RULE (srw_ss() ++ DNF_ss)
                      [sym2peg_def, MAP_EQ_CONS, cmlG_applied, EXTENSION,
                       DISJ_COMM, AND_IMP_INTRO]) >> gs[stoppers_def] >>
      irule_at Any IS_SUFFIX_REFL >> rpt strip_tac >>
      first_x_assum irule >> simp[stoppers_def])
  >- (print_tac "nTypeAbbrevDec" >> dsimp[MAP_EQ_CONS] >>
      rw[] >> gvs[DISJ_IMP_THM, FORALL_AND_THM, MAP_EQ_CONS] >>
      simp[peg_eval_NT_SOME] >>
      simp[FDOM_cmlPEG, cmlpeg_rules_applied, seql_cons_SOME, PULL_EXISTS] >>
      gvs[MAP_EQ_APPEND, MAP_EQ_CONS] >>
      first_x_assum (kall_tac o has_const “NT_rank”) >>
      gs[GSYM RIGHT_EXISTS_IMP_THM, SKOLEM_THM] >>
      normlist >> first_assum $ irule_at (Pos hd) >> simp[stoppers_def] >>
      first_x_assum $ irule_at Any >> gs[stoppers_def])
  >- (print_tac "nType" >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, MAP_EQ_CONS] >> rw[] >>
      gvs[MAP_EQ_APPEND, MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM,
          seql_cons_SOME, PULL_EXISTS]
      >- (gs[SKOLEM_THM, GSYM RIGHT_EXISTS_IMP_THM] >>
          ‘NT_rank (mkNT nPType) < NT_rank (mkNT nType)’ by simp[NT_rank_def] >>
          first_x_assum (pop_assum o mp_then Any (irule_at Any)) >> simp[] >>
          dsimp[choicel_cons, seql_cons, peg_eval_tok] >> csimp[] >>
          Cases_on ‘sfx’ >> gvs[stoppers_def]) >>
      first_x_assum (kall_tac o has_const “NT_rank”) >>
      gs[GSYM RIGHT_EXISTS_IMP_THM, SKOLEM_THM] >> normlist >>
      first_assum $ irule_at Any >> simp[stoppers_def] >>
      dsimp[choicel_cons, seql_cons, peg_eval_tok] >>
      first_x_assum $ irule_at Any >> gs[stoppers_def])
  >- (print_tac "nTyVarList" >> simp[peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, FDOM_cmlPEG] >>
      disch_then assume_tac >>
      match_mp_tac (peg_linfix_complete
                      |> Q.INST [‘C’ |-> ‘NN nTyvarN’, ‘SEP’ |-> ‘TK CommaT’,
                                 ‘P’ |-> ‘nTyVarList’,
                                 ‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (srw_ss() ++ DNF_ss)
                      [sym2peg_def, cmlG_applied, cmlG_FDOM, EXTENSION,
                       DISJ_COMM, AND_IMP_INTRO]) >>
      simp[MAP_EQ_SING] >> simp[cmlG_FDOM, cmlG_applied, FORALL_PROD] >>
      ‘NT_rank (mkNT nTyvarN) < NT_rank (mkNT nTyVarList)’
      by simp[NT_rank_def]>> simp[FDOM_cmlPEG] >> fs[])
  >- (print_tac "nTyOp" >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, MAP_EQ_CONS] >>
      rw[] >> fs[MAP_EQ_CONS]
      >- dsimp[NT_rank_def, Once EXISTS_PROD, mkNd_def] >> pmap_cases >>
      simp[peg_respects_firstSets, firstSet_nUQTyOp, mkNd_def])
  >- (print_tac "nTopLevelDecs" >> dsimp[MAP_EQ_CONS] >> rpt conj_tac >>
      rpt gen_tac >> strip_tac >> rveq >> simp[peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, FDOM_cmlPEG] >> fs[]
      >- (disj1_tac >> dsimp[] >> fs[DISJ_IMP_THM, FORALL_AND_THM] >> rw[] >>
          simp[mkNd_def] >>
          fs[MAP_EQ_APPEND, MAP_EQ_CONS] >> rveq >> pmap_cases >>
          rename [‘ptree_head Ept = NN nE’,
                  ‘real_fringe Ept = MAP _ Efr’,
                  ‘ptree_head TLDpt = NN nTopLevelDecs’,
                  ‘real_fringe TLDpt = MAP _ TLDfr’,
                  ‘(SemicolonT, semiloc)’] >>
          first_assum
            (qspecl_then [‘Ept’, ‘nE’, ‘Efr’, ‘(SemicolonT, semiloc) :: TLDfr’]
                         mp_tac) >>
          impl_tac >- simp[] >>
          strip_tac >>
          map_every qexists_tac [‘[Ept]’, ‘TLDfr’, ‘[TLDpt]’] >>
          simp[Once EXISTS_PROD] >> conj_tac
          >- asm_simp_tac bool_ss [GSYM APPEND_ASSOC, APPEND] >>
          first_x_assum
            (qspecl_then [‘TLDpt’, ‘nTopLevelDecs’, ‘TLDfr’, ‘[]’] mp_tac) >>
          simp[])
      >- (disj2_tac >> fs[MAP_EQ_APPEND] >> fs[DISJ_IMP_THM, FORALL_AND_THM] >>
          rveq >>
          rename [‘ptree_head TLDpt = NN nTopLevelDec’,
                  ‘ptree_head NeTLDspt = NN nNonETopLevelDecs’,
                  ‘real_fringe TLDpt = MAP _ TLDfr’,
                  ‘real_fringe NeTLDspt = MAP _ NeTLDsfr’] >>
          ‘peg_eval cmlPEG (TLDfr ++ NeTLDsfr, nt (mkNT nTopLevelDec) I)
                           (SOME (NeTLDsfr, [TLDpt]))’
             by (Cases_on ‘NeTLDsfr = []’
                 >- (loseC “LENGTH” >>
                     first_x_assum (qspecl_then [‘TLDpt’, ‘nTopLevelDec’, ‘[]’]
                                                mp_tac) >>
                     simp[NT_rank_def]) >>
                 loseC “NT_rank” >>
                 ‘0 < LENGTH NeTLDsfr’ by (Cases_on ‘NeTLDsfr’ >> fs[]) >>
                 first_x_assum irule >> simp[] >>
                 Cases_on ‘NeTLDsfr’ >> fs[] >>
                 rename [‘real_fringe NeTLDspt = (TK ## I) pair :: _’] >>
                 Cases_on ‘pair’ >> fs[] >> rename [‘(TK tok1,_) :: MAP _ _’] >>
                 ‘tok1 ∈ firstSet cmlG [NN nNonETopLevelDecs]’
                   by metis_tac[rfirstSet_nonempty_fringe] >>
                 fs[]) >>
          ‘0 < LENGTH (MAP (TK ## I) TLDfr)’
            by metis_tac[rfringe_length_not_nullable, nullable_TopLevelDec] >>
          fs[] >>
          ‘∃tok1 loc1 TLDfr0. TLDfr = (tok1,loc1) :: TLDfr0’
              by (Cases_on ‘TLDfr’ >> fs[] >> metis_tac[pair_CASES])>>
          rveq >> fs[] >>
          ‘tok1 ∈ firstSet cmlG [NN nTopLevelDec]’
            by metis_tac[rfirstSet_nonempty_fringe] >>
          pop_assum (fn th =>
            ‘peg_eval cmlPEG ((tok1,loc1)::(TLDfr0 ++ NeTLDsfr),
                              nt (mkNT nE) I) NONE’
            by (irule peg_respects_firstSets >> simp[] >> strip_tac >>
                assume_tac th >> fs[firstSet_nE] >> rveq >> fs[])) >> simp[] >>
          disj1_tac >> simp[mkNd_def] >>
          map_every qexists_tac [‘[TLDpt]’, ‘NeTLDsfr’, ‘[NeTLDspt]’] >>
          simp[] >> loseC “NT_rank” >>
          first_x_assum
            (qspecl_then [‘NeTLDspt’, ‘nNonETopLevelDecs’, ‘NeTLDsfr’, ‘[]’]
                         mp_tac) >> simp[])
      >- (fs[MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM] >> rveq >> disj2_tac >>
          conj_tac >> pmap_cases
          >- (disj1_tac >> irule peg_respects_firstSets >> simp[]) >>
          disj2_tac >> conj_tac
          >- (disj1_tac >> irule peg_respects_firstSets >> simp[]) >>
          fs[] >> ‘mkNT nTopLevelDecs ∈ FDOM cmlPEG.rules’ by simp[] >>
          simp[mkNd_def] >>
          metis_tac[APPEND_NIL, DECIDE “x < SUC x”])
      >- (simp[not_peg0_peg_eval_NIL_NONE] >> disj2_tac >>
          simp[peg_eval_tok_NONE, mkNd_def]))
  >- (print_tac "nTopLevelDec" >> simp[peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, FDOM_cmlPEG] >> strip_tac >>
      fs[MAP_EQ_SING] >> rw[] >> fs[mkNd_def]
      >- (DISJ1_TAC >> first_x_assum match_mp_tac >>
          simp[NT_rank_def, FDOM_cmlPEG]) >>
      DISJ2_TAC >> reverse conj_tac
      >- (first_x_assum match_mp_tac >> simp[NT_rank_def, FDOM_cmlPEG]) >>
      ‘0 < LENGTH (MAP (TK ## I) pfx)’
        by metis_tac [rfringe_length_not_nullable, nullable_Decl] >> fs[] >>
      Cases_on ‘pfx’ >> fs[] >>
      rename [‘(TK ## I) pair :: MAP _ _’] >> Cases_on ‘pair’ >> fs[] >>
      match_mp_tac peg_respects_firstSets >>
      simp[PEG_exprs] >> strip_tac >> rw[] >>
      ‘StructureT ∈ firstSet cmlG [NN nDecl]’
        by metis_tac [rfirstSet_nonempty_fringe] >> fs[])
  >- (print_tac "nTbaseList" >> stdstart >> pmap_cases
      >- (rename [‘sfx = []’] >> Cases_on ‘sfx’ >> fs[]
          >- simp[not_peg0_peg_eval_NIL_NONE, peg0_nPTbase] >>
          rename [‘FST tkl = LparT’] >> Cases_on ‘tkl’ >>
          fs[peg_respects_firstSets, peg0_nPTbase]) >>
      rename [‘ptree_head bpt = NN nPTbase’, ‘real_fringe bpt = MAP _ bf’,
              ‘ptree_head blpt = NN nTbaseList’, ‘real_fringe blpt = MAP _ blf’
      ] >>
      Cases_on ‘blf = []’
      >- (fs[] >>
          ‘NT_rank (mkNT nPTbase) < NT_rank (mkNT nTbaseList)’
            by simp[NT_rank_def] >>
          first_x_assum (pop_assum o mp_then Any mp_tac) >>
          disch_then (first_assum o mp_then (Pos hd) mp_tac) >> simp[] >>
          rename [‘peg_eval _ (bf ++ sfx, _)’] >>
          disch_then (qspec_then ‘sfx’ assume_tac) >>
          pop_assum (assume_tac o MATCH_MP (CONJUNCT1 peg_deterministic)) >>
          simp[] >>
          first_x_assum (qpat_assum ‘ptree_head _ = NN nTbaseList’ o
                         mp_then Any mp_tac) >> simp[] >>
          disch_then irule >> simp[] >>
          metis_tac[not_peg0_LENGTH_decreases, LENGTH_APPEND,
                    DECIDE “y < x + y:num ⇒ 0 < x”, peg0_nPTbase]) >>
      ‘0 < LENGTH blf’ by (Cases_on ‘blf’ >> fs[]) >>
      ‘LENGTH bf < LENGTH (bf ++ blf)’ by simp[] >>
      first_assum (pop_assum o mp_then (Pos hd) mp_tac) >>
      disch_then (qpat_assum ‘ptree_head _ = NN nPTbase’ o
                  mp_then Any mp_tac) >>
      rename [‘FST (HD sfx) ≠ LparT’] >>
      disch_then (qspec_then ‘blf ++ sfx’ mp_tac) >>
      impl_tac >- simp[] >>
      disch_then (assume_tac o MATCH_MP (CONJUNCT1 peg_deterministic) o
                  SIMP_RULE (srw_ss()) []) >> simp[] >>
      first_x_assum irule >> simp[] >>
      ‘LENGTH (blf ++ sfx) < LENGTH (bf ++ blf ++ sfx)’ suffices_by simp[] >>
      metis_tac[not_peg0_LENGTH_decreases, peg0_nPTbase])
  >- (print_tac "nTbase" >> stdstart >> pmap_cases >>
      simp[mkNd_def, peg_eval_tok_NONE]
      >- (rename [‘real_fringe topt = MAP _ opf’,
                  ‘ptree_head topt = NN nTyOp’] >>
          erule mp_tac (MATCH_MP rfringe_length_not_nullable nullable_TyOp) >>
          simp[] >> Cases_on ‘opf’ >> simp[] >> fs[] >>
          rename [‘(TK ## I) pair :: MAP _ _’] >> Cases_on ‘pair’ >> fs[] >>
          rename [‘(TK tok1, loc1) :: MAP _ _’] >>
          simp[peg_eval_tok_NONE] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> simp[] >>
          strip_tac >> rveq >> simp[NT_rank_def])
      >- (rename [‘ptree_head topt = NN nTyOp’, ‘MAP _ opf = real_fringe topt’,
                  ‘ptree_head l2pt = NN nTypeList2’,
                  ‘real_fringe l2pt = MAP _ l2f’] >>
          DISJ2_TAC >> reverse conj_tac
          >- (dsimp[] >> normlist >> first_assum (unify_firstconj kall_tac) >>
              simp[]) >>
          DISJ2_TAC >>
          ‘∃subs. l2pt = mkNd (mkNT nTypeList2) subs’
            by metis_tac[ptree_head_NT_mkNd] >>
          fs[MAP_EQ_CONS, MAP_EQ_APPEND, cmlG_FDOM, cmlG_applied] >> rw[] >>
          fs[MAP_EQ_CONS, MAP_EQ_APPEND] >> rw[] >>
          normlist >> first_assum (unify_firstconj kall_tac) >>
          asm_match ‘ptree_head typt = NN nType’ >> qexists_tac ‘typt’ >>
          simp[peg_eval_tok_NONE] >> pmap_cases) >>
      rename [‘ptree_head typt = NN nType’, ‘real_fringe typt = MAP _ tyf’] >>
      DISJ1_TAC >> dsimp[Once EXISTS_PROD] >> normlist >> simp[])
  >- (print_tac "nStructure" >> dsimp[MAP_EQ_CONS] >> rw[] >>
      fs[DISJ_IMP_THM, FORALL_AND_THM, MAP_EQ_CONS, MAP_EQ_APPEND] >>
      rw[] >> fs[] >> pmap_cases >>
      simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied, FDOM_cmlPEG] >>
      dsimp[mkNd_def] >> loseC “NT_rank” >>
      normlist >> first_assum (unify_firstconj kall_tac) >> simp[] >>
      normlist >> simp[] >>
      first_assum (unify_firstconj kall_tac) >> simp[Once EXISTS_PROD])
  >- (print_tac "nStructName" >>
      simp[MAP_EQ_SING, peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, FDOM_cmlPEG, peg_StructName_def] >>
      strip_tac >> rveq >> fs[MAP_EQ_SING, mkNd_def] >> pmap_cases >> simp[])
  >- (print_tac "nSpecLineList" >>
      simp[peg_eval_NT_SOME] >>
      simp[cmlpeg_rules_applied, FDOM_cmlPEG] >> simp[MAP_EQ_CONS] >>
      strip_tac >> rveq >> fs[MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >>
      rw[]
      >- (rename [‘ptree_head slpt = NN nSpecLine’,
                  ‘real_fringe slpt = MAP _ sf’,
                  ‘ptree_head sllpt = NN nSpecLineList’,
                  ‘real_fringe sllpt = MAP _ lf’] >>
          DISJ1_TAC >>
          map_every qexists_tac [‘[slpt]’, ‘lf ++ sfx’, ‘[sllpt]’] >>
          simp[] >>
          ‘0 < LENGTH (MAP (TK ## I) sf)’
            by metis_tac [nullable_SpecLine, rfringe_length_not_nullable] >>
          fs[] >>
          Cases_on ‘lf = []’ >> fs[] >- simp[NT_rank_def, mkNd_def] >>
          ‘0 < LENGTH lf’ by (Cases_on ‘lf’ >> fs[]) >>
          simp[mkNd_def] >>
          REWRITE_TAC [GSYM APPEND_ASSOC] >>
          first_x_assum (match_mp_tac o has_length) >> simp[] >>
          Cases_on ‘lf’ >> fs[] >> rpt strip_tac >> rw[] >> fs[PAIR_MAP] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> simp[])
      >- (DISJ2_TAC >> fs[MAP_EQ_CONS] >> rw[] >> pmap_cases >>
          simp[peg_respects_firstSets, PEG_exprs, mkNd_def]) >>
      DISJ2_TAC >> Cases_on ‘sfx’ >> fs[peg_eval_tok_NONE]
      >- simp[not_peg0_peg_eval_NIL_NONE, PEG_exprs, PEG_wellformed,
              mkNd_def] >>
      rename [‘FST h ≠ ValT’] >> Cases_on ‘h’ >> fs[] >>
      simp[peg_respects_firstSets, PEG_exprs, mkNd_def])
  >- (print_tac "nSpecLine" >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, MAP_EQ_CONS] >> rw[] >>
      fs[MAP_EQ_APPEND, MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM] >> rw[] >>
      pmap_cases >> simp[mkNd_def]
      >- (DISJ1_TAC >> normlist >>
          first_assum (unify_firstconj kall_tac o has_length) >> simp[])
      >- (simp[peg_eval_tok_NONE] >> DISJ1_TAC >> normlist >>
          first_assum (unify_firstconj kall_tac) >> simp[] >> normlist >>
          simp[] >> first_assum match_mp_tac >> simp[])
      >- simp[peg_eval_tok_NONE]
      >- (DISJ2_TAC >> simp[] >>
          erule mp_tac (MATCH_MP rfringe_length_not_nullable nullable_TypeDec)>>
          simp[] >> dsimp[] >> csimp[] >>
          Cases_on ‘pfx’ >> fs[peg_eval_tok_NONE] >> strip_tac >>
          rw[]>> fs[PAIR_MAP] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >>
          simp[NT_rank_def]))
  >- (print_tac "nSignatureValue" >> dsimp[MAP_EQ_CONS] >>
      simp[peg_eval_NT_SOME] >> simp[FDOM_cmlPEG, cmlpeg_rules_applied] >>
      rw[] >> fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >>
      rw[] >> pmap_cases >> dsimp[mkNd_def, Once EXISTS_PROD] >>
      normlist >> simp[])
  >- (print_tac "nRelOps" >> simp[peg_eval_NT_SOME] >>
      simp[FDOM_cmlPEG, cmlpeg_rules_applied, MAP_EQ_SING] >>
      strip_tac >> fs[MAP_EQ_SING,peg_eval_tok_NONE] >> pmap_cases >>
      simp[mkNd_def])
  (*>- (print_tac "nREPLTop" >> simp[MAP_EQ_CONS] >> rw[] >>
      fs[DISJ_IMP_THM, FORALL_AND_THM, MAP_EQ_APPEND, MAP_EQ_CONS] >> rw[]
      >- (simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied, FDOM_cmlPEG] >>
          DISJ2_TAC >> asm_match `ptree_head tdpt = NN nTopLevelDec` >>
          asm_match `ptree_fringe tdpt = MAP TK tf` >>
          conj_tac
          >- (DISJ1_TAC >>
              `0 < LENGTH (MAP TK tf)`
                by metis_tac[fringe_length_not_nullable,nullable_TopLevelDec] >>
              fs[] >>
              `∃tf0 tft. tf = tf0 :: tft` by (Cases_on `tf` >> fs[]) >> rveq >>
              fs[] >>
              `tf0 ∈ firstSet cmlG [NN nTopLevelDec]`
                by metis_tac [firstSet_nonempty_fringe] >>
              match_mp_tac peg_respects_firstSets >>
              simp[PEG_exprs] >> fs[]) >>
          normlist >> simp[]) >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, FDOM_cmlPEG] >>
      normlist >> simp[])*)
  >- (print_tac "nPtuple" >> stdstart >> pmap_cases >>
      dsimp[peg_eval_tok_NONE]
      >- (erule mp_tac
            (MATCH_MP rfringe_length_not_nullable nullable_PatternList) >>
          simp[] >>
          asm_match ‘real_fringe pt = MAP _ f’ >> Cases_on ‘f’ >> fs[] >>
          strip_tac >> rw[] >>
          rename [‘FST tkl = RparT’] >> Cases_on ‘tkl’ >> fs[] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> simp[PAIR_MAP]) >>
      dsimp[Once EXISTS_PROD] >>
      REWRITE_TAC[GSYM (CONJUNCT2 APPEND), GSYM APPEND_ASSOC] >>
      rename [‘ptree_head pt = NN nPatternList’,
              ‘pfx0 ++ ([(RparT, Rloc)] ++ sfx)’] >>
      first_x_assum (qspecl_then [‘pt’, ‘nPatternList’, ‘pfx0’,
                                  ‘[(RparT,Rloc)] ++ sfx’] mp_tac) >>
      simp[])
  >- (print_tac "nPcons" >> stdstart
      >- (normlist >> first_assum (unify_firstconj kall_tac o has_length) >>
          simp[mkNd_def] >> pmap_cases >>
          first_x_assum
            (fn th => match_mp_tac th >>
                      simp[firstSet_nV, firstSet_nConstructorName] >>
                      NO_TAC)) >>
      first_assum (unify_firstconj kall_tac) >> simp[mkNd_def] >>
      conj_tac >- simp[NT_rank_def] >>
      Cases_on ‘sfx’ >> fs[peg_eval_tok_NONE])
  >- (print_tac "nPbaseList1" >> stdstart
      >- (first_x_assum (unify_firstconj mp_tac) >> simp[] >>
          rename [‘real_fringe pt = MAP _ pfx’] >>
          disch_then (qspec_then ‘pt’ mp_tac) >> simp[NT_rank_def, mkNd_def] >>
          strip_tac >> disj2_tac >> rename1 ‘sfx ≠ []’ >>
          Cases_on ‘sfx’ >> simp[not_peg0_peg_eval_NIL_NONE] >>
          rename [‘peg_eval _ (tokloc1::_, _)’] >> Cases_on ‘tokloc1’ >>
          match_mp_tac peg_respects_firstSets >> simp[] >> fs[]) >>
      normlist >> first_assum (unify_firstconj mp_tac) >>
      simp_tac (srw_ss()) [mkNd_def] >>
      erule mp_tac
            (MATCH_MP rfringe_length_not_nullable nullable_PbaseList1) >>
      simp[] >> rename1 ‘0 < LENGTH plf’ >> strip_tac >>
      rename1 ‘ptree_head ppt = NN nPbase’ >>
      disch_then (qspec_then ‘ppt’ mp_tac) >> simp[] >>
      strip_tac >> first_x_assum match_mp_tac >> simp[] >>
      erule mp_tac
            (MATCH_MP rfringe_length_not_nullable nullable_Pbase) >>
      simp[])
  >- (print_tac "nPbase" >> stdstart >> pmap_cases >> simp[mkNd_def] >>
      TRY (simp[peg_respects_firstSets, peg_eval_tok_NONE] >> NO_TAC)
      >- simp[NT_rank_def]
      >- (DISJ2_TAC >> reverse conj_tac >- simp[NT_rank_def] >>
          erule mp_tac
            (MATCH_MP rfringe_length_not_nullable nullable_ConstructorName) >>
          simp[] >> Cases_on ‘pfx’ >> fs[] >>
          rename [‘peg_eval _ (tokloc1 :: _, _)’] >> Cases_on ‘tokloc1’ >>
          fs[] >>
          match_mp_tac peg_respects_firstSets >> simp[] >>
          metis_tac [firstSets_nV_nConstructorName, rfirstSet_nonempty_fringe])
      >- (simp[NT_rank_def] >>
          erule mp_tac
            (MATCH_MP rfringe_length_not_nullable nullable_Ptuple) >>
          simp[] >> Cases_on ‘pfx’ >> fs[] >>
          rename [‘peg_eval _ (tokloc1 :: _, _)’] >> Cases_on ‘tokloc1’ >>
          fs[] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >>
          simp[peg_respects_firstSets, peg_eval_tok_NONE])
      >- (simp[peg_respects_firstSets, peg_eval_tok_NONE] >>
          dsimp[EXISTS_PROD] >> metis_tac[PAIR])
      >- (simp[peg_respects_firstSets, peg_eval_tok_NONE] >>
          dsimp[Once EXISTS_PROD] >> normlist >> simp[]))
  >- (print_tac "nPatternList" >> stdstart
      >- (first_assum (unify_firstconj kall_tac) >>
          simp[NT_rank_def, mkNd_def] >>
          Cases_on ‘sfx’ >> fs[peg_eval_tok_NONE]) >>
      normlist >> first_assum (unify_firstconj kall_tac o has_length) >>
      pmap_cases >> simp[mkNd_def])
  >- (print_tac "nPattern" >> stdstart >> dsimp[]
      >- (simp[NT_rank_def, mkNd_def] >>
          rename[‘sfx ≠ [] ⇒ _’] >> Cases_on ‘sfx’ >>
          simp[peg_eval_tok_NONE] >> fs[]) >>
      disj1_tac >> normlist >>
      first_assum (unify_firstconj kall_tac) >> pmap_cases >>
      simp[APPEND_EQ_CONS, mkNd_def])
  >- (print_tac "nPapp" >> strip_tac
      >- (fs[MAP_EQ_CONS] >> rveq >> fs[MAP_EQ_APPEND] >> rveq >>
          rename [‘ptree_head pcpt = NN nPConApp’,
                  ‘ptree_head bpt = NN nPbase’,
                  ‘real_fringe pcpt = MAP _ pcf’,
                  ‘real_fringe bpt = MAP _ bf’] >>
          mp_tac (Q.INST [‘master’ |-> ‘pcf ++ bf’] papp_complete) >>
          impl_tac >- (rpt strip_tac >> simp[NT_rank_def]) >>
          disch_then (qspecl_then [‘pcf’, ‘pcpt’, ‘[]’] mp_tac) >> simp[] >>
          strip_tac
          >- (simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
              disj1_tac >>
              rename [‘peg_eval _ (pcf, nt (mkNT nConstructorName) I)
                         (SOME (i1, [cpt]))’,
                      ‘peg_eval_list _ (i1, nt (mkNT nPbase) I) ([], bpts)’] >>
              ‘peg_eval cmlPEG (pcf ++ bf ++ sfx, nt (mkNT nConstructorName) I)
                         (SOME (i1 ++ bf ++ sfx, [cpt]))’
                 by metis_tac[nConstructorName_input_monotone] >>
              pop_assum (assume_tac o MATCH_MP (CONJUNCT1 peg_deterministic)) >>
              simp[] >>
              first_x_assum (qpat_assum ‘ptree_head bpt = NN nPbase’ o
                             mp_then Any (qspecl_then [‘bf’, ‘sfx’] mp_tac) o
                             has_const “LENGTH”)  >> simp[] >>
              impl_tac (* 0 < LENGTH pcf *)
              >- (imp_res_tac
                    (MATCH_MP rfringe_length_not_nullable
                              nullable_PConApp) >>
                  rfs[DISJ_IMP_THM]) >>
              strip_tac >>
              first_assum (mp_then (Pos hd) mp_tac extend_Pbase_list) >>
              disch_then (first_assum o mp_then (Pos hd) mp_tac) >> simp[] >>
              simp[peg_eval_rpt] >>
              disch_then
                (assume_tac o MATCH_MP (CONJUNCT2 peg_deterministic)) >>
              simp[] >>
              Cases_on ‘FLAT bpts ++ [bpt]’ >> simp[] >- fs[] >>
              simp[ptPapply_def] >> pop_assum (SUBST1_TAC o SYM) >>
              simp[ptPapply0_FOLDL]) >>
          simp[peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >> disj2_tac >>
          simp[peg_respects_firstSets, firstSet_nConstructorName] >>
          disj1_tac >> dsimp[] >> rveq >>
          first_x_assum (qpat_assum ‘ptree_head _ = NN nPbase’ o
                         mp_then Any mp_tac o has_const “LENGTH”) >>
          simp[] >>
          disch_then (qspec_then ‘sfx’ assume_tac) >>
          first_assum (mp_then (Pos hd) mp_tac extend_Pbase_list) >>
          disch_then (first_assum o mp_then (Pos hd) mp_tac) >> simp[] >>
          simp[Once peg_eval_list] >> strip_tac >>
          first_assum (assume_tac o MATCH_MP (CONJUNCT1 peg_deterministic)) >>
          simp[] >> dsimp[peg_eval_rpt] >>
          first_assum (assume_tac o MATCH_MP (CONJUNCT2 peg_deterministic)) >>
          rename [‘peg_eval cmlPEG (_ ++ _ ++ _, _) (SOME (_, res1))’] >>
          ‘∃pt. res1 = [pt]’ suffices_by
            (strip_tac >> rveq >> fs[] >> simp[ptPapply_def] >>
             Cases_on ‘bpts’ >> fs[] >> rveq >> fs[ptPapply0_def] >>
             ONCE_REWRITE_TAC [GSYM (CONJUNCT2 APPEND)] >>
             REWRITE_TAC [ptPapply0_FOLDL] >> simp[]) >>
          qpat_x_assum ‘peg_eval _ _ (SOME (_, res1))’ mp_tac >>
          simp_tac (srw_ss()) [peg_eval_NT_SOME] >>
          simp[cmlpeg_rules_applied] >> rw[]) >>
      (* case split on possible forms of Pbase *)
      rveq >> rename [‘ptree_head bpt = NN nPbase’] >> fs[] >>
      ‘∃subs. bpt = mkNd (mkNT nPbase) subs’
        by metis_tac[ptree_head_NT_mkNd] >> rveq >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      fs[cmlG_FDOM,cmlG_applied,MAP_EQ_CONS] >> rveq >> fs[]
      >- (note_tac "nPapp: nV" >> rename [‘ptree_head pt1 = NN nV’] >>
          disj2_tac >> conj_tac
          >- (erule mp_tac (MATCH_MP rfringe_length_not_nullable nullable_V) >>
              simp[] >> strip_tac >> rename [‘0 < LENGTH pfx’] >>
              ‘∃t l rest. pfx = (t,l) :: rest’
                by (Cases_on ‘pfx’ >> fs[] >> metis_tac[pair_CASES]) >>
              rveq >> simp[] >> irule peg_respects_firstSets >> simp[] >>
              fs[] >>
              metis_tac[rfirstSet_nonempty_fringe,
                        firstSets_nV_nConstructorName]) >>
          first_x_assum
            (qspecl_then [‘mkNd (mkNT nPbase) [pt1]’, ‘nPbase’, ‘sfx’]mp_tac) >>
          simp[NT_rank_def, cmlG_applied, cmlG_FDOM] >> dsimp[] >>
          strip_tac >>
          imp_res_tac (MATCH_MP rfringe_length_not_nullable nullable_V) >>
          ‘pfx = [] ∨ ∃tk l rest. pfx = (tk,l) :: rest’
             by metis_tac[pair_CASES, list_CASES] >>
          rveq >> rfs[peg_eval_tok_NONE])
      >- (note_tac "nPapp: nConstructorName" >>
          disj1_tac >> rename [‘ptree_head pt1 = NN nConstructorName’] >>
          first_x_assum (qspecl_then [‘pt1’, ‘nConstructorName’, ‘sfx’] mp_tac o
                         has_const “NT_rank”) >> simp[NT_rank_def] >>
          strip_tac >> map_every qexists_tac [‘[pt1]’, ‘sfx’, ‘[]’] >>
          simp[] >> simp[peg_eval_rpt, Once peg_eval_list] >> dsimp[] >>
          disj1_tac >> Cases_on ‘sfx’
          >- (irule not_peg0_peg_eval_NIL_NONE >> simp[]) >>
          fs[] >> rename [‘FST tk = LparT’] >> Cases_on ‘tk’ >> fs[] >>
          irule peg_respects_firstSets >> simp[])
      >- (note_tac "nPapp: IntT" >> rveq >> fs[] >> pmap_cases >>
          simp[peg_eval_tok_NONE] >> disj2_tac >>
          conj_tac >- (irule peg_respects_firstSets >> simp[]) >>
          first_x_assum
            (fn th => irule th >> simp[NT_rank_def, cmlG_FDOM, cmlG_applied] >>
                      NO_TAC))
      >- (note_tac "nPapp: StringT" >> rveq >> fs[] >> pmap_cases >>
          simp[peg_eval_tok_NONE] >> disj2_tac>>
          conj_tac >- (irule peg_respects_firstSets >> simp[]) >>
          first_x_assum
            (fn th => irule th >> simp[NT_rank_def, cmlG_FDOM, cmlG_applied] >>
                      NO_TAC))
      >- (note_tac "nPapp: CharT" >> rveq >> fs[] >> pmap_cases >>
          simp[peg_eval_tok_NONE] >> disj2_tac>>
          conj_tac >- (irule peg_respects_firstSets >> simp[]) >>
          first_x_assum
            (fn th => irule th >> simp[NT_rank_def, cmlG_FDOM, cmlG_applied] >>
                      NO_TAC))
      >- (note_tac "nPapp: nPtuple" >> rename [‘ptree_head pt1 = NN nPtuple’]>>
          disj2_tac >> conj_tac
          >- (erule mp_tac
                (MATCH_MP rfringe_length_not_nullable nullable_Ptuple) >>
              simp[] >> strip_tac >> rename [‘0 < LENGTH pfx’] >>
              ‘∃t l rest. pfx = (t,l) :: rest’
                by (Cases_on ‘pfx’ >> fs[] >> metis_tac[pair_CASES]) >>
              rveq >> simp[] >> irule peg_respects_firstSets >> simp[] >>
              fs[] >> imp_res_tac rfirstSet_nonempty_fringe >> rfs[]) >>
          first_x_assum
            (qspecl_then [‘mkNd (mkNT nPbase) [pt1]’, ‘nPbase’, ‘sfx’]mp_tac) >>
          simp[NT_rank_def, cmlG_applied, cmlG_FDOM] >> dsimp[])
      >- (note_tac "nPapp: UnderbarT" >> rveq >> fs[] >> pmap_cases >>
          simp[peg_eval_tok_NONE] >> disj2_tac>>
          conj_tac >- (irule peg_respects_firstSets >> simp[]) >>
          first_x_assum
            (fn th => irule th >> simp[NT_rank_def, cmlG_FDOM, cmlG_applied] >>
                      NO_TAC))
      >- (note_tac "nPapp: LBrackT-RBrackT" >> fs[MAP_EQ_CONS] >> pmap_cases >>
          simp[peg_eval_tok_NONE] >>
          disj2_tac >> conj_tac >- (irule peg_respects_firstSets >> simp[]) >>
          first_x_assum
            (fn th => irule th >> dsimp[NT_rank_def, cmlG_FDOM, cmlG_applied] >>
                      NO_TAC))
      >- (note_tac "nPapp: PatternList" >> fs[MAP_EQ_CONS, MAP_EQ_APPEND] >>
          rveq >> pmap_cases >> simp[peg_eval_tok_NONE] >> disj2_tac >>
          conj_tac >- (irule peg_respects_firstSets >> simp[]) >>
          first_x_assum
            (fn th => irule th >> dsimp[NT_rank_def, cmlG_applied, cmlG_FDOM] >>
                      NO_TAC))
      >- (note_tac "nPapp: nOpID" >> fs[MAP_EQ_CONS] >> pmap_cases >>
          simp[peg_eval_tok_NONE] >>
          disj2_tac >> conj_tac >- (irule peg_respects_firstSets >> simp[]) >>
          first_x_assum
            (fn th => irule th >> dsimp[NT_rank_def, cmlG_applied, cmlG_FDOM] >>
                      NO_TAC)))
  >- (print_tac "nPType" >> stdstart >> pmap_cases >> simp[mkNd_def]
      >- (normlist >> first_assum (unify_firstconj kall_tac) >> simp[]) >>
      first_assum (unify_firstconj kall_tac) >> simp[NT_rank_def] >>
      Cases_on ‘sfx’ >> fs[peg_eval_tok_NONE])
  >- (print_tac "nPTbase" >> stdstart >> pmap_cases >>
      simp[peg_eval_tok_NONE]
      >- (rename [‘ptree_head pt = NN nTyOp’] >>
          ‘NT_rank (mkNT nTyOp) < NT_rank (mkNT nPTbase)’ by simp[NT_rank_def]>>
          first_x_assum (pop_assum o mp_then Any mp_tac) >> simp[] >>
          disch_then (qpat_assum ‘ptree_head _ = NN nTyOp’ o
                      mp_then Any mp_tac) >> simp[] >> strip_tac >>
          ‘∀sfx. ∃e t. pfx ++ sfx = e::t ∧ FST e ≠ LparT ∧ ¬isTyvarT (FST e)’
             suffices_by metis_tac[] >>
          qx_gen_tac ‘sfx’ >> Cases_on ‘pfx’
          >- (pop_assum (qspec_then ‘sfx’ assume_tac) >>
              imp_res_tac
                (MATCH_MP (GEN_ALL not_peg0_LENGTH_decreases) peg0_nTyOp) >>
              fs[]) >>
          simp[] >> rename [‘FST tkl = LparT’] >> Cases_on ‘tkl’ >>
          simp[] >> pop_assum (qspec_then ‘sfx’ assume_tac) >> rpt strip_tac >>
          (* 2 goals *)
          fs[] >> (* 1 goal *)
          first_assum (mp_then (Pos hd) mp_tac peg_respects_firstSets') >>
          simp[] >> rename [‘isTyvarT tk’] >> Cases_on ‘tk’ >> fs[]) >>
      first_x_assum (qpat_assum ‘ptree_head _ = NN nType’ o
                     mp_then Any mp_tac o has_const “LENGTH”) >> simp[] >>
      rename [‘_ ++ [(RparT, rl)] ++ sfx’] >>
      disch_then (qspec_then ‘(RparT, rl) :: sfx’ mp_tac) >> simp[] >>
      disch_then (assume_tac o MATCH_MP (CONJUNCT1 peg_deterministic)) >>
      REWRITE_TAC [GSYM APPEND_ASSOC, APPEND] >> simp[])
  >- (print_tac "nPEs" >>
      simp[MAP_EQ_CONS] >> strip_tac >> rw[] >> fs[] >> rw[]
      >- ((* single nPE *)
         simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> DISJ2_TAC >>
         reverse CONJ_ASM2_TAC >- simp[NT_rank_def] >>
         pop_assum mp_tac >>
         simp[peg_eval_tok_NONE] >>
         ONCE_REWRITE_TAC [peg_eval_NT_SOME] >> simp[cmlpeg_rules_applied] >>
         strip_tac >> rveq >> fs[MAP_EQ_APPEND, MAP_EQ_CONS] >> rveq >>
         dsimp[] >>
         pmap_cases >>
         rename [‘FST tokloc1 = DarrowT’] >> Cases_on ‘tokloc1’ >> fs[] >>
         rveq >>
         first_assum
           (assume_tac o MATCH_MP (CONJUNCT1 peg_deterministic) o
            assert (free_in “DarrowT” o concl)) >>
         simp[] >>
         simp[Once peg_eval_NT_NONE, cmlpeg_rules_applied, peg_eval_tok_NONE] >>
         asm_match ‘peg_eval cmlPEG (i2, nt (mkNT nE) I) (SOME(sfx,r2))’ >>
         Cases_on ‘peg_eval cmlPEG (i2, nt (mkNT nE') I) NONE’ >> simp[] >>
         DISJ1_TAC >>
         ‘∃rr. peg_eval cmlPEG (i2, nt (mkNT nE') I) rr’
           by simp[MATCH_MP peg_eval_total PEG_wellformed] >>
         ‘∃i3 r3. rr = SOME(i3,r3)’
           by metis_tac[optionTheory.option_CASES, pairTheory.pair_CASES] >>
         rveq >> pop_assum (assume_tac o MATCH_MP peg_det) >>
         simp[] >> Cases_on ‘i3’ >> simp[] >>
         metis_tac[nE'_bar_nE, listTheory.HD, listTheory.NOT_CONS_NIL]) >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> dsimp[] >>
      DISJ1_TAC >>
      fs[MAP_EQ_APPEND, MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM] >> rveq >>
      pmap_cases >>
      rename [‘ptree_head pept = NN nPE'’,
              ‘real_fringe pept = MAP _ pef’,
              ‘ptree_head pspt = NN nPEs’,
              ‘real_fringe pspt = MAP _ psf’] >>
      map_every qexists_tac [‘[pept]’, ‘psf ++ sfx’, ‘[pspt]’] >>
      normlist >> simp[Once EXISTS_PROD])
  >- (print_tac "nPE'" >> simp[MAP_EQ_CONS] >> strip_tac >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> dsimp[mkNd_def] >>
      rveq >> fs[MAP_EQ_APPEND, MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM] >>
      rveq >>
      rename[‘ptree_head ppt = NN nPattern’, ‘real_fringe ppt = MAP _ pf’,
             ‘ptree_head e'pt = NN nE'’,
             ‘MAP _ ef = real_fringe e'pt’] >>
      map_every qexists_tac [‘[ppt]’, ‘ef ++ sfx’, ‘[e'pt]’] >> simp[] >>
      simp[Once EXISTS_PROD] >> pmap_cases >>
      normlist >> simp[])
  >- (print_tac "nPE" >> simp[MAP_EQ_CONS] >> strip_tac >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> dsimp[] >>
      rveq >> fs[MAP_EQ_APPEND, MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM] >>
      rveq >>
      rename[‘ptree_head ppt = NN nPattern’,
             ‘real_fringe ppt = MAP _ pf’,
             ‘ptree_head ept = NN nE’,
             ‘MAP _ ef = real_fringe ept’] >> pmap_cases >> simp[mkNd_def] >>
      map_every qexists_tac [‘[ppt]’, ‘ef ++ sfx’, ‘[ept]’] >>
      simp[Once EXISTS_PROD] >> normlist >> simp[])
  >- (print_tac "nPConApp" >> fs[FDOM_cmlPEG])
  >- (print_tac "nOptionalSignatureAscription" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied, mkNd_def]>>
      strip_tac >>
      fs[MAP_EQ_APPEND, MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM] >> rw[] >>
      pmap_cases >>
      Cases_on ‘sfx’ >> simp[peg_eval_tok_NONE] >> fs[])
  >- (print_tac "nOptTypEqn" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      strip_tac >> rw[] >> fs[MAP_EQ_CONS] >> rw[mkNd_def] >> pmap_cases >>
      Cases_on ‘sfx’ >> simp[peg_eval_tok_NONE] >> fs[])
  >- (print_tac "nOpID" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied,
           mkNd_def] >>
      dsimp[pairTheory.EXISTS_PROD, peg_eval_tok_NONE] >> rpt strip_tac >>
      rveq >> fs[MAP_EQ_CONS] >> pmap_cases >>
      simp[peg_eval_seq_NONE, peg_eval_tok_NONE])
  >- (print_tac "nNonETopLevelDecs" >> strip_tac >>
      fs[MAP_EQ_CONS] >> rveq >> fs[MAP_EQ_APPEND]
      >- (rename [‘ptree_head TLDpt = NN nTopLevelDec’,
                  ‘ptree_head NeTLDpt = NN nNonETopLevelDecs’,
                  ‘real_fringe TLDpt = MAP _ TLDfr’,
                  ‘real_fringe NeTLDpt = MAP _ NeTLDfr’] >>
          simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> rveq >>
          ‘peg_eval cmlPEG (TLDfr ++ NeTLDfr, nt (mkNT nTopLevelDec) I)
                           (SOME (NeTLDfr, [TLDpt]))’
            by (Cases_on ‘NeTLDfr’
                >- (fs[] >> loseC “LENGTH” >>
                    first_x_assum (qspecl_then [‘TLDpt’, ‘nTopLevelDec’, ‘[]’]
                                               mp_tac) >>
                    simp[NT_rank_def]) >>
                first_x_assum irule >> simp[] >> fs[] >>
                rename1 ‘real_fringe NeTLDpt = (TK ## I) tl1 :: _’ >>
                ‘∃tok1 loc1. tl1 = (tok1,loc1)’ by (Cases_on ‘tl1’ >> simp[]) >>
                rveq >> fs[] >>
                ‘tok1 ∈ firstSet cmlG [NN nNonETopLevelDecs]’
                  by metis_tac[rfirstSet_nonempty_fringe] >>
                rw[] >> fs[]) >>
          disj1_tac >>
          map_every qexists_tac [‘[TLDpt]’, ‘NeTLDfr’, ‘[NeTLDpt]’] >>
          simp[mkNd_def] >>
          first_x_assum
            (qspecl_then [‘NeTLDpt’, ‘nNonETopLevelDecs’, ‘NeTLDfr’, ‘[]’]
                         mp_tac) >>
          simp[] >> disch_then irule >>
          ‘0 < LENGTH (real_fringe TLDpt)’ suffices_by simp[] >>
          irule rfringe_length_not_nullable >> simp[] >> qexists_tac ‘cmlG’ >>
          simp[])
      >- (fs[MAP_EQ_CONS] >> rveq >> pmap_cases >>
          simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> disj2_tac >>
          conj_tac
          >- (disj1_tac >> irule peg_respects_firstSets >> simp[]) >> fs[] >>
          ‘mkNT nTopLevelDecs ∈ FDOM cmlPEG.rules’ by simp[] >>
          simp[mkNd_def] >>
          metis_tac[APPEND_NIL, DECIDE “x < SUC x”])
      >- (simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, mkNd_def] >>
          simp[not_peg0_peg_eval_NIL_NONE, peg_eval_tok_NONE]))
  >- (print_tac "nMultOps" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      rw[] >> fs[MAP_EQ_CONS, peg_eval_tok_NONE, mkNd_def] >> pmap_cases >>
      simp[])
  >- (print_tac "nListOps" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      rw[] >> fs[MAP_EQ_CONS, peg_eval_tok_NONE, mkNd_def] >> pmap_cases >>
      simp[])
  >- (print_tac "nLetDecs" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> rw[]>>
      fs[MAP_EQ_APPEND, MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM] >>
      rw[mkNd_def]
      >- (DISJ1_TAC >>
          rename [‘ptree_head lpt = NN nLetDec’,
                  ‘real_fringe lpt = MAP _ lf’,
                  ‘ptree_head lspt = NN nLetDecs’,
                  ‘real_fringe lspt = MAP _ lsf’] >>
          map_every qexists_tac [‘[lpt]’, ‘lsf ++ sfx’, ‘[lspt]’] >>
          ‘0 < LENGTH (MAP (TK ## I) lf)’
            by metis_tac [rfringe_length_not_nullable,
                          nullable_LetDec] >> fs[] >>
          Cases_on‘lsf’ >> fs[] >- simp[NT_rank_def] >>
          normlist >>
          first_x_assum (match_mp_tac o has_length) >> simp[] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> rw[] >> rw[] >>
          fs[PAIR_MAP])
      >- (pmap_cases >> simp[peg_respects_firstSets]) >>
      DISJ2_TAC >> Cases_on ‘sfx’ >>
      simp[not_peg0_peg_eval_NIL_NONE, peg_eval_tok_NONE] >>
      rename [‘peg_eval _ (tl1 :: _, _)’] >> Cases_on ‘tl1’ >>
      fs[peg_respects_firstSets, peg_eval_tok_NONE])
  >- (print_tac "nLetDec" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied,
           mkNd_def] >>
      rw[] >> fs[MAP_EQ_APPEND, MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM] >>
      rw[] >> dsimp[peg_eval_tok_NONE] >> pmap_cases >>
      rename [‘ptree_head ppt = NN nPattern’,
              ‘real_fringe ppt = MAP _ pf’,
              ‘ptree_head ept = NN nE’,
              ‘MAP _ ef = real_fringe ept’] >>
      map_every qexists_tac [‘[ppt]’, ‘ef ++ sfx’, ‘[ept]’] >>
      normlist >>
      simp[Once EXISTS_PROD])
  >- (print_tac "nFQV" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied,
           peg_longV_def, mkNd_def] >> rw[] >> fs[MAP_EQ_SING] >> rveq >>
      pmap_cases >>
      simp[NT_rank_def, peg_eval_seq_NONE, peg_respects_firstSets,
           firstSet_nV])
  >- (print_tac "nFDecl" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied,
           mkNd_def] >> rw[] >>
      fs[MAP_EQ_APPEND, MAP_EQ_CONS, DISJ_IMP_THM, FORALL_AND_THM] >> rw[] >>
      dsimp[] >> pmap_cases >>
      rename [‘ptree_head vpt = NN nV’,
              ‘real_fringe vpt = MAP _ vf’,
              ‘ptree_head plpt = NN nPbaseList1’,
              ‘real_fringe plpt = MAP _ plf’,
              ‘ptree_head ept = NN nE’,
              ‘MAP _ ef = real_fringe ept’, ‘(EqualsT, eqloc)’] >>
      map_every qexists_tac [‘[vpt]’, ‘plf ++ (EqualsT,eqloc)::ef ++ sfx’,
                             ‘[plpt]’, ‘ef ++ sfx’, ‘[ept]’] >> simp[] >>
      simp[Once EXISTS_PROD] >>
      normlist >>
      simp[])
  >- (print_tac "nEtyped" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied,
           mkNd_def] >> rw[] >>
      fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >> rw[]
      >- (dsimp[] >> DISJ2_TAC >> DISJ1_TAC >> simp[NT_rank_def] >>
          simp[peg_eval_tok_NONE] >> Cases_on ‘sfx’ >>
          fs[Once EXISTS_PROD] >> metis_tac[PAIR]) >>
      pmap_cases >> dsimp[] >> DISJ1_TAC >>
      normlist >>
      first_assum (unify_firstconj kall_tac o has_length) >> simp[])
  >- (print_tac "nEtuple" >> fs[FDOM_cmlPEG])
  >- (print_tac "nEseq" >> stdstart >> pmap_cases
      >- (normlist >> first_assum (unify_firstconj kall_tac) >>
          simp[mkNd_def]) >>
      first_assum(unify_firstconj kall_tac) >> simp[NT_rank_def, mkNd_def] >>
      dsimp[] >>
      Cases_on ‘sfx’ >> fs[peg_eval_tok_NONE])
  >- (print_tac "nErel" >>
      disch_then assume_tac >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      match_mp_tac (peg_linfix_complete
                      |> Q.INST [‘P’ |-> ‘nErel’, ‘SEP’ |-> ‘NN nRelOps’,
                                 ‘C’ |-> ‘NN nElistop’, ‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (srw_ss() ++ DNF_ss)
                           [sym2peg_def, cmlG_applied, MAP_EQ_CONS,
                            AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM, NT_rank_def] >>
      conj_tac
      >- (simp[firstSet_nFQV, firstSet_nConstructorName, firstSet_nV] >>
          metis_tac[validSym_incompatibility]) >> fs[])
  >- (print_tac "nEmult" >> disch_then assume_tac >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      match_mp_tac (peg_linfix_complete
                      |> Q.INST [‘P’ |-> ‘nEmult’, ‘SEP’ |-> ‘NN nMultOps’,
                                 ‘C’ |-> ‘NN nEapp’, ‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (srw_ss() ++ DNF_ss)
                           [sym2peg_def, cmlG_applied, MAP_EQ_CONS,
                            AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM, NT_rank_def] >>
      fs[] >> simp[firstSet_nFQV, firstSet_nV, firstSet_nConstructorName] >>
      rw[disjImpI, stringTheory.isUpper_def] >>
      metis_tac[validSym_incompatibility])
  >- (print_tac "nElogicOR" >> disch_then assume_tac >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      match_mp_tac (peg_linfix_complete
                      |> Q.INST [‘P’ |-> ‘nElogicOR’, ‘SEP’ |-> ‘TK OrelseT’,
                                 ‘C’ |-> ‘NN nElogicAND’, ‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (srw_ss() ++ DNF_ss)
                           [sym2peg_def, cmlG_applied, MAP_EQ_CONS,
                            AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM, NT_rank_def] >>
      conj_tac >- simp[firstSet_nFQV, firstSet_nConstructorName,
                       firstSet_nV, FORALL_PROD] >> fs[])
  >- (print_tac "nElogicAND" >> disch_then assume_tac >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      match_mp_tac (peg_linfix_complete
                      |> Q.INST [‘P’ |-> ‘nElogicAND’, ‘SEP’ |-> ‘TK AndalsoT’,
                                 ‘C’ |-> ‘NN nEtyped’, ‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (srw_ss() ++ DNF_ss)
                           [sym2peg_def, cmlG_applied, MAP_EQ_CONS,
                            AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM, NT_rank_def] >>
      conj_tac
      >- simp[firstSet_nV,firstSet_nConstructorName,firstSet_nFQV,
              FORALL_PROD] >>
      fs[])
  >- (print_tac "nEliteral" >> stdstart >> pmap_cases >>
      simp[peg_eval_tok_NONE,mkNd_def])
  >- (print_tac "nElistop" >> stdstart
      >- (normlist >> first_assum (unify_firstconj kall_tac) >>
          rename[‘ptree_head eaddpt = NN nEadd’,
                 ‘ptree_head oppt = NN nListOps’,
                 ‘real_fringe oppt = MAP _ opf’] >>
          qexists_tac ‘eaddpt’ >>
          ‘0 < LENGTH (MAP (TK ## I) opf)’
            by metis_tac[rfringe_length_not_nullable,
                         nullable_ListOps] >> fs[] >>
          ‘(∀l1 l2. HD (opf ++ l1 ++ l2) = HD opf) ∧ opf ≠ []’
            by (Cases_on ‘opf’ >> fs[]) >>  simp[mkNd_def] >>
          ‘FST (HD opf) ∈ stoppers nEadd’
            by (Cases_on ‘opf’ >> fs[PAIR_MAP] >>
                first_assum
                  (mp_tac o
                   MATCH_MP (rfirstSet_nonempty_fringe
                               |> GEN_ALL |> Q.ISPEC ‘cmlG’
                               |> REWRITE_RULE [GSYM AND_IMP_INTRO])) >>
                simp[] >>
                rw[firstSet_nFQV, firstSet_nV, firstSet_nConstructorName,
                   disjImpI] >> rw[] >> fs[] >>
                metis_tac[validSym_incompatibility]) >>
          conj_tac >- (normlist >> loseC “NT_rank” >>
                       first_x_assum match_mp_tac >> simp[] >>
                       fs[]) >>
          normlist >> first_assum (unify_firstconj kall_tac) >> simp[] >>
          normlist >> first_assum (match_mp_tac o has_length) >>
          simp[] >> CONV_TAC NumRelNorms.sum_lt_norm >>
          metis_tac [rfringe_length_not_nullable,
                     nullable_Eadd, listTheory.LENGTH_MAP,
                     arithmeticTheory.ZERO_LESS_ADD]) >>
      first_assum (unify_firstconj kall_tac) >> simp[mkNd_def] >>
      conj_tac >- simp[NT_rank_def] >>
      Cases_on ‘sfx’ >> fs[not_peg0_peg_eval_NIL_NONE] >>
      rename [‘peg_eval _ (tl::_, _)’] >> Cases_on ‘tl’ >> fs[] >>
      simp[peg_respects_firstSets])
  >- (print_tac "nElist2" >> fs[FDOM_cmlPEG])
  >- (print_tac "nElist1" >> stdstart >> pmap_cases >> simp[mkNd_def]
      >- (first_assum (unify_firstconj kall_tac) >> simp[NT_rank_def] >>
          Cases_on ‘sfx’ >> fs[peg_eval_tok_NONE]) >>
      normlist >> first_assum (unify_firstconj kall_tac) >> simp[])
  >- (print_tac "nEhandle" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied,mkNd_def] >>
      strip_tac >>
      fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >> rw[]
      >- (rename[‘ptree_head ept = NN nElogicOR’] >>
          map_every qexists_tac [‘[ept]’, ‘sfx’, ‘[]’] >>
          simp[NT_rank_def, peg_eval_tok_NONE] >> DISJ1_TAC >>
          Cases_on ‘sfx’ >> simp[] >> strip_tac >> fs[]) >>
      pmap_cases >>
      rename [‘ptree_head ept = NN nElogicOR’,
              ‘ptree_head pespt = NN nPEs’,
              ‘MAP _ pesf = real_fringe pespt’] >>
      qexists_tac ‘[ept]’ >> dsimp[] >> simp[Once EXISTS_PROD] >>
      qexists_tac ‘pesf ++ sfx’ >> normlist >>
      simp[firstSet_nConstructorName, firstSet_nFQV, firstSet_nV])
  >- (print_tac "nEcomp" >> disch_then assume_tac >>
      simp[peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      match_mp_tac (peg_linfix_complete
                      |> Q.INST [‘P’ |-> ‘nEcomp’, ‘SEP’ |-> ‘NN nCompOps’,
                                 ‘C’ |-> ‘NN nErel’, ‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (srw_ss() ++ DNF_ss)
                           [sym2peg_def, cmlG_applied, MAP_EQ_CONS,
                            AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM] >> conj_tac
      >- (conj_tac
          >- (simp[firstSet_nV, firstSet_nFQV, firstSet_nConstructorName,
                   stringTheory.isUpper_def] >>
              simp[validRelSym_def, validListSym_def, validMultSym_def,
                   validAddSym_def, validPrefixSym_def]) >>
          simp[NT_rank_def]) >>
      fs[])
  >- (print_tac "nEbefore" >> disch_then assume_tac >>
      simp[peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      match_mp_tac (peg_linfix_complete
                      |> Q.INST [‘P’ |-> ‘nEbefore’,
                                 ‘SEP’ |-> ‘TK (AlphaT "before")’,
                                 ‘C’ |-> ‘NN nEcomp’, ‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (srw_ss() ++ DNF_ss)
                           [sym2peg_def, cmlG_applied, MAP_EQ_CONS,
                            AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM, NT_rank_def] >>
      conj_tac
      >- simp[firstSet_nConstructorName, firstSet_nFQV, firstSet_nV,
              stringTheory.isUpper_def, FORALL_PROD]>>
      fs[])
  >- (print_tac "nEbase" >> note_tac "** Slow nEbase beginning" >> stdstart >>
      simp[mkNd_def] >> pmap_cases >> TRY (simp[peg_eval_tok_NONE] >> NO_TAC)
      (* 10 subgoals *)
      >- (note_tac "Ebase:Eseq (not ()) (1/10)" >>
          simp[peg_eval_tok_NONE, peg_eval_seq_NONE, peg_respects_firstSets] >>
          disj2_tac >>
          conj_tac
          >- (erule mp_tac
                    (MATCH_MP rfringe_length_not_nullable nullable_Eseq) >>
              rename1 ‘real_fringe pt = MAP _ f’ >> Cases_on ‘f’ >>
              simp[] >> fs[] >> fs[PAIR_MAP] >>
              IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> simp[] >>
              rpt strip_tac >> fs[firstSet_nE]) >>
          disj1_tac >> dsimp[peg_EbaseParen_def] >>
          CONV_TAC
            (EVERY_DISJ_CONV (SIMP_CONV (srw_ss()) [Once EXISTS_PROD])) >>
          simp[peg_eval_tok_NONE] >>
          rename [‘ptree_head qpt = NN nEseq’] >>
          ‘∃subs l. qpt = Nd (mkNT nEseq, l) subs’
            by metis_tac[ptree_head_NT_mkNd, mkNd_def] >>
          fs[cmlG_FDOM, cmlG_applied, MAP_EQ_CONS] >> rveq >>
          fs[MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM, MAP_EQ_CONS] >>
          rw[]
          >- (rpt disj2_tac >>
              simp[peg_eval_tok_NONE, peg_EbaseParenFn_def, list_case_eq,
                   bool_case_eq, mkNd_def, option_case_eq] >> pmap_cases >>
              rename [‘ptree_head e_pt = NN nE’,
                      ‘ptree_head seq_pt = NN nEseq’,
                      ‘real_fringe e_pt = MAP _ etoks’,
                      ‘MAP _ seqtoks = real_fringe seq_pt’] >>
              last_assum (qpat_assum ‘ptree_head e_pt = NN nE’ o
                           mp_then Any mp_tac) >>
              last_x_assum (qpat_assum ‘ptree_head seq_pt = NN nEseq’ o
                            mp_then Any mp_tac) >>
              simp[] >> rpt strip_tac >> rename [‘(RparT, rploc)’] >>
              first_x_assum
                (qspecl_then [‘seqtoks’, ‘(RparT,rploc) :: sfx’] mp_tac) >>
              simp[] >> rename [‘(SemicolonT, scloc)’] >>
              pop_assum
                (qspec_then
                   ‘(SemicolonT, scloc) :: seqtoks ++ [(RparT,rploc)] ++ sfx’
                   mp_tac) >>
              simp[] >> rpt strip_tac >>
              goal_assum
                (first_assum o mp_then (Pos hd) mp_tac) >>
              simp[] >> normlist >>
              goal_assum
                (first_assum o mp_then (Pos hd) mp_tac) >> simp[] >>
              simp[ptree_list_loc_def]) >>
          rpt disj1_tac >>
          rename [‘ptree_head e_pt = NN nE’,
                  ‘real_fringe e_pt = MAP _ etoks’] >>
          rename [‘(RparT, rploc)’] >>
          first_x_assum
            (qspecl_then [‘e_pt’, ‘nE’, ‘etoks’, ‘[(RparT,rploc)] ++ sfx’]
                         mp_tac) >>
          simp[] >> strip_tac >>
          goal_assum
            (first_assum o mp_then (Pos hd) mp_tac) >>
          simp[peg_EbaseParenFn_def, ptree_list_loc_def, mkNd_def])
      >- (note_tac "Ebase:Etuple (2/10)" >> disj2_tac >>
          simp[peg_eval_tok_NONE, peg_eval_seq_NONE] >>
          asm_match ‘ptree_head qpt = NN nEtuple’ >>
          ‘∃subs sloc. qpt = Nd (mkNT nEtuple, sloc) subs’
            by metis_tac[ptree_head_NT_mkNd, mkNd_def] >>
          fs[cmlG_FDOM, cmlG_applied, MAP_EQ_CONS] >> rveq >>
          fs[MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM, MAP_EQ_CONS] >>
          rw[]
          >- (pmap_cases >>
              simp[peg_eval_NT_NONE, cmlpeg_rules_applied, peg_eval_tok_NONE])
          >- (pmap_cases >>
              erule mp_tac
                    (MATCH_MP rfringe_length_not_nullable nullable_Elist2) >>
              rename1 ‘real_fringe pt = MAP _ f’ >> Cases_on ‘f’ >>
              simp[] >> fs[PAIR_MAP] >>
              IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> simp[] >>
              rpt strip_tac >> fs[firstSet_nE])
          >- (pmap_cases >>
              disj1_tac >> dsimp[peg_EbaseParen_def, peg_eval_tok_NONE] >>
              disj2_tac >> disj1_tac >> const_x_assum "NT_rank" kall_tac >>
              asm_match ‘ptree_head qpt = NN nElist2’ >>
              ‘∃subs sloc. qpt = Nd (mkNT nElist2, sloc) subs’
                 by metis_tac[ptree_head_NT_mkNd, mkNd_def] >>
              fs[cmlG_FDOM, cmlG_applied, MAP_EQ_CONS] >> rveq >>
              fs[MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM, MAP_EQ_CONS] >>
              rw[] >> pmap_cases >>
              first_assum (const_assum "nE" o mp_then Any mp_tac) >>
              first_x_assum (const_assum "nElist1" o mp_then Any mp_tac) >>
              simp[] >> rpt strip_tac >>
              rename [‘ptree_head e_pt = NN nE’, ‘ptree_head l_pt = NN nElist1’,
                      ‘real_fringe e_pt = MAP _ etks’,
                      ‘MAP _ ltks = real_fringe l_pt’, ‘(RparT, rploc)’] >>
              first_x_assum
                (qspecl_then [‘ltks’, ‘[(RparT,rploc)] ++ sfx’] mp_tac) >>
              simp[] >>
              strip_tac >>
              goal_assum (first_assum o mp_then Any mp_tac) >>
              simp[] >> rename [‘(CommaT,ctloc)’] >>
              first_x_assum
                (qspecl_then [‘(CommaT,ctloc)::ltks ++ [(RparT,rploc)] ++ sfx’]
                             mp_tac) >>
              simp[] >> strip_tac >>
              goal_assum (first_assum o mp_then Any mp_tac) >>
              simp[peg_EbaseParenFn_def,ptree_list_loc_def, mkNd_def]))
      >- (note_tac "Ebase: 3/10" >>
          simp[peg_eval_NT_NONE, peg_eval_seq_NONE, cmlpeg_rules_applied,
               peg_eval_tok_NONE])
      >- (note_tac "Ebase: 4/10" >> disj2_tac >>
          erule mp_tac (MATCH_MP rfringe_length_not_nullable nullable_FQV) >>
          rename1 ‘real_fringe pt = MAP _ f’ >> Cases_on ‘f’ >>
          simp[] >> fs[PAIR_MAP] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> simp[] >>
          rpt strip_tac
          >- (simp[peg_eval_seq_NONE, peg_eval_NT_NONE, cmlpeg_rules_applied] >>
              rpt strip_tac >> simp[peg_eval_tok_NONE] >>
              rename1 ‘tk ∈ firstSet _ _’ >> Cases_on ‘tk’ >> simp[] >>
              fs[NOTIN_firstSet_nFQV])
          >- (simp[peg_eval_tok_NONE] >> metis_tac[NOTIN_firstSet_nFQV]) >>
          disj2_tac >> conj_tac
          >- (simp[peg_EbaseParen_def, peg_eval_tok_NONE] >>
              metis_tac[NOTIN_firstSet_nFQV]) >>
          conj_tac
          >- (simp[peg_eval_tok_NONE] >> metis_tac[NOTIN_firstSet_nFQV]) >>
          simp[peg_eval_tok_NONE] >> conj_tac
          >- metis_tac[NOTIN_firstSet_nFQV] >>
          const_x_assum "NT_rank" (first_assum o mp_then (Pos hd) mp_tac) >>
          simp[NT_rank_def])
      >- (note_tac "Ebase: nConstructorName (5/10)" >> disj2_tac >>
          erule mp_tac
            (MATCH_MP rfringe_length_not_nullable nullable_ConstructorName) >>
          rename1 ‘real_fringe pt = MAP _ f’ >> Cases_on ‘f’ >>
          simp[] >> fs[PAIR_MAP] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> simp[] >>
          rpt strip_tac >> simp[peg_eval_tok_NONE]
          >- (simp[peg_eval_seq_NONE, peg_eval_NT_NONE, cmlpeg_rules_applied] >>
              rpt strip_tac >> simp[peg_eval_tok_NONE] >>
              rename1 ‘tk ∈ firstSet _ _’ >> Cases_on ‘tk’ >> simp[] >>
              fs[NOTIN_firstSet_nFQV])
          >- metis_tac[NOTIN_firstSet_nConstructorName] >>
          disj2_tac >> conj_tac
          >- (simp[peg_EbaseParen_def, peg_eval_tok_NONE] >>
              metis_tac[NOTIN_firstSet_nConstructorName]) >>
          conj_tac
          >- metis_tac[NOTIN_firstSet_nConstructorName] >>
          conj_tac
          >- metis_tac[NOTIN_firstSet_nConstructorName] >>
          disj2_tac >> conj_tac
          >- (simp[peg_eval_seq_NONE] >>
              rename [‘TK(FST tl)’] >> Cases_on ‘tl’ >> fs[] >>
              irule peg_respects_firstSets >>
              simp[peg0_nFQV] >> simp[firstSet_nFQV] >> conj_tac
              >- metis_tac[firstSets_nV_nConstructorName] >>
              fs[firstSet_nConstructorName]) >>
          disj1_tac >> const_x_assum "NT_rank" irule >> simp[NT_rank_def])
      >- (note_tac "Ebase: nEliteral (6/10)" >> disj1_tac >>
          const_x_assum "NT_rank" irule >> simp[NT_rank_def])
      >- (note_tac "Ebase: let-in-end (7/10)" >> disj2_tac >>
          simp[peg_eval_tok_NONE] >>
          conj_tac
          >- simp[peg_eval_seq_NONE, peg_eval_NT_NONE, cmlpeg_rules_applied,
                  peg_eval_tok_NONE] >>
          disj2_tac >> conj_tac
          >- simp[peg_EbaseParen_def, peg_eval_tok_NONE] >>
          disj1_tac >> dsimp[] >>
          rename[‘ptree_head ld_pt = NN nLetDecs’,
                 ‘real_fringe ld_pt = MAP _ ldtks’,
                 ‘ptree_head es_pt = NN nEseq’,
                 ‘real_fringe es_pt = MAP _ estks’, ‘(EndT, endl)’] >>
          map_every qexists_tac [‘[ld_pt]’,
                                 ‘estks ++ [(EndT,endl)] ++ sfx’] >>
          simp[] >> simp[Once EXISTS_PROD] >> simp[Once EXISTS_PROD] >>
          simp_tac bool_ss [APPEND, GSYM APPEND_ASSOC] >> conj_tac >>
          const_x_assum "LENGTH" irule >> simp[])
      >- (note_tac "Ebase: empty list (8/10)" >> simp[peg_eval_tok_NONE] >>
          disj2_tac >> conj_tac
          >- simp[peg_eval_seq_NONE, peg_eval_NT_NONE, cmlpeg_rules_applied,
                  peg_eval_tok_NONE] >>
          disj2_tac >> conj_tac
          >- simp[peg_EbaseParen_def, peg_eval_tok_NONE] >>
          disj1_tac >> dsimp[] >> disj2_tac >>
          simp[peg_respects_firstSets])
      >- (note_tac "Ebase: [..] (9/10)" >> simp[peg_eval_tok_NONE] >>
          disj2_tac >> conj_tac
          >- simp[peg_eval_seq_NONE, peg_eval_NT_NONE, cmlpeg_rules_applied,
                  peg_eval_tok_NONE] >>
          disj2_tac >> conj_tac
          >- simp[peg_EbaseParen_def, peg_eval_tok_NONE] >>
          disj1_tac >> dsimp[] >> simp[Once EXISTS_PROD] >>
          simp_tac bool_ss [GSYM APPEND_ASSOC, APPEND] >>
          const_x_assum "LENGTH" irule >> simp[])
      >- (note_tac "Ebase: op ID (10/10)" >> simp[peg_eval_tok_NONE] >>
          disj2_tac >> conj_tac
          >- simp[peg_eval_seq_NONE, peg_eval_NT_NONE, cmlpeg_rules_applied,
                  peg_eval_tok_NONE] >>
          disj2_tac >> conj_tac
          >- simp[peg_eval_tok_NONE, peg_EbaseParen_def] >>
          disj2_tac >> simp[peg_respects_firstSets, peg_eval_seq_NONE]))
  >- (print_tac "nEapp" >> disch_then assume_tac >>
      match_mp_tac (eapp_complete
                      |> Q.INST [‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (bool_ss ++ DNF_ss) [AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM, NT_rank_def] >> simp[])
  >- (print_tac "nEadd" >> disch_then assume_tac >>
      simp[peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      match_mp_tac (peg_linfix_complete
                      |> Q.INST [‘P’ |-> ‘nEadd’, ‘SEP’ |-> ‘NN nAddOps’,
                                 ‘C’ |-> ‘NN nEmult’, ‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (srw_ss() ++ DNF_ss)
                           [sym2peg_def, cmlG_applied, MAP_EQ_CONS,
                            AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM, NT_rank_def] >>
      conj_tac >- (simp[firstSet_nConstructorName, firstSet_nFQV, firstSet_nV]>>
                   metis_tac[validSym_incompatibility])>>
      fs[])
  >- (print_tac "nE'" >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, MAP_EQ_CONS] >> rw[] >>
      fs[MAP_EQ_CONS, MAP_EQ_APPEND, mkNd_def] >> rveq >> pmap_cases >>
      simp[peg_eval_tok_NONE]
      >- (rename [‘ptree_head gdpt = NN nE’, ‘ptree_head thpt = NN nE’,
                  ‘ptree_head elpt = NN nE'’, ‘real_fringe gdpt = MAP _ gf’,
                  ‘real_fringe thpt = MAP _ tf’, ‘MAP _ elf = real_fringe elpt’,
                  ‘(IfT,_) :: (gf ++ (ThenT,_)::(tf ++ _) ++ _)’] >>
          disj2_tac >> conj_tac
          >- simp[peg_eval_seq_NONE, peg_respects_firstSets] >>
          dsimp[] >> normlist >>
          const_assum "LENGTH" (unify_firstconj kall_tac) >> simp[] >>
          const_assum "LENGTH" (unify_firstconj kall_tac) >> simp[]) >>
      disj2_tac >> conj_tac
      >- (Cases_on ‘pfx’ >> simp[]
          >- (Cases_on ‘sfx’ >> simp[] >> fs[] >>
              erule mp_tac
                (MATCH_MP rfringe_length_not_nullable nullable_ElogicOR) >>
              simp[]) >>
          fs[MAP_EQ_CONS, PAIR_MAP] >>
          rename [‘FST tl ≠ RaiseT’] >> Cases_on ‘tl’ >> fs[] >>
          rename [‘real_fringe pt = (TK t, _) :: _’] >>
          ‘t ∈ firstSet cmlG [NN nElogicOR]’
            by metis_tac[rfirstSet_nonempty_fringe] >>
          fs[firstSet_nFQV, firstSet_nV, firstSet_nConstructorName]) >>
      disj1_tac >> const_x_assum "NT_rank" irule >> simp[NT_rank_def] >>
      rpt strip_tac >> fs[] >> rfs[])
  >- (print_tac "nE" >>
      simp[Once peg_eval_NT_SOME, cmlpeg_rules_applied, MAP_EQ_CONS] >> rw[] >>
      fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >>
      rw[peg_eval_tok_NONE, peg_respects_firstSets, peg_eval_seq_NONE] >>
      pmap_cases >> simp[mkNd_def, peg_respects_firstSets]
      >- (DISJ2_TAC >> Q.REFINE_EXISTS_TAC ‘[ppt]’ >> simp[] >>
          normlist >> first_assum (unify_firstconj kall_tac o has_length) >>
          simp[] >>
          Q.REFINE_EXISTS_TAC ‘[ppt]’ >> simp[] >> normlist >>
          first_assum (unify_firstconj kall_tac o has_length) >>
          simp[])
      >- (DISJ2_TAC >> Q.REFINE_EXISTS_TAC ‘[ppt]’ >> simp[] >>
          normlist >> first_assum (unify_firstconj kall_tac o has_length) >>
          simp[])
      >- (DISJ2_TAC >> Q.REFINE_EXISTS_TAC ‘[ppt]’ >> simp[] >>
          normlist >> first_assum (unify_firstconj kall_tac o has_length) >>
          simp[]) >>
      DISJ2_TAC >> simp[NT_rank_def] >>
      ‘0 < LENGTH (MAP (TK ## I)pfx)’
        by metis_tac [rfringe_length_not_nullable, nullable_Ehandle] >> fs[] >>
      Cases_on ‘pfx’ >> fs[disjImpI] >> rw[] >>
      IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> simp[PAIR_MAP])
  >- (print_tac "nDtypeDecls" >> fs[FDOM_cmlPEG])
  >- (print_tac "nDtypeDecl" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> rw[] >>
      fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >> rw[] >>
      pmap_cases >>
      Q.REFINE_EXISTS_TAC ‘[pt]’ >> simp[] >> normlist >>
      first_assum (unify_firstconj kall_tac o has_length) >> simp[] >>
      rename1 ‘peg_eval cmlPEG (ppfx ++ sfx, _) _’ >>
      match_mp_tac (peg_linfix_complete
                      |> Q.INST [‘P’ |-> ‘nDtypeCons’, ‘SEP’ |-> ‘TK BarT’,
                                 ‘C’ |-> ‘NN nDconstructor’,
                                 ‘master’ |-> ‘ppfx’]
                      |> SIMP_RULE (srw_ss() ++ DNF_ss)
                           [sym2peg_def, cmlG_applied, MAP_EQ_CONS,
                            AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM, NT_rank_def] >>
      dsimp[EXTENSION, EQ_IMP_THM, FORALL_PROD])
  >- (print_tac "nDtypeCons" >> fs[FDOM_cmlPEG])
  >- (print_tac "nDecls" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> rw[] >>
      fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >> rw[] >>
      pmap_cases >> simp[mkNd_def]
      >- (DISJ1_TAC >>
          rename [‘ptree_head dpt = NN nDecl’,
                  ‘ptree_head dspt = NN nDecls’,
                  ‘real_fringe dspt = MAP _ dsf’,
                  ‘real_fringe dpt = MAP _ df’] >>
          map_every qexists_tac [‘[dpt]’, ‘dsf ++ sfx’, ‘[dspt]’] >>
          ‘0 < LENGTH(MAP (TK##I) df)’
            by metis_tac [rfringe_length_not_nullable, nullable_Decl] >>
          fs[] >>
          Cases_on ‘dsf’ >- (fs[] >> simp[NT_rank_def]) >>
          normlist >> first_x_assum (match_mp_tac o has_length) >>
          simp[] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >>
          simp[] >> rw[] >> simp[] >> fs[PAIR_MAP])
      >- simp[peg_respects_firstSets] >>
      DISJ2_TAC >> Cases_on ‘sfx’ >>
      fs[not_peg0_peg_eval_NIL_NONE, peg_eval_tok_NONE,
         peg_respects_firstSets] >> rename [‘FST tl ≠ EqualsT’] >>
      Cases_on ‘tl’ >> fs[peg_respects_firstSets])
  >- (print_tac "nDecl" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> rw[] >>
      fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >>
      rw[peg_eval_tok_NONE] >> pmap_cases >> simp[mkNd_def]
      >- (DISJ1_TAC >> normlist >>
          first_assum (unify_firstconj kall_tac o has_length) >> simp[])
      >- (asm_match ‘ptree_head tpt = NN nTypeDec’ >>
          ‘0 < LENGTH (real_fringe tpt)’
            by metis_tac[rfringe_length_not_nullable, nullable_TypeDec] >>
          pop_assum mp_tac >> simp[] >> Cases_on ‘pfx’ >> fs[] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> simp[PAIR_MAP] >>
          rename [‘FST tl = DatatypeT’] >> Cases_on ‘tl’ >> fs[] >>
          rw[] >> disj1_tac >> first_x_assum irule >> simp[NT_rank_def])
      >- (asm_match ‘ptree_head tpt = NN nTypeAbbrevDec’ >>
          ‘0 < LENGTH (real_fringe tpt)’
            by metis_tac[rfringe_length_not_nullable, nullable_TypeAbbrevDec] >>
          pop_assum mp_tac >> simp[] >> Cases_on ‘pfx’ >> fs[] >>
          IMP_RES_THEN mp_tac rfirstSet_nonempty_fringe >> simp[PAIR_MAP] >>
          rpt strip_tac >> disj2_tac >>
          rename [‘FST tl = TypeT’] >> Cases_on ‘tl’ >> fs[] >>
          simp[peg_respects_firstSets] >> rw[] >>
          first_x_assum match_mp_tac >> simp[NT_rank_def])
      >- (DISJ1_TAC >> normlist >>
          rename [‘peg_eval _ (in1 ++ (InT,_)::(in2 ++ (EndT,_)::sfx),
                               nt (mkNT nDecls) I)’,
                  ‘real_fringe decls_pt1 = MAP _ in1’] >>
          first_assum (unify_firstconj kall_tac o has_length) >>
          qexists_tac ‘decls_pt1’ >> simp[] >> dsimp[EXISTS_PROD] >>
          normlist >> first_x_assum irule >> simp[]))
  >- (print_tac "nDconstructor" >> stdstart >> pmap_cases >>
      rename [‘ptree_head upt = NN nUQConstructorName’,
              ‘real_fringe upt = MAP _ upf’,
              ‘ptree_head blpt = NN nTbaseList’,
              ‘real_fringe blpt = MAP _ blf’] >>
      Cases_on ‘blf = []’
      >- (rveq >> fs[] >>
          ‘NT_rank (mkNT nUQConstructorName) < NT_rank (mkNT nDconstructor)’
             by simp[NT_rank_def] >>
          first_x_assum (pop_assum o mp_then Any mp_tac) >> simp[] >>
          disch_then (first_assum o mp_then (Pos hd) mp_tac) >> simp[] >>
          rename [‘sfx ≠ []’] >> disch_then (qspec_then ‘sfx’ mp_tac) >>
          disch_then (assume_tac o MATCH_MP (CONJUNCT1 peg_deterministic)) >>
          simp[] >> dsimp[] >> csimp[] >>
          ‘peg_eval cmlPEG ([] ++ sfx, nt (mkNT nTbaseList) I)
                    (SOME(sfx,[blpt]))’
            by (first_x_assum irule >> simp[] >>
                imp_res_tac
                  (MATCH_MP rfringe_length_not_nullable
                            nullable_UQConstructorName) >> rfs[]) >>
          fs[] >> Cases_on ‘sfx’ >> fs[peg_eval_tok_NONE]) >>
      ‘0 < LENGTH blf’ by (Cases_on ‘blf’ >> fs[]) >>
      ‘0 < LENGTH upf’
        by (imp_res_tac
                  (MATCH_MP rfringe_length_not_nullable
                            nullable_UQConstructorName) >> rfs[]) >>
      ‘peg_eval cmlPEG (blf ++ sfx, nt (mkNT nTbaseList) I)
                (SOME(sfx, [blpt])) ∧
       peg_eval cmlPEG (upf ++ (blf ++ sfx), nt (mkNT nUQConstructorName) I)
                (SOME (blf++sfx, [upt]))’ by simp[] >>
      pop_assum (assume_tac o MATCH_MP (CONJUNCT1 peg_deterministic)) >>
      fs[] >>
      ‘peg_eval cmlPEG (blf ++ sfx, tok ((=) OfT) mktokLf) NONE’
        suffices_by simp[] >>
      Cases_on ‘blf’ >> fs[peg_eval_tok_NONE] >>
      rename [‘FST tkl = OfT’] >> Cases_on ‘tkl’ >>
      simp[] >> fs[] >> imp_res_tac rfirstSet_nonempty_fringe >> rfs[])
  >- (print_tac "nDType" >> disch_then assume_tac >>
      match_mp_tac (dtype_complete
                      |> Q.INST [‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (bool_ss ++ DNF_ss) [AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM, NT_rank_def] >> simp[])
  >- (print_tac "nConstructorName" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> rw[] >>
      fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >>
      rw[mkNd_def] >> pmap_cases >> simp[]
      (* 6 cases *)
      >- simp[NT_rank_def] >>
      DISJ2_TAC >> simp[peg_eval_seq_NONE] >>
      match_mp_tac peg_respects_firstSets >> simp[] >>
      simp[firstSet_NT, cmlG_FDOM, cmlG_applied, disjImpI] >>
      dsimp[])
  >- (print_tac "nCompOps" >>
      simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> rw[] >>
      fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM] >>
      pmap_cases >>
      rw[peg_eval_tok_NONE, mkNd_def])
  >- (print_tac "nAndFDecls" >> disch_then assume_tac >>
      simp[peg_eval_NT_SOME, cmlpeg_rules_applied] >>
      match_mp_tac (peg_linfix_complete
                      |> Q.INST [‘P’ |-> ‘nAndFDecls’, ‘SEP’ |-> ‘TK AndT’,
                                 ‘C’ |-> ‘NN nFDecl’, ‘master’ |-> ‘pfx’]
                      |> SIMP_RULE (srw_ss() ++ DNF_ss)
                           [sym2peg_def, cmlG_applied, MAP_EQ_CONS,
                            AND_IMP_INTRO]) >>
      simp[cmlG_applied, cmlG_FDOM, NT_rank_def] >>
      dsimp[EXTENSION, EQ_IMP_THM] >> fs[FORALL_PROD]) >>
  print_tac "nAddOps" >>
  simp[MAP_EQ_CONS, Once peg_eval_NT_SOME, cmlpeg_rules_applied] >> rw[] >>
  fs[MAP_EQ_CONS, MAP_EQ_APPEND, DISJ_IMP_THM, FORALL_AND_THM,
     peg_eval_tok_NONE, mkNd_def] >> pmap_cases >> simp[]
QED

Theorem cmlG_unambiguous:
   valid_lptree cmlG pt1 ∧ ptree_head pt1 = NT (mkNT N) ∧
   valid_lptree cmlG pt2 ∧ ptree_head pt2 = NT (mkNT N) ∧
   mkNT N ∈ FDOM cmlPEG.rules ∧ (* e.g., nTopLevelDecs *)
   real_fringe pt2 = real_fringe pt1 ∧
   (∀s. s ∈ set (ptree_fringe pt1) ⇒ ∃t. s = TOK t) ⇒
     pt1 = pt2
Proof
  rpt strip_tac >>
  ‘∃pfx. real_fringe pt1 = MAP (TK ## I) pfx’
    by (Q.UNDISCH_THEN ‘real_fringe pt2 = real_fringe pt1’ kall_tac >>
        fs[ptree_fringe_real_fringe, MEM_MAP, GSYM LEFT_FORALL_IMP_THM] >>
        qabbrev_tac ‘l = real_fringe pt1’ >> markerLib.RM_ALL_ABBREVS_TAC >>
        Induct_on ‘l’ >>
        fs[DISJ_IMP_THM, FORALL_AND_THM, FORALL_PROD] >> rw[] >>
        simp[Once EXISTS_LIST] >> simp[Once EXISTS_PROD] >>
        metis_tac[listTheory.MAP]) >>
  qspecl_then [‘pt’, ‘N’, ‘pfx’, ‘[]’] (ASSUME_TAC o Q.GEN ‘pt’)
    completeness >>
  pop_assum (fn th => MP_TAC (Q.SPEC ‘pt1’ th) THEN
                      MP_TAC (Q.SPEC ‘pt2’ th)) >> simp[] >>
  metis_tac[PAIR_EQ, peg_deterministic, SOME_11, CONS_11]
QED

val _ = export_theory();
