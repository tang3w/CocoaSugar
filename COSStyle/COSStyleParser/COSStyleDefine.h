#include <stdio.h>

#define YYSTYPE char *

#define COSSTYLE_INVALID -1
#define YY_DECL int COSStylelex (yyscan_t yyscanner, char **token_value)

enum COSStyleNodeType {
    COSStyleNodeTypeVal = 1,
    COSStyleNodeTypeProp,
    COSStyleNodeTypeDecl,
    COSStyleNodeTypeDeclList,
    COSStyleNodeTypeCls,
    COSStyleNodeTypeClsList,
    COSStyleNodeTypeSel,
    COSStyleNodeTypeSelList,
    COSStyleNodeTypeRule,
    COSStyleNodeTypeRuleList,
    COSStyleNodeTypeSheet,
};

typedef enum COSStyleNodeType COSStyleNodeType;

enum COSStyleNodeValType {
    COSStyleNodeValTypeID = 1,
    COSStyleNodeValTypeString,
    COSStyleNodeValTypeHex,
    COSStyleNodeValTypeExpression,
    COSStyleNodeValTypeSize,
};

typedef enum COSStyleNodeValType COSStyleNodeValType;

struct COSStyleAST {
    COSStyleNodeType nodeType;
    void *nodeValue;
    COSStyleNodeValType nodeValueType;
    struct COSStyleAST *l;
    struct COSStyleAST *r;
    void *data;
};

typedef struct COSStyleAST COSStyleAST;

struct COSStyleCtx {
    int result;
    struct COSStyleAST *ast;
};

typedef struct COSStyleCtx COSStyleCtx;

void *COSStyleParseAlloc(void *(*mallocProc)(size_t));
void COSStyleParse(void *parser, int token, char *value, COSStyleCtx *cxt);
void COSStyleParseFree(void *p, void (*freeProc)(void*));

void COSStyleCtxInit(COSStyleCtx *ctx);
void COSStylePrintAstAsDot(COSStyleAST *astp);
void COSStyleCtxFree(COSStyleCtx ctx);
