/*****************************************************************************/
/**  Cabecera del compilador: definiciones de constantes, variables y       **/
/**  estructuras de datos compartidas por los modulos de C--.               **/
/*****************************************************************************/
#ifndef _HEADER_H
#define _HEADER_H

/****************************************************** Constantes generales */
#define TRUE  1
#define FALSE 0

/**Constantes simbólicas**/
#define TALLA_TIPO_SIMPLE 1
#define TALLA_SEGENLACES 2

/**Variables globales**/
extern int verTdS;

/******************************************************* Estructuras de datos */
//Estructuras para atributos para struct y dominios de función
typedef struct registro {
    int ref;
    int talla;
} Reg;

//Estructura para atributos de las expresiones
typedef struct expresion {
    int tipo;
    int d;
} Exp;

//Estructura para atributos de los operadores
typedef struct operador {
    int tipo;
    int op;
} Op;

//Estructura para guardar referencia de Lans
typedef struct ref{
   int ref1;
   int ref2;
} Ref;

/************************************* Variables externas definidas en el AL */
extern int yylex();
extern int yyparse();

extern FILE *yyin;                           /* Fichero de entrada           */
extern int   yylineno;                 /* Numero de linea asociado a un token*/
extern char *yytext;                         /* Patron detectado             */

/********* Funciones y variables externas definidas en el Programa Principal */
extern void yyerror(const char * msg);      /* Tratamiento de errores       */

extern int verbosidad;                   /* Flag si se desea una traza       */
extern int numErrores;                   /* Contador del numero de errores   */

#endif  /* _HEADER_H */
/*****************************************************************************/
/*****************************************************************************/
