(**
 * Copyright (c) 2016, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

module PositionedSyntax = Full_fidelity_positioned_syntax
module SyntaxUtilities =
  Full_fidelity_syntax_utilities.WithSyntax(PositionedSyntax)
module SyntaxError = Full_fidelity_syntax_error

open PositionedSyntax

type accumulator = {
  errors : SyntaxError.t list;
}

(* True or false: the first item in this list matches the predicate? *)
let matches_first f items =
  match items with
  | h :: _ when f h -> true
  | _ -> false

let parent_is_function parents =
  matches_first is_function parents

let parameter_errors node parents is_strict =
  (* TODO: We need the parent here; in strict mode it is legal for the type
           to be missing if the param is an anonymous method param. *)
  match syntax node with
  | ParameterDeclaration p ->
    if is_strict &&
        (parent_is_function parents) &&
        is_missing (param_type p) then
      let s = start_offset node in
      let e = end_offset node in
      [ SyntaxError.make s e SyntaxError.error2001 ]
    else
      [ ]
  | _ -> [ ]

let function_errors node _parents is_strict =
  match syntax node with
  | FunctionDeclaration f ->
    if is_strict && is_missing (function_type f) then
      (* Where do we want to report the error? Probably on the right paren. *)
      let rparen = function_right_paren f in
      let s = start_offset rparen in
      let e = end_offset rparen in
      [ SyntaxError.make s e SyntaxError.error2001 ]
    else
      [ ]
  | _ -> [ ]

let find_syntax_errors node is_strict =
  let folder acc node parents =
    let param_errors = parameter_errors node parents is_strict in
    let func_errors = function_errors node parents is_strict in
    let errors = func_errors @ param_errors @ acc.errors in
    { errors } in
  let acc = SyntaxUtilities.parented_fold_pre folder { errors = [] } node in
  acc.errors
