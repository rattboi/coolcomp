/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
    if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
        YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

int nest_comm_level = 0;
bool string_contains_null = false;

%}

/*
 * Define names for regular expressions here.
 */
WHITESPACE      [ \f\r\t\v]+
NEWLINE         [\n]
ML_COMM_START   \(\*
ML_COMM_END     \*\)
SL_COMMENT      --
DIGIT           [0-9]+
TYPEID          [A-Z][A-Za-z0-9_]*
OBJECTID        [a-z][A-Za-z0-9_]*
TRUE            t[Rr][Uu][Ee]
FALSE           f[Aa][Ll][Ss][Ee]
CLASS           [Cc][Ll][Aa][Ss][Ss]
ELSE            [Ee][Ll][Ss][Ee]
FI              [Ff][Ii]
IF              [Ii][Ff]
IN              [Ii][Nn]
INHERITS        [Ii][Nn][Hh][Ee][Rr][Ii][Tt][Ss]
LET             [Ll][Ee][Tt]
LOOP            [Ll][Oo][Oo][Pp]
POOL            [Pp][Oo][Oo][Ll]
THEN            [Tt][Hh][Ee][Nn]
WHILE           [Ww][Hh][Ii][Ll][Ee]
CASE            [Cc][Aa][Ss][Ee]
ESAC            [Ee][Ss][Aa][Cc]
OF              [Oo][Ff]
DARROW          =>
NEW             [Nn][Ee][Ww]
ISVOID          [Ii][Ss][Vv][Oo][Ii][Dd]
ASSIGN          <-
NOT             [Nn][Oo][Tt]
LE              <=
LBLOCK          \{
RBLOCK          \}
LPAREN          \(
RPAREN          \)
SEMICOLON       ;
COLON           :
COMMA           ,
DOT             \.
EQUAL           =
LT              <
ADD             \+
SUB             -
MULT            \*
DIV             \/
ATSIGN          @
TILDE           ~

QUOTE           \"

%x string sl_comment ml_comment

%%

 /*
  *  Nested comments
  */

<INITIAL,ml_comment,sl_comment>{
    {ML_COMM_START} { 
        if (nest_comm_level == 0) BEGIN(ml_comment); 
        nest_comm_level++;
    }
    {ML_COMM_END} { 
        if (!nest_comm_level) {
            yylval.error_msg = "Close comment parentheses didn't match open parentheses";
            return (ERROR);
        }
        if (--nest_comm_level == 0) BEGIN(INITIAL);
    }
}

<ml_comment>{
    <<EOF>> {
       yylval.error_msg = "EOF in comment";
       BEGIN(INITIAL);
       return (ERROR);
    } 
    \n curr_lineno++;
    . {}
}

<sl_comment>{
    [^\n]* 
    \n {
        curr_lineno++;
        if (nest_comm_level > 0)
            BEGIN(ml_comment);
        else
            BEGIN(INITIAL);
    }
}

<INITIAL>{
    {SL_COMMENT} BEGIN(sl_comment);
    {ML_COMM_END} { 
        yylval.error_msg = "Unmatched *)";
        return (ERROR);
    }
}
 /*
  *  The multiple-character operators.
  */
{DARROW}        { return (DARROW); }
{ASSIGN}        { return (ASSIGN); }
{LE}            { return (LE); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
{CLASS}         { return (CLASS); }
{ELSE}          { return (ELSE); }
{FI}            { return (FI); }
{IF}            { return (IF); }
{IN}            { return (IN); }
{INHERITS}      { return (INHERITS); }
{LET}           { return (LET); }
{LOOP}          { return (LOOP); }
{POOL}          { return (POOL); }
{THEN}          { return (THEN); }
{WHILE}         { return (WHILE); }
{CASE}          { return (CASE); }
{ESAC}          { return (ESAC); }
{OF}            { return (OF); }
{NEW}           { return (NEW); }
{ISVOID}        { return (ISVOID); }
{NOT}           { return (NOT); }
{TRUE} {
    cool_yylval.boolean = true;
    return (BOOL_CONST);
}
{FALSE} { 
    cool_yylval.boolean = false;
    return (BOOL_CONST);
}

{DIGIT} {
     cool_yylval.symbol = inttable.add_string(yytext);
     return (INT_CONST); 
}

{TYPEID} {
     cool_yylval.symbol = idtable.add_string(yytext);
     return (TYPEID); 
}

{OBJECTID} {
     cool_yylval.symbol = idtable.add_string(yytext);
     return (OBJECTID); 
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */

{QUOTE} { string_buf_ptr = string_buf; BEGIN(string); }
<string>{
    \0   string_contains_null = true;
    \\n  *string_buf_ptr++ = '\n';
    \\t  *string_buf_ptr++ = '\t';
    \\b  *string_buf_ptr++ = '\b';
    \\f  *string_buf_ptr++ = '\f';  
    \\\n { curr_lineno++; *string_buf_ptr++ = '\n'; }
    \\\\ *string_buf_ptr++ = '\\';
    \\.  yytext++; *string_buf_ptr++ = *yytext;
    {QUOTE} { 
        BEGIN(INITIAL); 
        if (string_contains_null) {
            string_contains_null = false;
            yylval.error_msg = "String contains null character";
            return (ERROR);
        }
        
        *string_buf_ptr = '\0';
        cool_yylval.symbol = stringtable.add_string(string_buf);
        return (STR_CONST);
    }
    \n {
        yylval.error_msg = "Unterminated string constant";
        curr_lineno++;
        BEGIN(INITIAL);
        return (ERROR);
    }
    <<EOF>> {
       yylval.error_msg = "EOF in string constant";
       BEGIN(INITIAL);
       return (ERROR);
    }
    [^\\\n\"\0]+ { 
       char *yptr = yytext;
                 
       while ( *yptr )
       *string_buf_ptr++ = *yptr++;
    }
}

{WHITESPACE}    { }
{NEWLINE}       { curr_lineno++; }
{LBLOCK}        { return '{'; }
{RBLOCK}        { return '}'; }
{LPAREN}        { return '('; }
{RPAREN}        { return ')'; }
{SEMICOLON}     { return ';'; }
{COLON}         { return ':'; }
{COMMA}         { return ','; }
{DOT}           { return '.'; }
{EQUAL}         { return '='; }
{LT}            { return '<'; }
{ADD}           { return '+'; }
{SUB}           { return '-'; }
{MULT}          { return '*'; }
{DIV}           { return '/'; }
{ATSIGN}        { return '@'; }
{TILDE}         { return '~'; }

. { char* invalid = new char[2];
    strcpy(invalid, yytext);
    cool_yylval.error_msg = invalid; 
    return (ERROR);
  }
%%
