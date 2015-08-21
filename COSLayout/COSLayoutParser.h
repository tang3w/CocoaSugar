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

#ifndef YY_COSLAYOUT_COSLAYOUTPARSER_H_INCLUDED
# define YY_COSLAYOUT_COSLAYOUTPARSER_H_INCLUDED
/* Debug traces.  */
#ifndef COSLAYOUTDEBUG
# if defined YYDEBUG
#if YYDEBUG
#   define COSLAYOUTDEBUG 1
#  else
#   define COSLAYOUTDEBUG 0
#  endif
# else /* ! defined YYDEBUG */
#  define COSLAYOUTDEBUG 0
# endif /* ! defined YYDEBUG */
#endif  /* ! defined COSLAYOUTDEBUG */
#if COSLAYOUTDEBUG
extern int coslayoutdebug;
#endif
/* "%code requires" blocks.  */
#line 18 "COSLayoutParser.y" /* yacc.c:1915  */

#define YYSTYPE COSLAYOUTSTYPE

#define YY_DECL int coslayoutlex \
    (YYSTYPE *yylval_param, yyscan_t yyscanner, COSLAYOUT_AST **astpp)

struct COSLAYOUT_AST {
    int node_type;
    struct COSLAYOUT_AST *l;
    struct COSLAYOUT_AST *r;
    union {
        float number;
        float percentage;
        char *coord;
    } value;
    void *data;
};

typedef struct COSLAYOUT_AST COSLAYOUT_AST;

COSLAYOUT_AST *coslayout_create_ast(int type, COSLAYOUT_AST *l, COSLAYOUT_AST *r);

int coslayout_parse_rule(char *rule, COSLAYOUT_AST **astpp);
void coslayout_destroy_ast(COSLAYOUT_AST *astp);

#line 78 "COSLayoutParser.h" /* yacc.c:1915  */

/* Token type.  */
#ifndef COSLAYOUTTOKENTYPE
# define COSLAYOUTTOKENTYPE
  enum coslayouttokentype
  {
    COSLAYOUT_TOKEN_ATTR = 258,
    COSLAYOUT_TOKEN_NUMBER = 259,
    COSLAYOUT_TOKEN_PERCENTAGE = 260,
    COSLAYOUT_TOKEN_PERCENTAGE_H = 261,
    COSLAYOUT_TOKEN_PERCENTAGE_V = 262,
    COSLAYOUT_TOKEN_COORD = 263
  };
#endif

/* Value type.  */
#if ! defined COSLAYOUTSTYPE && ! defined COSLAYOUTSTYPE_IS_DECLARED
typedef COSLAYOUT_AST * COSLAYOUTSTYPE;
# define COSLAYOUTSTYPE_IS_TRIVIAL 1
# define COSLAYOUTSTYPE_IS_DECLARED 1
#endif



int coslayoutparse (void *scanner, COSLAYOUT_AST **astpp);

#endif /* !YY_COSLAYOUT_COSLAYOUTPARSER_H_INCLUDED  */
