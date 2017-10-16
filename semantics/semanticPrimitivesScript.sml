(*Generated by Lem from semanticPrimitives.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_pervasivesTheory lem_list_extraTheory lem_stringTheory libTheory lem_string_extraTheory astTheory namespaceTheory ffiTheory fpSemTheory;

val _ = numLib.prefer_num();



val _ = new_theory "semanticPrimitives"

(*open import Pervasives*)
(*open import Lib*)
(*import List_extra*)
(*import String*)
(*import String_extra*)
(*open import Ast*)
(*open import Namespace*)
(*open import Ffi*)
(*open import FpSem*)

(* The type that a constructor builds is either a named datatype or an exception.
 * For exceptions, we also keep the module that the exception was declared in. *)
val _ = Hol_datatype `
 tid_or_exn =
    TypeId of (modN, typeN) id
  | TypeExn of (modN, conN) id`;


(*val type_defs_to_new_tdecs : list modN -> type_def -> set tid_or_exn*)
val _ = Define `
 (type_defs_to_new_tdecs mn tdefs=
 (LIST_TO_SET (MAP (\ (tvs,tn,ctors) .  TypeId (mk_id mn tn)) tdefs)))`;


val _ = Hol_datatype `
(*  'v *) sem_env =
  <| v : (modN, varN, 'v) namespace
   ; c : (modN, conN, (num # tid_or_exn)) namespace
   |>`;


(* Value forms *)
val _ = Hol_datatype `
 v =
    Litv of lit
  (* Constructor application. *)
  | Conv of  (conN # tid_or_exn)option => v list
  (* Function closures
     The environment is used for the free variables in the function *)
  | Closure of v sem_env => varN => exp
  (* Function closure for recursive functions
   * See Closure and Letrec above
   * The last variable name indicates which function from the mutually
   * recursive bundle this closure value represents *)
  | Recclosure of v sem_env => (varN # varN # exp) list => varN
  | Loc of num
  | Vectorv of v list`;


val _ = type_abbrev( "env_ctor" , ``: (modN, conN, (num # tid_or_exn)) namespace``);
val _ = type_abbrev( "env_val" , ``: (modN, varN, v) namespace``);

val _ = Define `
 (Bindv=  (Conv (SOME("Bind",TypeExn(Short"Bind"))) []))`;


(* The result of evaluation *)
val _ = Hol_datatype `
 abort =
    Rtype_error
  | Rtimeout_error`;


val _ = Hol_datatype `
 error_result =
    Rraise of 'a (* Should only be a value of type exn *)
  | Rabort of abort`;


val _ = Hol_datatype `
 result =
    Rval of 'a
  | Rerr of 'b error_result`;


(* Stores *)
val _ = Hol_datatype `
 store_v =
  (* A ref cell *)
    Refv of 'a
  (* A byte array *)
  | W8array of word8 list
  (* An array of values *)
  | Varray of 'a list`;


(*val store_v_same_type : forall 'a. store_v 'a -> store_v 'a -> bool*)
val _ = Define `
 (store_v_same_type v1 v2=
 ((case (v1,v2) of
    (Refv _, Refv _) => T
  | (W8array _,W8array _) => T
  | (Varray _,Varray _) => T
  | _ => F
  )))`;


(* The nth item in the list is the value at location n *)
val _ = type_abbrev((*  'a *) "store" , ``: ( 'a store_v) list``);

(*val empty_store : forall 'a. store 'a*)
val _ = Define `
 (empty_store=  ([]))`;


(*val store_lookup : forall 'a. nat -> store 'a -> maybe (store_v 'a)*)
val _ = Define `
 (store_lookup l st=
 (if l < LENGTH st then
    SOME (EL l st)
  else
    NONE))`;


(*val store_alloc : forall 'a. store_v 'a -> store 'a -> store 'a * nat*)
val _ = Define `
 (store_alloc v st=
  ((st ++ [v]), LENGTH st))`;


(*val store_assign : forall 'a. nat -> store_v 'a -> store 'a -> maybe (store 'a)*)
val _ = Define `
 (store_assign n v st=
 (if (n < LENGTH st) /\
     store_v_same_type (EL n st) v
  then
    SOME (LUPDATE v n st)
  else
    NONE))`;


val _ = Hol_datatype `
(*  'ffi *) state =
  <| clock : num
   ; refs  : v store
   ; ffi : 'ffi ffi_state
   ; defined_types : tid_or_exn set
   ; defined_mods : ( modN list) set
   |>`;


(* Other primitives *)
(* Check that a constructor is properly applied *)
(*val do_con_check : env_ctor -> maybe (id modN conN) -> nat -> bool*)
val _ = Define `
 (do_con_check cenv n_opt l=
 ((case n_opt of
      NONE => T
    | SOME n =>
        (case nsLookup cenv n of
            NONE => F
          | SOME (l',ns) => l = l'
        )
  )))`;


(*val build_conv : env_ctor -> maybe (id modN conN) -> list v -> maybe v*)
val _ = Define `
 (build_conv envC cn vs=
 ((case cn of
      NONE =>
        SOME (Conv NONE vs)
    | SOME id =>
        (case nsLookup envC id of
            NONE => NONE
          | SOME (len,t) => SOME (Conv (SOME (id_to_n id, t)) vs)
        )
  )))`;


(*val lit_same_type : lit -> lit -> bool*)
val _ = Define `
 (lit_same_type l1 l2=
 ((case (l1,l2) of
      (IntLit _, IntLit _) => T
    | (Char _, Char _) => T
    | (StrLit _, StrLit _) => T
    | (Word8 _, Word8 _) => T
    | (Word64 _, Word64 _) => T
    | _ => F
  )))`;


val _ = Hol_datatype `
 match_result =
    No_match
  | Match_type_error
  | Match of 'a`;


(*val same_tid : tid_or_exn -> tid_or_exn -> bool*)
 val _ = Define `
 (same_tid (TypeId tn1) (TypeId tn2)=  (tn1 = tn2))
/\ (same_tid (TypeExn _) (TypeExn _)=  T)
/\ (same_tid _ _=  F)`;


(*val same_ctor : conN * tid_or_exn -> conN * tid_or_exn -> bool*)
 val _ = Define `
 (same_ctor (cn1, TypeExn mn1) (cn2, TypeExn mn2)=  ((cn1 = cn2) /\ (mn1 = mn2)))
/\ (same_ctor (cn1, _) (cn2, _)=  (cn1 = cn2))`;


(*val ctor_same_type : maybe (conN * tid_or_exn) -> maybe (conN * tid_or_exn) -> bool*)
val _ = Define `
 (ctor_same_type c1 c2=
 ((case (c1,c2) of
      (NONE, NONE) => T
    | (SOME (_,t1), SOME (_,t2)) => same_tid t1 t2
    | _ => F
  )))`;


(* A big-step pattern matcher.  If the value matches the pattern, return an
 * environment with the pattern variables bound to the corresponding sub-terms
 * of the value; this environment extends the environment given as an argument.
 * No_match is returned when there is no match, but any constructors
 * encountered in determining the match failure are applied to the correct
 * number of arguments, and constructors in corresponding positions in the
 * pattern and value come from the same type.  Match_type_error is returned
 * when one of these conditions is violated *)
(*val pmatch : env_ctor -> store v -> pat -> v -> alist varN v -> match_result (alist varN v)*)
 val pmatch_defn = Defn.Hol_multi_defns `

(pmatch envC s Pany v' env=  (Match env))
/\
(pmatch envC s (Pvar x) v' env=  (Match ((x,v')::env)))
/\
(pmatch envC s (Plit l) (Litv l') env=
 (if l = l' then
    Match env
  else if lit_same_type l l' then
    No_match
  else
    Match_type_error))
/\
(pmatch envC s (Pcon (SOME n) ps) (Conv (SOME (n', t')) vs) env=
 ((case nsLookup envC n of
      SOME (l, t) =>
        if same_tid t t' /\ (LENGTH ps = l) then
          if same_ctor (id_to_n n, t) (n',t') then
            pmatch_list envC s ps vs env
          else
            No_match
        else
          Match_type_error
    | _ => Match_type_error
  )))
/\
(pmatch envC s (Pcon NONE ps) (Conv NONE vs) env=
 (if LENGTH ps = LENGTH vs then
    pmatch_list envC s ps vs env
  else
    Match_type_error))
/\
(pmatch envC s (Pref p) (Loc lnum) env=
 ((case store_lookup lnum s of
      SOME (Refv v) => pmatch envC s p v env
    | SOME _ => Match_type_error
    | NONE => Match_type_error
  )))
/\
(pmatch envC s (Ptannot p t) v env=
 (pmatch envC s p v env))
/\
(pmatch envC _ _ _ env=  Match_type_error)
/\
(pmatch_list envC s [] [] env=  (Match env))
/\
(pmatch_list envC s (p::ps) (v::vs) env=
 ((case pmatch envC s p v env of
      No_match => No_match
    | Match_type_error => Match_type_error
    | Match env' => pmatch_list envC s ps vs env'
  )))
/\
(pmatch_list envC s _ _ env=  Match_type_error)`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) (List.map Defn.save_defn) pmatch_defn;

(* Bind each function of a mutually recursive set of functions to its closure *)
(*val build_rec_env : list (varN * varN * exp) -> sem_env v -> env_val -> env_val*)
val _ = Define `
 (build_rec_env funs cl_env add_to_env=
 (FOLDR
    (\ (f,x,e) env' .  nsBind f (Recclosure cl_env funs f) env')
    add_to_env
    funs))`;


(* Lookup in the list of mutually recursive functions *)
(*val find_recfun : forall 'a 'b. varN -> list (varN * 'a * 'b) -> maybe ('a * 'b)*)
 val _ = Define `
 (find_recfun n funs=
 ((case funs of
      [] => NONE
    | (f,x,e) :: funs =>
        if f = n then
          SOME (x,e)
        else
          find_recfun n funs
  )))`;


val _ = Hol_datatype `
 eq_result =
    Eq_val of bool
  | Eq_type_error`;


(*val do_eq : v -> v -> eq_result*)
 val do_eq_defn = Defn.Hol_multi_defns `

(do_eq (Litv l1) (Litv l2)=
 (if lit_same_type l1 l2 then Eq_val (l1 = l2)
  else Eq_type_error))
/\
(do_eq (Loc l1) (Loc l2)=  (Eq_val (l1 = l2)))
/\
(do_eq (Conv cn1 vs1) (Conv cn2 vs2)=
 (if (cn1 = cn2) /\ (LENGTH vs1 = LENGTH vs2) then
    do_eq_list vs1 vs2
  else if ctor_same_type cn1 cn2 then
    Eq_val F
  else
    Eq_type_error))
/\
(do_eq (Vectorv vs1) (Vectorv vs2)=
 (if LENGTH vs1 = LENGTH vs2 then
    do_eq_list vs1 vs2
  else
    Eq_val F))
/\
(do_eq (Closure _ _ _) (Closure _ _ _)=  (Eq_val T))
/\
(do_eq (Closure _ _ _) (Recclosure _ _ _)=  (Eq_val T))
/\
(do_eq (Recclosure _ _ _) (Closure _ _ _)=  (Eq_val T))
/\
(do_eq (Recclosure _ _ _) (Recclosure _ _ _)=  (Eq_val T))
/\
(do_eq _ _=  Eq_type_error)
/\
(do_eq_list [] []=  (Eq_val T))
/\
(do_eq_list (v1::vs1) (v2::vs2)=
 ((case do_eq v1 v2 of
      Eq_type_error => Eq_type_error
    | Eq_val r =>
        if ~ r then
          Eq_val F
        else
          do_eq_list vs1 vs2
  )))
/\
(do_eq_list _ _=  (Eq_val F))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) (List.map Defn.save_defn) do_eq_defn;

(*val prim_exn : conN -> v*)
val _ = Define `
 (prim_exn cn=  (Conv (SOME (cn, TypeExn (Short cn))) []))`;


(* Do an application *)
(*val do_opapp : list v -> maybe (sem_env v * exp)*)
val _ = Define `
 (do_opapp vs=
 ((case vs of
    [Closure env n e; v] =>
      SOME (( env with<| v := (nsBind n v env.v) |>), e)
  | [Recclosure env funs n; v] =>
      if ALL_DISTINCT (MAP (\ (f,x,e) .  f) funs) then
        (case find_recfun n funs of
            SOME (n,e) => SOME (( env with<| v := (nsBind n v (build_rec_env funs env env.v)) |>), e)
          | NONE => NONE
        )
      else
        NONE
  | _ => NONE
  )))`;


(* If a value represents a list, get that list. Otherwise return Nothing *)
(*val v_to_list : v -> maybe (list v)*)
 val v_to_list_defn = Defn.Hol_multi_defns `
 (v_to_list (Conv (SOME (cn, TypeId (Short tn))) [])=
 (if (cn = "nil") /\ (tn = "list") then
    SOME []
  else
    NONE))
/\ (v_to_list (Conv (SOME (cn,TypeId (Short tn))) [v1;v2])=
 (if (cn = "::")  /\ (tn = "list") then
    (case v_to_list v2 of
        SOME vs => SOME (v1::vs)
      | NONE => NONE
    )
  else
    NONE))
/\ (v_to_list _=  NONE)`;

val list_to_v_def = Define `
  list_to_v []      = Conv (SOME ("nil", TypeId (Short "list"))) [] /\
  list_to_v (x::xs) = Conv (SOME ("::", TypeId (Short "list"))) [x; list_to_v xs]
  `;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) (List.map Defn.save_defn) v_to_list_defn;

(*val v_to_char_list : v -> maybe (list char)*)
 val v_to_char_list_defn = Defn.Hol_multi_defns `
 (v_to_char_list (Conv (SOME (cn, TypeId (Short tn))) [])=
 (if (cn = "nil") /\ (tn = "list") then
    SOME []
  else
    NONE))
/\ (v_to_char_list (Conv (SOME (cn,TypeId (Short tn))) [Litv (Char c);v])=
 (if (cn = "::")  /\ (tn = "list") then
    (case v_to_char_list v of
        SOME cs => SOME (c::cs)
      | NONE => NONE
    )
  else
    NONE))
/\ (v_to_char_list _=  NONE)`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) (List.map Defn.save_defn) v_to_char_list_defn;

(*val vs_to_string : list v -> maybe string*)
 val vs_to_string_defn = Defn.Hol_multi_defns `
 (vs_to_string []=  (SOME ""))
/\ (vs_to_string (Litv(StrLit s1)::vs)=
 ((case vs_to_string vs of
    SOME s2 => SOME ( STRCAT s1 s2)
  | _ => NONE
  )))
/\ (vs_to_string _=  NONE)`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) (List.map Defn.save_defn) vs_to_string_defn;

(*val copy_array : forall 'a. list 'a * integer -> integer -> maybe (list 'a * integer) -> maybe (list 'a)*)
val _ = Define `
 (copy_array (src,srcoff) len d=
 (if (srcoff <( 0 : int)) \/ ((len <( 0 : int)) \/ (LENGTH src < Num (ABS (I (srcoff + len))))) then NONE else
    let copied = (TAKE (Num (ABS (I len))) (DROP (Num (ABS (I srcoff))) src)) in
    (case d of
      SOME (dst,dstoff) =>
        if (dstoff <( 0 : int)) \/ (LENGTH dst < Num (ABS (I (dstoff + len)))) then NONE else
          SOME ((TAKE (Num (ABS (I dstoff))) dst ++
                copied) ++
                DROP (Num (ABS (I (dstoff + len)))) dst)
    | NONE => SOME copied
    )))`;


(*val ws_to_chars : list word8 -> list char*)
val _ = Define `
 (ws_to_chars ws=  (MAP (\ w .  CHR(w2n w)) ws))`;


(*val chars_to_ws : list char -> list word8*)
val _ = Define `
 (chars_to_ws cs=  (MAP (\ c .  i2w(int_of_num(ORD c))) cs))`;


(*val opn_lookup : opn -> integer -> integer -> integer*)
val _ = Define `
 (opn_lookup n : int -> int -> int=  ((case n of
    Plus => (+)
  | Minus => (-)
  | Times => ( * )
  | Divide => (/)
  | Modulo => (%)
)))`;


(*val opb_lookup : opb -> integer -> integer -> bool*)
val _ = Define `
 (opb_lookup n : int -> int -> bool=  ((case n of
    Lt => (<)
  | Gt => (>)
  | Leq => (<=)
  | Geq => (>=)
)))`;


(*val opw8_lookup : opw -> word8 -> word8 -> word8*)
val _ = Define `
 (opw8_lookup op=  ((case op of
    Andw => word_and
  | Orw => word_or
  | Xor => word_xor
  | Add => word_add
  | Sub => word_sub
)))`;


(*val opw64_lookup : opw -> word64 -> word64 -> word64*)
val _ = Define `
 (opw64_lookup op=  ((case op of
    Andw => word_and
  | Orw => word_or
  | Xor => word_xor
  | Add => word_add
  | Sub => word_sub
)))`;


(*val shift8_lookup : shift -> word8 -> nat -> word8*)
val _ = Define `
 (shift8_lookup sh=  ((case sh of
    Lsl => word_lsl
  | Lsr => word_lsr
  | Asr => word_asr
  | Ror => word_ror
)))`;


(*val shift64_lookup : shift -> word64 -> nat -> word64*)
val _ = Define `
 (shift64_lookup sh=  ((case sh of
    Lsl => word_lsl
  | Lsr => word_lsr
  | Asr => word_asr
  | Ror => word_ror
)))`;


(*val Boolv : bool -> v*)
val _ = Define `
 (Boolv b=  (if b
  then Conv (SOME ("true", TypeId (Short "bool"))) []
  else Conv (SOME ("false", TypeId (Short "bool"))) []))`;


val _ = Hol_datatype `
 exp_or_val =
    Exp of exp
  | Val of v`;


val _ = type_abbrev((* ( 'ffi, 'v) *) "store_ffi" , ``: 'v store # 'ffi ffi_state``);

(*val do_app : forall 'ffi. store_ffi 'ffi v -> op -> list v -> maybe (store_ffi 'ffi v * result v v)*)
val _ = Define `
 (do_app ((s: v store),(t: 'ffi ffi_state)) op vs=
 ((case (op, vs) of
      (ListAppend, [x1; x2]) =>
        (case (v_to_list x1, v_to_list x2) of
           (SOME xs, SOME ys) => SOME ((s,t), Rval (list_to_v (xs++ys)))
         | _ => NONE)
    | (Opn op, [Litv (IntLit n1); Litv (IntLit n2)]) =>
        if ((op = Divide) \/ (op = Modulo)) /\ (n2 =( 0 : int)) then
          SOME ((s,t), Rerr (Rraise (prim_exn "Div")))
        else
          SOME ((s,t), Rval (Litv (IntLit (opn_lookup op n1 n2))))
    | (Opb op, [Litv (IntLit n1); Litv (IntLit n2)]) =>
        SOME ((s,t), Rval (Boolv (opb_lookup op n1 n2)))
    | (Opw W8 op, [Litv (Word8 w1); Litv (Word8 w2)]) =>
        SOME ((s,t), Rval (Litv (Word8 (opw8_lookup op w1 w2))))
    | (Opw W64 op, [Litv (Word64 w1); Litv (Word64 w2)]) =>
        SOME ((s,t), Rval (Litv (Word64 (opw64_lookup op w1 w2))))
    | (FP_bop bop, [Litv (Word64 w1); Litv (Word64 w2)]) =>
        SOME ((s,t),Rval (Litv (Word64 (fp_bop bop w1 w2))))
    | (FP_uop uop, [Litv (Word64 w)]) =>
        SOME ((s,t),Rval (Litv (Word64 (fp_uop uop w))))
    | (FP_cmp cmp, [Litv (Word64 w1); Litv (Word64 w2)]) =>
        SOME ((s,t),Rval (Boolv (fp_cmp cmp w1 w2)))
    | (Shift W8 op n, [Litv (Word8 w)]) =>
        SOME ((s,t), Rval (Litv (Word8 (shift8_lookup op w n))))
    | (Shift W64 op n, [Litv (Word64 w)]) =>
        SOME ((s,t), Rval (Litv (Word64 (shift64_lookup op w n))))
    | (Equality, [v1; v2]) =>
        (case do_eq v1 v2 of
            Eq_type_error => NONE
          | Eq_val b => SOME ((s,t), Rval (Boolv b))
        )
    | (Opassign, [Loc lnum; v]) =>
        (case store_assign lnum (Refv v) s of
            SOME s' => SOME ((s',t), Rval (Conv NONE []))
          | NONE => NONE
        )
    | (Opref, [v]) =>
        let (s',n) = (store_alloc (Refv v) s) in
          SOME ((s',t), Rval (Loc n))
    | (Opderef, [Loc n]) =>
        (case store_lookup n s of
            SOME (Refv v) => SOME ((s,t),Rval v)
          | _ => NONE
        )
    | (Aw8alloc, [Litv (IntLit n); Litv (Word8 w)]) =>
        if n <( 0 : int) then
          SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
        else
          let (s',lnum) =
(store_alloc (W8array (REPLICATE (Num (ABS (I n))) w)) s)
          in
            SOME ((s',t), Rval (Loc lnum))
    | (Aw8sub, [Loc lnum; Litv (IntLit i)]) =>
        (case store_lookup lnum s of
            SOME (W8array ws) =>
              if i <( 0 : int) then
                SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
              else
                let n = (Num (ABS (I i))) in
                  if n >= LENGTH ws then
                    SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
                  else
                    SOME ((s,t), Rval (Litv (Word8 (EL n ws))))
          | _ => NONE
        )
    | (Aw8length, [Loc n]) =>
        (case store_lookup n s of
            SOME (W8array ws) =>
              SOME ((s,t),Rval (Litv(IntLit(int_of_num(LENGTH ws)))))
          | _ => NONE
         )
    | (Aw8update, [Loc lnum; Litv(IntLit i); Litv(Word8 w)]) =>
        (case store_lookup lnum s of
          SOME (W8array ws) =>
            if i <( 0 : int) then
              SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
            else
              let n = (Num (ABS (I i))) in
                if n >= LENGTH ws then
                  SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
                else
                  (case store_assign lnum (W8array (LUPDATE w n ws)) s of
                      NONE => NONE
                    | SOME s' => SOME ((s',t), Rval (Conv NONE []))
                  )
        | _ => NONE
      )
    | (WordFromInt W8, [Litv(IntLit i)]) =>
        SOME ((s,t), Rval (Litv (Word8 (i2w i))))
    | (WordFromInt W64, [Litv(IntLit i)]) =>
        SOME ((s,t), Rval (Litv (Word64 (i2w i))))
    | (WordToInt W8, [Litv (Word8 w)]) =>
        SOME ((s,t), Rval (Litv (IntLit (int_of_num(w2n w)))))
    | (WordToInt W64, [Litv (Word64 w)]) =>
        SOME ((s,t), Rval (Litv (IntLit (int_of_num(w2n w)))))
    | (CopyStrStr, [Litv(StrLit str);Litv(IntLit off);Litv(IntLit len)]) =>
        SOME ((s,t),
        (case copy_array (EXPLODE str,off) len NONE of
          NONE => Rerr (Rraise (prim_exn "Subscript"))
        | SOME cs => Rval (Litv(StrLit(IMPLODE(cs))))
        ))
    | (CopyStrAw8, [Litv(StrLit str);Litv(IntLit off);Litv(IntLit len);
                    Loc dst;Litv(IntLit dstoff)]) =>
        (case store_lookup dst s of
          SOME (W8array ws) =>
            (case copy_array (EXPLODE str,off) len (SOME(ws_to_chars ws,dstoff)) of
              NONE => SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
            | SOME cs =>
              (case store_assign dst (W8array (chars_to_ws cs)) s of
                SOME s' =>  SOME ((s',t), Rval (Conv NONE []))
              | _ => NONE
              )
            )
        | _ => NONE
        )
    | (CopyAw8Str, [Loc src;Litv(IntLit off);Litv(IntLit len)]) =>
      (case store_lookup src s of
        SOME (W8array ws) =>
        SOME ((s,t),
          (case copy_array (ws,off) len NONE of
            NONE => Rerr (Rraise (prim_exn "Subscript"))
          | SOME ws => Rval (Litv(StrLit(IMPLODE(ws_to_chars ws))))
          ))
      | _ => NONE
      )
    | (CopyAw8Aw8, [Loc src;Litv(IntLit off);Litv(IntLit len);
                    Loc dst;Litv(IntLit dstoff)]) =>
      (case (store_lookup src s, store_lookup dst s) of
        (SOME (W8array ws), SOME (W8array ds)) =>
          (case copy_array (ws,off) len (SOME(ds,dstoff)) of
            NONE => SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
          | SOME ws =>
              (case store_assign dst (W8array ws) s of
                SOME s' => SOME ((s',t), Rval (Conv NONE []))
              | _ => NONE
              )
          )
      | _ => NONE
      )
    | (Ord, [Litv (Char c)]) =>
          SOME ((s,t), Rval (Litv(IntLit(int_of_num(ORD c)))))
    | (Chr, [Litv (IntLit i)]) =>
        SOME ((s,t),
(if (i <( 0 : int)) \/ (i >( 255 : int)) then
            Rerr (Rraise (prim_exn "Chr"))
          else
            Rval (Litv(Char(CHR(Num (ABS (I i))))))))
    | (Chopb op, [Litv (Char c1); Litv (Char c2)]) =>
        SOME ((s,t), Rval (Boolv (opb_lookup op (int_of_num(ORD c1)) (int_of_num(ORD c2)))))
    | (Implode, [v]) =>
          (case v_to_char_list v of
            SOME ls =>
              SOME ((s,t), Rval (Litv (StrLit (IMPLODE ls))))
          | NONE => NONE
          )
    | (Strsub, [Litv (StrLit str); Litv (IntLit i)]) =>
        if i <( 0 : int) then
          SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
        else
          let n = (Num (ABS (I i))) in
            if n >= STRLEN str then
              SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
            else
              SOME ((s,t), Rval (Litv (Char (EL n (EXPLODE str)))))
    | (Strlen, [Litv (StrLit str)]) =>
        SOME ((s,t), Rval (Litv(IntLit(int_of_num(STRLEN str)))))
    | (Strcat, [v]) =>
        (case v_to_list v of
          SOME vs =>
            (case vs_to_string vs of
              SOME str =>
                SOME ((s,t), Rval (Litv(StrLit str)))
            | _ => NONE
            )
        | _ => NONE
        )
    | (VfromList, [v]) =>
          (case v_to_list v of
              SOME vs =>
                SOME ((s,t), Rval (Vectorv vs))
            | NONE => NONE
          )
    | (Vsub, [Vectorv vs; Litv (IntLit i)]) =>
        if i <( 0 : int) then
          SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
        else
          let n = (Num (ABS (I i))) in
            if n >= LENGTH vs then
              SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
            else
              SOME ((s,t), Rval (EL n vs))
    | (Vlength, [Vectorv vs]) =>
        SOME ((s,t), Rval (Litv (IntLit (int_of_num (LENGTH vs)))))
    | (Aalloc, [Litv (IntLit n); v]) =>
        if n <( 0 : int) then
          SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
        else
          let (s',lnum) =
(store_alloc (Varray (REPLICATE (Num (ABS (I n))) v)) s)
          in
            SOME ((s',t), Rval (Loc lnum))
    | (AallocEmpty, [Conv NONE []]) =>
        let (s',lnum) = (store_alloc (Varray []) s) in
          SOME ((s',t), Rval (Loc lnum))
    | (Asub, [Loc lnum; Litv (IntLit i)]) =>
        (case store_lookup lnum s of
            SOME (Varray vs) =>
              if i <( 0 : int) then
                SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
              else
                let n = (Num (ABS (I i))) in
                  if n >= LENGTH vs then
                    SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
                  else
                    SOME ((s,t), Rval (EL n vs))
          | _ => NONE
        )
    | (Alength, [Loc n]) =>
        (case store_lookup n s of
            SOME (Varray ws) =>
              SOME ((s,t),Rval (Litv(IntLit(int_of_num(LENGTH ws)))))
          | _ => NONE
         )
    | (Aupdate, [Loc lnum; Litv (IntLit i); v]) =>
        (case store_lookup lnum s of
          SOME (Varray vs) =>
            if i <( 0 : int) then
              SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
            else
              let n = (Num (ABS (I i))) in
                if n >= LENGTH vs then
                  SOME ((s,t), Rerr (Rraise (prim_exn "Subscript")))
                else
                  (case store_assign lnum (Varray (LUPDATE v n vs)) s of
                      NONE => NONE
                    | SOME s' => SOME ((s',t), Rval (Conv NONE []))
                  )
        | _ => NONE
      )
    | (FFI n, [Litv(StrLit conf); Loc lnum]) =>
        (case store_lookup lnum s of
          SOME (W8array ws) =>
            (case call_FFI t n (MAP (\ c .  n2w(ORD c)) (EXPLODE conf)) ws of
              (t', ws') =>
               (case store_assign lnum (W8array ws') s of
                 SOME s' => SOME ((s', t'), Rval (Conv NONE []))
               | NONE => NONE
               )
            )
        | _ => NONE
        )
    | _ => NONE
  )))`;


(* Do a logical operation *)
(*val do_log : lop -> v -> exp -> maybe exp_or_val*)
val _ = Define `
 (do_log l v e=
 ((case (l, v) of
      (And, Conv (SOME ("true", TypeId (Short "bool"))) []) => SOME (Exp e)
    | (Or, Conv (SOME ("false", TypeId (Short "bool"))) []) => SOME (Exp e)
    | (_, Conv (SOME ("true", TypeId (Short "bool"))) []) => SOME (Val v)
    | (_, Conv (SOME ("false", TypeId (Short "bool"))) []) => SOME (Val v)
    | _ => NONE
  )))`;


(* Do an if-then-else *)
(*val do_if : v -> exp -> exp -> maybe exp*)
val _ = Define `
 (do_if v e1 e2=
 (if v = (Boolv T) then
    SOME e1
  else if v = (Boolv F) then
    SOME e2
  else
    NONE))`;


(* Semantic helpers for definitions *)

(* Build a constructor environment for the type definition tds *)
(*val build_tdefs : list modN -> list (list tvarN * typeN * list (conN * list t)) -> env_ctor*)
val _ = Define `
 (build_tdefs mn tds=
 (alist_to_ns
    (REVERSE
      (FLAT
        (MAP
          (\ (tvs, tn, condefs) .
             MAP
               (\ (conN, ts) .
                  (conN, (LENGTH ts, TypeId (mk_id mn tn))))
               condefs)
          tds)))))`;


(* Checks that no constructor is defined twice in a type *)
(*val check_dup_ctors : list (list tvarN * typeN * list (conN * list t)) -> bool*)
val _ = Define `
 (check_dup_ctors tds=
 (ALL_DISTINCT (let x2 =
  ([]) in  FOLDR
   (\(tvs, tn, condefs) x2 .  FOLDR
                                (\(n, ts) x2 .  if T then n :: x2 else x2)
                              x2 condefs) x2 tds)))`;


(*val combine_dec_result : forall 'a. sem_env v -> result (sem_env v) 'a -> result (sem_env v) 'a*)
val _ = Define `
 (combine_dec_result env r=
 ((case r of
      Rerr e => Rerr e
    | Rval env' => Rval <| v := (nsAppend env'.v env.v); c := (nsAppend env'.c env.c) |>
  )))`;


(*val extend_dec_env : sem_env v -> sem_env v -> sem_env v*)
val _ = Define `
 (extend_dec_env new_env env=
 (<| c := (nsAppend new_env.c env.c); v := (nsAppend new_env.v env.v) |>))`;


(*val decs_to_types : list dec -> list typeN*)
val _ = Define `
 (decs_to_types ds=
 (FLAT (MAP (\ d .
        (case d of
            Dtype locs tds => MAP (\ (tvs,tn,ctors) .  tn) tds
          | _ => [] ))
     ds)))`;


(*val no_dup_types : list dec -> bool*)
val _ = Define `
 (no_dup_types ds=
 (ALL_DISTINCT (decs_to_types ds)))`;


(*val prog_to_mods : list top -> list (list modN)*)
val _ = Define `
 (prog_to_mods tops=
 (FLAT (MAP (\ top .
        (case top of
            Tmod mn _ _ => [[mn]]
          | _ => [] ))
     tops)))`;


(*val no_dup_mods : list top -> set (list modN) -> bool*)
val _ = Define `
 (no_dup_mods tops defined_mods=
 (ALL_DISTINCT (prog_to_mods tops) /\
  DISJOINT (LIST_TO_SET (prog_to_mods tops)) defined_mods))`;


(*val prog_to_top_types : list top -> list typeN*)
val _ = Define `
 (prog_to_top_types tops=
 (FLAT (MAP (\ top .
        (case top of
            Tdec d => decs_to_types [d]
          | _ => [] ))
     tops)))`;


(*val no_dup_top_types : list top -> set tid_or_exn -> bool*)
val _ = Define `
 (no_dup_top_types tops defined_types=
 (ALL_DISTINCT (prog_to_top_types tops) /\
  DISJOINT (LIST_TO_SET (MAP (\ tn .  TypeId (Short tn)) (prog_to_top_types tops))) defined_types))`;

val _ = export_theory()

