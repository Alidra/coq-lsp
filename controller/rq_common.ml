(************************************************************************)
(* Coq Language Server Protocol -- Common requests routines             *)
(* Copyright 2019 MINES ParisTech -- Dual License LGPL 2.1 / GPL3+      *)
(* Copyright 2019-2023 Inria      -- Dual License LGPL 2.1 / GPL3+      *)
(* Written by: Emilio J. Gallego Arias                                  *)
(************************************************************************)

(* XXX: this doesn't work for Unicode either... *)
(* Common with completion... refactor and make proper *)
let is_id_char x =
  ('a' <= x && x <= 'z')
  || ('A' <= x && x <= 'Z')
  || ('0' <= x && x <= '9')
  || x = '_' || x = '\'' || x = '.'

let rec find_start s c =
  if c <= 0 then 0
  else if not (is_id_char s.[c - 1]) then c
  else find_start s (c - 1)

let id_from_start s start =
  let l = String.length s in
  let rec end_of_id s c =
    if c >= l then c else if is_id_char s.[c] then end_of_id s (c + 1) else c
  in
  let end_ = end_of_id s start in
  (* Correct for last dot *)
  let end_ = if end_ > 1 && s.[end_ - 1] = '.' then end_ - 1 else end_ in
  if start < end_ then (
    let id = String.sub s start (end_ - start) in
    Fleche.Io.Log.trace "find_id" "found: %s" id;
    Some id)
  else None

let find_id s c =
  let start = find_start s c in
  Fleche.Io.Log.trace "find_id" "start: %d" start;
  id_from_start s start

let get_id_at_point ~contents ~point =
  let line, character = point in
  Fleche.Io.Log.trace "get_id_at_point" "l: %d c: %d)" line character;
  let { Fleche.Contents.lines; _ } = contents in
  if line <= Array.length lines then
    let line = Array.get lines line in
    let character =
      Lang.Utf.utf8_offset_of_utf16_offset ~line ~offset:character
    in
    find_id line character
  else None

let validate_line ~(contents : Fleche.Contents.t) ~line =
  if Array.length contents.lines > line then
    Some (Array.get contents.lines line)
  else None

let validate_column ~get char line =
  let length = Lang.Utf.length_utf16 line in
  if char < length then
    let char = Lang.Utf.utf8_offset_of_utf16_offset ~line ~offset:char in
    get line char
  else None

(* This returns a byte-based char offset for the line *)
let validate_position ~get ~contents ~point =
  let line, char = point in
  validate_line ~contents ~line |> fun l ->
  Option.bind l (validate_column ~get char)

let get_char_at_point_gen ~prev ~get ~contents ~point =
  if prev then
    let line, char = point in
    if char >= 1 then
      let point = (line, char - 1) in
      validate_position ~get ~contents ~point
    else (* Can't get previous char *)
      None
  else validate_position ~get ~contents ~point

let get_char_at_point ~prev ~contents ~point =
  let get line utf8_offset = Some (String.get line utf8_offset) in
  get_char_at_point_gen ~prev ~get ~contents ~point

let get_uchar_at_point ~prev ~contents ~point =
  let get line utf8_offset =
    let decode =
      Lang.Compat.OCaml4_14.String.get_utf_8_uchar line utf8_offset
    in
    if Lang.Compat.OCaml4_14.Uchar.utf_decode_is_valid decode then
      let str =
        String.sub line utf8_offset
          (Lang.Compat.OCaml4_14.Uchar.utf_decode_length decode)
      in
      Some (Lang.Compat.OCaml4_14.Uchar.utf_decode_uchar decode, str)
    else None
  in
  get_char_at_point_gen ~prev ~get ~contents ~point
