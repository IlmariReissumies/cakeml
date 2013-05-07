(*Generated by Lem from toBytecode.lem.*)
open bossLib Theory Parse res_quanTheory
open fixedPointTheory finite_mapTheory listTheory pairTheory pred_setTheory
open integerTheory set_relationTheory sortingTheory stringTheory wordsTheory

val _ = numLib.prefer_num();



open ToIntLangTheory IntLangTheory CompilerPrimitivesTheory BytecodeTheory CompilerLibTheory SemanticPrimitivesTheory AstTheory LibTheory

val _ = new_theory "ToBytecode"

(* Intermediate Language to Bytecode *)

(*open Ast*)
(*open CompilerLib*)
(*open CompilerPrimitives*)
(*open IntLang*)
(*open ToIntLang*)
(*open Bytecode*)

(* pull closure bodies into code environment *)

 val bind_fv_def = Define `
 (bind_fv (az,e) nz ix =  
(let fvs = ( free_vars e) in
  let recs = ( FILTER (\ v . MEM (az +v) fvs /\ ~  (v =ix)) ( GENLIST (\ n . n) nz)) in
  let envs = ( FILTER (\ v . az +nz <= v) fvs) in
  let envs = ( MAP (\ v . v -(az +nz)) envs) in
  let rz = ( LENGTH recs +1) in
  let e = ( mkshift (\ v . if v < nz then the 0 (find_index v (ix ::recs) 0)
                            else the 0 (find_index (v - nz) envs rz))
                  az e) in
  let rz = (rz - 1) in
  ((( GENLIST (\ i . CCArg (2 +i)) (az +1)) ++(( GENLIST CCRef rz) ++( GENLIST (\ i . CCEnv (rz +i)) ( LENGTH envs))))
  ,(recs,envs)
  ,e
  )))`;


 val label_closures_defn = Hol_defn "label_closures" `

(label_closures _ j (CRaise err) = (CRaise err, j))
/\
(label_closures ez j (CHandle e1 e2) =  
(let (e1,j) = (label_closures ez j e1) in
  let (e2,j) = (label_closures (ez +1) j e2) in
  (CHandle e1 e2, j)))
/\
(label_closures _ j (CVar x) = (CVar x, j))
/\
(label_closures _ j (CLit l) = (CLit l, j))
/\
(label_closures ez j (CCon cn es) =  
(let (es,j) = (label_closures_list ez j es) in
  (CCon cn es,j)))
/\
(label_closures ez j (CTagEq e n) =  
(let (e,j) = (label_closures ez j e) in
  (CTagEq e n,j)))
/\
(label_closures ez j (CProj e n) =  
(let (e,j) = (label_closures ez j e) in
  (CProj e n,j)))
/\
(label_closures ez j (CLet e1 e2) =  
(let (e1,j) = (label_closures ez j e1) in
  let (e2,j) = (label_closures (ez +1) j e2) in
  (CLet e1 e2, j)))
/\
(label_closures ez j (CLetrec defs e) =  
(let defs = ( MAP SND ( FILTER ((o) IS_NONE FST) defs)) in
  let nz = ( LENGTH defs) in
  let (defs,j) = (label_closures_defs ez j nz 0 defs) in
  let (e,j) = (label_closures (ez +nz) j e) in
  (CLetrec defs e, j)))
/\
(label_closures ez j (CFun (NONE, def)) =  
(let (defs,j) = (label_closures_defs ez j 1 0 [def]) in
  (CFun ( EL  0  defs), j)))
/\
(label_closures _ j (CFun (SOME x,y)) = (CFun (SOME x,y),j)) (* should not happen *)
/\
(label_closures ez j (CCall e es) =  
(let (e,j) = (label_closures ez j e) in
  let (es,j) = (label_closures_list ez j es) in
  (CCall e es,j)))
/\
(label_closures ez j (CPrim1 p1 e) =  
(let (e,j) = (label_closures ez j e) in
  (CPrim1 p1 e, j)))
/\
(label_closures ez j (CPrim2 p2 e1 e2) =  
(let (e1,j) = (label_closures ez j e1) in
  let (e2,j) = (label_closures ez j e2) in
  (CPrim2 p2 e1 e2, j)))
/\
(label_closures ez j (CUpd e1 e2) =  
(let (e1,j) = (label_closures ez j e1) in
  let (e2,j) = (label_closures ez j e2) in
  (CUpd e1 e2, j)))
/\
(label_closures ez j (CIf e1 e2 e3) =  
(let (e1,j) = (label_closures ez j e1) in
  let (e2,j) = (label_closures ez j e2) in
  let (e3,j) = (label_closures ez j e3) in
  (CIf e1 e2 e3, j)))
/\
(label_closures_list _ j [] = ([],j))
/\
(label_closures_list ez j (e::es) =  
(let (e,j) = (label_closures ez j e) in
  let (es,j) = (label_closures_list ez j es) in
  ((e ::es),j)))
/\
(label_closures_defs _ j _ _ [] = ([], j))
/\
(label_closures_defs ez ld nz k ((az,b)::defs) =  
(let (ccenv,ceenv,b) = ( bind_fv (az,b) nz k) in
  let cz = (az + LENGTH ( FST ceenv) + LENGTH ( SND ceenv) + 1) in
  let (b,j) = (label_closures cz (ld +1) b) in
  let (defs,j) = (label_closures_defs ez j nz (k +1) defs) in
  (((SOME (ld,(ccenv,ceenv)),(az,b)) ::defs), j)))`;

val _ = Defn.save_defn label_closures_defn;

val _ = Hol_datatype `
 call_context = TCNonTail | TCTail of num => num`;

(* TCTail j k = in tail position,
   * the called function has j arguments, and
   * k let variables have been bound *)
(* TCNonTail = in tail position, or called from top-level *)

val _ = Hol_datatype `
 compiler_result =
  <| out: bc_inst list (* reversed code *)
   ; next_label: num
   |>`;


 val prim1_to_bc_def = Define `

(prim1_to_bc CRef = Ref)
/\
(prim1_to_bc CDer = Deref)`;


 val prim2_to_bc_def = Define `

(prim2_to_bc CAdd = Add)
/\
(prim2_to_bc CSub = Sub)
/\
(prim2_to_bc CMul = Mult)
/\
(prim2_to_bc CDiv = Div)
/\
(prim2_to_bc CMod = Mod)
/\
(prim2_to_bc CLt = Less)
/\
(prim2_to_bc CEq = Equal)`;


val _ = Define `
 emit = ( FOLDL (\ s i . ( s with<| out := i :: s.out |>)))`;


 val get_labels_def = Define `

(get_labels n s = (( s with<| next_label := s.next_label + n |>), GENLIST (\ i . s.next_label + i) n))`;


 val compile_envref_defn = Hol_defn "compile_envref" `

(compile_envref sz s (CCArg n) = ( emit s [Stack (Load (sz + n))]))
/\
(compile_envref sz s (CCEnv n) = ( emit s [Stack (Load sz); Stack (El n)]))
/\
(compile_envref sz s (CCRef n) = ( emit (compile_envref sz s (CCEnv n)) [Deref]))`;

val _ = Defn.save_defn compile_envref_defn;

 val compile_varref_def = Define `

(compile_varref sz s (CTLet n) = ( emit s [Stack (Load (sz - n))]))
/\
(compile_varref sz s (CTEnv x) = ( compile_envref sz s x))`;


(* calling convention:
 * before: env, CodePtr ret, argn, ..., arg1, Block 0 [CodePtr c; env],
 * thus, since env = stack[sz], argk should be CTArg (2 + n - k)
 * after:  retval,
 *)

(* closure representation:
 * Block 3 [CodePtr f; Env]
 * where Env = Number 0 for empty, or else
 * Block 3 [v1,...,vk]
 * with a value for each free variable
 * (some values may be RefPtrs to other (mutrec) closures)
 *)

(* closure construction, for a bundle of nz names, nk defs:
 * - push nz refptrs
 * - push nk CodePtrs, each pointing to the appropriate body
 * - for each def, load its CodePtr, load its environment, cons them up, and
     store them where its CodePtr was
   - for each name, load the refptr and update it with the closure
   - for each name, store the refptr back where it was
 *)

 val emit_ceenv_def = Define `

(emit_ceenv env (sz,s) fv = ((sz +1),compile_varref sz s ( EL  fv  env)))`;


 val emit_ceref_def = Define `

(* sz                                                           z                             *)
(* e, ..., e, CodePtr_k, cl_1, ..., CodePtr k, ..., CodePtr nz, RefPtr_1 0, ..., RefPtr_nz 0, *)
(emit_ceref z (sz,s) j = ((sz +1),emit s [Stack (Load ((sz - z) +j))]))`;


 val push_lab_def = Define `

(push_lab (s,ecs) (NONE,_) = (s,(([],[]) ::ecs))) (* should not happen *)
/\
(push_lab (s,ecs) (SOME (l,(_,ceenv)),_) =
  (emit s [PushPtr (Lab l)],(ceenv ::ecs)))`;


 val cons_closure_def = Define `

(cons_closure env0 sz nk (s,k) (refs,envs) =  
(
  (*                                                                      sz *)
  (* cl_1, ..., CodePtr_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0,    *)let s = ( emit s [Stack (Load k)]) in
  (* CodePtr_k, cl_1, ..., CodePtr_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let (z,s) = ( FOLDL (emit_ceref (sz +nk)) ((sz +nk +nk +1),s) refs) in  
  (case FOLDL (emit_ceenv env0) (z,s) envs of
      (_,s) =>
  (* e_kj, ..., e_k1, CodePtr_k, cl_1, ..., CodePtr_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let s = ( emit s [Stack (Cons 0 ( LENGTH refs + LENGTH envs))]) in
  (* env_k, CodePtr_k, cl_1, ..., CodePtr_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let s = ( emit s [Stack (Cons closure_tag 2)]) in
  (* cl_k,  cl_1, ..., CodePtr_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let s = ( emit s [Stack (Store k)]) in
  (* cl_1, ..., cl_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  (s,(k + 1))
  )))`;


 val update_refptr_def = Define `

(update_refptr nk (s,k) =  
(
  (* cl_1, ..., cl_nk, RefPtr_1 cl_1, ..., RefPtr_k 0, ..., RefPtr_nk 0, *)let s = ( emit s [Stack (Load (nk + k))]) in
  (* RefPtr_k 0, cl_1, ..., cl_nk, RefPtr_1 cl_1, ..., RefPtr_k 0, ..., RefPtr_nk 0, *)
  let s = ( emit s [Stack (Load (1 + k))]) in
  (* cl_k, RefPtr_k 0, cl_1, ..., cl_nk, RefPtr_1 cl_1, ..., RefPtr_k 0, ..., RefPtr_nk 0, *)
  let s = ( emit s [Update]) in
  (* cl_1, ..., cl_nk, RefPtr_1 cl_1, ..., RefPtr_k cl_k, ..., RefPtr_nk 0, *)
  (s,(k +1))))`;


 val compile_closures_def = Define `

(compile_closures env sz s defs =  
(let nk = ( LENGTH defs) in
  let s = ( num_fold (\ s . emit s [Stack (PushInt i0); Ref]) s nk) in
  (* RefPtr_1 0, ..., RefPtr_nk 0, *)
  let (s,ecs) = ( FOLDL push_lab (s,[]) ( REVERSE defs)) in
  (* CodePtr 1, ..., CodePtr nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let (s,k) = ( FOLDL (cons_closure env sz nk) (s,0) ecs) in
  (* cl_1, ..., cl_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let (s,k) = ( num_fold (update_refptr nk) (s,0) nk) in
  (* cl_1, ..., cl_nk, RefPtr_1 cl_1, ..., RefPtr_nk cl_nk, *)
  let k = (nk - 1) in
  num_fold (\ s . emit s [Stack (Store k)]) s nk))`;

  (* cl_1, ..., cl_nk, *)

 val pushret_def = Define `

(pushret TCNonTail s = s)
/\
(pushret (TCTail j k) s =  
(
 (* val, vk, ..., v1, env, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c; env], *)
  emit s [Stack (Pops (k +1));
 (* val, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c; env], *)
          Stack (Load 1);
 (* CodePtr ret, val, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c; env], *)
          Stack (Store (j +2));
 (* val, CodePtr ret, argj, ..., arg1, CodePtr ret, *)
          Stack (Pops (j +1));
 (* val, CodePtr ret, *)
          Return]))`;


 val compile_defn = Hol_defn "compile" `

(compile _ t _ s (CRaise err) =  
(
  pushret t (emit s [Stack (PushInt (error_to_int err)); PopExc])))
/\
(compile env t sz s (CHandle e1 e2) = (compile env t sz s e1))
/\
(compile _ t _ s (CLit (IntLit i)) =  
(
  pushret t (emit s [Stack (PushInt i)])))
/\
(compile _ t _ s (CLit (Bool b)) =  
(
  pushret t (emit s [Stack (Cons (bool_to_tag b) 0)])))
/\
(compile _ t _ s (CLit Unit) =  
(
  pushret t (emit s [Stack (Cons unit_tag 0)])))
/\
(compile env t sz s (CVar vn) = ( pushret t (compile_varref sz s ( EL  vn  env))))
/\
(compile env t sz s (CCon n es) =  
(
  pushret t (emit (compile_nts env sz s es) [Stack (Cons (n +block_tag) ( LENGTH es))])))
/\
(compile env t sz s (CTagEq e n) =  
(
  pushret t (emit (compile env TCNonTail sz s e) [Stack (TagEq (n +block_tag))])))
/\
(compile env t sz s (CProj e n) =  
(
  pushret t (emit (compile env TCNonTail sz s e) [Stack (El n)])))
/\
(compile env t sz s (CLet e eb) =  
(compile_bindings env t sz eb 0 (compile env TCNonTail sz s e) 1))
/\
(compile env t sz s (CLetrec defs eb) =  
(let s = ( compile_closures env sz s defs) in
  compile_bindings env t sz eb 0 s ( LENGTH defs)))
/\
(compile env t sz s (CFun cb) =  
(
  pushret t (compile_closures env sz s [cb])))
/\
(compile env t sz s (CCall e es) =  
(let n = ( LENGTH es) in
  let s = (compile_nts env sz s (e ::es)) in
  (case t of
    TCNonTail =>
    (* argn, ..., arg2, arg1, Block 0 [CodePtr c; env], *)
    let s = ( emit s [Stack (Load n); Stack (El 1)]) in
    (* env, argn, ..., arg1, Block 0 [CodePtr c; env], *)
    let s = ( emit s [Stack (Load (n +1)); Stack (El 0)]) in
    (* CodePtr c, env, argn, ..., arg1, Block 0 [CodePtr c; env], *)
    emit s [CallPtr]
    (* before: env, CodePtr ret, argn, ..., arg1, Block 0 [CodePtr c; env], *)
    (* after:  retval, *)
  | TCTail j k =>
    (* argn, ..., arg1, Block 0 [CodePtr c; env],
     * vk, ..., v1, env1, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c1; env1], *)
    let s = ( emit s [Stack (Load (n +1 +k +1))]) in
    (* CodePtr ret, argn, ..., arg1, Block 0 [CodePtr c; env],
     * vk, ..., v1, env1, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c1; env1], *)
    let s = ( emit s [Stack (Load (n +1)); Stack (El 1)]) in
    (* env, CodePtr ret, argn, ..., arg1, Block 0 [CodePtr c; env],
     * vk, ..., v1, env1, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c1; env1], *)
    let s = ( emit s [Stack (Load (n +2)); Stack (El 0)]) in
    (* CodePtr c, env, CodePtr ret, argn, ..., arg1, Block 0 [CodePtr c; env],
     * vk, ..., v1, env1, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c1; env1], *)
    let s = ( emit s [Stack (Shift (1 +1 +1 +n +1) (k +1 +1 +j +1))]) in
    emit s [JumpPtr]
  )))
/\
(compile env t sz s (CPrim1 uop e) =  
(
  pushret t (emit (compile env TCNonTail sz s e) [prim1_to_bc uop])))
/\
(compile env t sz s (CPrim2 op e1 e2) =  
( (* TODO: need to detect div by zero? *)
  pushret t (emit (compile_nts env sz s [e1;e2]) [Stack (prim2_to_bc op)])))
/\
(compile env t sz s (CUpd e1 e2) =  
(
  pushret t (emit (compile_nts env sz s [e1;e2]) [Update; Stack (Cons unit_tag 0)])))
/\
(compile env t sz s (CIf e1 e2 e3) =  
(let s = (compile env TCNonTail sz s e1) in
  let (s,labs) = ( get_labels 2 s) in
  let n0 = ( EL  0  labs) in
  let n1 = ( EL  1  labs) in
  (case t of
    TCNonTail =>
    let (s,labs) = ( get_labels 1 s) in
    let n2 = ( EL  0  labs) in
    let s = ( emit s [(JumpIf (Lab n0)); (Jump (Lab n1)); Label n0]) in
    let s = (compile env t sz s e2) in
    let s = ( emit s [Jump (Lab n2); Label n1]) in
    let s = (compile env t sz s e3) in
    emit s [Label n2]
  | TCTail _ _ =>
    let s = ( emit s [(JumpIf (Lab n0)); (Jump (Lab n1)); Label n0]) in
    let s = (compile env t sz s e2) in
    let s = ( emit s [Label n1]) in
    compile env t sz s e3
  )))
/\
(compile_bindings env t sz e n s 0 =  
((case t of
    TCTail j k => compile env (TCTail j (k +n)) (sz +n) s e
  | TCNonTail =>
    emit (compile env t (sz +n) s e) [Stack (Pops n)]
  )))
/\
(compile_bindings env t sz e n s m =  
(compile_bindings ((CTLet (sz +(n +1))) ::env) t sz e (n +1) s (m - 1)))
/\
(compile_nts _ _ s [] = s)
/\
(compile_nts env sz s (e::es) =  
(compile_nts env (sz +1) (compile env TCNonTail sz s e) es))`;

val _ = Defn.save_defn compile_defn;

(* code env to bytecode *)

 val free_labs_defn = Hol_defn "free_labs" `

(free_labs _ (CRaise _) = ([]))
/\
(free_labs ez (CHandle e1 e2) = (free_labs ez e1 ++ free_labs (ez +1) e2))
/\
(free_labs _ (CVar _) = ([]))
/\
(free_labs _ (CLit _) = ([]))
/\
(free_labs ez (CCon _ es) = (free_labs_list ez es))
/\
(free_labs ez (CTagEq e _) = (free_labs ez e))
/\
(free_labs ez (CProj e _) = (free_labs ez e))
/\
(free_labs ez (CLet e b) = (free_labs ez e ++ free_labs (ez +1) b))
/\
(free_labs ez (CLetrec defs e) =  
(free_labs_defs ez ( LENGTH defs) 0 defs ++
  free_labs (ez + LENGTH defs) e))
/\
(free_labs ez (CFun def) = (free_labs_def ez 1 0 def))
/\
(free_labs ez (CCall e es) = (free_labs ez e ++ free_labs_list ez es))
/\
(free_labs ez (CPrim2 _ e1 e2) = (free_labs ez e1 ++ free_labs ez e2))
/\
(free_labs ez (CUpd e1 e2) = (free_labs ez e1 ++ free_labs ez e2))
/\
(free_labs ez (CPrim1 _ e) = (free_labs ez e))
/\
(free_labs ez (CIf e1 e2 e3) = (free_labs ez e1 ++ (free_labs ez e2 ++ free_labs ez e3)))
/\
(free_labs_list _ [] = ([]))
/\
(free_labs_list ez (e::es) = (free_labs ez e ++ free_labs_list ez es))
/\
(free_labs_defs _ _ _ [] = ([]))
/\
(free_labs_defs ez nz ix (d::ds) = (free_labs_def ez nz ix d ++ free_labs_defs ez nz (ix +1) ds))
/\
(free_labs_def ez nz ix (SOME (l,(cc,(re,ev))),(az,b)) =
  (((ez,nz,ix),((l,(cc,(re,ev))),(az,b))) ::(free_labs (1 + LENGTH re + LENGTH ev + az) b)))
/\
(free_labs_def ez nz _ (NONE,(az,b)) = (free_labs (ez +nz +az) b))`;

val _ = Defn.save_defn free_labs_defn;

 val cce_aux_def = Define `
 (cce_aux s ((l,(ccenv,_)),(az,b)) =  
(
  compile ( MAP CTEnv ccenv) (TCTail az 0) 0 (emit s [Label l]) b))`;


 val compile_code_env_def = Define `

(compile_code_env s e =  
(let (s,ls) = ( get_labels 1 s) in
  let l = ( EL  0  ls) in
  let s = ( emit s [Jump (Lab l)]) in
  let s = ( FOLDL cce_aux s ( MAP SND (free_labs 0 e))) in
  emit s [Label l]))`;


(* replace labels in bytecode with addresses *)

 val calculate_labels_defn = Hol_defn "calculate_labels" `

(calculate_labels _ m n a [] = (m,n,a))
/\
(calculate_labels il m n a (Label l::lbc) =  
(calculate_labels il ( FUPDATE  m ( l, n)) n a lbc))
/\
(calculate_labels il m n a (i::lbc) =  
(calculate_labels il m (n + il i + 1) (i ::a) lbc))`;

val _ = Defn.save_defn calculate_labels_defn;

 val replace_labels_defn = Hol_defn "replace_labels" `

(replace_labels _ a [] = a)
/\
(replace_labels m a (Jump (Lab l)::bc) =  
(replace_labels m (Jump (Addr ( FAPPLY  m  l)) ::a) bc))
/\
(replace_labels m a (JumpIf (Lab l)::bc) =  
(replace_labels m (JumpIf (Addr ( FAPPLY  m  l)) ::a) bc))
/\
(replace_labels m a (Call (Lab l)::bc) =  
(replace_labels m (Call (Addr ( FAPPLY  m  l)) ::a) bc))
/\
(replace_labels m a (PushPtr (Lab l)::bc) =  
(replace_labels m (PushPtr (Addr ( FAPPLY  m  l)) ::a) bc))
/\
(replace_labels m a (i::bc) =  
(replace_labels m (i ::a) bc))`;

val _ = Defn.save_defn replace_labels_defn;

 val compile_labels_def = Define `

(compile_labels il lbc = 
  ((case calculate_labels il FEMPTY 0 [] lbc of
       (m,_,bc) =>
   replace_labels m [] bc
   )))`;

val _ = export_theory()

