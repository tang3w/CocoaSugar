#include <stdio.h>

#define YYSTYPE char *

#define COSSTYLE_INVALID -1
#define YY_DECL int COSStylelex (yyscan_t yyscanner, char **token_value)

typedef struct COSStyleCtx COSStyleCtx;

struct COSStyleAST {
    int nodeType;
    void *nodeValue;
    struct COSStyleAST *l;
    struct COSStyleAST *r;
    void *data;
};

struct COSStyleCtx {
    int result;
    struct COSStyleAST *ast;
};

typedef struct COSStyleAST COSStyleAST;

struct COSStyleDecl {
    char *name;
    char *value;
};

typedef struct COSStyleDecl COSStyleDecl;

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

void *COSStyleParseAlloc(void *(*mallocProc)(size_t));
void COSStyleParse(void *parser, int token, char *value, COSStyleCtx *cxt);
void COSStyleParseFree(void *p, void (*freeProc)(void*));

void COSStyleCtxInit(COSStyleCtx *ctx);
void COSStylePrintAstAsDot(COSStyleAST *astp);
void COSStyleCtxFree(COSStyleCtx ctx);
