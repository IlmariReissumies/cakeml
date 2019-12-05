(*
  The abstract syntax of Pancake language
*)

open preamble
     asmTheory (* for binop and cmp *)
     backend_commonTheory (* for overloading the shift operation  *);

val _ = new_theory "panLang";

Type shift = ``:ast$shift``

val _ = Datatype `
  exp = Const ('a word)
      | Var num        (* TOASK: num is fine for variable names? *)
      | Loc num        (* destination of call *)
      | Load exp
      | LoadByte exp
      | Op binop (exp list)
      | Shift shift exp num`


Theorem MEM_IMP_exp_size:
   !xs a. MEM a xs ==> (exp_size l a < exp1_size l xs)
Proof
  Induct \\ FULL_SIMP_TAC (srw_ss()) []
  \\ REPEAT STRIP_TAC \\ SRW_TAC [] [definition"exp_size_def"]
  \\ RES_TAC \\ DECIDE_TAC
QED

val _ = Datatype `
  bexp = Bconst bool
       | Bcomp cmp ('a exp) ('a exp)
       | Bbinop (bool -> bool -> bool) bexp bexp (* TOASK: should we have Bbinop? *)
       | Bnot bexp` (* TOASK: should we have Bnot? *)

val _ = Datatype `
  ret = NoRet
      | Ret num
      | Handle num num` (* what are these nums?  *)

(*
val _ = Datatype `
  var_imm = Str num
          | Imm ('a word)`
*)

 (*  | Call (num option)
              (* return var *)
              (num option) (* target of call *)
              (num list) (* arguments *)
              ((num # panLang$prog) option)
              (* handler: var to store exception (number?), exception-handler code *) *)


val _ = Datatype `
  prog = Skip
       | Assign    ('a exp) ('a exp)
       | Store     ('a exp) ('a exp)
       | StoreByte ('a exp) ('a exp)
       | Seq panLang$prog panLang$prog
       | If    ('a bexp) panLang$prog panLang$prog
       | While ('a bexp) panLang$prog
       | Break
       | Continue
       | Call ret (panLang$prog option) ('a exp) (('a exp) list)
   (*  | Handle panLang$prog (num # panLang$prog)  (* not sure about num right now *) *)
       | Raise num
       | Return num
       | Tick
       | FFI string num num num num num_set (* FFI name, conf_ptr, conf_len, array_ptr, array_len, cut-set *) `;
         (* num_set is abbreviation for unit num_map *)


(* op:asm$binop  *)
val word_op_def = Define `
  word_op op (ws:('a word) list) =
    case (op,ws) of
    | (And,ws) => SOME (FOLDR word_and (¬0w) ws)
    | (Add,ws) => SOME (FOLDR word_add 0w ws)
    | (Or,ws) => SOME (FOLDR word_or 0w ws)
    | (Xor,ws) => SOME (FOLDR word_xor 0w ws)
    | (Sub,[w1;w2]) => SOME (w1 - w2)
    | _ => NONE`;


(* sh:ast$shift  *)
val word_sh_def = Define `
  word_sh sh (w:'a word) n =
    if n <> 0 /\ n ≥ dimindex (:'a) then NONE else
      case sh of
      | Lsl => SOME (w << n)
      | Lsr => SOME (w >>> n)
      | Asr => SOME (w >> n)
      | Ror => SOME (word_ror w n)`;

Overload shift = “backend_common$word_shift”

val _ = export_theory();
