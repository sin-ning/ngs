%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "ngs.h"
#include "compile.h"

// handle warnings - start
int yylex();
int yyerror();
// handle warnings - end

#define NODE(name) \
	ast_node *name = calloc(sizeof(*name), 1); \
	DEBUG_PARSER("Allocated ast_node at %p\n", name);
#define NODET(name, type_) NODE(name); name->type = type_; DEBUG_PARSER("ast_node %p has type %d\n", name, name->type)
#define SET_LOC(src) \
	yyloc.first_line   = src.first_line; \
	yyloc.first_column = src.first_column; \
	yyloc.last_line    = src.first_column; \
	yyloc.last_column  = src.last_column;
%}

%define api.pure full
/* cheat a little: supposed to be scanner_t scanner */
%parse-param { void * scanner }
%parse-param { ast_node ** result }
%lex-param   { void * scanner }
%locations

// Symbols.
%union
{
	int      number;
	char     *name;
	ast_node *ast_node;
};

%token EXPRESSIONS_DELIMITER
%token EQUALS
%token FOR
%token WHILE

%token <name> BINOP
%token <name> IDENTIFIER
%token <number> NUMBER

%type <ast_node> assignment
%type <ast_node> call
%type <ast_node> expression
%type <ast_node> expressions
%type <ast_node> for
%type <ast_node> binop
%type <ast_node> identifier
%type <ast_node> number
%type <ast_node> top_level
%type <ast_node> top_level2

/*TODO: intern symbols*/

%%

top_level: top_level2 {
	 DEBUG_PARSER("top_level $1 %p\n", $1);
	 *result = $1;
}

top_level2:
		 expressions;

assignment: identifier EQUALS expression {
		 DEBUG_PARSER("assignment $1 %p $3 %p\n", $1, $3);
		 NODET(ret, ASSIGNMENT_NODE);
		 $1->next_sibling = $3;
		 ret->first_child = $1;
		 $$ = ret;
}


identifier: IDENTIFIER {
		 DEBUG_PARSER("identifier $1 %p name=%s\n", $1, $1);
		 NODET(ret, IDENTIFIER_NODE);
		 ret->name = $1;
		 SET_LOC(@1);
		 $$ = ret;
}

expressions:
		expressions EXPRESSIONS_DELIMITER expression {
			DEBUG_PARSER("expressions $1 %p $3 %p\n", $1, $3);
			$1->last_child->next_sibling = $3;
			$1->last_child = $3;
			$$ = $1;
		}
		| expression {
			NODET(ret, EXPRESSIONS_NODE);
			ret->first_child = $1;
			ret->last_child = $1;
			$$ = ret;
		};

expression: assignment | binop | number | identifier | call | for;

binop: expression BINOP expression {
		DEBUG_PARSER("expression $1 %p $3 %p\n", $1, $3);
		NODET(ret, CALL_NODE);
		NODET(id, IDENTIFIER_NODE);
		$1->next_sibling = $3;
		id->next_sibling = $1;
		id->name = $2;
		ret->first_child = id;
		SET_LOC(@2);
		$$ = ret;
}

call: expression '(' expression ')' {
		NODET(ret, CALL_NODE);
		ret->first_child = $1;
		ret->first_child->next_sibling = $3;
		$$ = ret;
}

for: FOR expression expression expression expression {
		NODET(ret, FOR_NODE);
		$2->next_sibling = $3;
		$3->next_sibling = $4;
		$4->next_sibling = $5;
		ret->first_child = $2;
		$$ = ret;
}

number: NUMBER { NODET(ret, NUMBER_NODE); ret->number = $1; $$ = ret; }

%%