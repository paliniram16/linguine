
%{
open CoreAst
open GatorAst
open Str

exception ParseException of string
%}

(* Tokens *)

%token EOF
%token <int> NUM
%token <float> FLOAT
%token <string> ID
%token <string> STRING
%token PLUS
%token MINUS
%token TIMES
%token DIV
%token CTIMES
%token LBRACK
%token RBRACK
%token LPAREN
%token RPAREN
%token GETS
%token IN
%token OUT
%token AS
%token INC
%token DEC
%token PLUSEQ
%token MINUSEQ
%token TIMESEQ
%token DIVEQ
%token CTIMESEQ
%token EQ
%token LEQ
%token GEQ
%token AND
%token OR
%token NOT
%token COMMA
%token DOT
%token USING
%token PROTOTYPE
%token OBJECT
%token COORDINATE
%token DIMENSION
%token FRAME
%token TYP
%token CANON
%token IS
%token HAS
%token THIS
%token WITH
%token TRUE
%token FALSE
%token IF
%token ELSE
%token ELIF
%token FOR
%token SKIP
%token PRINT
%token SEMI
%token INTTYP
%token FLOATTYP
%token STRINGTYP
%token BOOLTYP
%token AUTOTYP
%token LBRACE
%token RBRACE
%token RETURN
%token VOID
%token DECLARE
%token COLON
%token GENTYPE
%token LWICK
%token RWICK
%token CONST
%token ATTRIBUTE
%token UNIFORM
%token VARYING
%token POUND

(* Precedences *)

%left ID THIS
%left AND OR
%left NOT EQ LEQ GEQ LBRACK 
%left LWICK RWICK 

%left PLUS MINUS
%left TIMES DIV CTIMES 
%left AS IN
%left DOT

(* After declaring associativity and precedence, we need to declare what
   the starting point is for parsing the language.  The following
   declaration says to start with a rule (defined below) named [prog].
   The declaration also says that parsing a [prog] will return an OCaml
   value of type [GatorAst.expr]. *)

%start main
(* The explicit types of some key parser expressions to help with debugging *)
%type <GatorAst.prog> main
%type <GatorAst.exp> exp
%type <GatorAst.comm> comm  
%type <GatorAst.term> term 

(* The following %% ends the declarations section of the grammar definition. *)

%%

main:
  | t = node(term)+; EOF;
    { t }

let terminated_list(X, Y) ==
  | y = Y;
    { ([], y) }
  | x = X+; y = Y;
    <>

let oplist(X) ==
  | x = X?;
    { match x with | Some y -> y | None -> [] }

let combined(A, B) == a = A; b = B; { (a, b) }
let fst(T) == (a, b) = T; { a }
let snd(T) == (a, b) = T; { b }
let node(T) == t = T; { (t, $startpos) }

let term ==
  | USING; s = STRING; SEMI;
    <Using>
  | POUND; s = STRING; SEMI;
    <ExactCode>
  | PROTOTYPE; x = ID; LBRACE; p = list(node(prototype_element)); RBRACE;
    <Prototype>
  | m = modification*; COORDINATE; x = ID; COLON; p = ID;
    LBRACE; c = list(node(coordinate_element)); RBRACE;
    <Coordinate>
  | FRAME; x = ID; HAS; DIMENSION; d = dexp; SEMI;
    <Frame>
  | (m, t) = terminated_list(modification, typ); x = ID; SEMI; 
    { GlobalVar(m, BuiltIn, t, x, None) }
  | m = modification*; TYP; x = ID; SEMI;
    { Typ(m, x, AnyTyp) }
  | m = modification*; TYP; x = ID; IS; t = typ; SEMI;
    <Typ>
  | m = modification*; sq = storage_qual; t = typ;
    x = ID; v = preceded(GETS, node(exp))?; SEMI; 
    <GlobalVar>
  | f = fn;
    <Fn>

let prototype_element ==
  | m = modification*; OBJECT; x = ID; t = snd(combined(IS, typ))?; SEMI;
    <ProtoObject>
  | f = fn_typ; SEMI;
    <ProtoFn>

let modification ==
  | WITH; t = typ; r = separated_list(COMMA, ID); COLON;
    <With>
  | CANON;
    { Canon }
  | DECLARE;
    { External }

let coordinate_element ==
  | m = modification*; OBJECT; x = ID; IS; t = typ; SEMI;
    <CoordObjectAssign>
  | f = fn;
    <CoordFn>

let parameter == 
  | (ml, t) = terminated_list (modification, typ); x = ID;
    { (ml, t, x) }

let parameters(L, P, R) ==
  | x = delimited(L, separated_list(COMMA, P), R); <>

let arguments ==
  | x = parameters(LPAREN, node(exp), RPAREN); <>

let id_expanded ==
  | x = ID; <>
  | NOT; { "!" }
  | x = unop_effectful; <>
  | x = infix; <>

let fn_typ ==
  | (m, t) = terminated_list(modification, typ); x = id_expanded; 
    params = parameters(LPAREN, parameter, RPAREN);
    { (m, t, x, params, $startpos) }

let fn ==
  | f = fn_typ; LBRACE; cl = acomm*; RBRACE; <>
  | f = fn_typ; SEMI; { (f, []) }

let acomm ==
  | c = comm;
    { (c, $startpos) }

let comm ==
  | c = comm_block;
    <>
  | c = comm_element; SEMI;
    <>

let if_block(delim) ==
  | delim; LPAREN; b = node(exp); RPAREN; LBRACE; c = acomm*; RBRACE;
    <>

let comm_block ==
  | i = if_block(IF); el = if_block(ELIF)*; 
    e = option(preceded(ELSE, delimited(LBRACE, list(acomm), RBRACE)));
    <If>
  | FOR; LPAREN; c1 = node(comm_element); SEMI; b = node(exp); SEMI; c2 = node(comm_element); RPAREN;
    LBRACE; cl = node(comm)*; RBRACE; 
    <For>

let assignop ==
  | PLUSEQ;
    { "+" }
  | MINUSEQ;
    { "-" }
  | TIMESEQ;
    { "*" }
  | DIVEQ;
    { "/" }
  | CTIMESEQ;
    { ".*" }

let comm_element == 
  | SKIP;
    { Skip }
  | (m, t) = terminated_list(modification, typ); x = ID; GETS; e = node(exp); 
    { Decl(m, t, x, e) }
  | e = node(effectful_exp);
    < Exp >
  | x = node(assign_exp); GETS; e = node(exp); 
    < Assign >
  | x = node(assign_exp); a = assignop; e = node(exp); 
    < AssignOp >
  | PRINT; e = node(exp); 
    < Print >
  | RETURN; e = node(exp)?;
    < Return >
  | POUND; s = STRING; 
    < ExactCodeComm >

let dexp :=
  | d1 = dexp; PLUS; d2 = dexp;
    <DimPlus>
  | n = NUM;
    <DimNum>
  | x = ID;
    <DimVar>

let typ :=
  | AUTOTYP;
    { AutoTyp }
  | BOOLTYP;
    { BoolTyp }
  | FLOATTYP;
    { FloatTyp }
  | INTTYP;
    { IntTyp }
  | STRINGTYP;
    { StringTyp }
  | VOID;
    { UnitTyp }
  | THIS;
    { ThisTyp }
  | FRAME; LPAREN; RPAREN;
    { AnyFrameTyp }
  | FRAME; LPAREN; d = dexp; RPAREN;
    <FrameTyp>
  | t = typ; LBRACK; dl = separated_list(combined(LBRACK, RBRACK), dexp); RBRACK;
    { List.fold_right (fun d acc -> ArrTyp(acc, d)) dl t }
  | t1 = typ; DOT; t2 = typ;
    <MemberTyp>
  | x = ID; pt = parameters(LWICK, typ, RWICK);
    <ParTyp>
  | THIS; pt = parameters(LWICK, typ, RWICK);
    { ParTyp("this", pt) }
  | x = ID; /* explicit for clarity and to help out the parser */
    { ParTyp(x, []) }
  | GENTYPE; 
    { GenTyp }

let storage_qual ==
  | IN;
    { InQual }
  | OUT;
    { Out }
  | CONST;
    { Const }
  | ATTRIBUTE;
    { Attribute }
  | UNIFORM;
    { Uniform }
  | VARYING;
    { Varying }

let value ==
  | b = bool;
    <Bool>
  | i = NUM;
    <Num>
  | f = FLOAT;
    <Float>
  | s = STRING;
    <StringVal>

let bool ==
  | TRUE;
    { true }
  | FALSE;
    { false }

let exp:=
  | LPAREN; a = exp; RPAREN;
    <>
  | v = value;
    <Val>
  | e = assign_exp;
    <>
  | op = unop; e = node(exp);
    { FnInv(op, [], [e]) }
  | e1 = node(exp); op = infix; e2 = node(exp);
    { FnInv(op, [], [e1; e2]) }
  | e = effectful_exp;
    <>
  | LBRACK; e = separated_list(COMMA, node(exp)); RBRACK; 
    <Arr>
  | e = node(exp); AS; t = typ;
    <As>
  | e = node(exp); IN; t = typ;
    <In>
  | e = node(exp); DOT; s = ID;
    { FnInv("swizzle",[],[Var s, $startpos; e]) }

/* A strict subset of expressions that can have effects, separated to help parse commands */
/* In other words, we syntactically reject commands that have no effect on the program */
/* See comm_element for more details */
let effectful_exp ==
  | x = ID; p = oplist(parameters(LWICK, typ, RWICK)); a = arguments;
    <FnInv>
  | op = unop_effectful; x = node(ID);
    { FnInv(op, [], [(Var (fst x), snd x)]) }
  | x = node(ID); op = unop_effectful;
    { FnInv(op, [], [(Var (fst x), snd x)]) }

/* A strict subset of expressions that can be in assignments to help the parser */
/* We syntactically reject assignments to anything but Indexes and Vars */
/* Note that indexes may _recurse_ on expressions, this is fine */
let assign_exp ==
  | x = ID;
    <Var>
  | x = ID; LBRACK; e = node(exp); RBRACK;
    { Index((Var x, $startpos), e) }

let unop ==
  /* NOTE: if you update this, update id_extended, which is built to avoid MINUS conflicts */
  | NOT; { "!" }
  | MINUS; { "-" }

let unop_effectful ==
  | INC; {"++"}
  | DEC; {"--"}

let infix ==
  | PLUS; { "+" }
  | TIMES; { "*" }
  | MINUS; { "-" }
  | DIV; { "/" }
  | LWICK; { "<" }
  | RWICK; { ">" }
  | CTIMES; { ".*" }
  | EQ; { "==" }
  | LEQ; { "<=" }
  | GEQ; { ">=" }
  | OR; { "||" }
  | AND; { "&&" }

%%