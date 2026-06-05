/*****************************************************************************/
/**  Analizador lexico (FLEX).                                              **/
/**  Proyecto academico de un compilador de C-- (curso 2023-2024).          **/
/**  Desarrollado por un equipo de 4 estudiantes.                           **/
/*****************************************************************************/

/*************************** Subseccion preambulo ***************************/

%{
#include <stdio.h>
#include <string.h>
#include "header.h"
#include "asin.h"

#define  retornar(x) {if (verbosidad) ECHO; return(x); }
%}


/************************* Subseccion de definiciones *************************/

/*-----------------------------------------------------------------------------
  Estas opciones evitan "warnings" innecesarios (noinput y nounput) y permiten 
  obtener el numero de linea actual en la variable global "yylineno".
-----------------------------------------------------------------------------*/
%option noinput       
%option nounput       
%option yylineno  

delimitador    [ \t]+
digito         [0-9]
constante      {digito}+("."{digito}*)?|{digito}*"."{digito}+    
id             [a-zA-Z][a-zA-Z0-9_]*  

/**************************** Subseccion de reglas ****************************/

%%
{delimitador}  { if (verbosidad) ECHO; }
"//".*         { if (verbosidad) ECHO; }
\n             { if (verbosidad) { ECHO; printf("  %d.- ", yylineno); } }

"bool"         { retornar (BOOL_);     }
"int"          { retornar (INT_);      }
"struct"       { retornar (STRUCT_);   }
"true"         { retornar (TRUE_);     }
"false"        { retornar (FALSE_);    }
"print"        { retornar (PRINT_);    }
"read"         { retornar (READ_);     }
"if"           { retornar (IF_);       }
"else"         { retornar (ELSE_);     }
"while"        { retornar (WHILE_);    }
"return"       { retornar (RETURN_);   }

"="	           { retornar (ASIG_);     }
"&&"	         { retornar (AND_);      }
"||"	         { retornar (OR_);       }
"!"	           { retornar (NOT_);      }
"=="	         { retornar (IGUAL_);    }
"!="	         { retornar (DIST_);     }
">"	           { retornar (MY_);       }
">="	         { retornar (MYIG_);     }
"<"	           { retornar (MN_);       }
"<="	         { retornar (MNIG_);     }
"+"	           { retornar (MAS_);      }
"-"            { retornar (MENOS_);    }
"*"            { retornar (POR_);      }
"/"            { retornar (DIV_);      }
"++"	         { retornar (MAS2_);     }
"--"           { retornar (MENOS2_);   }

"{"            { retornar (AL_);       }
"}"            { retornar (CL_);       }
"["            { retornar (AC_);       }
"]"            { retornar (CC_);       }
"("            { retornar (AP_);       }
")"            { retornar (CP_);       }
"."            { retornar (PTO_);      }
","            { retornar (COMA_);     }
";"            { retornar (PCOMA_);    }

{constante}    { yylval.cent = atoi(yytext); retornar (CTE_);   }
{id}           { yylval.ident = strdup(yytext); retornar (ID_); }
.	             { yyerror("Caracter desconocido");               }

%%


/********************** Subseccion de funciones de usuario **********************/
