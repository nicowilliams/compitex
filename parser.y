/***************************************************************************
 *  
 *                    ___                _ _____   __  __
 *                   / __|___ _ __  _ __(_)_   _|__\ \/ /
 *                  | (__/ _ \ '  \| '_ \ | | |/ -_)>  < 
 *                   \___\___/_|_|_| .__/_| |_|\___/_/\_\
 *                                 |_|                  
 *
 * Copyright (C) 2012 - 2017, Mohamed Tarek El-Haddad <mtarek16@gmail.com>.
 *
 * This software is licensed as described in the LICENSE file, which
 * you should have received as part of this distribution.
 *
 * You may opt to use, copy, modify, merge, publish, distribute and/or sell
 * copies of the Software, and permit persons to whom the Software is
 * furnished to do so, under the terms of the COPYING file.
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied.
 *
 ***************************************************************************/
%{ 
#include <stdio.h> 
#include <stdlib.h> 
#include <stdarg.h> 
#include <string.h>
#include "parser.h" 

int sym[26];                             /* symbol table */ 
%} 

%union { 
	double dValue;                      /* double value */ 
	char* str;                          /* string value */ 
	nodeType *nPtr;                     /* node pointer */ 
}; 
%token <dValue> REAL

%token <str> VARIABLE
%token <str> SIN COS TAN
%token <str> SEC CSC COT
%token <str> ARCSIN ARCCOS ARCTAN
%token <str> SINH COSH TANH
%token <str> LN LOG LOGB
%token WHILE IF PRINT FRAC MUL SUM SQRT BAR LEFT RIGHT
%nonassoc IFX 
%nonassoc ELSE 

%left GE LE EQ NE '>' '<' 
%left '+' '-' 
%left MUL '/' 
%right '^'
%nonassoc LN LOG LOGB
%nonassoc SIN COS TAN SEC CSC COT ARCSIN ARCCOS ARCTAN SINH COSH TANH
%nonassoc UMINUS 

%type <nPtr> stmt expr stmt_list ident funcs

/*
 * The LOGB rule causes 11 shift-reduce conflicts (which are resolved by
 * taking the shift).  Thus \log_{3}a+b means the logarithm base three of
 * (a+b), not b plus the logarithm base 3 of a.
 *
 * The trig functions also have this problem, and cause another 11
 * shift-reduce conflicts, and another 11 more for the exponentiated
 * trigonometric functions.  Thus \sin a+b is the sine of (a+b), not b
 * plus the sine of a.  And so on.
 *
 * The sum form also has this problem, which adds yet another 11
 * shift-reduce conflicts.
 */
%expect 44

%% 

program: 
   function                        { return(0); } 
   ; 

function: 
    function stmt                  { ex($2); freeNode($2);} 
  | /* NULL */ 
   ; 

stmt: 
    ';'                            { $$ = opr(';', 2, NULL, NULL); } 
  | expr ';'                       { $$ = $1; } 
  | PRINT expr ';'                 { $$ = opr(PRINT, 1, $2); } 
  | expr '=' expr ';'              { $$ = opr('=', 2, $1, $3); }
  | WHILE '(' expr ')' stmt { $$ = opr(WHILE, 2, $3, $5); } 
  | IF '(' expr ')' stmt %prec IFX { $$ = opr(IF, 2, $3, $5); } 
  | IF '(' expr ')' stmt ELSE stmt 
                                   { $$ = opr(IF, 3, $3, $5, $7); } 
  | '{' stmt_list '}'              { $$ = $2; } 
     ; 

stmt_list: 
    stmt                       { $$ = $1; } 
  | stmt_list stmt              { $$ = opr(';', 2, $1, $2); } 
  ; 

ident:
	REAL                        { $$ = con($1); }
  | VARIABLE                    { $$ = id($1); } 
  ;

funcs:
    SIN     { $$ = id("sin"); }
  | COS     { $$ = id("cos"); }
  | TAN     { $$ = id("tan"); }
  | SEC     { $$ = id("sec"); }
  | CSC     { $$ = id("csc"); }
  | COT     { $$ = id("cot"); }
  | ARCSIN  { $$ = id("asin"); }
  | ARCCOS  { $$ = id("acos"); }
  | ARCTAN  { $$ = id("atan"); }
  | SINH    { $$ = id("sinh"); }
  | COSH    { $$ = id("cosh"); }
  | TANH    { $$ = id("tanh"); }

expr:
    ident
  | BAR '{' VARIABLE '}'		{
									char tmp[32];
									sprintf(tmp, "%s_bar", $3);
									$$ = id(tmp);
								}
  | '-' expr %prec UMINUS 		{ $$ = opr(UMINUS, 1, $2); } 
  | expr '+' expr               { $$ = opr('+', 2, $1, $3); }
  | expr '-' expr               { $$ = opr('-', 2, $1, $3); } 
  | expr MUL expr               { $$ = opr('*', 2, $1, $3); }
  | expr '/' expr               { $$ = opr('/', 2, $1, $3); }
  | FRAC '{'expr'}' '{'expr'}'  { $$ = opr('/', 2, $3, $6); }
  | SUM '{'VARIABLE '=' expr '}' '^' '{'expr'}' expr
								{ $$ = opr(SUM, 4, id($3), $5, $9, $11);}
  | SUM '{'VARIABLE '=' expr '}' '^' '{'expr'}''{'expr'}'     
								{ $$ = opr(SUM, 4, id($3), $5, $9, $12);}
  | SQRT '{' expr '}'			{ $$ = opr('s', 1, $3); }
  | SQRT '[' REAL ']''{' expr '}'			
								{ $$ = opr('^', 2, $6, con(1/$3)); }

  | LN expr                     { $$ = opr('c', 2, id("log"), $2); }
  | LOG expr                    { $$ = opr('c', 2, id("log"), $2); }
  | LOGB '{' expr '}' expr      { $$ = opr('C', 3, id("logB"), $3, $5); }

  | funcs expr                      { $$ = opr('c', 2, $1, $2); }
  | funcs '^' '{' expr '}' expr     { $$ = opr('C', 3, $1, $4, $6); }

  | LEFT '{' expr RIGHT '}'			{ $$ = $3; }

  | expr '^' '{' expr '}'       { $$ = opr('^', 2, $1, $4); }
  | expr '<' expr               { $$ = opr('<', 2, $1, $3); } 
  | expr '>' expr               { $$ = opr('>', 2, $1, $3); } 
  | expr GE expr                { $$ = opr(GE, 2, $1, $3); } 
  | expr LE expr                { $$ = opr(LE, 2, $1, $3); } 
  | expr NE expr                { $$ = opr(NE, 2, $1, $3); } 
  | expr EQ expr                { $$ = opr(EQ, 2, $1, $3); } 
  | '(' expr ')'                { $$ = $2; } 
  | ident ident					{ $$ = opr('*', 2, $1, $2); }
  | ident '(' expr ')'		{ $$ = opr('*', 2, $1, $3); }
  | '(' expr ')' ident			{ $$ = opr('*', 2, $2, $4); }
  | '(' expr ')' '(' expr ')'	{ $$ = opr('*', 2, $2, $5); }
  | error						{ printf("%d: Error at (%c)\n", lineno, yychar);}	
  ; 

%% 

#define SIZEOF_NODETYPE ((char *)&p->con - (char *)p) 

nodeType *con(double value) { 
     nodeType *p; 
     size_t nodeSize; 

     /* allocate node */ 
     nodeSize = SIZEOF_NODETYPE + sizeof(conNodeType); 
     if ((p = (nodeType*)malloc(nodeSize)) == NULL) 
          yyerror("out of memory"); 

     /* copy information */ 
     p->type = typeCon; 
     p->con.value = value; 

     return p; 
} 


nodeType *id(char* s) { 
     nodeType *p; 
     size_t nodeSize; 

     /* allocate node */ 
     nodeSize = SIZEOF_NODETYPE + sizeof(idNodeType); 
      if ((p = (nodeType*)malloc(nodeSize)) == NULL) 
            yyerror("out of memory"); 

      /* copy information */ 
      p->type = typeId; 
      p->id.s = strdup(s); 

      return p; 
} 

nodeType *opr(int oper, int nops, ...) { 
      va_list ap; 
      nodeType *p; 
      size_t nodeSize; 
      int i; 

      /* allocate node */ 
      nodeSize = SIZEOF_NODETYPE + sizeof(oprNodeType) + 
            (nops - 1) * sizeof(nodeType*); 
      if ((p = (nodeType*)malloc(nodeSize)) == NULL) 
            yyerror("out of memory"); 

      /* copy information */ 
      p->type = typeOpr; 
      p->opr.oper = oper; 
      p->opr.nops = nops; 
      va_start(ap, nops); 
      for (i = 0; i < nops; i++) 
            p->opr.op[i] = va_arg(ap, nodeType*); 
      va_end(ap); 
      return p; 
} 

void freeNode(nodeType *p) { 
      int i; 

      if (!p) return; 
      if (p->type == typeOpr) { 
            for (i = 0; i < p->opr.nops; i++) 
                 freeNode(p->opr.op[i]); 
      } 
      free (p); 
} 

void yyerror(char *s) { 
      fprintf(stdout, "%s\n", s); 
} 

int parse(FILE *out, FILE *in) {
      scan_init(out, in);
      yyparse();
      return 0; 
}
	 
