/* A Bison parser, made by GNU Bison 3.0.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2013 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

#ifndef YY_CSLAYOUT_CSLAYOUTPARSER_H_INCLUDED
# define YY_CSLAYOUT_CSLAYOUTPARSER_H_INCLUDED
/* Debug traces.  */
#ifndef CSLAYOUTDEBUG
# if defined YYDEBUG
#if YYDEBUG
#   define CSLAYOUTDEBUG 1
#  else
#   define CSLAYOUTDEBUG 0
#  endif
# else /* ! defined YYDEBUG */
#  define CSLAYOUTDEBUG 0
# endif /* ! defined YYDEBUG */
#endif  /* ! defined CSLAYOUTDEBUG */
#if CSLAYOUTDEBUG
extern int cslayoutdebug;
#endif
/* "%code requires" blocks.  */
#line 20 "CSLayoutParser.y" /* yacc.c:1915  */

#define YYSTYPE CSLAYOUTSTYPE

#define YY_DECL int cslayoutlex \
    (YYSTYPE *yylval_param, yyscan_t yyscanner, CSLAYOUT_AST **astpp, int *argc)

struct CSLAYOUT_AST {
    int node_type;
    struct CSLAYOUT_AST *l;
    struct CSLAYOUT_AST *r;
    union {
        float number;
        float percentage;
        char *coord;
    } value;
    void *data;
};

typedef struct CSLAYOUT_AST CSLAYOUT_AST;

CSLAYOUT_AST *cslayout_create_ast(int type, CSLAYOUT_AST *l, CSLAYOUT_AST *r);

CSLAYOUT_AST *cslayout_parse_rule(char *rule, int *argc);
void cslayout_destroy_ast(CSLAYOUT_AST *astp);

#line 78 "CSLayoutParser.h" /* yacc.c:1915  */

/* Token type.  */
#ifndef CSLAYOUTTOKENTYPE
# define CSLAYOUTTOKENTYPE
  enum cslayouttokentype
  {
    CSLAYOUT_TOKEN_ATTR = 258,
    CSLAYOUT_TOKEN_NUMBER = 259,
    CSLAYOUT_TOKEN_PERCENTAGE = 260,
    CSLAYOUT_TOKEN_COORD = 261
  };
#endif

/* Value type.  */
#if ! defined CSLAYOUTSTYPE && ! defined CSLAYOUTSTYPE_IS_DECLARED
typedef CSLAYOUT_AST * CSLAYOUTSTYPE;
# define CSLAYOUTSTYPE_IS_TRIVIAL 1
# define CSLAYOUTSTYPE_IS_DECLARED 1
#endif



int cslayoutparse (void *scanner, CSLAYOUT_AST **astpp, int *argc);

#endif /* !YY_CSLAYOUT_CSLAYOUTPARSER_H_INCLUDED  */
