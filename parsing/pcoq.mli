(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2015     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

open Loc
open Names
open Extend
open Vernacexpr
open Genarg
open Constrexpr
open Tacexpr
open Libnames
open Misctypes
open Genredexpr

(** The parser of Coq *)

module Gram : Compat.GrammarSig

(** The parser of Coq is built from three kinds of rule declarations:

   - dynamic rules declared at the evaluation of Coq files (using
     e.g. Notation, Infix, or Tactic Notation)
   - static rules explicitly defined in files g_*.ml4
   - static rules macro-generated by ARGUMENT EXTEND, TACTIC EXTEND and
     VERNAC EXTEND (see e.g. file extratactics.ml4)
*)

(** Dynamic extension of rules

    For constr notations, dynamic addition of new rules is done in
    several steps:

    - "x + y" (user gives a notation string of type Topconstr.notation)
        |     (together with a constr entry level, e.g. 50, and indications of)
        |     (subentries, e.g. x in constr next level and y constr same level)
        |
        | spliting into tokens by Metasyntax.split_notation_string
        V
      [String "x"; String "+"; String "y"] : symbol_token list
        |
        | interpreted as a mixed parsing/printing production
        | by Metasyntax.analyse_notation_tokens
        V
      [NonTerminal "x"; Terminal "+"; NonTerminal "y"] : symbol list
        |
        | translated to a parsing production by Metasyntax.make_production
        V
      [GramConstrNonTerminal (ETConstr (NextLevel,(BorderProd Left,LeftA)),
                              Some "x");
       GramConstrTerminal ("","+");
       GramConstrNonTerminal (ETConstr (NextLevel,(BorderProd Right,LeftA)),
                              Some "y")]
       : grammar_constr_prod_item list
        |
        | Egrammar.make_constr_prod_item
        V
      Gramext.g_symbol list which is sent to camlp4

    For user level tactic notations, dynamic addition of new rules is
    also done in several steps:

    - "f" constr(x) (user gives a Tactic Notation command)
        |
        | parsing
        V
      [TacTerm "f"; TacNonTerm ("constr", Some "x")]
      : grammar_tactic_prod_item_expr list
        |
        | Metasyntax.interp_prod_item
        V
      [GramTerminal "f";
       GramNonTerminal (ConstrArgType, Aentry ("constr","constr"), Some "x")]
      : grammar_prod_item list
        |
        | Egrammar.make_prod_item
        V
      Gramext.g_symbol list

    For TACTIC/VERNAC/ARGUMENT EXTEND, addition of new rules is done as follows:

    - "f" constr(x) (developer gives an EXTEND rule)
        |
        | macro-generation in tacextend.ml4/vernacextend.ml4/argextend.ml4
        V
      [GramTerminal "f";
       GramNonTerminal (ConstrArgType, Aentry ("constr","constr"), Some "x")]
        |
        | Egrammar.make_prod_item
        V
      Gramext.g_symbol list

*)

val gram_token_of_token : Tok.t -> Gram.symbol
val gram_token_of_string : string -> Gram.symbol

(** The superclass of all grammar entries *)
type grammar_object

(** Type of reinitialization data *)
type gram_reinit = gram_assoc * gram_position

(** Add one extension at some camlp4 position of some camlp4 entry *)
val grammar_extend :
  grammar_object Gram.entry ->
  gram_reinit option (** for reinitialization if ever needed *) ->
  Gram.extend_statment -> unit

(** Remove the last n extensions *)
val remove_grammars : int -> unit




(** The type of typed grammar objects *)
type typed_entry

(** The possible types for extensible grammars *)
type entry_type = argument_type

val type_of_typed_entry : typed_entry -> entry_type
val object_of_typed_entry : typed_entry -> grammar_object Gram.entry
val weaken_entry : 'a Gram.entry -> grammar_object Gram.entry

(** Temporary activate camlp4 verbosity *)

val camlp4_verbosity : bool -> ('a -> unit) -> 'a -> unit

(** Parse a string *)

val parse_string : 'a Gram.entry -> string -> 'a
val eoi_entry : 'a Gram.entry -> 'a Gram.entry
val map_entry : ('a -> 'b) -> 'a Gram.entry -> 'b Gram.entry

(** Table of Coq statically defined grammar entries *)

type gram_universe

(** There are four predefined universes: "prim", "constr", "tactic", "vernac" *)

val get_univ : string -> gram_universe

val uprim : gram_universe
val uconstr : gram_universe
val utactic : gram_universe
val uvernac : gram_universe

val create_entry : gram_universe -> string -> entry_type -> typed_entry
val create_generic_entry : string -> ('a, rlevel) abstract_argument_type ->
  'a Gram.entry

module Prim :
  sig
    open Names
    open Libnames
    val preident : string Gram.entry
    val ident : Id.t Gram.entry
    val name : Name.t located Gram.entry
    val identref : Id.t located Gram.entry
    val pattern_ident : Id.t Gram.entry
    val pattern_identref : Id.t located Gram.entry
    val base_ident : Id.t Gram.entry
    val natural : int Gram.entry
    val bigint : Bigint.bigint Gram.entry
    val integer : int Gram.entry
    val string : string Gram.entry
    val qualid : qualid located Gram.entry
    val fullyqualid : Id.t list located Gram.entry
    val reference : reference Gram.entry
    val by_notation : (Loc.t * string * string option) Gram.entry
    val smart_global : reference or_by_notation Gram.entry
    val dirpath : DirPath.t Gram.entry
    val ne_string : string Gram.entry
    val ne_lstring : string located Gram.entry
    val var : Id.t located Gram.entry
  end

module Constr :
  sig
    val constr : constr_expr Gram.entry
    val constr_eoi : constr_expr Gram.entry
    val lconstr : constr_expr Gram.entry
    val binder_constr : constr_expr Gram.entry
    val operconstr : constr_expr Gram.entry
    val ident : Id.t Gram.entry
    val global : reference Gram.entry
    val sort : glob_sort Gram.entry
    val pattern : cases_pattern_expr Gram.entry
    val constr_pattern : constr_expr Gram.entry
    val lconstr_pattern : constr_expr Gram.entry
    val closed_binder : local_binder list Gram.entry
    val binder : local_binder list Gram.entry (* closed_binder or variable *)
    val binders : local_binder list Gram.entry (* list of binder *)
    val open_binders : local_binder list Gram.entry
    val binders_fixannot : (local_binder list * (Id.t located option * recursion_order_expr)) Gram.entry
    val typeclass_constraint : (Name.t located * bool * constr_expr) Gram.entry
    val record_declaration : constr_expr Gram.entry
    val appl_arg : (constr_expr * explicitation located option) Gram.entry
  end

module Module :
  sig
    val module_expr : module_ast Gram.entry
    val module_type : module_ast Gram.entry
  end

module Tactic :
  sig
    val open_constr : open_constr_expr Gram.entry
    val constr_with_bindings : constr_expr with_bindings Gram.entry
    val bindings : constr_expr bindings Gram.entry
    val hypident : (Id.t located * Locus.hyp_location_flag) Gram.entry
    val constr_may_eval : (constr_expr,reference or_by_notation,constr_expr) may_eval Gram.entry
    val constr_eval : (constr_expr,reference or_by_notation,constr_expr) may_eval Gram.entry
    val uconstr : constr_expr Gram.entry
    val quantified_hypothesis : quantified_hypothesis Gram.entry
    val int_or_var : int or_var Gram.entry
    val red_expr : raw_red_expr Gram.entry
    val simple_tactic : raw_tactic_expr Gram.entry
    val simple_intropattern : constr_expr intro_pattern_expr located Gram.entry
    val clause_dft_concl : Names.Id.t Loc.located Locus.clause_expr Gram.entry
    val tactic_arg : raw_tactic_arg Gram.entry
    val tactic_expr : raw_tactic_expr Gram.entry
    val binder_tactic : raw_tactic_expr Gram.entry
    val tactic : raw_tactic_expr Gram.entry
    val tactic_eoi : raw_tactic_expr Gram.entry
    val tacdef_body : (reference * bool * raw_tactic_expr) Gram.entry
  end

module Vernac_ :
  sig
    val gallina : vernac_expr Gram.entry
    val gallina_ext : vernac_expr Gram.entry
    val command : vernac_expr Gram.entry
    val syntax : vernac_expr Gram.entry
    val vernac : vernac_expr Gram.entry
    val rec_definition : (fixpoint_expr * decl_notation list) Gram.entry
    val vernac_eoi : vernac_expr Gram.entry
  end

(** The main entry: reads an optional vernac command *)
val main_entry : (Loc.t * vernac_expr) option Gram.entry

(** Mapping formal entries into concrete ones *)

(** Binding constr entry keys to entries and symbols *)

val interp_constr_entry_key : bool (** true for cases_pattern *) ->
  constr_entry_key -> grammar_object Gram.entry * int option

val symbol_of_constr_prod_entry_key : gram_assoc option ->
  constr_entry_key -> bool -> constr_prod_entry_key ->
    Gram.symbol

(** General entry keys *)

(** This intermediate abstract representation of entries can
   both be reified into mlexpr for the ML extensions and
   dynamically interpreted as entries for the Coq level extensions
*)

type ('self, _) entry_key =
| Alist1 : ('self, 'a) entry_key -> ('self, 'a list) entry_key
| Alist1sep : ('self, 'a) entry_key * string -> ('self, 'a list) entry_key
| Alist0 : ('self, 'a) entry_key -> ('self, 'a list) entry_key
| Alist0sep : ('self, 'a) entry_key * string -> ('self, 'a list) entry_key
| Aopt : ('self, 'a) entry_key -> ('self, 'a option) entry_key
| Amodifiers : ('self, 'a) entry_key -> ('self, 'a list) entry_key
| Aself : ('self, 'self) entry_key
| Anext : ('self, 'self) entry_key
| Atactic : int -> ('self, raw_tactic_expr) entry_key
| Agram : string -> ('self, 'a) entry_key
| Aentry : string * string -> ('self, 'a) entry_key

(** Binding general entry keys to symbols *)

val symbol_of_prod_entry_key :
  ('self, 'a) entry_key -> Gram.symbol

type entry_name = EntryName : entry_type * ('self, 'a) entry_key -> entry_name

(** Interpret entry names of the form "ne_constr_list" as entry keys   *)

val interp_entry_name : bool (** true to fail on unknown entry *) ->
  int option -> string -> string -> entry_name

(** Recover the list of all known tactic notation entries. *)
val list_entry_names : unit -> (string * entry_type) list

(** Registering/resetting the level of a constr entry *)

val find_position :
  bool (** true if for creation in pattern entry; false if in constr entry *) ->
  Extend.gram_assoc option -> int option ->
    Extend.gram_position option * Extend.gram_assoc option * string option *
    (** for reinitialization: *) gram_reinit option

val synchronize_level_positions : unit -> unit

val register_empty_levels : bool -> int list ->
    (Extend.gram_position option * Extend.gram_assoc option *
     string option * gram_reinit option) list

val remove_levels : int -> unit

val level_of_snterml : Gram.symbol -> int
