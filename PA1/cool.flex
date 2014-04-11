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
int str_length = 0;

void reset_str_buffer() {
    str_length = 0;
    string_buf_ptr = string_buf;
}

void add_to_str(char c) {
    str_length++;
    *string_buf_ptr++ = c;
}

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
        nest_comm_level--;
        if (nest_comm_level == 0) BEGIN(INITIAL);
    }
}

<ml_comment>{
    <<EOF>> {
       BEGIN(INITIAL);
       yylval.error_msg = "EOF in comment";
       return (ERROR);
    } 
    \n curr_lineno++;
    . { }
}

<sl_comment>{
    [^\n]*  { }
    \n {
        BEGIN(INITIAL);
        curr_lineno++;
    }
}

<INITIAL>{
    {SL_COMMENT} BEGIN(sl_comment);
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

{QUOTE} { BEGIN(string); reset_str_buffer(); }
<string>{
    \0   string_contains_null = true;
    \\\0 string_contains_null = true;
    \\n  add_to_str('\n');
    \\t  add_to_str('\t');
    \\b  add_to_str('\b');
    \\f  add_to_str('\f');
    \\\n add_to_str('\n'); curr_lineno++;
    \\\\ add_to_str('\\');
    \\.  add_to_str(*(++yytext));
    {QUOTE} { 
        BEGIN(INITIAL); 
        if (string_contains_null) {
            string_contains_null = false;
            yylval.error_msg = "String contains null character";
            return (ERROR);
        }

        if (str_length >= MAX_STR_CONST) {
            yylval.error_msg = "String contains too long";
            return (ERROR);
        }
        
        add_to_str('\0');
        cool_yylval.symbol = stringtable.add_string(string_buf);
        return (STR_CONST);
    }
    \n {
        BEGIN(INITIAL);
        curr_lineno++;
        yylval.error_msg = "Unterminated string constant";
        return (ERROR);
    }
    <<EOF>> {
       BEGIN(INITIAL);
       yylval.error_msg = "EOF in string constant";
       return (ERROR);
    }
    [^\\\n\"\0]+ { 
       char *yptr = yytext;
                 
       while ( *yptr )
           add_to_str(*yptr++);
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
